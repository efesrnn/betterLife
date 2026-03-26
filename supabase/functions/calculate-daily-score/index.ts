// ============================================================
// HabitQuest - calculate-daily-score Edge Function
// KEY-BASED i18n: Returns error_key, Flutter translates.
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function errorResponse(key: string, status: number) {
  return new Response(
    JSON.stringify({ error_key: key }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return errorResponse("errors.missing_auth", 401);

    const userClient = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) return errorResponse("errors.unauthorized", 401);

    const body = await req.json();
    const {
      user_habit_id,
      reported_value,
      calories_burned = null,
      activity_entries = [],
      notes = null,
    } = body;

    if (!user_habit_id || reported_value === undefined || reported_value === null) {
      return errorResponse("errors.fields_required", 400);
    }
    if (typeof reported_value !== "number" || reported_value < 0) {
      return errorResponse("errors.invalid_value", 400);
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const { data: uh, error: uhErr } = await admin
      .from("user_habits")
      .select("user_id, is_active")
      .eq("id", user_habit_id)
      .single();

    if (uhErr || !uh) return errorResponse("errors.habit_not_found", 404);
    if (uh.user_id !== user.id) return errorResponse("errors.not_your_habit", 403);
    if (!uh.is_active) return errorResponse("errors.habit_paused", 400);

    if (!Array.isArray(activity_entries)) {
      return errorResponse("errors.invalid_activities", 400);
    }
    for (const e of activity_entries) {
      if (!e.slug || e.value === undefined || !e.unit) {
        return errorResponse("errors.invalid_activity_entry", 400);
      }
    }

    const { data: result, error: rpcErr } = await admin.rpc("submit_daily_log", {
      p_user_habit_id: user_habit_id,
      p_reported_value: reported_value,
      p_calories_burned: calories_burned,
      p_activity_entries: activity_entries,
      p_notes: notes,
    });

    if (rpcErr) throw new Error(`RPC: ${rpcErr.message}`);

    if (result?.error) {
      const key = `errors.${result.error}`;
      const code = result.error === "already_logged_today" ? 409 : 400;
      return errorResponse(key, code);
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error_key: "errors.internal_error", details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});