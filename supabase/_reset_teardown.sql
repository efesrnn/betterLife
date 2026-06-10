-- ============================================================
-- TEMİZ SIFIRLAMA (teardown)
-- ============================================================
-- Bu dosya bir migration DEĞİLDİR. Tek seferlik elle çalıştırılır.
-- Amaç: önceki deneme/çakışmalardan kalan tüm public objelerini
-- silip, gerçek migration'ları (001..006) temiz bir zeminde
-- çalıştırabilmek.
--
-- DİKKAT: public.profiles dahil her şeyi siler → test hesapları
-- gider. Çalıştırmadan ÖNCE: Supabase → Authentication → Users →
-- test kullanıcılarını sil (yoksa profilsiz auth user kalır).
--
-- ÇALIŞTIRMA SIRASI:
--   1) Auth → Users → test kullanıcılarını sil
--   2) Bu dosya (teardown)
--   3) migrations/001_core_schema.sql
--   4) migrations/002_scoring_engine.sql
--   5) migrations/003_rls.sql
--   6) migrations/004_seed.sql
--   7) migrations/005_canonical.sql
--   8) migrations/006_cron.sql   (pg_cron yoksa atla)
-- ============================================================

-- auth.users üzerindeki trigger (tablolar dışında, ayrıca düşürülmeli)
drop trigger if exists on_auth_user_created on auth.users;

-- Fonksiyonlar
drop function if exists public.handle_new_user() cascade;
drop function if exists public.update_updated_at() cascade;
drop function if exists public.calc_streak_multiplier(int, numeric) cascade;
drop function if exists public.get_combo_bonus_points(int) cascade;
drop function if exists public.check_and_award_combo_bonus(uuid) cascade;
drop function if exists public.calculate_daily_score(uuid, numeric, numeric, jsonb) cascade;
drop function if exists public.update_gradual_target(uuid) cascade;
drop function if exists public.submit_daily_log(uuid, numeric, numeric, jsonb, text) cascade;
drop function if exists public.match_habit_by_embedding(vector, numeric, int) cascade;
drop function if exists public.match_habit_by_embedding(text, float, int) cascade;
drop function if exists public.get_user_dashboard(uuid) cascade;
drop function if exists public.get_friend_leaderboard(uuid) cascade;
drop function if exists public.reset_weekly_scores() cascade;
drop function if exists public.recalculate_weekly_score(uuid) cascade;
drop function if exists public.resolve_canonical(uuid) cascade;
drop function if exists public.get_habit_aliases(uuid) cascade;
drop function if exists public.get_unclassified_habits() cascade;
drop function if exists public.get_canonical_habits() cascade;
drop function if exists public.merge_habit_into_canonical(uuid, uuid) cascade;
drop function if exists public.promote_to_canonical(uuid) cascade;

-- Tablolar (bağımlılıklarıyla)
drop table if exists public.milestone_logs cascade;
drop table if exists public.combo_streak_logs cascade;
drop table if exists public.daily_logs cascade;
drop table if exists public.user_habits cascade;
drop table if exists public.habit_embeddings cascade;
drop table if exists public.habits cascade;
drop table if exists public.friendships cascade;
drop table if exists public.profiles cascade;

-- Enum tipleri
drop type if exists public.friendship_status cascade;
drop type if exists public.program_type cascade;
drop type if exists public.risk_level cascade;
drop type if exists public.target_direction cascade;
drop type if exists public.habit_type cascade;
