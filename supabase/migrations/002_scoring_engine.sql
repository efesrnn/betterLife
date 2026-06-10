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
