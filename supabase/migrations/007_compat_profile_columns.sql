-- ============================================================
-- 007 — Uyumluluk: eski (sigara izleyici) ekran kolonları
-- ============================================================
-- home_screen / username_selection / friends_screen / settings
-- profiles'ta şu kolonları okuyup yazıyor. Gerçek şema (001)
-- bunları içermez; eski ekranlar çalışsın diye ekleniyor.
-- (Home yeniden tasarımında bunlar user_habits modeline taşınacak.)
-- ============================================================
alter table public.profiles add column if not exists habit          text;
alter table public.profiles add column if not exists goal           text;
alter table public.profiles add column if not exists quit_date      timestamptz;
alter table public.profiles add column if not exists total_saved    numeric default 0;
alter table public.profiles add column if not exists lung_score     numeric default 10;
alter table public.profiles add column if not exists pack_price     numeric default 115;
alter table public.profiles add column if not exists pack_size      int default 20;
alter table public.profiles add column if not exists daily_baseline int default 20;

notify pgrst, 'reload schema';
