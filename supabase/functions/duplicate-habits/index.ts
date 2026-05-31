// ============================================================
// HabitQuest - deduplicate-habits Edge Function
//
// Runs every 12 hours (via pg_cron or external scheduler).
//
// FLOW:
//   1. Fetch all unclassified habits (is_classified = false)
//   2. Fetch all canonical habits (is_canonical = true, is_classified = true)
//   3. Send ONLY unclassified + canonicals to Gemini
//      (already-classified aliases are NEVER in the prompt)
//   4. Gemini returns: which unclassified are duplicates of which canonical
//   5. Duplicates → merge into canonical (alias pointer)
//   6. Unique → promote to canonical
//
// TOKEN EFFICIENCY:
//   - Only unclassified habits are sent (not the whole DB)
//   - Canonical list is compact (slug + title_en + category only)
//   - Runs at most twice a day
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
// Preview model (…preview-05-20) kullanımdan kalkabiliyor → stable sürüm.
const FLASH_MODEL = "gemini-2.5-flash";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

async function askGeminiToDeduplicate(
  canonicals: any[],
  unclassified: any[]
): Promise<any[]> {
  const systemPrompt = `You are a habit deduplication engine. You will receive two lists:
1. CANONICAL_HABITS: Existing verified habits (English, authoritative).
2. UNCLASSIFIED_HABITS: New habits that need to be matched or promoted.

Your job: For each unclassified habit, determine if it is a DUPLICATE of any canonical habit.

MATCHING RULES:
- Match based on SEMANTIC MEANING, not exact text.
- "Bilgisayar oyunu oynamayı azalt" (TR) = "Reduce Video Games" (EN) → DUPLICATE
- "Sigara bırakma" (TR) = "Quit Smoking" (EN) → DUPLICATE
- "Günlük meditasyon" (TR) = "Daily Meditation" (EN) → DUPLICATE
- Different activities are NOT duplicates even if categories overlap:
  "Quit Smoking" ≠ "Quit Alcohol" (different substances)
  "Daily Walking" ≠ "Daily Running" (different activities)
- Also compare target_direction and category: "Reduce Gaming" and "Increase Gaming" are NOT duplicates.

Return ONLY a JSON array. Each element:
{
  "unclassified_id": string,
  "action": "MERGE" | "PROMOTE",
  "canonical_id": string | null,
  "confidence": number (0.0-1.0),
  "reason": string
}

- MERGE: This is a duplicate. Set canonical_id to the matching canonical habit's id.
- PROMOTE: This is unique. Set canonical_id to null.
- Only MERGE if confidence >= 0.85.

Return ONLY the JSON array, nothing else.`;

  const canonicalSummary = canonicals.map((c) => ({
    id: c.id,
    slug: c.slug,
    title_en: c.title_en,
    category: c.category_tag,
    direction: c.target_direction,
  }));

  const unclassifiedSummary = unclassified.map((u) => ({
    id: u.id,
    slug: u.slug,
    title_tr: u.title_tr,
    title_en: u.title_en,
    description_en: u.description_en,
    category: u.category_tag,
    direction: u.target_direction,
    source_locale: u.source_locale,
  }));

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
                text: `CANONICAL_HABITS:\n${JSON.stringify(canonicalSummary, null, 2)}\n\nUNCLASSIFIED_HABITS:\n${JSON.stringify(unclassifiedSummary, null, 2)}\n\nDeduplicate and return JSON array.`,
              },
            ],
          },
        ],
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: {
          temperature: 0.1,
          topP: 0.8,
          responseMimeType: "application/json",
        },
      }),
    }
  );

  if (!res.ok) throw new Error(`Gemini: ${await res.text()}`);
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
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // 1. Fetch unclassified habits
    const { data: unclassified, error: uncErr } = await supabase.rpc(
      "get_unclassified_habits"
    );
    if (uncErr) throw new Error(`Fetch unclassified: ${uncErr.message}`);

    if (!unclassified || unclassified.length === 0) {
      return new Response(
        JSON.stringify({
          status: "no_work",
          message: "No unclassified habits to process",
          processed: 0,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Fetch canonical habits
    const { data: canonicals, error: canErr } = await supabase.rpc(
      "get_canonical_habits"
    );
    if (canErr) throw new Error(`Fetch canonicals: ${canErr.message}`);

    let merged = 0;
    let promoted = 0;
    const details: any[] = [];

    // 3. If no canonicals exist yet, promote all unclassified
    if (!canonicals || canonicals.length === 0) {
      for (const habit of unclassified) {
        await supabase.rpc("promote_to_canonical", { p_habit_id: habit.id });
        promoted++;
        details.push({
          id: habit.id,
          slug: habit.slug,
          action: "PROMOTED",
          reason: "No canonicals exist yet",
        });
      }
    } else {
      // 4. Ask Gemini to deduplicate
      const decisions = await askGeminiToDeduplicate(canonicals, unclassified);

      // 5. Execute decisions
      for (const decision of decisions) {
        if (
          decision.action === "MERGE" &&
          decision.canonical_id &&
          decision.confidence >= 0.85
        ) {
          // Verify canonical exists
          const canonicalExists = canonicals.some(
            (c: any) => c.id === decision.canonical_id
          );

          if (canonicalExists) {
            await supabase.rpc("merge_habit_into_canonical", {
              p_alias_id: decision.unclassified_id,
              p_canonical_id: decision.canonical_id,
            });
            merged++;
            details.push({
              id: decision.unclassified_id,
              action: "MERGED",
              canonical_id: decision.canonical_id,
              confidence: decision.confidence,
              reason: decision.reason,
            });
          } else {
            // Canonical not found, promote instead
            await supabase.rpc("promote_to_canonical", {
              p_habit_id: decision.unclassified_id,
            });
            promoted++;
            details.push({
              id: decision.unclassified_id,
              action: "PROMOTED",
              reason: "Referenced canonical not found",
            });
          }
        } else {
          // PROMOTE or low confidence
          await supabase.rpc("promote_to_canonical", {
            p_habit_id: decision.unclassified_id,
          });
          promoted++;
          details.push({
            id: decision.unclassified_id,
            action: "PROMOTED",
            confidence: decision.confidence,
            reason: decision.reason,
          });
        }
      }

      // Handle any unclassified habits not in Gemini's response
      const processedIds = new Set(decisions.map((d: any) => d.unclassified_id));
      for (const habit of unclassified) {
        if (!processedIds.has(habit.id)) {
          await supabase.rpc("promote_to_canonical", {
            p_habit_id: habit.id,
          });
          promoted++;
          details.push({
            id: habit.id,
            slug: habit.slug,
            action: "PROMOTED",
            reason: "Not in Gemini response, promoted by default",
          });
        }
      }
    }

    return new Response(
      JSON.stringify({
        status: "completed",
        total_unclassified: unclassified.length,
        total_canonicals: canonicals?.length ?? 0,
        merged,
        promoted,
        details,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Dedup Error:", error);
    return new Response(
      JSON.stringify({
        error_key: "errors.internal_error",
        details: (error as Error).message,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
