/**
 * Flow Worker - Cloudflare Worker entry point using Hono.
 *
 * Endpoints:
 * - POST / - Main transcription + formatting endpoint
 * - POST /validate-corrections - Correction validation endpoint
 */

import { Hono } from "hono";
import type {
  Env,
  CombinedRequest,
  CombinedResponse,
  ValidateCorrectionsRequest,
  ValidateCorrectionsResponse,
} from "./types.js";
import { runFlowGraph } from "./graph.js";
import { validateCorrections } from "./validation.js";

const app = new Hono<{ Bindings: Env }>();

/**
 * POST / - Main transcription + formatting endpoint.
 *
 * Request body:
 * {
 *   "whisper_input": {
 *     "audio": { "audio_b64": "..." },
 *     "whisper_params": { "audio_language": "en", "prompt": "optional hint" }
 *   },
 *   "completion": {
 *     "mode": "casual",
 *     "app_context": "optional context",
 *     "shortcuts_triggered": [],
 *     "voice_instruction": "optional override"
 *   }
 * }
 *
 * Response:
 * { "transcription": "...", "text": "..." }
 */
app.post("/", async (c) => {
  let body: CombinedRequest;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "Invalid JSON" }, 400);
  }

  // Validate required fields
  if (!body.whisper_input?.audio?.audio_b64) {
    return c.json({ error: "Missing audio_b64" }, 400);
  }
  if (!body.whisper_input?.whisper_params?.audio_language) {
    return c.json({ error: "Missing audio_language" }, 400);
  }
  if (!body.completion?.mode) {
    return c.json({ error: "Missing mode" }, 400);
  }

  const result = await runFlowGraph({
    audioB64: body.whisper_input.audio.audio_b64,
    audioLanguage: body.whisper_input.whisper_params.audio_language,
    promptHint: body.whisper_input.whisper_params.prompt,
    mode: body.completion.mode,
    appContext: body.completion.app_context,
    shortcutsTriggered: body.completion.shortcuts_triggered,
    voiceInstruction: body.completion.voice_instruction,
    env: c.env,
  });

  if (result.error) {
    return c.json({ error: result.error }, 500);
  }

  const response: CombinedResponse = {
    transcription: result.transcription ?? "",
    text: result.formattedText ?? "",
  };

  return c.json(response);
});

/**
 * POST /validate-corrections - Correction validation endpoint.
 *
 * Request body:
 * { "corrections": [{ "original": "...", "corrected": "..." }] }
 *
 * Response:
 * { "results": [{ "original": "...", "corrected": "...", "valid": true/false, "reason": "..." }] }
 */
app.post("/validate-corrections", async (c) => {
  let body: ValidateCorrectionsRequest;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "Invalid JSON" }, 400);
  }

  if (!Array.isArray(body.corrections)) {
    return c.json({ error: "Missing corrections array" }, 400);
  }

  try {
    const results = await validateCorrections(c.env, body.corrections);
    const response: ValidateCorrectionsResponse = { results };
    return c.json(response);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return c.json({ error: message }, 500);
  }
});

// 405 for non-POST requests
app.all("*", (c) => {
  return c.text("Method Not Allowed", 405);
});

export default app;
