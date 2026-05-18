-- ============================================================
-- Better Life (HabitArena) — Initial Schema Migration
-- ------------------------------------------------------------
-- Bu migration:
--   * Mevcut profiles + friendships tablolarını KIRMADAN genişletir
--     (ALTER TABLE ADD COLUMN IF NOT EXISTS).
--   * Yeni tabloları (habit_categories, activity_categories,
--     user_habits, habit_logs, activity_logs, achievements,
--     user_achievements) sıfırdan oluşturur.
--   * Tüm tablolar için RLS politikaları ekler.
--   * Puan hesaplamasını otomatikleştiren 4 trigger kurar.
--   * 3 RPC (recalculate_user_score, get_friend_leaderboard,
--     get_weekly_score) ekler.
--   * 5 zararlı alışkanlık + 5 olumlu aktivite seed'ler.
--
-- Idempotent: aynı migration tekrar çalışırsa veri kaybetmeden geçer.
-- Friendship status hem 'PENDING/ACCEPTED' (mevcut UI) hem 'pending/accepted'
-- (yeni şema) değerlerini kabul eder; ileride harmonize edilecek.
-- ============================================================

-- ============================================================
-- 1) profiles — mevcut tabloyu genişlet
-- ============================================================

-- (profiles tablosu zaten var: id, username, habit, goal)
-- habit/goal alanları LEGACY (geriye dönük uyumluluk için kalıyor).

alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists total_score int not null default 0;
alter table public.profiles add column if not exists current_streak int not null default 0;
alter table public.profiles add column if not exists longest_streak int not null default 0;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- display_name boş kalmasın: username'i kullan (NULL'lar için).
update public.profiles
   set display_name = username
 where display_name is null;

-- updated_at otomatik güncelleme trigger'ı
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- ============================================================
-- 2) habit_categories — Gemini değerlendirmesinden geçen
--    "zararlı alışkanlık" tanımları
-- ============================================================

create table if not exists public.habit_categories (
  id                  bigint generated always as identity primary key,
  name                text unique not null,
  description         text,
  icon_name           text default 'block',
  color_hex           text default '#EF4444',
  base_daily_points   int not null,
  health_impact       int not null check (health_impact between 1 and 10),
  social_impact       int not null check (social_impact between 1 and 10),
  financial_impact    int not null check (financial_impact between 1 and 10),
  addiction_level     int not null check (addiction_level between 1 and 10),
  gemini_evaluation   jsonb,
  is_valid            boolean not null default true,
  created_by          uuid references public.profiles(id) on delete set null,
  created_at          timestamptz not null default now()
);

-- ============================================================
-- 3) activity_categories — olumlu aktivite tanımları
-- ============================================================

create table if not exists public.activity_categories (
  id                  bigint generated always as identity primary key,
  name                text unique not null,
  description         text,
  icon_name           text default 'fitness_center',
  color_hex           text default '#22C55E',
  base_bonus_points   int not null,
  health_benefit      int not null check (health_benefit between 1 and 10),
  mental_benefit      int not null check (mental_benefit between 1 and 10),
  is_duration_based   boolean not null default false,
  points_per_minute   numeric(4,2) not null default 0,
  min_duration_minutes int not null default 0,
  gemini_evaluation   jsonb,
  is_valid            boolean not null default true,
  created_by          uuid references public.profiles(id) on delete set null,
  created_at          timestamptz not null default now()
);

-- ============================================================
-- 4) user_habits — kullanıcının bırakmak istediği alışkanlıklar
-- ============================================================

create table if not exists public.user_habits (
  id                bigint generated always as identity primary key,
  user_id           uuid not null references public.profiles(id) on delete cascade,
  habit_category_id bigint not null references public.habit_categories(id) on delete restrict,
  quit_date         date not null default current_date,
  motivation        text,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  unique (user_id, habit_category_id)
);

create index if not exists idx_user_habits_user_active
  on public.user_habits(user_id, is_active);

-- ============================================================
-- 5) habit_logs — günlük "bugün yapmadım/yaptım" kayıtları
-- ============================================================

create table if not exists public.habit_logs (
  id            bigint generated always as identity primary key,
  user_habit_id bigint not null references public.user_habits(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  log_date      date not null default current_date,
  stayed_clean  boolean not null,
  points_earned int not null default 0,
  relapse_note  text,
  created_at    timestamptz not null default now(),
  unique (user_habit_id, log_date)
);

create index if not exists idx_habit_logs_user_date
  on public.habit_logs(user_id, log_date desc);

-- ============================================================
-- 6) activity_logs — günlük aktivite kayıtları
-- ============================================================

create table if not exists public.activity_logs (
  id                   bigint generated always as identity primary key,
  user_id              uuid not null references public.profiles(id) on delete cascade,
  activity_category_id bigint not null references public.activity_categories(id) on delete restrict,
  log_date             date not null default current_date,
  duration_minutes     int,
  points_earned        int not null default 0,
  notes                text,
  created_at           timestamptz not null default now()
);

create index if not exists idx_activity_logs_user_date
  on public.activity_logs(user_id, log_date desc);

-- ============================================================
-- 7) friendships — mevcut tabloyu yeni şema ile uyumlulaştır
-- ============================================================

-- Eğer tablo yoksa oluştur (prompt şemasıyla).
create table if not exists public.friendships (
  id            bigint generated always as identity primary key,
  requester_id  uuid not null references public.profiles(id) on delete cascade,
  addressee_id  uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'PENDING',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Mevcut tabloda olmayan kolonları ekle (idempotent).
alter table public.friendships add column if not exists created_at timestamptz not null default now();
alter table public.friendships add column if not exists updated_at timestamptz not null default now();

-- Status değer aralığı: mevcut UI uppercase ('PENDING','ACCEPTED') kullanıyor;
-- yeni şema lowercase istiyor. İkisini de kabul edecek esnek constraint.
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'friendships_status_check'
  ) then
    alter table public.friendships
      add constraint friendships_status_check
      check (status in (
        'pending','accepted','rejected','blocked',
        'PENDING','ACCEPTED','REJECTED','BLOCKED'
      ));
  end if;
end$$;

-- Aynı kişiye iki istek atılmasın
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'friendships_unique_pair'
  ) then
    alter table public.friendships
      add constraint friendships_unique_pair unique (requester_id, addressee_id);
  end if;
end$$;

-- Kendine istek atılmasın
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'friendships_no_self'
  ) then
    alter table public.friendships
      add constraint friendships_no_self check (requester_id <> addressee_id);
  end if;
end$$;

drop trigger if exists trg_friendships_updated_at on public.friendships;
create trigger trg_friendships_updated_at
before update on public.friendships
for each row execute function public.set_updated_at();

-- ============================================================
-- 8) achievements + user_achievements — rozet sistemi
-- ============================================================

create table if not exists public.achievements (
  id              bigint generated always as identity primary key,
  name            text unique not null,
  description     text,
  icon_name       text default 'emoji_events',
  required_streak int,
  required_score  int,
  category        text not null default 'general'
                  check (category in ('general','streak','social','activity')),
  created_at      timestamptz not null default now()
);

create table if not exists public.user_achievements (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  achievement_id bigint not null references public.achievements(id) on delete cascade,
  earned_at      timestamptz not null default now(),
  unique (user_id, achievement_id)
);

-- ============================================================
-- 9) Trigger'lar: puan otomatik hesaplaması
-- ------------------------------------------------------------
-- KURAL: Hiçbir puan client tarafında hesaplanmaz; tüm hesaplama
-- DB seviyesinde yapılır. UI sadece sonucu okur.
-- ============================================================

-- 9.1 habit_log puanı: stayed_clean=true ise category.base_daily_points
create or replace function public.calc_habit_log_points()
returns trigger
language plpgsql
as $$
declare
  v_base int;
begin
  if new.stayed_clean then
    select hc.base_daily_points
      into v_base
      from public.user_habits uh
      join public.habit_categories hc on hc.id = uh.habit_category_id
     where uh.id = new.user_habit_id;
    new.points_earned := coalesce(v_base, 0);
  else
    new.points_earned := 0;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_habit_log_points on public.habit_logs;
create trigger trg_habit_log_points
before insert or update on public.habit_logs
for each row execute function public.calc_habit_log_points();

-- 9.2 activity_log puanı:
--     base_bonus + (duration × points_per_minute)
--     süre bazlıysa ve min süre karşılandıysa.
create or replace function public.calc_activity_log_points()
returns trigger
language plpgsql
as $$
declare
  v_base       int;
  v_per_min    numeric(4,2);
  v_min_min    int;
  v_duration   numeric(4,2);
  v_is_dur     boolean;
begin
  select ac.base_bonus_points,
         ac.points_per_minute,
         ac.min_duration_minutes,
         ac.is_duration_based
    into v_base, v_per_min, v_min_min, v_is_dur
    from public.activity_categories ac
   where ac.id = new.activity_category_id;

  v_duration := coalesce(new.duration_minutes, 0);

  if v_is_dur then
    if v_duration >= v_min_min then
      new.points_earned := round(coalesce(v_base, 0) + (v_duration * coalesce(v_per_min, 0)));
    else
      new.points_earned := 0;
    end if;
  else
    new.points_earned := coalesce(v_base, 0);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_activity_log_points on public.activity_logs;
create trigger trg_activity_log_points
before insert or update on public.activity_logs
for each row execute function public.calc_activity_log_points();

-- 9.3 Toplam puanı yeniden hesapla (profiles.total_score)
create or replace function public.recalculate_user_score(p_user_id uuid)
returns int
language plpgsql
as $$
declare
  v_habit_pts int;
  v_act_pts int;
  v_total int;
begin
  select coalesce(sum(points_earned),0)
    into v_habit_pts
    from public.habit_logs
   where user_id = p_user_id;

  select coalesce(sum(points_earned),0)
    into v_act_pts
    from public.activity_logs
   where user_id = p_user_id;

  v_total := v_habit_pts + v_act_pts;

  update public.profiles
     set total_score = v_total,
         updated_at = now()
   where id = p_user_id;

  return v_total;
end;
$$;

-- 9.4 Her habit_log / activity_log sonrası total_score güncelle
create or replace function public.trg_after_habit_log()
returns trigger
language plpgsql
as $$
begin
  perform public.recalculate_user_score(new.user_id);
  return new;
end;
$$;

drop trigger if exists trg_update_score_habit on public.habit_logs;
create trigger trg_update_score_habit
after insert or update on public.habit_logs
for each row execute function public.trg_after_habit_log();

create or replace function public.trg_after_activity_log()
returns trigger
language plpgsql
as $$
begin
  perform public.recalculate_user_score(new.user_id);
  return new;
end;
$$;

drop trigger if exists trg_update_score_activity on public.activity_logs;
create trigger trg_update_score_activity
after insert or update on public.activity_logs
for each row execute function public.trg_after_activity_log();

-- ============================================================
-- 10) RPC: get_friend_leaderboard
--     Kullanıcı + arkadaşları (ACCEPTED/accepted) için rank'li liste
-- ============================================================

create or replace function public.get_friend_leaderboard(p_user_id uuid)
returns table (
  user_id         uuid,
  username        text,
  display_name    text,
  avatar_url      text,
  total_score     int,
  current_streak  int,
  rank            bigint
)
language sql
stable
as $$
  with friends as (
    -- Ben + arkadaşlarımın id'leri
    select p_user_id as id
    union
    select case
             when f.requester_id = p_user_id then f.addressee_id
             else f.requester_id
           end as id
      from public.friendships f
     where (f.requester_id = p_user_id or f.addressee_id = p_user_id)
       and lower(f.status) = 'accepted'
  )
  select p.id,
         p.username,
         coalesce(p.display_name, p.username) as display_name,
         p.avatar_url,
         p.total_score,
         p.current_streak,
         rank() over (order by p.total_score desc) as rank
    from public.profiles p
   where p.id in (select id from friends)
   order by p.total_score desc;
$$;

-- ============================================================
-- 11) RPC: get_weekly_score
--     7 günlük habit_points / activity_points / total tablosu
-- ============================================================

create or replace function public.get_weekly_score(
  p_user_id   uuid,
  p_week_start date default (current_date - interval '6 days')::date
)
returns table (
  day             date,
  habit_points    int,
  activity_points int,
  total_points    int
)
language sql
stable
as $$
  with days as (
    select (p_week_start + i)::date as day
      from generate_series(0, 6) as g(i)
  ),
  habit_sums as (
    select log_date, sum(points_earned)::int as pts
      from public.habit_logs
     where user_id = p_user_id
       and log_date between p_week_start and (p_week_start + 6)::date
     group by log_date
  ),
  activity_sums as (
    select log_date, sum(points_earned)::int as pts
      from public.activity_logs
     where user_id = p_user_id
       and log_date between p_week_start and (p_week_start + 6)::date
     group by log_date
  )
  select d.day,
         coalesce(h.pts, 0) as habit_points,
         coalesce(a.pts, 0) as activity_points,
         coalesce(h.pts, 0) + coalesce(a.pts, 0) as total_points
    from days d
    left join habit_sums    h on h.log_date = d.day
    left join activity_sums a on a.log_date = d.day
   order by d.day;
$$;

-- ============================================================
-- 12) RLS — Row Level Security
-- ============================================================

alter table public.profiles            enable row level security;
alter table public.habit_categories    enable row level security;
alter table public.activity_categories enable row level security;
alter table public.user_habits         enable row level security;
alter table public.habit_logs          enable row level security;
alter table public.activity_logs       enable row level security;
alter table public.friendships         enable row level security;
alter table public.achievements        enable row level security;
alter table public.user_achievements   enable row level security;

-- Yardımcı: bir kullanıcıyla arkadaş mıyım?
create or replace function public.is_friend_of(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.friendships f
     where lower(f.status) = 'accepted'
       and (
         (f.requester_id = auth.uid() and f.addressee_id = p_other) or
         (f.addressee_id = auth.uid() and f.requester_id = p_other)
       )
  );
$$;

-- profiles: herkes okur, sadece kendi yazar
drop policy if exists "profiles select all" on public.profiles;
create policy "profiles select all" on public.profiles
  for select using (true);

drop policy if exists "profiles insert self" on public.profiles;
create policy "profiles insert self" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles update self" on public.profiles;
create policy "profiles update self" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- habit_categories: herkes okur; auth olan ekler (Gemini onaylı kayıtlar)
drop policy if exists "habit_categories select all" on public.habit_categories;
create policy "habit_categories select all" on public.habit_categories
  for select using (true);

drop policy if exists "habit_categories insert auth" on public.habit_categories;
create policy "habit_categories insert auth" on public.habit_categories
  for insert with check (auth.role() = 'authenticated');

-- activity_categories: aynı mantık
drop policy if exists "activity_categories select all" on public.activity_categories;
create policy "activity_categories select all" on public.activity_categories
  for select using (true);

drop policy if exists "activity_categories insert auth" on public.activity_categories;
create policy "activity_categories insert auth" on public.activity_categories
  for insert with check (auth.role() = 'authenticated');

-- user_habits: sadece kendi
drop policy if exists "user_habits all self" on public.user_habits;
create policy "user_habits all self" on public.user_habits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- habit_logs: kendi yazar; kendi ve arkadaşları okur
drop policy if exists "habit_logs select self or friends" on public.habit_logs;
create policy "habit_logs select self or friends" on public.habit_logs
  for select using (auth.uid() = user_id or public.is_friend_of(user_id));

drop policy if exists "habit_logs insert self" on public.habit_logs;
create policy "habit_logs insert self" on public.habit_logs
  for insert with check (auth.uid() = user_id);

drop policy if exists "habit_logs update self" on public.habit_logs;
create policy "habit_logs update self" on public.habit_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- activity_logs: aynı mantık
drop policy if exists "activity_logs select self or friends" on public.activity_logs;
create policy "activity_logs select self or friends" on public.activity_logs
  for select using (auth.uid() = user_id or public.is_friend_of(user_id));

drop policy if exists "activity_logs insert self" on public.activity_logs;
create policy "activity_logs insert self" on public.activity_logs
  for insert with check (auth.uid() = user_id);

drop policy if exists "activity_logs update self" on public.activity_logs;
create policy "activity_logs update self" on public.activity_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- friendships: dahil olanlar okur, requester insert, addressee update
drop policy if exists "friendships select involved" on public.friendships;
create policy "friendships select involved" on public.friendships
  for select using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists "friendships insert requester" on public.friendships;
create policy "friendships insert requester" on public.friendships
  for insert with check (auth.uid() = requester_id);

drop policy if exists "friendships update addressee" on public.friendships;
create policy "friendships update addressee" on public.friendships
  for update using (auth.uid() = addressee_id) with check (auth.uid() = addressee_id);

drop policy if exists "friendships delete involved" on public.friendships;
create policy "friendships delete involved" on public.friendships
  for delete using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- achievements: herkes okur; sistem ekler (service_role)
drop policy if exists "achievements select all" on public.achievements;
create policy "achievements select all" on public.achievements
  for select using (true);

-- user_achievements: sadece kendi okur, sistem ekler
drop policy if exists "user_achievements select self" on public.user_achievements;
create policy "user_achievements select self" on public.user_achievements
  for select using (auth.uid() = user_id);

-- ============================================================
-- 13) SEED DATA
-- ============================================================

-- Habit Categories (zararlı alışkanlıklar)
insert into public.habit_categories
  (name, description, icon_name, color_hex, base_daily_points,
   health_impact, social_impact, financial_impact, addiction_level)
values
  ('Sigara',                      'Sigara içmemek', 'smoking_rooms', '#EF4444', 10, 9, 6, 7, 9),
  ('Alkol',                       'Alkol almamak', 'local_bar',     '#F59E0B',  8, 7, 7, 6, 7),
  ('Fast Food',                   'Fast food yememek', 'fastfood',  '#F97316',  5, 6, 3, 5, 5),
  ('Sosyal Medya Bağımlılığı',    'Sosyal medya kullanımını azaltmak', 'phone_iphone', '#8B5CF6', 4, 3, 7, 2, 6),
  ('Kumar',                       'Kumar oynamamak', 'casino',      '#DC2626',  9, 4, 8, 10, 8)
on conflict (name) do nothing;

-- Activity Categories (olumlu aktiviteler)
insert into public.activity_categories
  (name, description, icon_name, color_hex, base_bonus_points,
   health_benefit, mental_benefit, is_duration_based,
   points_per_minute, min_duration_minutes)
values
  ('Yürüyüş',       'Yürüyüş yapmak',          'directions_walk', '#22C55E', 2, 7, 6, true, 0.07, 15),
  ('Koşu',          'Koşu yapmak',             'directions_run',  '#16A34A', 3, 9, 7, true, 0.10, 10),
  ('Meditasyon',    'Meditasyon yapmak',       'self_improvement','#06B6D4', 2, 4, 9, true, 0.08,  5),
  ('Kitap Okuma',   'Kitap okumak',            'menu_book',       '#0EA5E9', 1, 2, 8, true, 0.05, 15),
  ('Su İçme (2L+)', 'Günde 2L+ su tüketmek',   'local_drink',     '#3B82F6', 1, 6, 3, false, 0,    0)
on conflict (name) do nothing;

-- Achievements (rozetler)
insert into public.achievements
  (name, description, icon_name, required_streak, required_score, category)
values
  ('İlk Adım',           'İlk check-in', 'emoji_events',         1, null, 'general'),
  ('Bir Hafta',          '7 günlük streak', 'local_fire_department', 7, null, 'streak'),
  ('Bir Ay',             '30 günlük streak', 'local_fire_department', 30, null, 'streak'),
  ('Yüz Puan',           '100 toplam puan', 'star',              null, 100, 'general'),
  ('Bin Puan',           '1000 toplam puan', 'workspace_premium', null, 1000, 'general'),
  ('Sosyal Kelebek',     '5 arkadaş', 'people',                  null, null, 'social'),
  ('Spor Aşığı',         '10 aktivite kaydı', 'fitness_center',  null, null, 'activity')
on conflict (name) do nothing;

-- ============================================================
-- 14) Yeni kullanıcı kaydı için trigger
--     auth.users'a kayıt olunduğunda profiles'a otomatik insert
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ============================================================
-- BİTTİ. Bu migration güvenle yeniden çalıştırılabilir.
-- ============================================================
