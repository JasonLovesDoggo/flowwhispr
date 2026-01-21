/**
 * Correction validation functionality.
 * Validates whether correction pairs are legitimate typo fixes.
 */

import type {
  Env,
  CorrectionPair,
  CorrectionValidation,
  OpenRouterRequest,
  OpenRouterResponse,
} from "./types.js";
import { buildValidationPrompt } from "./prompts.js";

const OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions";

const OPENROUTER_MODELS = [
  "meta-llama/llama-4-maverick:nitro",
  "openai/gpt-oss-120b:nitro",
  "openrouter/auto",
];

interface AIValidation {
  valid: boolean;
  reason?: string;
}

/**
 * Validate correction pairs using AI to determine if they're legitimate typo fixes.
 */
export async function validateCorrections(
  env: Env,
  corrections: CorrectionPair[]
): Promise<CorrectionValidation[]> {
  if (corrections.length === 0) {
    return [];
  }

  const pairsJson = JSON.stringify(corrections);

  const request: OpenRouterRequest = {
    models: OPENROUTER_MODELS,
    messages: [
      { role: "system", content: buildValidationPrompt() },
      { role: "user", content: `Validate these corrections:\n${pairsJson}` },
    ],
    max_tokens: 500,
    temperature: 0.1,
    provider: {
      allow_fallbacks: true,
      sort: {
        by: "throughput",
        partition: "none",
      },
    },
  };

  const response = await fetch(OPENROUTER_API_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(request),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenRouter error ${response.status}: ${errorText}`);
  }

  const openRouterResponse: OpenRouterResponse = await response.json();
  const content = openRouterResponse.choices[0]?.message?.content;

  if (!content) {
    throw new Error("No completion returned");
  }

  // Parse the AI's response
  let aiResults: AIValidation[];
  try {
    aiResults = JSON.parse(content);
  } catch {
    // If parsing fails, assume all are valid (fail open)
    console.warn(`[WARN] Failed to parse AI validation response: ${content}`);
    aiResults = corrections.map(() => ({ valid: true }));
  }

  // Zip with original corrections
  return corrections.map((pair, i) => ({
    original: pair.original,
    corrected: pair.corrected,
    valid: aiResults[i]?.valid ?? true,
    reason: aiResults[i]?.reason,
  }));
}
