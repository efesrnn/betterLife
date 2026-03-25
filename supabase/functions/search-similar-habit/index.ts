// ============================================================
// HabitQuest - calculate-daily-score Edge Function
// Günlük log → DB scoring → Combo streak check (otomatik)
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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userClient = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user },
      error: authErr,
    } = await userClient.auth.getUser();
    if (authErr || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const {
      user_habit_id,
      reported_value,
      calories_burned = null,
      activity_entries = [],
      notes = null,
    } = body;

    // Validation
    if (!user_habit_id || reported_value === undefined || reported_value === null) {
      return new Response(
        JSON.stringify({ error: "user_habit_id ve reported_value zorunlu" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (typeof reported_value !== "number" || reported_value < 0) {
      return new Response(
        JSON.stringify({ error: "reported_value negatif olmayan bir sayı olmalı" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Ownership check
    const { data: uh, error: uhErr } = await admin
      .from("user_habits")
      .select("user_id, is_active")
      .eq("id", user_habit_id)
      .single();

    if (uhErr || !uh) {
      return new Response(
        JSON.stringify({ error: "Habit bulunamadı" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (uh.user_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Bu habit size ait değil" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (!uh.is_active) {
      return new Response(
        JSON.stringify({ error: "Bu habit duraklatılmış" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Activity entries format check
    if (!Array.isArray(activity_entries)) {
      return new Response(
        JSON.stringify({ error: "activity_entries bir dizi olmalı" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    for (const e of activity_entries) {
      if (!e.slug || e.value === undefined || !e.unit) {
        return new Response(
          JSON.stringify({ error: 'Her activity entry\'de "slug", "value" ve "unit" olmalı' }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // DB fonksiyonunu çağır (scoring + combo streak otomatik)
    const { data: result, error: rpcErr } = await admin.rpc("submit_daily_log", {
      p_user_habit_id: user_habit_id,
      p_reported_value: reported_value,
      p_calories_burned: calories_burned,
      p_activity_entries: activity_entries,
      p_notes: notes,
    });

    if (rpcErr) throw new Error(`RPC: ${rpcErr.message}`);

    if (result?.error) {
      const code = result.error === "already_logged_today" ? 409 : 400;
      return new Response(
        JSON.stringify({ error: result.error }),
        { status: code, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // result = { log_id, score, combo_streak }
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
