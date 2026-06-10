-- ============================================================
-- HabitQuest - Canonical Habit System
-- Migration 005
-- Canonical (ana, EN) habit'ler tüm scoring verisini tutar;
-- alias'lar canonical_id ile ona işaret eder. 12 saatte bir
-- Gemini batch job sınıflandırılmamışları deduplicate eder.
-- ============================================================

alter table public.habits
  add column if not exists is_canonical boolean not null default true,
  add column if not exists canonical_id uuid references public.habits(id) on delete set null,
  add column if not exists is_classified boolean not null default false,
  add column if not exists source_locale text default 'en';

update public.habits
set is_canonical = true, is_classified = true, source_locale = 'en'
where canonical_id is null;

create index if not exists idx_habits_unclassified
  on public.habits(is_classified) where is_classified = false;
create index if not exists idx_habits_canonical_id
  on public.habits(canonical_id) where canonical_id is not null;

create or replace function public.resolve_canonical(p_habit_id uuid)
returns uuid language plpgsql stable as $$
declare v_canonical_id uuid; v_is_canonical boolean;
begin
  select is_canonical, canonical_id into v_is_canonical, v_canonical_id
  from public.habits where id = p_habit_id;
  if v_is_canonical or v_canonical_id is null then return p_habit_id;
  else return v_canonical_id; end if;
end;
$$;

create or replace function public.get_habit_aliases(p_canonical_id uuid)
returns table (alias_id uuid, slug text, title_tr text, title_en text, source_locale text)
language plpgsql stable as $$
begin
  return query
  select h.id, h.slug, h.title_tr, h.title_en, h.source_locale
  from public.habits h
  where h.canonical_id = p_canonical_id or h.id = p_canonical_id
  order by h.is_canonical desc, h.created_at;
end;
$$;

create or replace function public.get_unclassified_habits()
returns table (
  id uuid, slug text, title_tr text, title_en text, description_tr text, description_en text,
  source_locale text, category_tag text, health_impact int, mental_discipline int,
  financial_impact int, time_impact int, social_impact int,
  target_direction target_direction, created_at timestamptz
) language plpgsql stable security definer as $$
begin
  return query
  select h.id, h.slug, h.title_tr, h.title_en, h.description_tr, h.description_en,
    h.source_locale, h.category_tag, h.health_impact, h.mental_discipline,
    h.financial_impact, h.time_impact, h.social_impact, h.target_direction, h.created_at
  from public.habits h where h.is_classified = false and h.is_valid = true
  order by h.created_at;
end;
$$;

create or replace function public.get_canonical_habits()
returns table (id uuid, slug text, title_en text, description_en text, category_tag text, target_direction target_direction)
language plpgsql stable security definer as $$
begin
  return query
  select h.id, h.slug, h.title_en, h.description_en, h.category_tag, h.target_direction
  from public.habits h
  where h.is_canonical = true and h.is_classified = true and h.is_valid = true
  order by h.category_tag, h.slug;
end;
$$;

create or replace function public.merge_habit_into_canonical(p_alias_id uuid, p_canonical_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.habits set is_canonical = false, canonical_id = p_canonical_id, is_classified = true
  where id = p_alias_id;
  update public.user_habits set habit_id = p_canonical_id where habit_id = p_alias_id;
  update public.habit_embeddings set habit_id = p_canonical_id where habit_id = p_alias_id;
end;
$$;

create or replace function public.promote_to_canonical(p_habit_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.habits set is_canonical = true, canonical_id = null, is_classified = true
  where id = p_habit_id;
end;
$$;
