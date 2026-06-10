-- ============================================================
-- HabitQuest Backend - Row Level Security Policies (v2)
-- Migration 003
-- ============================================================

alter table public.profiles enable row level security;
alter table public.habits enable row level security;
alter table public.habit_embeddings enable row level security;
alter table public.user_habits enable row level security;
alter table public.daily_logs enable row level security;
alter table public.friendships enable row level security;
alter table public.milestone_logs enable row level security;
alter table public.combo_streak_logs enable row level security;

-- PROFILES
create policy "profiles_select_all"   on public.profiles for select using (true);
create policy "profiles_insert_own"   on public.profiles for insert
  with check (auth.uid() = id);
create policy "profiles_update_own"   on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);

-- HABITS
create policy "habits_select_valid"   on public.habits for select using (is_valid = true);
create policy "habits_insert_auth"    on public.habits for insert with check (auth.uid() is not null);

-- EMBEDDINGS
create policy "embeddings_no_direct"  on public.habit_embeddings for select using (false);

-- USER HABITS
create policy "user_habits_select_own" on public.user_habits for select
  using (auth.uid() = user_id);
create policy "user_habits_select_friends" on public.user_habits for select
  using (exists (select 1 from public.friendships f where f.status = 'ACCEPTED'
    and ((f.requester_id = auth.uid() and f.addressee_id = user_id)
      or (f.addressee_id = auth.uid() and f.requester_id = user_id))));
create policy "user_habits_insert_own" on public.user_habits for insert
  with check (auth.uid() = user_id);
create policy "user_habits_update_own" on public.user_habits for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "user_habits_delete_own" on public.user_habits for delete
  using (auth.uid() = user_id);

-- DAILY LOGS
create policy "daily_logs_select_own" on public.daily_logs for select
  using (auth.uid() = user_id);
create policy "daily_logs_select_friends" on public.daily_logs for select
  using (exists (select 1 from public.friendships f where f.status = 'ACCEPTED'
    and ((f.requester_id = auth.uid() and f.addressee_id = user_id)
      or (f.addressee_id = auth.uid() and f.requester_id = user_id))));
create policy "daily_logs_insert_own" on public.daily_logs for insert
  with check (auth.uid() = user_id);
create policy "daily_logs_update_today" on public.daily_logs for update
  using (auth.uid() = user_id and log_date = current_date)
  with check (auth.uid() = user_id);

-- COMBO STREAK LOGS
create policy "combo_select_own" on public.combo_streak_logs for select
  using (auth.uid() = user_id);
create policy "combo_select_friends" on public.combo_streak_logs for select
  using (exists (select 1 from public.friendships f where f.status = 'ACCEPTED'
    and ((f.requester_id = auth.uid() and f.addressee_id = user_id)
      or (f.addressee_id = auth.uid() and f.requester_id = user_id))));

-- FRIENDSHIPS
create policy "friendships_select_own" on public.friendships for select
  using (auth.uid() in (requester_id, addressee_id));
create policy "friendships_insert" on public.friendships for insert
  with check (auth.uid() = requester_id);
create policy "friendships_update_addressee" on public.friendships for update
  using (auth.uid() = addressee_id) with check (auth.uid() = addressee_id);
create policy "friendships_delete" on public.friendships for delete
  using (auth.uid() in (requester_id, addressee_id));

-- MILESTONE LOGS
create policy "milestones_select_own" on public.milestone_logs for select
  using (auth.uid() = user_id);
create policy "milestones_insert_own" on public.milestone_logs for insert
  with check (auth.uid() = user_id);
