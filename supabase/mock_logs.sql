-- ============================================================
-- MOCK için zengin günlük loglar — puanlar anlamlı görünsün.
-- Mock kullanıcıların her aktif habit'ine son 28 gün için günlük log üretir.
-- (Mock profilleri zaten oluşturduysan SADECE bunu çalıştırman yeterli.)
-- Idempotent: ON CONFLICT DO NOTHING.
-- ============================================================

insert into public.daily_logs
  (user_id, user_habit_id, log_date, reported_value, daily_target,
   base_points, streak_bonus, total_points, streak_day, is_success, created_at)
select
  uh.user_id,
  uh.id,
  (current_date - g)::date,
  -- start_value'dan target'a doğru azalan trend (aktivite akışında "20 -> 10" gibi)
  round(greatest(
    coalesce(uh.target_value, 0),
    coalesce(uh.start_value, 10)
      - (coalesce(uh.start_value, 10) - coalesce(uh.target_value, 0)) * ((27 - g)::numeric / 27)
  )),
  coalesce(uh.current_daily_target, uh.target_value, 0),
  round(h.base_daily_points * h.difficulty_weight, 1),          -- base_points
  round(h.base_daily_points * 0.3 * h.difficulty_weight, 1),    -- streak_bonus
  round(h.base_daily_points * 1.3 * h.difficulty_weight, 1),    -- total_points (base+streak)
  (27 - g),                                                     -- streak_day
  true,
  (now() - (g || ' days')::interval)
from public.user_habits uh
join public.habits h on h.id = uh.habit_id
cross join generate_series(0, 27) as g
where uh.user_id in (
  '0a000001-0000-4000-a000-000000000001',
  '0a000002-0000-4000-a000-000000000002',
  '0a000003-0000-4000-a000-000000000003',
  '0a000004-0000-4000-a000-000000000004',
  '0a000005-0000-4000-a000-000000000005'
)
on conflict (user_habit_id, log_date) do nothing;

-- Kolon tutarlılığı: habit & profil toplam skorlarını loglardan tazele.
update public.user_habits uh
set habit_total_score = coalesce(
  (select sum(dl.total_points) from public.daily_logs dl where dl.user_habit_id = uh.id), 0)
where uh.user_id in (
  '0a000001-0000-4000-a000-000000000001','0a000002-0000-4000-a000-000000000002',
  '0a000003-0000-4000-a000-000000000003','0a000004-0000-4000-a000-000000000004',
  '0a000005-0000-4000-a000-000000000005');

update public.profiles p
set total_score = coalesce(
  (select sum(uh.habit_total_score) from public.user_habits uh where uh.user_id = p.id), 0)
where p.id in (
  '0a000001-0000-4000-a000-000000000001','0a000002-0000-4000-a000-000000000002',
  '0a000003-0000-4000-a000-000000000003','0a000004-0000-4000-a000-000000000004',
  '0a000005-0000-4000-a000-000000000005');

-- Kontrol: mock kullanıcıların aylık ~ toplam puanları
select p.username, p.total_score,
       (select count(*) from public.daily_logs d where d.user_id = p.id) as log_sayisi
from public.profiles p
where p.id in (
  '0a000001-0000-4000-a000-000000000001','0a000002-0000-4000-a000-000000000002',
  '0a000003-0000-4000-a000-000000000003','0a000004-0000-4000-a000-000000000004',
  '0a000005-0000-4000-a000-000000000005')
order by p.total_score desc;
