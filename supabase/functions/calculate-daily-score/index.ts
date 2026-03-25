// ============================================================
// HabitQuest - search-similar-habit Edge Function
// Hybrid model: Embedding → pgvector → Gemini Flash 2.5
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

// ========================
// Gemini Embedding
// ========================
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
  const data = await res.json();
  return data.embedding.values;
}

// ========================
// Gemini Flash Habit Analysis
// ========================
async function analyzeHabitWithGemini(userInput: string, locale: string): Promise<any> {
  const systemPrompt = `Sen bir alışkanlık analiz motorusun. Kullanıcının tanımladığı alışkanlığı analiz edip JSON formatında yanıt vereceksin.

KURALLAR:
1. Geçerli bir alışkanlık DEĞİLSE: "is_valid": false döndür.
2. Tüm impact skorları 1-10 arasında.
3. base_daily_points: 3-12 arasında (zorluğa göre).
4. difficulty_weight: 0.7 (kolay) - 1.8 (çok zor).
5. step_penalty_reward: DECREASE → negatif (ceza), INCREASE → pozitif (ödül).
6. Katsayılar tıbbi/bilimsel verilere dayansın.
7. activity_converters: Alışkanlığı destekleyecek aktiviteler öner.
8. calories_per_minute: Fiziksel aktivitelerde ortalama 70kg yetişkin, diğerlerinde 0.
9. adaptation_coefficient: Bağımlılık 1.2-1.5, kolay 1.0.
10. YALNIZCA JSON döndür, hiçbir ek metin yok.

ÇIKTI:
{
  "is_valid": boolean,
  "rejection_reason": string | null,
  "habit_metadata": {
    "internal_id": string,
    "type": "NEGATIVE_BYPASS" | "POSITIVE_BUILD",
    "slug": string,
    "title_tr": string,
    "title_en": string,
    "description_tr": string,
    "description_en": string,
    "icon": string,
    "unit": string
  },
  "scoring_engine": {
    "base_daily_points": number,
    "difficulty_weight": number,
    "streak_multiplier_cap": number,
    "effort_multiplier": number
  },
  "impact_matrix": {
    "health_impact": number,
    "mental_discipline": number,
    "financial_impact": number,
    "time_impact": number,
    "social_impact": number
  },
  "progression": {
    "target_direction": "DECREASE" | "INCREASE",
    "default_start_value": number | null,
    "default_target_value": number | null,
    "step_penalty_reward": number,
    "adaptation_coefficient": number
  },
  "activity_converters": [
    {
      "trigger_slug": string,
      "input_unit": string,
      "point_conversion": number,
      "max_bonus_limit": number
    }
  ],
  "calorie_data": {
    "calories_per_minute": number,
    "calorie_to_point_rate": number
  },
  "gemini_report": {
    "category_tag": string,
    "risk_level": "LOW" | "MEDIUM" | "HIGH" | "CRITICAL",
    "analysis_notes": string,
    "suggested_programs": string[]
  }
}`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${FLASH_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              {
                text: `Kullanıcı şu alışkanlığı tanımlıyor (dil: ${locale}): "${userInput}"\n\nAnaliz et ve JSON döndür.`,
              },
            ],
          },
        ],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.3,
          topP: 0.8,
          responseMimeType: "application/json",
        },
      }),
    }
  );
  if (!res.ok) throw new Error(`Gemini Flash: ${await res.text()}`);
  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Empty Gemini response");
  return JSON.parse(text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim());
}

// ========================
// MAIN
// ========================
serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user_input, locale = "tr" } = await req.json();

    if (!user_input || user_input.trim().length < 2) {
      return new Response(
        JSON.stringify({ error: "user_input gerekli (min 2 karakter)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // 1. Embedding üret (ucuz)
    const embedding = await generateEmbedding(user_input);

    // 2. pgvector'de benzer habit ara
    const { data: matches, error: matchError } = await supabase.rpc(
      "match_habit_by_embedding",
      {
        query_embedding: JSON.stringify(embedding),
        match_threshold: SIMILARITY_MAYBE,
        max_results: 3,
      }
    );
    if (matchError) throw new Error(`Vector search: ${matchError.message}`);

    // 3. Karar
    if (matches && matches.length > 0) {
      const top = matches[0];

      if (top.similarity >= SIMILARITY_EXACT) {
        return new Response(
          JSON.stringify({
            action: "EXACT_MATCH",
            message: "Bu alışkanlık zaten sistemde kayıtlı.",
            match: {
              habit_id: top.habit_id,
              slug: top.slug,
              title_tr: top.title_tr,
              title_en: top.title_en,
              similarity: top.similarity,
            },
            gemini_called: false,
            token_cost: 0,
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (top.similarity >= SIMILARITY_MAYBE) {
        return new Response(
          JSON.stringify({
            action: "MAYBE_MATCH",
            message: "Benzer bir alışkanlık bulundu. Bunu mu demek istediniz?",
            suggestions: matches.map((m: any) => ({
              habit_id: m.habit_id,
              slug: m.slug,
              title_tr: m.title_tr,
              title_en: m.title_en,
              similarity: m.similarity,
            })),
            gemini_called: false,
            token_cost: 0,
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 4. Yeni habit → Gemini Flash
    const result = await analyzeHabitWithGemini(user_input, locale);

    if (!result.is_valid) {
      return new Response(
        JSON.stringify({
          action: "INVALID_HABIT",
          message: result.rejection_reason || "Geçerli bir alışkanlık olarak tanımlanamadı.",
          gemini_called: true,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const m = result.habit_metadata;
    const s = result.scoring_engine;
    const imp = result.impact_matrix;
    const prog = result.progression;
    const cal = result.calorie_data;
    const rep = result.gemini_report;

    const { data: newHabit, error: insertErr } = await supabase
      .from("habits")
      .insert({
        internal_id: m.internal_id,
        type: m.type,
        slug: m.slug,
        title_tr: m.title_tr,
        title_en: m.title_en,
        description_tr: m.description_tr,
        description_en: m.description_en,
        icon: m.icon,
        unit: m.unit,
        base_daily_points: s.base_daily_points,
        difficulty_weight: s.difficulty_weight,
        streak_multiplier_cap: s.streak_multiplier_cap,
        effort_multiplier: s.effort_multiplier,
        health_impact: imp.health_impact,
        mental_discipline: imp.mental_discipline,
        financial_impact: imp.financial_impact,
        time_impact: imp.time_impact,
        social_impact: imp.social_impact,
        target_direction: prog.target_direction,
        default_start_value: prog.default_start_value,
        default_target_value: prog.default_target_value,
        step_penalty_reward: prog.step_penalty_reward,
        adaptation_coefficient: prog.adaptation_coefficient,
        activity_converters: result.activity_converters,
        gemini_raw_response: result,
        category_tag: rep.category_tag,
        risk_level: rep.risk_level,
        calories_per_minute: cal.calories_per_minute,
        calorie_to_point_rate: cal.calorie_to_point_rate,
        analysis_version: "v2-flash-2.5",
        is_valid: true,
      })
      .select("id")
      .single();

    if (insertErr) throw new Error(`Insert habit: ${insertErr.message}`);

    // Embedding kaydet
    await supabase.from("habit_embeddings").insert({
      habit_id: newHabit.id,
      embedding: JSON.stringify(embedding),
      input_text: user_input,
      locale,
    });

    return new Response(
      JSON.stringify({
        action: "NEW_HABIT_CREATED",
        message: "Yeni alışkanlık başarıyla oluşturuldu.",
        habit_id: newHabit.id,
        habit: result,
        suggested_programs: rep.suggested_programs,
        gemini_called: true,
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
