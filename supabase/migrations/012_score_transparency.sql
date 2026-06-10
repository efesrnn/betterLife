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
