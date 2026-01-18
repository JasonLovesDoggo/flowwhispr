/**
 * LangGraph node functions for the Flow worker.
 * Each node performs a step in the transcription/formatting pipeline.
 */

import type { FlowState, Base10Request, Base10Response, OpenRouterRequest, OpenRouterResponse } from "./types.js";
import { buildFormattingPrompt, buildInstructionPrompt } from "./prompts.js";

const BASE10_API_URL = "https://model-232nj723.api.baseten.co/environments/production/predict";
const OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions";
const WAKE_PHRASE = "hey flow";

const OPENROUTER_MODELS = [
  "meta-llama/llama-4-maverick:nitro",
  "openai/gpt-oss-120b:nitro",
  "openrouter/auto",
];

/**
 * Node: Transcribe audio using Base10 Whisper API.
 */
export async function transcribeNode(state: FlowState): Promise<Partial<FlowState>> {
  const { env, audioB64, audioLanguage, promptHint } = state;

  // Build prompt: include "Hey Flow" to help recognize wake phrase
  const prompt = promptHint && promptHint.length > 0
    ? `Hey Flow. ${promptHint}`
    : "Hey Flow.";

  const request: Base10Request = {
    whisper_input: {
      audio: { audio_b64: audioB64 },
      whisper_params: {
        prompt,
        audio_language: audioLanguage,
      },
    },
  };

  const response = await fetch(BASE10_API_URL, {
    method: "POST",
    headers: {
      "Authorization": `Api-Key ${env.BASETEN_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(request),
  });

  if (!response.ok) {
    const errorText = await response.text();
    return { error: `Base10 error ${response.status}: ${errorText}` };
  }

  const base10Response: Base10Response = await response.json();

  // Extract transcription from segments or text field
  let transcription: string | undefined;

  if (base10Response.segments && base10Response.segments.length > 0) {
    transcription = base10Response.segments.map((s) => s.text).join("").trim();
  }

  if (!transcription && base10Response.text) {
    transcription = base10Response.text.trim();
  }

  if (!transcription) {
    return { error: "No transcription returned" };
  }

  console.log(`[DEBUG] transcription=${transcription}`);
  return { transcription };
}

/**
 * Node: Detect wake phrase ("Hey Flow") and extract command if present.
 */
export function detectWakePhraseNode(state: FlowState): Partial<FlowState> {
  const { transcription, voiceInstruction } = state;

  // If voice instruction already provided, use that
  if (voiceInstruction) {
    console.log(`[DEBUG] Using provided voice instruction: ${voiceInstruction}`);
    return { detectedCommand: voiceInstruction };
  }

  // Check for wake phrase in transcription
  if (transcription) {
    const lower = transcription.toLowerCase();
    if (lower.startsWith(WAKE_PHRASE)) {
      // Extract everything after "hey flow" (trim leading comma/space)
      let rest = transcription.slice(WAKE_PHRASE.length);
      // Trim leading commas and spaces
      while (rest.length > 0 && (rest[0] === "," || rest[0] === " ")) {
        rest = rest.slice(1);
      }
      if (rest.length > 0) {
        console.log(`[DEBUG] Detected voice command: ${rest}`);
        return { detectedCommand: rest };
      }
    }
  }

  console.log("[DEBUG] No wake phrase detected, using normal formatting");
  return { detectedCommand: undefined };
}

/**
 * Routing function: determine which path to take based on wake phrase detection.
 */
export function routeByWakePhrase(state: FlowState): "format" | "instruct" {
  return state.detectedCommand ? "instruct" : "format";
}

/**
 * Node: Format text using normal formatting mode.
 */
export async function formatNode(state: FlowState): Promise<Partial<FlowState>> {
  const { env, transcription, mode, appContext, shortcutsTriggered } = state;

  if (!transcription) {
    return { error: "No transcription to format" };
  }

  console.log(`[DEBUG] Using normal formatting mode with mode=${mode}`);

  const systemPrompt = buildFormattingPrompt(mode, appContext, shortcutsTriggered);

  const request: OpenRouterRequest = {
    models: OPENROUTER_MODELS,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: `<TRANSCRIPTION>\n${transcription}\n</TRANSCRIPTION>` },
    ],
    max_tokens: 1000,
    temperature: 0.3,
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
    return { error: `OpenRouter error ${response.status}: ${errorText}` };
  }

  const openRouterResponse: OpenRouterResponse = await response.json();
  const formattedText = openRouterResponse.choices[0]?.message?.content;

  if (!formattedText) {
    return { error: "No completion returned" };
  }

  console.log(`[DEBUG] result text=${formattedText}`);
  return { formattedText };
}

/**
 * Node: Generate text from voice command (ghostwriter mode).
 */
export async function instructNode(state: FlowState): Promise<Partial<FlowState>> {
  const { env, detectedCommand } = state;

  if (!detectedCommand) {
    return { error: "No voice command to process" };
  }

  console.log("[DEBUG] Using voice command mode");

  const systemPrompt = buildInstructionPrompt();

  const request: OpenRouterRequest = {
    models: OPENROUTER_MODELS,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: detectedCommand },
    ],
    max_tokens: 1000,
    temperature: 0.3,
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
    return { error: `OpenRouter error ${response.status}: ${errorText}` };
  }

  const openRouterResponse: OpenRouterResponse = await response.json();
  const formattedText = openRouterResponse.choices[0]?.message?.content;

  if (!formattedText) {
    return { error: "No completion returned" };
  }

  console.log(`[DEBUG] result text=${formattedText}`);
  return { formattedText };
}
