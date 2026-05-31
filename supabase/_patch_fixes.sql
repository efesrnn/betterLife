-- ============================================================
-- _patch_fixes.sql — VERİ KAYBI OLMADAN çalıştırılır (additive)
-- Mevcut DB'ye eksikleri ekler; hiçbir şeyi silmez, hesap gitmez.
-- SQL Editor'de tek seferde çalıştır.
-- ============================================================

-- 1) profiles INSERT politikası (kayıt sırasındaki 42501 hatasını çözer)
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

-- 2) Eski ekranların kullandığı uyumluluk kolonları
alter table public.profiles add column if not exists habit          text;
alter table public.profiles add column if not exists goal           text;
alter table public.profiles add column if not exists quit_date      timestamptz;
alter table public.profiles add column if not exists total_saved    numeric default 0;
alter table public.profiles add column if not exists lung_score     numeric default 10;
alter table public.profiles add column if not exists pack_price     numeric default 115;
alter table public.profiles add column if not exists pack_size      int default 20;
alter table public.profiles add column if not exists daily_baseline int default 20;

-- 3) Avatars storage bucket + politikaları
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true) on conflict (id) do nothing;
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');
drop policy if exists "avatars_auth_insert" on storage.objects;
create policy "avatars_auth_insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'avatars');
drop policy if exists "avatars_auth_update" on storage.objects;
create policy "avatars_auth_update" on storage.objects
  for update to authenticated using (bucket_id = 'avatars');

notify pgrst, 'reload schema';

-- 4) Çok-habit Home için birim maliyet
alter table public.user_habits add column if not exists unit_cost numeric default 0;
notify pgrst, 'reload schema';
