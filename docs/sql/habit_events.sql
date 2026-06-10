-- Profil akisinda gorunen relapse / habit silme olaylari.
-- Supabase SQL editorunde calistirilir.

create table if not exists public.habit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_habit_id uuid references public.user_habits(id) on delete set null,
  event_type text not null check (event_type in ('RELAPSE', 'REMOVED')),
  -- baslik ve ikon o anki haliyle saklanir, habit silinse de akista gorunur
  title_tr text,
  title_en text,
  icon text,
  created_at timestamptz not null default now()
);

alter table public.habit_events enable row level security;

-- Herkes yalnizca kendi adina olay ekleyebilir
create policy "kendi olayini ekle" on public.habit_events
  for insert with check (auth.uid() = user_id);

-- Profiller herkese acik oldugu icin olaylar da okunabilir
create policy "olaylari herkes gorebilir" on public.habit_events
  for select using (true);

create index if not exists habit_events_user_idx
  on public.habit_events (user_id, created_at desc);
