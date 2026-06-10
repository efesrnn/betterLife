-- Gelistirici ayarlarindan habit katalogunu duzenleme yetkisi.
-- RLS policy yerine SECURITY DEFINER fonksiyon kullanilir; yetki kontrolu
-- fonksiyonun icinde e-posta ile yapilir. Gerekirse e-postayi degistir.
--
-- Sema notu (SETUP_ALL.sql): risk_level kolonu enum tipidir
-- (LOW / MEDIUM / HIGH / CRITICAL), category_tag duz metindir.
--
-- Daha once "admin habit duzenler" policy'sini olusturduysan su komutla
-- kaldirabilirsin (zorunlu degil):
--   drop policy if exists "admin habit duzenler" on public.habits;

create or replace function public.admin_update_habit(p_habit_id uuid, p_patch jsonb)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_risk text;
begin
  if (auth.jwt() ->> 'email') is distinct from 'plus.medtrack@gmail.com' then
    return jsonb_build_object('error', 'forbidden');
  end if;

  -- risk_level enum oldugu icin once dogrula, sonra cast et
  v_risk := upper(coalesce(p_patch->>'risk_level', ''));
  if v_risk <> '' and v_risk not in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') then
    return jsonb_build_object('error', 'invalid_risk_level',
      'detail', 'risk_level must be LOW, MEDIUM, HIGH or CRITICAL');
  end if;

  update public.habits set
    title_tr          = coalesce(nullif(p_patch->>'title_tr', ''), title_tr),
    title_en          = coalesce(nullif(p_patch->>'title_en', ''), title_en),
    icon              = coalesce(nullif(p_patch->>'icon', ''), icon),
    unit              = coalesce(nullif(p_patch->>'unit', ''), unit),
    base_daily_points = coalesce((p_patch->>'base_daily_points')::numeric, base_daily_points),
    difficulty_weight = coalesce((p_patch->>'difficulty_weight')::numeric, difficulty_weight),
    category_tag      = coalesce(nullif(p_patch->>'category_tag', ''), category_tag),
    risk_level        = coalesce(nullif(v_risk, '')::risk_level, risk_level),
    is_valid          = coalesce((p_patch->>'is_valid')::boolean, is_valid)
  where id = p_habit_id;

  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;
  return jsonb_build_object('ok', true);
exception
  when others then
    return jsonb_build_object('error', 'internal_error', 'detail', SQLERRM);
end;
$$;
