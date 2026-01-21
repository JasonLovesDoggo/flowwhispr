/**
 * Type definitions for the Flow worker.
 */

export interface Env {
  BASETEN_API_KEY: string;
  OPENROUTER_API_KEY: string;
}

// ============ Request Types ============

export interface CombinedRequest {
  whisper_input: WhisperInput;
  completion: CompletionParams;
}

export interface WhisperInput {
  audio: AudioInput;
  whisper_params: WhisperParams;
}

export interface AudioInput {
  audio_b64: string;
}

export interface WhisperParams {
  audio_language: string;
  prompt?: string;
}

export interface CompletionParams {
  mode: string;
  app_context?: string;
  shortcuts_triggered?: string[];
  voice_instruction?: string;
}

// ============ Response Types ============

export interface CombinedResponse {
  transcription: string;
  text: string;
  language?: string;
}

// ============ Base10 Types ============

export interface Base10Request {
  whisper_input: {
    audio: {
      audio_b64: string;
    };
    whisper_params: {
      prompt?: string;
      audio_language: string;
    };
  };
}

export interface Base10Response {
  segments?: Array<{ text: string }>;
  text?: string;
}

// ============ OpenRouter Types ============

export interface OpenRouterRequest {
  models: string[];
  messages: Array<{
    role: string;
    content: string;
  }>;
  max_tokens: number;
  temperature: number;
  provider: {
    allow_fallbacks: boolean;
    sort: {
      by: string;
      partition: string;
    };
  };
}

export interface OpenRouterResponse {
  choices: Array<{
    message: {
      content: string;
    };
  }>;
}

// ============ Validation Types ============

export interface ValidateCorrectionsRequest {
  corrections: CorrectionPair[];
}

export interface CorrectionPair {
  original: string;
  corrected: string;
}

export interface CorrectionValidation {
  original: string;
  corrected: string;
  valid: boolean;
  reason?: string;
}

export interface ValidateCorrectionsResponse {
  results: CorrectionValidation[];
}

// ============ Graph State ============

export interface FlowState {
  // Input
  audioB64: string;
  audioLanguage: string;
  promptHint?: string;
  mode: string;
  appContext?: string;
  shortcutsTriggered: string[];
  voiceInstruction?: string;

  // Environment (passed through state for node access)
  env: Env;

  // Intermediate
  transcription?: string;
  detectedCommand?: string;

  // Output
  formattedText?: string;
  error?: string;
}
