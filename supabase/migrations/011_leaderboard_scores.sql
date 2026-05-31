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
