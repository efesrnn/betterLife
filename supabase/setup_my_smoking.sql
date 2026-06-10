-- ============================================================
-- KENDİ HESABIN için sigara bırakma verisi + PUAN
-- E-posta: kelekarpuz32@gmail.com  (farklıysa aşağıda değiştir)
--
-- 116 gün 8 saat 4 dk temiz · günde 17 sigara · paket 110₺ (20'li = adet 5,5₺)
-- Tasarruf ≈ 10.846₺ · Lung recovery Home'da otomatik (~%63).
--
-- NOT: QUIT modunda günlük log butonu yok (sadece temiz kalıyorsun), bu yüzden
-- puan üreten kayıt oluşmuyordu. Burada 116 temiz günün her birini puan olarak
-- geriye dönük işliyoruz (taban × zorluk × seri çarpanı) → skor leaderboard ve
-- profile yansır.
-- Idempotent: tekrar çalıştırmak güvenli.
-- ============================================================

-- 1) smoking_cessation user_habit'ini QUIT olarak ayarla (yoksa oluştur).
insert into public.user_habits
  (user_id, habit_id, program_type, start_value, target_value,
   current_daily_target, current_streak, longest_streak, unit_cost, started_at)
select u.id, h.id, 'QUIT', 17, 0, 0, 116, 116, 5.5,
       now() - interval '116 days 8 hours 4 minutes'
from auth.users u, public.habits h
where u.email = 'kelekarpuz32@gmail.com'
  and h.slug = 'smoking_cessation'
on conflict (user_id, habit_id) do update set
  program_type='QUIT', start_value=17, target_value=0, current_daily_target=0,
  current_streak=116, longest_streak=116, unit_cost=5.5,
  started_at = now() - interval '116 days 8 hours 4 minutes',
  is_active=true, paused_at=null;

-- 2) 116 temiz günün her birini puan olarak işle (taban×zorluk×seri çarpanı).
insert into public.daily_logs
  (user_id, user_habit_id, log_date, reported_value, daily_target,
   base_points, streak_bonus, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id,
  (current_date - g)::date, 0, 0,
  round(h.base_daily_points * h.difficulty_weight, 1),
  round(h.base_daily_points * h.difficulty_weight
        * least((116 - g) * 0.01, h.streak_multiplier_cap - 1), 1),
  round(h.base_daily_points * h.difficulty_weight
        * (1 + least((116 - g) * 0.01, h.streak_multiplier_cap - 1)), 1),
  (116 - g), true,
  now() - (g || ' days')::interval
from public.user_habits uh
join public.habits h on h.id = uh.habit_id
cross join generate_series(0, 115) as g
where uh.user_id = (select id from auth.users where email = 'kelekarpuz32@gmail.com')
  and h.slug = 'smoking_cessation'
  and uh.program_type = 'QUIT'
on conflict (user_habit_id, log_date) do nothing;

-- 3) Habit skoru = loglarının toplamı.
update public.user_habits uh
set habit_total_score = coalesce(
  (select sum(dl.total_points) from public.daily_logs dl where dl.user_habit_id = uh.id), 0)
where uh.user_id = (select id from auth.users where email = 'kelekarpuz32@gmail.com');

-- 4) Profil: temiz tarih, paket, tasarruf, akciğer + toplam puan (tüm loglardan).
update public.profiles
set quit_date      = now() - interval '116 days 8 hours 4 minutes',
    pack_price     = 110,
    pack_size      = 20,
    daily_baseline = 17,
    total_saved    = 116 * 17 * 5.5,
    lung_score     = 64,
    total_score    = coalesce(
      (select sum(dl.total_points) from public.daily_logs dl
       where dl.user_id = profiles.id), 0)
where id = (select id from auth.users where email = 'kelekarpuz32@gmail.com');

-- 5) Kontrol
select p.username, p.total_score as toplam_puan, p.total_saved, p.lung_score,
       uh.current_streak, uh.habit_total_score as sigara_puani,
       (select count(*) from public.daily_logs d where d.user_habit_id = uh.id) as gun_sayisi
from public.profiles p
join public.user_habits uh on uh.user_id = p.id
join public.habits h on h.id = uh.habit_id and h.slug = 'smoking_cessation'
where p.id = (select id from auth.users where email = 'kelekarpuz32@gmail.com');
