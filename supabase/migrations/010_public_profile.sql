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
