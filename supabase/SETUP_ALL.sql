-- SETUP_ALL.sql — teardown + 001..005 + 007 + 008 (tekrar çalıştırılabilir)
-- DİKKAT: profiles dahil siler → önce Auth → Users temizle. 006 ayrı (pg_cron).

-- ====== TEARDOWN ======
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

-- ====== 001 ======
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

-- ====== 002 ======
-- ============================================================
-- HabitQuest Backend - Scoring Engine (v2 - Multi-Habit + Combo)
-- Migration 002
-- ============================================================

create or replace function public.calc_streak_multiplier(
  p_streak_days int, p_cap numeric default 2.0
) returns numeric language plpgsql immutable as $$
declare v_mult numeric := 1.0;
begin
  if p_streak_days > 7 then
    v_mult := 1.0 + ((p_streak_days - 7) * 0.05);
  end if;
  return least(v_mult, p_cap);
end;
$$;

create or replace function public.get_combo_bonus_points(p_active_count int)
returns numeric language plpgsql immutable as $$
begin
  case
    when p_active_count >= 5 then return 15.0;
    when p_active_count = 4 then return 10.0;
    when p_active_count = 3 then return 7.0;
    when p_active_count = 2 then return 5.0;
    else return 0.0;
  end case;
end;
$$;

create or replace function public.check_and_award_combo_bonus(p_user_id uuid)
returns jsonb language plpgsql security definer as $$
declare
  v_active_streak_count int;
  v_qualifying         jsonb;
  v_last_combo_date    date;
  v_bonus              numeric;
  v_today              date := current_date;
begin
  select count(*), jsonb_agg(jsonb_build_object(
    'user_habit_id', uh.id, 'habit_slug', h.slug,
    'habit_title_tr', h.title_tr, 'current_streak', uh.current_streak))
  into v_active_streak_count, v_qualifying
  from public.user_habits uh
  join public.habits h on h.id = uh.habit_id
  where uh.user_id = p_user_id and uh.is_active = true and uh.current_streak >= 1;

  if v_active_streak_count < 2 then
    return jsonb_build_object('combo_awarded', false,
      'reason', 'need_at_least_2_active_streaks', 'active_streak_count', v_active_streak_count);
  end if;

  select max(combo_date) into v_last_combo_date
  from public.combo_streak_logs where user_id = p_user_id;

  if v_last_combo_date is not null and (v_today - v_last_combo_date) < 14 then
    return jsonb_build_object('combo_awarded', false, 'reason', 'cooldown_active',
      'days_until_next', 14 - (v_today - v_last_combo_date),
      'active_streak_count', v_active_streak_count,
      'next_bonus_date', (v_last_combo_date + 14)::text);
  end if;

  v_bonus := public.get_combo_bonus_points(v_active_streak_count);

  insert into public.combo_streak_logs (user_id, combo_date, active_streak_count, combo_bonus_points, qualifying_habits)
  values (p_user_id, v_today, v_active_streak_count, v_bonus, coalesce(v_qualifying, '[]'::jsonb))
  on conflict (user_id, combo_date) do nothing;

  update public.profiles set total_score = total_score + v_bonus, updated_at = now() where id = p_user_id;

  return jsonb_build_object('combo_awarded', true, 'active_streak_count', v_active_streak_count,
    'combo_bonus_points', v_bonus, 'qualifying_habits', v_qualifying);
end;
$$;

create or replace function public.calculate_daily_score(
  p_user_habit_id uuid, p_reported_value numeric,
  p_calories_burned numeric default null, p_activity_entries jsonb default '[]'::jsonb
) returns jsonb language plpgsql security definer as $$
declare
  v_rec record; v_daily_target numeric; v_base_points numeric := 0;
  v_streak_mult numeric := 1.0; v_streak_bonus numeric := 0; v_effort_bonus numeric := 0;
  v_penalty numeric := 0; v_activity_bonus numeric := 0; v_total numeric := 0;
  v_is_success boolean := false; v_new_streak int; v_ratio numeric; v_exceeded numeric;
  v_converter jsonb; v_entry jsonb; v_entry_bonus numeric; v_act_results jsonb := '[]'::jsonb;
begin
  select h.base_daily_points, h.difficulty_weight, h.streak_multiplier_cap,
    h.effort_multiplier, h.step_penalty_reward, h.target_direction,
    h.activity_converters, h.calories_per_minute, h.calorie_to_point_rate,
    uh.program_type, uh.current_daily_target, uh.current_streak,
    uh.start_value, uh.target_value
  into v_rec from public.user_habits uh
  join public.habits h on h.id = uh.habit_id where uh.id = p_user_habit_id;

  if not found then return jsonb_build_object('error', 'user_habit_not_found'); end if;
  v_daily_target := coalesce(v_rec.current_daily_target, v_rec.target_value, 0);

  if v_rec.program_type in ('QUIT', 'REDUCE') and v_rec.target_direction = 'DECREASE' then
    if p_reported_value <= v_daily_target then
      v_base_points := v_rec.base_daily_points * v_rec.difficulty_weight; v_is_success := true;
    else
      v_exceeded := p_reported_value - v_daily_target;
      v_penalty := v_exceeded * abs(v_rec.step_penalty_reward);
      v_base_points := greatest(0, v_rec.base_daily_points - v_penalty);
    end if;
  elsif v_rec.program_type = 'GRADUAL_DECREASE' and v_rec.target_direction = 'DECREASE' then
    if p_reported_value <= v_daily_target then
      v_base_points := v_rec.base_daily_points * v_rec.difficulty_weight; v_is_success := true;
      if v_daily_target > 0 and p_reported_value < (v_daily_target * 0.5) then
        v_base_points := v_base_points * 1.15;
      end if;
    else
      v_exceeded := p_reported_value - v_daily_target;
      v_penalty := v_exceeded * abs(v_rec.step_penalty_reward);
      v_base_points := greatest(0, v_rec.base_daily_points - v_penalty);
    end if;
  elsif v_rec.program_type = 'GRADUAL_INCREASE' and v_rec.target_direction = 'INCREASE' then
    if v_daily_target > 0 then
      v_ratio := least(p_reported_value / v_daily_target, 1.5);
      v_base_points := v_ratio * v_rec.base_daily_points * v_rec.difficulty_weight;
      v_is_success := (p_reported_value >= v_daily_target);
      if p_reported_value > v_daily_target then
        v_effort_bonus := (p_reported_value - v_daily_target) * v_rec.step_penalty_reward;
      end if;
    else
      v_base_points := v_rec.base_daily_points; v_is_success := true;
    end if;
  elsif v_rec.program_type = 'MAINTAIN' then
    if v_rec.target_direction = 'INCREASE' then
      v_ratio := least(p_reported_value / nullif(v_daily_target, 0), 1.0);
      v_base_points := coalesce(v_ratio, 1.0) * v_rec.base_daily_points * v_rec.difficulty_weight;
      v_is_success := (p_reported_value >= v_daily_target);
    else
      v_is_success := (p_reported_value <= v_daily_target);
      if v_is_success then
        v_base_points := v_rec.base_daily_points * v_rec.difficulty_weight;
      else
        v_exceeded := p_reported_value - v_daily_target;
        v_penalty := v_exceeded * abs(v_rec.step_penalty_reward);
        v_base_points := greatest(0, v_rec.base_daily_points - v_penalty);
      end if;
    end if;
  else
    v_base_points := v_rec.base_daily_points; v_is_success := true;
  end if;

  if v_is_success then v_new_streak := v_rec.current_streak + 1; else v_new_streak := 0; end if;

  v_streak_mult := public.calc_streak_multiplier(v_new_streak, v_rec.streak_multiplier_cap);
  v_streak_bonus := v_base_points * (v_streak_mult - 1.0);

  if p_calories_burned is not null and v_rec.calorie_to_point_rate > 0 then
    v_effort_bonus := v_effort_bonus + (p_calories_burned * v_rec.calorie_to_point_rate);
  end if;
  if v_rec.effort_multiplier > 0 and v_rec.target_direction = 'INCREASE' then
    v_effort_bonus := v_effort_bonus + (p_reported_value * v_rec.effort_multiplier);
  end if;

  if jsonb_array_length(p_activity_entries) > 0 then
    for v_entry in select * from jsonb_array_elements(p_activity_entries) loop
      for v_converter in select * from jsonb_array_elements(v_rec.activity_converters) loop
        if (v_entry->>'slug') = (v_converter->>'trigger_slug') then
          v_entry_bonus := least(
            (v_entry->>'value')::numeric * (v_converter->>'point_conversion')::numeric,
            (v_converter->>'max_bonus_limit')::numeric);
          v_activity_bonus := v_activity_bonus + v_entry_bonus;
          v_act_results := v_act_results || jsonb_build_object(
            'slug', v_entry->>'slug', 'value', (v_entry->>'value')::numeric,
            'unit', v_entry->>'unit', 'bonus_points', round(v_entry_bonus, 2));
        end if;
      end loop;
    end loop;
  end if;

  v_total := greatest(0, round(v_base_points, 2) + round(v_streak_bonus, 2)
    + round(v_effort_bonus, 2) + round(v_activity_bonus, 2) - round(v_penalty, 2));

  return jsonb_build_object(
    'user_habit_id', p_user_habit_id, 'log_date', current_date,
    'reported_value', p_reported_value, 'daily_target', v_daily_target,
    'is_success', v_is_success, 'base_points', round(v_base_points, 2),
    'streak_day', v_new_streak, 'streak_multiplier', round(v_streak_mult, 2),
    'streak_bonus', round(v_streak_bonus, 2), 'effort_bonus', round(v_effort_bonus, 2),
    'activity_bonus', round(v_activity_bonus, 2), 'activity_entries', v_act_results,
    'penalty', round(v_penalty, 2), 'milestone_bonus', 0,
    'total_points', round(v_total, 2), 'new_streak', v_new_streak);
end;
$$;

create or replace function public.update_gradual_target(p_user_habit_id uuid)
returns void language plpgsql security definer as $$
declare v_uh record; v_logs_in_phase int; v_new_target numeric; v_dir target_direction;
begin
  select * into v_uh from public.user_habits where id = p_user_habit_id;
  select count(*) into v_logs_in_phase from public.daily_logs
  where user_habit_id = p_user_habit_id
    and log_date >= (v_uh.started_at::date + ((v_uh.current_phase - 1) * v_uh.phase_duration_days));
  if v_logs_in_phase >= v_uh.phase_duration_days then
    select target_direction into v_dir from public.habits where id = v_uh.habit_id;
    if v_dir = 'DECREASE' then
      v_new_target := greatest(v_uh.target_value, v_uh.current_daily_target - v_uh.phase_step_amount);
    else
      v_new_target := least(v_uh.target_value, v_uh.current_daily_target + v_uh.phase_step_amount);
    end if;
    update public.user_habits set current_daily_target = v_new_target, current_phase = v_uh.current_phase + 1
    where id = p_user_habit_id;
  end if;
end;
$$;

create or replace function public.submit_daily_log(
  p_user_habit_id uuid, p_reported_value numeric,
  p_calories_burned numeric default null, p_activity_entries jsonb default '[]'::jsonb,
  p_notes text default null
) returns jsonb language plpgsql security definer as $$
declare
  v_score jsonb; v_user_id uuid; v_log_id uuid; v_today date := current_date;
  v_milestone_bonus numeric := 0; v_uh record; v_milestone_intervals int[];
  v_new_streak int; v_combo_result jsonb;
begin
  select uh.user_id, uh.current_streak, uh.longest_streak,
    coalesce(uh.milestone_config, h.default_milestone_config) as ms_config,
    uh.program_type, uh.start_value, uh.target_value,
    uh.phase_duration_days, uh.current_phase, uh.phase_step_amount, uh.is_active
  into v_uh from public.user_habits uh
  join public.habits h on h.id = uh.habit_id where uh.id = p_user_habit_id;

  if not found then return jsonb_build_object('error', 'user_habit_not_found'); end if;
  if not v_uh.is_active then return jsonb_build_object('error', 'habit_is_paused'); end if;
  v_user_id := v_uh.user_id;

  if exists (select 1 from public.daily_logs where user_habit_id = p_user_habit_id and log_date = v_today) then
    return jsonb_build_object('error', 'already_logged_today');
  end if;

  v_score := public.calculate_daily_score(p_user_habit_id, p_reported_value, p_calories_burned, p_activity_entries);
  if v_score ? 'error' then return v_score; end if;
  v_new_streak := (v_score->>'new_streak')::int;

  select array_agg(val::int) into v_milestone_intervals
  from jsonb_array_elements_text(
    coalesce(v_uh.ms_config->'milestone_intervals_days', '[7,14,30,60,90,180,365]'::jsonb)) as val;

  if v_new_streak = any(v_milestone_intervals) then
    v_milestone_bonus := coalesce((v_uh.ms_config->>'milestone_bonus')::numeric, 50);
    insert into public.milestone_logs (user_id, user_habit_id, milestone_day, bonus_points)
    values (v_user_id, p_user_habit_id, v_new_streak, v_milestone_bonus)
    on conflict (user_habit_id, milestone_day) do nothing;
    v_score := jsonb_set(v_score, '{milestone_bonus}', to_jsonb(v_milestone_bonus));
    v_score := jsonb_set(v_score, '{total_points}',
      to_jsonb((v_score->>'total_points')::numeric + v_milestone_bonus));
  end if;

  insert into public.daily_logs (
    user_id, user_habit_id, log_date, reported_value, daily_target, calories_burned,
    base_points, streak_bonus, effort_bonus, penalty, milestone_bonus, activity_bonus,
    total_points, streak_multiplier, streak_day, activity_entries, notes, is_success
  ) values (
    v_user_id, p_user_habit_id, v_today, p_reported_value,
    (v_score->>'daily_target')::numeric, p_calories_burned,
    (v_score->>'base_points')::numeric, (v_score->>'streak_bonus')::numeric,
    (v_score->>'effort_bonus')::numeric, (v_score->>'penalty')::numeric,
    (v_score->>'milestone_bonus')::numeric, (v_score->>'activity_bonus')::numeric,
    (v_score->>'total_points')::numeric, (v_score->>'streak_multiplier')::numeric,
    v_new_streak, v_score->'activity_entries', p_notes, (v_score->>'is_success')::boolean
  ) returning id into v_log_id;

  update public.user_habits
  set current_streak = v_new_streak, longest_streak = greatest(longest_streak, v_new_streak),
      last_log_date = v_today, habit_total_score = habit_total_score + (v_score->>'total_points')::numeric
  where id = p_user_habit_id;

  update public.profiles set total_score = total_score + (v_score->>'total_points')::numeric,
      updated_at = now() where id = v_user_id;

  if v_uh.program_type in ('GRADUAL_DECREASE', 'GRADUAL_INCREASE') and v_uh.phase_step_amount is not null then
    perform public.update_gradual_target(p_user_habit_id);
  end if;

  v_combo_result := public.check_and_award_combo_bonus(v_user_id);

  return jsonb_build_object('log_id', v_log_id, 'score', v_score, 'combo_streak', v_combo_result);
end;
$$;

create or replace function public.match_habit_by_embedding(
  query_embedding vector(768), match_threshold numeric default 0.6, max_results int default 5
) returns table (
  habit_id uuid, slug text, title_tr text, title_en text, similarity numeric, input_text text
) language plpgsql stable as $$
begin
  return query
  select he.habit_id, h.slug, h.title_tr, h.title_en,
    round((1 - (he.embedding <=> query_embedding))::numeric, 4) as similarity, he.input_text
  from public.habit_embeddings he
  join public.habits h on h.id = he.habit_id
  where h.is_valid = true and (1 - (he.embedding <=> query_embedding)) > match_threshold
  order by he.embedding <=> query_embedding limit max_results;
end;
$$;

create or replace function public.get_user_dashboard(p_user_id uuid)
returns jsonb language plpgsql stable security definer as $$
declare
  v_habits jsonb; v_active_count int; v_combo_info jsonb;
  v_last_combo date; v_days_left int; v_today date := current_date; v_profile record;
begin
  select jsonb_agg(jsonb_build_object(
    'user_habit_id', uh.id, 'habit_slug', h.slug, 'habit_title_tr', h.title_tr,
    'icon', h.icon, 'program_type', uh.program_type, 'current_streak', uh.current_streak,
    'longest_streak', uh.longest_streak, 'current_daily_target', uh.current_daily_target,
    'habit_total_score', uh.habit_total_score, 'last_log_date', uh.last_log_date,
    'logged_today', exists(select 1 from public.daily_logs dl
      where dl.user_habit_id = uh.id and dl.log_date = v_today)) order by uh.started_at),
  count(*) filter (where uh.current_streak >= 1)
  into v_habits, v_active_count
  from public.user_habits uh join public.habits h on h.id = uh.habit_id
  where uh.user_id = p_user_id and uh.is_active = true;

  select max(combo_date) into v_last_combo from public.combo_streak_logs where user_id = p_user_id;
  if v_last_combo is not null then v_days_left := greatest(0, 14 - (v_today - v_last_combo));
  else v_days_left := 0; end if;

  v_combo_info := jsonb_build_object('active_streak_count', v_active_count,
    'potential_bonus', public.get_combo_bonus_points(v_active_count),
    'days_until_next_bonus', v_days_left,
    'next_bonus_date', case when v_last_combo is not null then (v_last_combo + 14)::text else v_today::text end);

  select * into v_profile from public.profiles where id = p_user_id;

  return jsonb_build_object(
    'profile', jsonb_build_object('username', v_profile.username, 'display_name', v_profile.display_name,
      'total_score', v_profile.total_score, 'weekly_score', v_profile.weekly_score, 'level', v_profile.level),
    'active_habits', coalesce(v_habits, '[]'::jsonb), 'combo_streak', v_combo_info);
end;
$$;

create or replace function public.get_friend_leaderboard(p_user_id uuid)
returns table (
  user_id uuid, username text, display_name text, avatar_url text,
  total_score numeric, weekly_score numeric, active_habits int, rank bigint
) language plpgsql stable security definer as $$
begin
  return query
  with friend_ids as (
    select p_user_id as fid
    union
    select case when requester_id = p_user_id then addressee_id else requester_id end
    from public.friendships
    where status = 'ACCEPTED' and (requester_id = p_user_id or addressee_id = p_user_id)
  )
  select p.id, p.username, p.display_name, p.avatar_url, p.total_score, p.weekly_score,
    (select count(*)::int from public.user_habits uh where uh.user_id = p.id and uh.is_active = true) as active_habits,
    row_number() over (order by p.total_score desc)
  from public.profiles p join friend_ids f on f.fid = p.id
  order by p.total_score desc;
end;
$$;

create or replace function public.reset_weekly_scores()
returns void language plpgsql security definer as $$
begin update public.profiles set weekly_score = 0; end;
$$;

create or replace function public.recalculate_weekly_score(p_user_id uuid)
returns numeric language plpgsql security definer as $$
declare v_weekly numeric;
begin
  select coalesce(sum(total_points), 0) into v_weekly from public.daily_logs
  where user_id = p_user_id and log_date >= date_trunc('week', current_date);
  update public.profiles set weekly_score = v_weekly where id = p_user_id;
  return v_weekly;
end;
$$;

-- ====== 003 ======
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
create poli
-- ====== 004 ======
-- ============================================================
-- HabitQuest Backend - Seed Data (v2)
-- Migration 004
-- ============================================================

insert into public.habits (
  internal_id, type, slug, title_tr, title_en, description_tr, description_en,
  icon, unit, base_daily_points, difficulty_weight, streak_multiplier_cap, effort_multiplier,
  health_impact, mental_discipline, financial_impact, time_impact, social_impact,
  target_direction, default_start_value, default_target_value,
  step_penalty_reward, adaptation_coefficient, activity_converters,
  category_tag, risk_level, calories_per_minute, calorie_to_point_rate
) values
('substance_quit_001', 'NEGATIVE_BYPASS', 'smoking_cessation',
 'Sigarayı Bırakma', 'Quit Smoking', 'Sigara içme alışkanlığını bırakma programı', 'Smoking cessation program',
 '🚭', 'adet', 10.0, 1.4, 2.5, 0.0, 10, 9, 9, 7, 6, 'DECREASE', 20, 0, -2.0, 1.2,
 '[{"trigger_slug":"physical_activity","input_unit":"minutes","point_conversion":0.15,"max_bonus_limit":5.0},
   {"trigger_slug":"water_intake","input_unit":"liters","point_conversion":1.0,"max_bonus_limit":3.0},
   {"trigger_slug":"deep_breathing","input_unit":"minutes","point_conversion":0.3,"max_bonus_limit":3.0}]'::jsonb,
 'ADDICTION', 'CRITICAL', 0, 0),
('substance_quit_002', 'NEGATIVE_BYPASS', 'alcohol_cessation',
 'Alkolü Bırakma', 'Quit Alcohol', 'Alkol tüketimini bırakma programı', 'Alcohol cessation program',
 '🍷', 'kadeh', 8.0, 1.3, 2.5, 0.0, 9, 9, 8, 6, 7, 'DECREASE', 4, 0, -2.5, 1.3,
 '[{"trigger_slug":"physical_activity","input_unit":"minutes","point_conversion":0.12,"max_bonus_limit":4.0},
   {"trigger_slug":"social_activity","input_unit":"events","point_conversion":2.0,"max_bonus_limit":4.0}]'::jsonb,
 'ADDICTION', 'HIGH', 0, 0),
('fitness_build_001', 'POSITIVE_BUILD', 'daily_walking',
 'Günlük Yürüyüş', 'Daily Walking', 'Her gün belirli süre yürüyüş yapma', 'Walk a set amount daily',
 '🚶', 'dakika', 6.0, 1.0, 2.0, 0.1, 7, 4, 2, 6, 3, 'INCREASE', 0, 30, 0.2, 1.0,
 '[{"trigger_slug":"water_intake","input_unit":"liters","point_conversion":0.5,"max_bonus_limit":2.0}]'::jsonb,
 'FITNESS', 'LOW', 4.0, 0.01),
('nutrition_quit_001', 'NEGATIVE_BYPASS', 'sugar_reduction',
 'Şeker Tüketimini Azaltma', 'Reduce Sugar Intake', 'Günlük şeker tüketimini azaltma', 'Reduce daily sugar consumption',
 '🍬', 'gram', 7.0, 1.1, 2.0, 0.0, 8, 7, 5, 3, 2, 'DECREASE', 80, 25, -0.1, 1.0,
 '[{"trigger_slug":"fruit_intake","input_unit":"porsiyon","point_conversion":1.5,"max_bonus_limit":3.0}]'::jsonb,
 'NUTRITION', 'MEDIUM', 0, 0),
('mental_build_001', 'POSITIVE_BUILD', 'daily_reading',
 'Günlük Kitap Okuma', 'Daily Reading', 'Her gün kitap okuma alışkanlığı', 'Build a daily reading habit',
 '📚', 'sayfa', 5.0, 0.9, 2.0, 0.0, 3, 6, 2, 8, 3, 'INCREASE', 0, 20, 0.15, 1.0,
 '[]'::jsonb, 'MENTAL', 'LOW', 0, 0),
('digital_quit_001', 'NEGATIVE_BYPASS', 'social_media_reduction',
 'Sosyal Medya Süresini Azaltma', 'Reduce Social Media Time', 'Günlük sosyal medya kullanımını azaltma', 'Cut down daily social media usage',
 '📱', 'dakika', 6.0, 1.0, 2.0, 0.0, 4, 7, 2, 9, 5, 'DECREASE', 180, 30, -0.05, 1.0,
 '[{"trigger_slug":"physical_activity","input_unit":"minutes","point_conversion":0.1,"max_bonus_limit":3.0},
   {"trigger_slug":"reading","input_unit":"pages","point_conversion":0.2,"max_bonus_limit":2.0}]'::jsonb,
 'DIGITAL_WELLNESS', 'MEDIUM', 0, 0),
('health_build_001', 'POSITIVE_BUILD', 'water_intake',
 'Günlük Su İçme', 'Daily Water Intake', 'Her gün yeterli su tüketme', 'Drink enough water daily',
 '💧', 'litre', 4.0, 0.8, 1.8, 0.0, 6, 3, 1, 2, 1, 'INCREASE', 0, 2.5, 0.5, 1.0,
 '[]'::jsonb, 'HEALTH', 'LOW', 0, 0),
('fitness_build_002', 'POSITIVE_BUILD', 'daily_exercise',
 'Günlük Egzersiz', 'Daily Exercise', 'Her gün egzersiz yapma alışkanlığı', 'Build a daily exercise routine',
 '💪', 'dakika', 8.0, 1.2, 2.0, 0.12, 9, 7, 3, 7, 4, 'INCREASE', 0, 45, 0.2, 1.0,
 '[{"trigger_slug":"water_intake","input_unit":"liters","point_conversion":0.5,"max_bonus_limit":2.0}]'::jsonb,
 'FITNESS', 'LOW', 7.5, 0.012),
('nutrition_quit_002', 'NEGATIVE_BYPASS', 'fast_food_cessation',
 'Fast Food''u Bırakma', 'Quit Fast Food', 'Fast food tüketimini bırakma', 'Stop eating fast food',
 '🍔', 'öğün', 7.0, 1.1, 2.0, 0.0, 7, 6, 7, 4, 3, 'DECREASE', 2, 0, -3.0, 1.1,
 '[{"trigger_slug":"home_cooking","input_unit":"meals","point_conversion":2.0,"max_bonus_limit":4.0},
   {"trigger_slug":"physical_activity","input_unit":"minutes","point_conversion":0.1,"max_bonus_limit":3.0}]'::jsonb,
 'NUTRITION', 'MEDIUM', 0, 0)
on conflict (slug) do nothing;

-- ====== 005 ======
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

-- ====== 007 ======
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

-- ====== 008 ======
-- ============================================================
-- 008 — Avatars storage bucket + politikaları
-- home_screen profil fotoğrafını 'avatars' bucket'ına yükler.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_auth_insert" on storage.objects;
create policy "avatars_auth_insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'avatars');

drop policy if exists "avatars_auth_update" on storage.objects;
create policy "avatars_auth_update" on storage.objects
  for update to authenticated using (bucket_id = 'avatars');

-- ====== 009 UNIT_COST ======
-- ============================================================
-- 009 — user_habits.unit_cost
-- Tasarruf hesabı için birim başına maliyet (₺). Örn. 1 sigara ₺5.75.
-- ============================================================
alter table public.user_habits add column if not exists unit_cost numeric default 0;
notify pgrst, 'reload schema';
