-- ============================================================
-- MOCK PROFILLER — test/sunum için 5 sahte kullanıcı
--
-- Her kullanıcıda 2-3 alışkanlık var; karışık program tipleri:
--   QUIT (tümden bırakan), REDUCE (azaltan), GRADUAL_DECREASE (kademeli).
-- Aktivite akışı dolu görünsün diye günlük log + milestone da ekleniyor.
-- Leaderboard'da görünmeleri için senin hesabınla ACCEPTED arkadaş yapılırlar.
--
-- ÇALIŞTIRMA: Supabase → SQL Editor'e yapıştır → Run.
-- Idempotent: tekrar çalıştırmak güvenli (ON CONFLICT DO NOTHING).
--
-- !!! AŞAĞIDAKİ E-POSTAYI kendi giriş e-postanla değiştir (gerekirse) !!!
--     (Friendships bloğunda kullanılıyor; yanlışsa mock'lar leaderboard'da
--      görünmez ama yine de oluşturulur.)
-- ============================================================

-- ---------- 1) auth.users (trigger otomatik profil oluşturur) ----------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
('00000000-0000-0000-0000-000000000000','0a000001-0000-4000-a000-000000000001','authenticated','authenticated',
 'ayse_k.mock@betterlife.test', extensions.crypt('Mockpass123!', extensions.gen_salt('bf')),
 now(), now() - interval '50 days', now(),
 '{"provider":"email","providers":["email"]}','{"username":"ayse_k","display_name":"Ayse K."}','','','',''),
('00000000-0000-0000-0000-000000000000','0a000002-0000-4000-a000-000000000002','authenticated','authenticated',
 'mehmet_y.mock@betterlife.test', extensions.crypt('Mockpass123!', extensions.gen_salt('bf')),
 now(), now() - interval '30 days', now(),
 '{"provider":"email","providers":["email"]}','{"username":"mehmet_y","display_name":"Mehmet Y."}','','','',''),
('00000000-0000-0000-0000-000000000000','0a000003-0000-4000-a000-000000000003','authenticated','authenticated',
 'zeynep_a.mock@betterlife.test', extensions.crypt('Mockpass123!', extensions.gen_salt('bf')),
 now(), now() - interval '20 days', now(),
 '{"provider":"email","providers":["email"]}','{"username":"zeynep_a","display_name":"Zeynep A."}','','','',''),
('00000000-0000-0000-0000-000000000000','0a000004-0000-4000-a000-000000000004','authenticated','authenticated',
 'can_d.mock@betterlife.test', extensions.crypt('Mockpass123!', extensions.gen_salt('bf')),
 now(), now() - interval '70 days', now(),
 '{"provider":"email","providers":["email"]}','{"username":"can_d","display_name":"Can D."}','','','',''),
('00000000-0000-0000-0000-000000000000','0a000005-0000-4000-a000-000000000005','authenticated','authenticated',
 'elif_s.mock@betterlife.test', extensions.crypt('Mockpass123!', extensions.gen_salt('bf')),
 now(), now() - interval '10 days', now(),
 '{"provider":"email","providers":["email"]}','{"username":"elif_s","display_name":"Elif S."}','','','','')
on conflict (id) do nothing;

-- ---------- 2) profil ek alanları (quit_date = sıralama metriği) ----------
update public.profiles set display_name='Ayşe K.',   quit_date = now() - interval '45 days', total_saved=2025, total_score=1820 where id='0a000001-0000-4000-a000-000000000001';
update public.profiles set display_name='Mehmet Y.', quit_date = now() - interval '22 days', total_saved=1340, total_score=990  where id='0a000002-0000-4000-a000-000000000002';
update public.profiles set display_name='Zeynep A.', quit_date = now() - interval '12 days', total_saved=540,  total_score=610  where id='0a000003-0000-4000-a000-000000000003';
update public.profiles set display_name='Can D.',    quit_date = now() - interval '60 days', total_saved=4100, total_score=3050 where id='0a000004-0000-4000-a000-000000000004';
update public.profiles set display_name='Elif S.',   quit_date = now() - interval '7 days',  total_saved=210,  total_score=240  where id='0a000005-0000-4000-a000-000000000005';

-- ---------- 3) user_habits (slug üzerinden; slug yoksa atlanır) ----------
-- yardımcı kalıp: insert ... select h.id ... from habits h where h.slug=...
-- AYŞE: QUIT smoking + REDUCE social media
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at)
select '0a000001-0000-4000-a000-000000000001', h.id, 'QUIT', 20, 0, 0, 45, 45, now() - interval '45 days' from public.habits h where h.slug='smoking_cessation' on conflict (user_id,habit_id) do nothing;
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at)
select '0a000001-0000-4000-a000-000000000001', h.id, 'REDUCE', 240, 60, 60, 14, 14, now() - interval '30 days' from public.habits h where h.slug='social_media_reduction' on conflict (user_id,habit_id) do nothing;

-- MEHMET: GRADUAL alcohol + QUIT fast food + REDUCE sugar
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at, target_date)
select '0a000002-0000-4000-a000-000000000002', h.id, 'GRADUAL_DECREASE', 14, 0, 6, 22, 22, now() - interval '22 days', current_date + 30 from public.habits h where h.slug='alcohol_cessation' on conflict (user_id,habit_id) do nothing;
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at)
select '0a000002-0000-4000-a000-000000000002', h.id, 'QUIT', 6, 0, 0, 18, 18, now() - interval '18 days' from public.habits h where h.slug='fast_food_cessation' on conflict (user_id,habit_id) do nothing;
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at)
select '0a000002-0000-4000-a000-000000000002', h.id, 'REDUCE', 100, 30, 30, 8, 8, now() - interval '12 days' from public.habits h where h.slug='sugar_reduction' on conflict (user_id,habit_id) do nothing;

-- ZEYNEP: REDUCE smoking + GRADUAL social media
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at)
select '0a000003-0000-4000-a000-000000000003', h.id, 'REDUCE', 15, 5, 5, 12, 12, now() - interval '12 days' from public.habits h where h.slug='smoking_cessation' on conflict (user_id,habit_id) do nothing;
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at, target_date)
select '0a000003-0000-4000-a000-000000000003', h.id, 'GRADUAL_DECREASE', 300, 60, 180, 6, 6, now() - interval '9 days', current_date + 45 from public.habits h where h.slug='social_media_reduction' on conflict (user_id,habit_id) do nothing;

-- CAN: QUIT alcohol + QUIT smoking + GRADUAL fast food
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at)
select '0a000004-0000-4000-a000-000000000004', h.id, 'QUIT', 10, 0, 0, 60, 60, now() - interval '60 days' from public.habits h where h.slug='alcohol_cessation' on conflict (user_id,habit_id) do nothing;
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at)
select '0a000004-0000-4000-a000-000000000004', h.id, 'QUIT', 25, 0, 0, 60, 60, now() - interval '60 days' from public.habits h where h.slug='smoking_cessation' on conflict (user_id,habit_id) do nothing;
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at, target_date)
select '0a000004-0000-4000-a000-000000000004', h.id, 'GRADUAL_DECREASE', 8, 2, 5, 30, 30, now() - interval '30 days', current_date + 30 from public.habits h where h.slug='fast_food_cessation' on conflict (user_id,habit_id) do nothing;

-- ELIF: REDUCE fast food + GRADUAL smoking
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at)
select '0a000005-0000-4000-a000-000000000005', h.id, 'REDUCE', 8, 2, 2, 7, 7, now() - interval '7 days' from public.habits h where h.slug='fast_food_cessation' on conflict (user_id,habit_id) do nothing;
insert into public.user_habits (user_id, habit_id, program_type, start_value, target_value, current_daily_target, current_streak, longest_streak, started_at, target_date)
select '0a000005-0000-4000-a000-000000000005', h.id, 'GRADUAL_DECREASE', 12, 0, 8, 7, 7, now() - interval '7 days', current_date + 60 from public.habits h where h.slug='smoking_cessation' on conflict (user_id,habit_id) do nothing;

-- ---------- 4) günlük loglar (azalan trend → aktivite akışında görünür) ----------
-- yardımcı kalıp: user_id + slug ile user_habit'i bul, log ekle
-- ZEYNEP smoking (15→6)
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-10, 14, 5, 3, 1, false, now()-interval '10 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000003-0000-4000-a000-000000000003' and h.slug='smoking_cessation' on conflict (user_habit_id,log_date) do nothing;
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-6, 10, 5, 4, 4, false, now()-interval '6 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000003-0000-4000-a000-000000000003' and h.slug='smoking_cessation' on conflict (user_habit_id,log_date) do nothing;
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-2, 6, 5, 6, 8, false, now()-interval '2 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000003-0000-4000-a000-000000000003' and h.slug='smoking_cessation' on conflict (user_habit_id,log_date) do nothing;

-- MEHMET alcohol (12→6)
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-15, 12, 8, 3, 1, false, now()-interval '15 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000002-0000-4000-a000-000000000002' and h.slug='alcohol_cessation' on conflict (user_habit_id,log_date) do nothing;
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-8, 9, 8, 4, 7, false, now()-interval '8 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000002-0000-4000-a000-000000000002' and h.slug='alcohol_cessation' on conflict (user_habit_id,log_date) do nothing;
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-2, 6, 6, 7, 13, true, now()-interval '2 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000002-0000-4000-a000-000000000002' and h.slug='alcohol_cessation' on conflict (user_habit_id,log_date) do nothing;

-- CAN fast food (8→5)
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-20, 8, 5, 3, 1, false, now()-interval '20 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000004-0000-4000-a000-000000000004' and h.slug='fast_food_cessation' on conflict (user_habit_id,log_date) do nothing;
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-3, 5, 5, 6, 17, true, now()-interval '3 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000004-0000-4000-a000-000000000004' and h.slug='fast_food_cessation' on conflict (user_habit_id,log_date) do nothing;

-- ELIF fast food (6→3)
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-5, 6, 2, 2, 1, false, now()-interval '5 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000005-0000-4000-a000-000000000005' and h.slug='fast_food_cessation' on conflict (user_habit_id,log_date) do nothing;
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-1, 3, 2, 4, 5, false, now()-interval '1 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000005-0000-4000-a000-000000000005' and h.slug='fast_food_cessation' on conflict (user_habit_id,log_date) do nothing;

-- AYŞE social media (240→70)
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-12, 180, 60, 3, 1, false, now()-interval '12 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000001-0000-4000-a000-000000000001' and h.slug='social_media_reduction' on conflict (user_habit_id,log_date) do nothing;
insert into public.daily_logs (user_id, user_habit_id, log_date, reported_value, daily_target, total_points, streak_day, is_success, created_at)
select uh.user_id, uh.id, current_date-1, 70, 60, 5, 11, false, now()-interval '1 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000001-0000-4000-a000-000000000001' and h.slug='social_media_reduction' on conflict (user_habit_id,log_date) do nothing;

-- ---------- 5) milestone'lar (aktivite akışında "dönüm noktası") ----------
insert into public.milestone_logs (user_id, user_habit_id, milestone_day, bonus_points, achieved_at)
select uh.user_id, uh.id, 30, 50, now()-interval '15 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000001-0000-4000-a000-000000000001' and h.slug='smoking_cessation' on conflict (user_habit_id,milestone_day) do nothing;
insert into public.milestone_logs (user_id, user_habit_id, milestone_day, bonus_points, achieved_at)
select uh.user_id, uh.id, 14, 25, now()-interval '8 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000002-0000-4000-a000-000000000002' and h.slug='alcohol_cessation' on conflict (user_habit_id,milestone_day) do nothing;
insert into public.milestone_logs (user_id, user_habit_id, milestone_day, bonus_points, achieved_at)
select uh.user_id, uh.id, 30, 50, now()-interval '30 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000004-0000-4000-a000-000000000004' and h.slug='alcohol_cessation' on conflict (user_habit_id,milestone_day) do nothing;
insert into public.milestone_logs (user_id, user_habit_id, milestone_day, bonus_points, achieved_at)
select uh.user_id, uh.id, 60, 100, now()-interval '1 days' from public.user_habits uh join public.habits h on h.id=uh.habit_id where uh.user_id='0a000004-0000-4000-a000-000000000004' and h.slug='alcohol_cessation' on conflict (user_habit_id,milestone_day) do nothing;

-- ---------- 6) leaderboard'da görünmeleri için ACCEPTED arkadaşlık ----------
-- E-postaya GEREK YOK ve istek kabul etmen GEREKMEZ: mock'lar mevcut TÜM
-- gerçek kullanıcılarla (yani seninle) doğrudan "kabul edilmiş" (ACCEPTED)
-- arkadaş yapılır. Çalıştırıp uygulamayı yenileyince direkt leaderboard'da çıkar.
insert into public.friendships (requester_id, addressee_id, status)
select p.id, m.id, 'ACCEPTED'
from public.profiles p
cross join (values
  ('0a000001-0000-4000-a000-000000000001'::uuid),
  ('0a000002-0000-4000-a000-000000000002'::uuid),
  ('0a000003-0000-4000-a000-000000000003'::uuid),
  ('0a000004-0000-4000-a000-000000000004'::uuid),
  ('0a000005-0000-4000-a000-000000000005'::uuid)
) as m(id)
where p.id <> m.id
  and p.id not in (
    '0a000001-0000-4000-a000-000000000001',
    '0a000002-0000-4000-a000-000000000002',
    '0a000003-0000-4000-a000-000000000003',
    '0a000004-0000-4000-a000-000000000004',
    '0a000005-0000-4000-a000-000000000005'
  )
on conflict (requester_id, addressee_id) do nothing;

-- Bitti. Leaderboard'da 5 yeni kişi görünmeli; üzerlerine tıklayınca
-- profilleri, alışkanlıkları ve son aktiviteleri açılır.
