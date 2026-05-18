-- ============================================================
-- Better Life — Migration v2: slug kolonu + UI parity seed
-- ------------------------------------------------------------
-- UI'da kullanılan slug'lar ('cigarettes', 'vapes', 'alcohol',
-- 'junk_food', 'screen_time') ile habit_categories arasında
-- 1:1 eşleme kurar. Aynı şey activity_categories için.
--
-- Idempotent: kolon ekleme IF NOT EXISTS; UPDATE'ler tekrar
-- çalışırsa aynı değeri yazar; INSERT'lerde ON CONFLICT DO NOTHING.
-- ============================================================

-- ============================================================
-- 1) slug kolonları
-- ============================================================

alter table public.habit_categories
  add column if not exists slug text;

alter table public.activity_categories
  add column if not exists slug text;

-- Unique constraint (NULL'lar serbest — legacy rows için)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'habit_categories_slug_key'
  ) then
    alter table public.habit_categories
      add constraint habit_categories_slug_key unique (slug);
  end if;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'activity_categories_slug_key'
  ) then
    alter table public.activity_categories
      add constraint activity_categories_slug_key unique (slug);
  end if;
end$$;

-- ============================================================
-- 2) Mevcut seed satırlarını slug ile etiketle
-- ============================================================

update public.habit_categories set slug = 'cigarettes'   where name = 'Sigara'                   and slug is null;
update public.habit_categories set slug = 'alcohol'      where name = 'Alkol'                    and slug is null;
update public.habit_categories set slug = 'junk_food'    where name = 'Fast Food'                and slug is null;
update public.habit_categories set slug = 'social_media' where name = 'Sosyal Medya Bağımlılığı' and slug is null;
update public.habit_categories set slug = 'gambling'     where name = 'Kumar'                    and slug is null;

update public.activity_categories set slug = 'walking'    where name = 'Yürüyüş'      and slug is null;
update public.activity_categories set slug = 'running'    where name = 'Koşu'         and slug is null;
update public.activity_categories set slug = 'meditation' where name = 'Meditasyon'   and slug is null;
update public.activity_categories set slug = 'reading'    where name = 'Kitap Okuma'  and slug is null;
update public.activity_categories set slug = 'water'      where name = 'Su İçme (2L+)' and slug is null;

-- ============================================================
-- 3) UI'da olup seed'de olmayan kategorileri ekle
-- ============================================================

-- 'vapes' → Elektronik Sigara
insert into public.habit_categories
  (slug, name, description, icon_name, color_hex, base_daily_points,
   health_impact, social_impact, financial_impact, addiction_level)
values
  ('vapes', 'Elektronik Sigara', 'E-sigara/vape kullanmamak',
   'vape_free', '#A855F7', 8, 8, 5, 5, 8)
on conflict (slug) do nothing;

-- 'screen_time' → Ekran Süresi (sosyal medyadan ayrı, daha geniş)
insert into public.habit_categories
  (slug, name, description, icon_name, color_hex, base_daily_points,
   health_impact, social_impact, financial_impact, addiction_level)
values
  ('screen_time', 'Ekran Süresi', 'Telefon/ekran süresini azaltmak',
   'phonelink_erase', '#6366F1', 5, 5, 6, 2, 7)
on conflict (slug) do nothing;

-- ============================================================
-- BİTTİ.
-- ============================================================
