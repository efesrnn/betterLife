-- ============================================================
-- submit_daily_log — sağlamlaştırma + gerçek hatayı görünür kılma
-- Günlük log kaydedilmiyorsa: bu fonksiyon (deploy edilmemişse) onu kurar,
-- ve herhangi bir runtime hatasında {error,detail} döndürür → uygulama
-- snackbar'da gerçek sebebi gösterir.
-- Supabase → SQL Editor → çalıştır.
-- ============================================================
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
    coalesce((v_score->>'daily_target')::numeric, 0), p_calories_burned,
    coalesce((v_score->>'base_points')::numeric, 0), coalesce((v_score->>'streak_bonus')::numeric, 0),
    coalesce((v_score->>'effort_bonus')::numeric, 0), coalesce((v_score->>'penalty')::numeric, 0),
    coalesce((v_score->>'milestone_bonus')::numeric, 0), coalesce((v_score->>'activity_bonus')::numeric, 0),
    coalesce((v_score->>'total_points')::numeric, 0), coalesce((v_score->>'streak_multiplier')::numeric, 1),
    v_new_streak, coalesce(v_score->'activity_entries', '[]'::jsonb), p_notes,
    coalesce((v_score->>'is_success')::boolean, false)
  ) returning id into v_log_id;

  update public.user_habits
  set current_streak = v_new_streak, longest_streak = greatest(longest_streak, v_new_streak),
      last_log_date = v_today,
      habit_total_score = habit_total_score + coalesce((v_score->>'total_points')::numeric, 0)
  where id = p_user_habit_id;

  update public.profiles set total_score = total_score + coalesce((v_score->>'total_points')::numeric, 0),
      updated_at = now() where id = v_user_id;

  if v_uh.program_type in ('GRADUAL_DECREASE', 'GRADUAL_INCREASE') and v_uh.phase_step_amount is not null then
    perform public.update_gradual_target(p_user_habit_id);
  end if;

  begin
    v_combo_result := public.check_and_award_combo_bonus(v_user_id);
  exception when others then
    v_combo_result := jsonb_build_object('combo_awarded', false);
  end;

  return jsonb_build_object('log_id', v_log_id, 'score', v_score, 'combo_streak', v_combo_result);
exception
  when others then
    return jsonb_build_object('error', 'internal_error', 'detail', SQLERRM);
end;
$$;

grant execute on function public.submit_daily_log(uuid, numeric, numeric, jsonb, text) to authenticated;

-- Hızlı test (kendi e-postan + bir user_habit id'si ile):
-- select public.submit_daily_log('<user_habit_id>'::uuid, 2);
