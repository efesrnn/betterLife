-- ============================================================
-- HabitQuest - Cron Schedules (Migration 006)
-- pg_cron gerektirir (Dashboard → Extensions). pg_cron, Edge
-- Function'ı doğrudan çağıramaz; pg_net ile HTTP çağrısı yapılır
-- veya harici scheduler (GitHub Actions / cron-job.org) kullanılır.
-- ============================================================

-- Option A: pg_net (etkinleştirildiyse aşağıyı aç)
/*
select cron.schedule(
  'deduplicate-habits-12h', '0 0,12 * * *',
  $$
  select net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/deduplicate-habits',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'),
    body := '{}'::jsonb);
  $$
);
*/

-- Haftalık skor sıfırlama (her Pazartesi 00:00 UTC) — pg_net gerekmez
select cron.schedule(
  'reset-weekly-scores', '0 0 * * 1',
  $$select public.reset_weekly_scores()$$
);
