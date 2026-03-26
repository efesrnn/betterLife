// ============================================================
// HabitQuest - search-similar-habit Edge Function
//
// KEY-BASED i18n: Returns message_key, NOT translated text.
// Flutter's easy_localization handles all translations.
//
// CROSS-LANGUAGE MATCHING: Stores embeddings for all supported
// locale titles so "video games" matches "Bilgisayar Oyunları".
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;

const EMBEDDING_MODEL = "text-embedding-004";
const FLASH_MODEL = "gemini-2.5-flash-preview-05-20";
const SIMILARITY_EXACT = 0.9;
const SIMILARITY_MAYBE = 0.6;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

async function generateEmbedding(text: string): Promise<number[]> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: `models/${EMBEDDING_MODEL}`,
        content: { parts: [{ text }] },
        taskType: "SEMANTIC_SIMILARITY",
      }),
    }
  );
  if (!res.ok) throw new Error(`Embedding API: ${await res.text()}`);
  return (await res.json()).embedding.values;
}

async function generateEmbeddings(
  texts: { text: string; locale: string }[]
): Promise<{ embedding: number[]; locale: string; text: string }[]> {
  const results = [];
  for (const item of texts) {
    results.push({
      embedding: await generateEmbedding(item.text),
      locale: item.locale,
      text: item.text,
    });
  }
  return results;
}

async function analyzeHabitWithGemini(userInput: string, locale: string): Promise<any> {
  const systemPrompt = `You are a habit analysis engine. Analyze the user's described habit and return a JSON response.

RULES:
1. If NOT a valid habit: set "is_valid": false.
2. Impact scores: 1-10. base_daily_points: 3-12. difficulty_weight: 0.7-1.8.
3. step_penalty_reward: negative for DECREASE, positive for INCREASE.
4. Base coefficients on medical/scientific data.
5. Return ONLY JSON.
6. ALWAYS provide both Turkish and English titles, descriptions, and unit names.
7. rejection_reason: {"tr": "...", "en": "..."} or null.

OUTPUT:
{
  "is_valid": boolean,
  "rejection_reason": {"tr": string, "en": string} | null,
  "habit_metadata": {
    "internal_id": string, "type": "NEGATIVE_BYPASS"|"POSITIVE_BUILD",
    "slug": string,
    "title_tr": string, "title_en": string,
    "description_tr": string, "description_en": string,
    "icon": string, "unit_tr": string, "unit_en": string
  },
  "scoring_engine": {
    "base_daily_points": number, "difficulty_weight": number,
    "streak_multiplier_cap": number, "effort_multiplier": number
  },
  "impact_matrix": {
    "health_impact": number, "mental_discipline": number,
    "financial_impact": number, "time_impact": number, "social_impact": number
  },
  "progression": {
    "target_direction": "DECREASE"|"INCREASE",
    "default_start_value": number|null, "default_target_value": number|null,
    "step_penalty_reward": number, "adaptation_coefficient": number
  },
  "activity_converters": [{"trigger_slug":string,"input_unit":string,"point_conversion":number,"max_bonus_limit":number}],
  "calorie_data": {"calories_per_minute": number, "calorie_to_point_rate": number},
  "gemini_report": {
    "category_tag": string, "risk_level": "LOW"|"MEDIUM"|"HIGH"|"CRITICAL",
    "analysis_notes": string, "suggested_programs": string[]
  }
}`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${FLASH_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{
          role: "user",
          parts: [{ text: `User describes this habit (locale: ${locale}): "${userInput}"\n\nAnalyze and return JSON.` }],
        }],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: { temperature: 0.3, topP: 0.8, responseMimeType: "application/json" },
      }),
    }
  );
  if (!res.ok) throw new Error(`Gemini Flash: ${await res.text()}`);
  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Empty Gemini response");
  return JSON.parse(text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim());
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user_input, locale = "en" } = await req.json();

    if (!user_input || user_input.trim().length < 2) {
      return new Response(
        JSON.stringify({ error_key: "errors.input_required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const embedding = await generateEmbedding(user_input);

    const { data: matches, error: matchError } = await supabase.rpc(
      "match_habit_by_embedding",
      { query_embedding: JSON.stringify(embedding), match_threshold: SIMILARITY_MAYBE, max_results: 3 }
    );
    if (matchError) throw new Error(`Vector search: ${matchError.message}`);

    if (matches && matches.length > 0) {
      const top = matches[0];

      if (top.similarity >= SIMILARITY_EXACT) {
        return new Response(
          JSON.stringify({
            action: "EXACT_MATCH",
            message_key: "habit_search.exact_match",
            match: {
              habit_id: top.habit_id, slug: top.slug,
              title_tr: top.title_tr, title_en: top.title_en,
              similarity: top.similarity,
            },
            gemini_called: false,
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (top.similarity >= SIMILARITY_MAYBE) {
        return new Response(
          JSON.stringify({
            action: "MAYBE_MATCH",
            message_key: "habit_search.maybe_match",
            suggestions: matches.map((m: any) => ({
              habit_id: m.habit_id, slug: m.slug,
              title_tr: m.title_tr, title_en: m.title_en,
              similarity: m.similarity,
            })),
            gemini_called: false,
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // New habit → Gemini
    const result = await analyzeHabitWithGemini(user_input, locale);

    if (!result.is_valid) {
      return new Response(
        JSON.stringify({
          action: "INVALID_HABIT",
          message_key: "habit_search.invalid_habit",
          rejection_reason: result.rejection_reason,
          gemini_called: true,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const m = result.habit_metadata;
    const s = result.scoring_engine;
    const i = result.impact_matrix;
    const p = result.progression;
    const c = result.calorie_data;
    const r = result.gemini_report;

    const { data: newHabit, error: insertErr } = await supabase
      .from("habits")
      .insert({
        internal_id: m.internal_id, type: m.type, slug: m.slug,
        title_tr: m.title_tr, title_en: m.title_en,
        description_tr: m.description_tr, description_en: m.description_en,
        icon: m.icon, unit: m.unit_tr || m.unit || "",
        base_daily_points: s.base_daily_points, difficulty_weight: s.difficulty_weight,
        streak_multiplier_cap: s.streak_multiplier_cap, effort_multiplier: s.effort_multiplier,
        health_impact: i.health_impact, mental_discipline: i.mental_discipline,
        financial_impact: i.financial_impact, time_impact: i.time_impact, social_impact: i.social_impact,
        target_direction: p.target_direction, default_start_value: p.default_start_value,
        default_target_value: p.default_target_value, step_penalty_reward: p.step_penalty_reward,
        adaptation_coefficient: p.adaptation_coefficient,
        activity_converters: result.activity_converters, gemini_raw_response: result,
        category_tag: r.category_tag, risk_level: r.risk_level,
        calories_per_minute: c.calories_per_minute, calorie_to_point_rate: c.calorie_to_point_rate,
        analysis_version: "v2-flash-2.5", is_valid: true,
      })
      .select("id")
      .single();

    if (insertErr) throw new Error(`Insert: ${insertErr.message}`);

    // Multi-locale embeddings
    const embTexts = [
      { text: user_input, locale },
      { text: `${m.title_tr}. ${m.description_tr || ""}`.trim(), locale: "tr" },
      { text: `${m.title_en}. ${m.description_en || ""}`.trim(), locale: "en" },
    ];
    const unique = embTexts.filter(
      (item, idx, arr) => idx === arr.findIndex((t) => t.text.toLowerCase() === item.text.toLowerCase())
    );
    const allEmb = await generateEmbeddings(unique);
    await supabase.from("habit_embeddings").insert(
      allEmb.map((e) => ({
        habit_id: newHabit.id, embedding: JSON.stringify(e.embedding),
        input_text: e.text, locale: e.locale,
      }))
    );

    return new Response(
      JSON.stringify({
        action: "NEW_HABIT_CREATED",
        message_key: "habit_search.new_habit_created",
        habit_id: newHabit.id,
        habit: result,
        suggested_programs: r.suggested_programs,
        gemini_called: true,
        embeddings_stored: unique.length,
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error_key: "errors.internal_error", details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});