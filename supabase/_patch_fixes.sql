-- ============================================================
-- _patch_fixes.sql — VERİ KAYBI OLMADAN çalıştırılır (additive)
-- Mevcut DB'ye eksikleri ekler; hiçbir şeyi silmez, hesap gitmez.
-- SQL Editor'de tek seferde çalıştır.
-- ============================================================

-- 1) profiles INSERT politikası (kayıt sırasındaki 42501 hatasını çözer)
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

-- 2) Eski ekranların kullandığı uyumluluk kolonları
alter table public.profiles add column if not exists habit          text;
alter table public.profiles add column if not exists goal           text;
alter table public.profiles add column if not exists quit_date      timestamptz;
alter table public.profiles add column if not exists total_saved    numeric default 0;
alter table public.profiles add column if not exists lung_score     numeric default 10;
alter table public.profiles add column if not exists pack_price     numeric default 115;
alter table public.profiles add column if not exists pack_size      int default 20;
alter table public.profiles add column if not exists daily_baseline int default 20;

-- 3) Avatars storage bucket + politikaları
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true) on conflict (id) do nothing;
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');
drop policy if exists "avatars_auth_insert" on storage.objects;
create policy "avatars_auth_insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'avatars');
drop policy if exists "avatars_auth_update" on storage.objects;
create policy "avatars_auth_update" on storage.objects
  for update to authenticated using (bucket_id = 'avatars');

notify pgrst, 'reload schema';

-- 4) Çok-habit Home için birim maliyet
alter table public.user_habits add column if not exists unit_cost numeric default 0;
notify pgrst, 'reload schema';

-- ===== 010: herkese açık profil RPC'leri (habits + aktivite akışı) =====
-- ============================================================
-- 010 — Herkese açık profil: alışkanlıklar + aktivite akışı
--
-- Leaderboard'da bir kişiye tıklayınca profili, alışkanlıkları ve son
-- aktiviteleri görülebilsin diye. SECURITY DEFINER ile RLS bypass edilir,
-- yalnızca küratör edilmiş (herkese açık) alanlar döndürülür.
-- ============================================================

-- Bir kullanıcının aktif alışkanlıkları (habit detaylarıyla)
create or replace function public.get_user_habits_public(p_user_id uuid)
returns table (
  user_habit_id uuid,
  program_type text,
  start_value numeric,
  target_value numeric,
  current_daily_target numeric,
  current_streak int,
  longest_streak int,
  started_at timestamptz,
  slug text,
  title_tr text,
  title_en text,
  icon text,
  unit text,
  category_tag text
)
language sql
security definer
set search_path = public
as $$
  select uh.id, uh.program_type::text, uh.start_value, uh.target_value,
         uh.current_daily_target, uh.current_streak, uh.longest_streak,
         uh.started_at, h.slug, h.title_tr, h.title_en, h.icon, h.unit, h.category_tag
  from public.user_habits uh
  join public.habits h on h.id = uh.habit_id
  where uh.user_id = p_user_id and uh.is_active = true
  order by uh.started_at desc;
$$;

-- Son N aktivite: yeni habit (STARTED) + günlük log (LOG) + milestone (MILESTONE)
-- tek akışta, tarih/saate göre azalan.
create or replace function public.get_user_activity_feed(p_user_id uuid, p_limit int default 20)
returns table (
  kind text,
  ts timestamptz,
  slug text,
  title_tr text,
  title_en text,
  icon text,
  unit text,
  value numeric,
  is_success boolean,
  milestone_day int
)
language sql
security definer
set search_path = public
as $$
  select * from (
    select 'STARTED'::text as kind, uh.started_at as ts, h.slug, h.title_tr, h.title_en,
           h.icon, h.unit, null::numeric as value, null::boolean as is_success,
           null::int as milestone_day
    from public.user_habits uh
    join public.habits h on h.id = uh.habit_id
    where uh.user_id = p_user_id
    union all
    select 'LOG'::text, dl.created_at, h.slug, h.title_tr, h.title_en,
           h.icon, h.unit, dl.reported_value, dl.is_success, null::int
    from public.daily_logs dl
    join public.user_habits uh on uh.id = dl.user_habit_id
    join public.habits h on h.id = uh.habit_id
    where dl.user_id = p_user_id
    union all
    select 'MILESTONE'::text, ml.achieved_at, h.slug, h.title_tr, h.title_en,
           h.icon, h.unit, null::numeric, null::boolean, ml.milestone_day
    from public.milestone_logs ml
    join public.user_habits uh on uh.id = ml.user_habit_id
    join public.habits h on h.id = uh.habit_id
    where ml.user_id = p_user_id
  ) feed
  order by ts desc
  limit p_limit;
$$;

grant execute on function public.get_user_habits_public(uuid) to anon, authenticated;
grant execute on function public.get_user_activity_feed(uuid, int) to anon, authenticated;

-- ===== 011: aylık leaderboard skoru + habit başına skor =====
-- ============================================================
-- 011 — Leaderboard puanlaması (AYLIK) + profilde habit başına skor
--
-- Spec: leaderboard streak'e göre DEĞİL PUANA göre sıralanır ve HER AY
-- sıfırlanır. Aylık skoru ayrı bir kolon/cron yerine, o ayki kayıtlardan
-- hesaplıyoruz (kendiliğinden "sıfırlanır"):
--   aylık skor = bu ayki daily_logs.total_points + bu ayki combo bonusları
-- (total_points zaten Gemini zorluk katsayısı + streak çarpanı içeriyor.)
-- Streak yine user_habits.current_streak'te tutulur (kaybolmaz).
-- ============================================================

-- Birden çok kullanıcının aylık skorunu tek çağrıda döndürür (leaderboard için)
create or replace function public.get_monthly_scores(p_user_ids uuid[])
returns table(user_id uuid, monthly_score numeric)
language sql
security definer
set search_path = public
as $$
  select u.uid,
    coalesce((
      select sum(dl.total_points) from public.daily_logs dl
      where dl.user_id = u.uid
        and dl.log_date >= date_trunc('month', current_date)::date
    ), 0)
    + coalesce((
      select sum(c.combo_bonus_points) from public.combo_streak_logs c
      where c.user_id = u.uid
        and c.combo_date >= date_trunc('month', current_date)::date
    ), 0)
  from unnest(p_user_ids) as u(uid);
$$;

-- get_user_habits_public: habit başına skoru (habit_total_score) da döndür.
-- Dönen kolonlar değiştiği için önce DROP gerekiyor.
drop function if exists public.get_user_habits_public(uuid);
create or replace function public.get_user_habits_public(p_user_id uuid)
returns table (
  user_habit_id uuid,
  program_type text,
  start_value numeric,
  target_value numeric,
  current_daily_target numeric,
  current_streak int,
  longest_streak int,
  habit_total_score numeric,
  started_at timestamptz,
  slug text,
  title_tr text,
  title_en text,
  icon text,
  unit text,
  category_tag text
)
language sql
security definer
set search_path = public
as $$
  select uh.id, uh.program_type::text, uh.start_value, uh.target_value,
         uh.current_daily_target, uh.current_streak, uh.longest_streak,
         uh.habit_total_score, uh.started_at, h.slug, h.title_tr, h.title_en,
         h.icon, h.unit, h.category_tag
  from public.user_habits uh
  join public.habits h on h.id = uh.habit_id
  where uh.user_id = p_user_id and uh.is_active = true
  order by uh.habit_total_score desc, uh.started_at desc;
$$;

grant execute on function public.get_monthly_scores(uuid[]) to anon, authenticated;
grant execute on function public.get_user_habits_public(uuid) to anon, authenticated;

-- ===== 012: skor şeffaflığı + best_streak =====
-- ============================================================
-- 012 — Skor şeffaflığı + leaderboard streak = en yüksek habit serisi
--
-- 1) get_monthly_scores: aylık skora ek olarak best_streak döndürür
--    (best_streak = aktif habitler arasında en yüksek current_streak;
--     en yüksek habit bozulursa bir sonraki en yükseğe düşer, hepsi
--     sıfırlanırsa 0 olur — bu max() ile kendiliğinden olur).
-- 2) get_user_habits_public: habit skorunu daily_logs toplamından HESAPLAR
--    (kolon güncellenmemiş olsa bile 0 yerine gerçek puanı gösterir).
-- 3) get_habit_score_breakdown: bir habit'in puanının NASIL oluştuğunu
--    şeffaf gösterir (Gemini taban puanı, zorluk, seri çarpanı + bileşen
--    toplamları).
-- ============================================================

drop function if exists public.get_monthly_scores(uuid[]);
create or replace function public.get_monthly_scores(p_user_ids uuid[])
returns table(user_id uuid, monthly_score numeric, best_streak int)
language sql
security definer
set search_path = public
as $$
  select u.uid,
    coalesce((
      select sum(dl.total_points) from public.daily_logs dl
      where dl.user_id = u.uid
        and dl.log_date >= date_trunc('month', current_date)::date
    ), 0)
    + coalesce((
      select sum(c.combo_bonus_points) from public.combo_streak_logs c
      where c.user_id = u.uid
        and c.combo_date >= date_trunc('month', current_date)::date
    ), 0),
    coalesce((
      select max(uh.current_streak) from public.user_habits uh
      where uh.user_id = u.uid and uh.is_active = true
    ), 0)
  from unnest(p_user_ids) as u(uid);
$$;

drop function if exists public.get_user_habits_public(uuid);
create or replace function public.get_user_habits_public(p_user_id uuid)
returns table (
  user_habit_id uuid,
  program_type text,
  start_value numeric,
  target_value numeric,
  current_daily_target numeric,
  current_streak int,
  longest_streak int,
  habit_total_score numeric,
  started_at timestamptz,
  slug text,
  title_tr text,
  title_en text,
  icon text,
  unit text,
  category_tag text
)
language sql
security definer
set search_path = public
as $$
  select uh.id, uh.program_type::text, uh.start_value, uh.target_value,
         uh.current_daily_target, uh.current_streak, uh.longest_streak,
         -- Puanı loglardan hesapla; log yoksa kolona düş.
         coalesce(
           (select sum(dl.total_points) from public.daily_logs dl
            where dl.user_habit_id = uh.id),
           uh.habit_total_score, 0) as habit_total_score,
         uh.started_at, h.slug, h.title_tr, h.title_en,
         h.icon, h.unit, h.category_tag
  from public.user_habits uh
  join public.habits h on h.id = uh.habit_id
  where uh.user_id = p_user_id and uh.is_active = true
  order by 8 desc, uh.started_at desc;
$$;

-- Şeffaf puan kırılımı (bir user_habit için)
create or replace function public.get_habit_score_breakdown(p_user_habit_id uuid)
returns table (
  base_daily_points numeric,
  difficulty_weight numeric,
  streak_multiplier_cap numeric,
  current_streak int,
  days_logged int,
  sum_base numeric,
  sum_streak_bonus numeric,
  sum_effort_bonus numeric,
  sum_activity_bonus numeric,
  sum_milestone_bonus numeric,
  sum_penalty numeric,
  total numeric
)
language sql
security definer
set search_path = public
as $$
  select
    h.base_daily_points, h.difficulty_weight, h.streak_multiplier_cap,
    uh.current_streak,
    (select count(*) from public.daily_logs dl where dl.user_habit_id = uh.id)::int,
    coalesce((select sum(base_points)     from public.daily_logs dl where dl.user_habit_id = uh.id), 0),
    coalesce((select sum(streak_bonus)    from public.daily_logs dl where dl.user_habit_id = uh.id), 0),
    coalesce((select sum(effort_bonus)    from public.daily_logs dl where dl.user_habit_id = uh.id), 0),
    coalesce((select sum(activity_bonus)  from public.daily_logs dl where dl.user_habit_id = uh.id), 0),
    coalesce((select sum(milestone_bonus) from public.daily_logs dl where dl.user_habit_id = uh.id), 0),
    coalesce((select sum(penalty)         from public.daily_logs dl where dl.user_habit_id = uh.id), 0),
    coalesce((select sum(total_points)    from public.daily_logs dl where dl.user_habit_id = uh.id), 0)
  from public.user_habits uh join public.habits h on h.id = uh.habit_id
  where uh.id = p_user_habit_id;
$$;

grant execute on function public.get_monthly_scores(uuid[]) to anon, authenticated;
grant execute on function public.get_user_habits_public(uuid) to anon, authenticated;
grant execute on function public.get_habit_score_breakdown(uuid) to anon, authenticated;
