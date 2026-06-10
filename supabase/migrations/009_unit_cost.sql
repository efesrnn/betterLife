-- ============================================================
-- 009 — user_habits.unit_cost
-- Tasarruf hesabı için birim başına maliyet (₺). Örn. 1 sigara ₺5.75.
-- ============================================================
alter table public.user_habits add column if not exists unit_cost numeric default 0;
notify pgrst, 'reload schema';
