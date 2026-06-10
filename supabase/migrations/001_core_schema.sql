-- ============================================================
-- HabitQuest Backend - Core Schema (v2 - Multi-Habit + Combo)
-- Migration 001
-- ============================================================

-- EXTENSIONS
create extension if not exists "pgcrypto";
create extension if not exists "vector";

-- ENUMS
create type habit_type as enum ('NEGATIVE_BYPASS', 'POSITIVE_BUILD');
create type target_direction as enum ('DECREASE', 'INCREASE');
create type risk_level as enum ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
create type program_type as enum (
  'QUIT', 'GRADUAL_DECREASE', 'REDUCE', 'GRADUAL_INCREASE', 'MAINTAIN'
);
create type friendship_status as enum ('PENDING', 'ACCEPTED', 'BLOCKED');

-- 1. PROFILES
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null,
  display_name  text,
  avatar_url    text,
  total_score   numeric not null default 0,
  weekly_score  numeric not null default 0,
  level         int not null default 1,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint username_length check (char_length(username) between 3 and 24),
  constraint username_format check (username ~ '^[a-z0-9_]+$')
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'username')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. HABITS
create table public.habits (
  id                      uuid primary key default gen_random_uuid(),
  internal_id             text unique not null,
  type                    habit_type not null,
  slug                    text unique not null,
  title_tr                text not null,
  title_en                text not null,
  description_tr          text,
  description_en          text,
  icon                    text default '🎯',
  unit                    text,
  base_daily_points       numeric not null default 5.0,
  difficulty_weight       numeric not null default 1.0,
  streak_multiplier_cap   numeric not null default 2.0,
  effort_multiplier       numeric not null default 0.0,
  health_impact           int not null default 5 check (health_impact between 1 and 10),
  mental_discipline       int not null default 5 check (mental_discipline between 1 and 10),
  financial_impact        int not null default 5 check (financial_impact between 1 and 10),
  time_impact             int not null default 5 check (time_impact between 1 and 10),
  social_impact           int not null default 5 check (social_impact between 1 and 10),
  target_direction        target_direction not null,
  default_start_value     numeric,
  default_target_value    numeric,
  step_penalty_reward     numeric not null default 0,
  adaptation_coefficient  numeric not null default 1.0,
  default_milestone_config jsonb not null default '{
    "weekly_reduction_pct": 20,
    "milestone_bonus": 50,
    "milestone_intervals_days": [7, 14, 30, 60, 90, 180, 365]
  }'::jsonb,
  activity_converters     jsonb not null default '[]'::jsonb,
  gemini_raw_response     jsonb,
  category_tag            text,
  risk_level              risk_level default 'MEDIUM',
  analysis_version        text default 'v1',
  calories_per_minute     numeric default 0,
  calorie_to_point_rate   numeric default 0.01,
  is_valid                boolean not null default true,
  created_by              uuid references auth.users(id),
  created_at              timestamptz not null default now()
);
create index idx_habits_slug on public.habits(slug);
create index idx_habits_category on public.habits(category_tag);
create index idx_habits_type on public.habits(type);

-- 3. HABIT EMBEDDINGS
create table public.habit_embeddings (
  id          uuid primary key default gen_random_uuid(),
  habit_id    uuid not null references public.habits(id) on delete cascade,
  embedding   vector(768) not null,
  input_text  text not null,
  locale      text default 'tr',
  created_at  timestamptz not null default now()
);
create index idx_habit_embeddings_vector
  on public.habit_embeddings using hnsw (embedding vector_cosine_ops)
  with (m = 16, ef_construction = 64);

-- 4. USER HABITS
create table public.user_habits (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references public.profiles(id) on delete cascade,
  habit_id                uuid not null references public.habits(id),
  program_type            program_type not null,
  start_value             numeric,
  target_value            numeric,
  current_daily_target    numeric,
  phase_duration_days     int default 7,
  current_phase           int default 1,
  phase_step_amount       numeric,
  current_streak          int not null default 0,
  longest_streak          int not null default 0,
  last_log_date           date,
  milestone_config        jsonb,
  habit_total_score       numeric not null default 0,
  started_at              timestamptz not null default now(),
  target_date             date,
  is_active               boolean not null default true,
  paused_at               timestamptz,
  unique(user_id, habit_id)
);
create index idx_user_habits_user_active on public.user_habits(user_id) where is_active = true;

-- 5. DAILY LOGS
create table public.daily_logs (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.profiles(id) on delete cascade,
  user_habit_id       uuid not null references public.user_habits(id) on delete cascade,
  log_date            date not null default current_date,
  reported_value      numeric,
  daily_target        numeric,
  calories_burned     numeric,
  base_points         numeric not null default 0,
  streak_bonus        numeric not null default 0,
  effort_bonus        numeric not null default 0,
  penalty             numeric not null default 0,
  milestone_bonus     numeric not null default 0,
  activity_bonus      numeric not null default 0,
  total_points        numeric not null default 0,
  streak_multiplier   numeric not null default 1.0,
  streak_day          int not null default 0,
  activity_entries    jsonb not null default '[]'::jsonb,
  notes               text,
  is_success          boolean,
  created_at          timestamptz not null default now(),
  unique(user_habit_id, log_date)
);
create index idx_daily_logs_user_date on public.daily_logs(user_id, log_date desc);
create index idx_daily_logs_habit_date on public.daily_logs(user_habit_id, log_date desc);

-- 6. COMBO STREAK BONUS LOG
create table public.combo_streak_logs (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles(id) on delete cascade,
  combo_date            date not null,
  active_streak_count   int not null,
  combo_bonus_points    numeric not null,
  qualifying_habits     jsonb not null default '[]',
  created_at            timestamptz not null default now(),
  unique(user_id, combo_date)
);
create index idx_combo_streak_user on public.combo_streak_logs(user_id, combo_date desc);

-- 7. FRIENDSHIPS
create table public.friendships (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles(id) on delete cascade,
  addressee_id  uuid not null references public.profiles(id) on delete cascade,
  status        friendship_status not null default 'PENDING',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique(requester_id, addressee_id),
  constraint no_self_friend check (requester_id != addressee_id)
);
create index idx_friendships_addressee on public.friendships(addressee_id) where status = 'PENDING';

-- 8. MILESTONE LOGS
create table public.milestone_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  user_habit_id uuid not null references public.user_habits(id) on delete cascade,
  milestone_day int not null,
  bonus_points  numeric not null,
  achieved_at   timestamptz not null default now(),
  unique(user_habit_id, milestone_day)
);

-- UPDATED_AT TRIGGER
create or replace function public.update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.update_updated_at();

create trigger set_friendships_updated_at
  before update on public.friendships
  for each row execute function public.update_updated_at();
