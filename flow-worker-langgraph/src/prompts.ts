/**
 * System prompts for the Flow worker.
 * Ported from the Rust base10-worker implementation.
 */

const MODE_PROMPTS: Record<string, string> = {
  formal:
    "Professional, polished writing. Use complete sentences with proper grammar. " +
    "Maintain a respectful, business-appropriate tone. Avoid contractions and casual expressions.",
  casual:
    "Natural, everyday writing. Use contractions and common expressions. " +
    "Keep a friendly, conversational tone while maintaining clarity.",
  very_casual:
    "Relaxed, informal writing. Use casual language, contractions, and expressions. " +
    "Keep it short and punchy. Skip unnecessary formalities.",
  excited:
    "Enthusiastic, energetic writing! Use exclamation points where appropriate. " +
    "Show genuine excitement while keeping the message clear.",
};

const DEFAULT_MODE_PROMPT =
  "Natural, everyday writing. Use contractions and common expressions. " +
  "Keep a friendly, conversational tone while maintaining clarity.";

export function getModePrompt(mode: string): string {
  return MODE_PROMPTS[mode] ?? DEFAULT_MODE_PROMPT;
}

export function buildFormattingPrompt(
  mode: string,
  appContext: string | undefined,
  shortcuts: string[]
): string {
  let prompt =
    "You are a text formatter. The user will provide raw transcribed text wrapped in <TRANSCRIPTION> tags. " +
    "Reformat ONLY the text inside according to the style below. Output the reformatted text exactly as it would " +
    "be typed. Do NOT generate new content, do NOT add commentary or responses, do NOT say anything.\n\n";

  prompt += "Formatting style: ";
  prompt += getModePrompt(mode);

  if (appContext) {
    prompt += "\n\nContext: User is typing in ";
    prompt += appContext;
    prompt += ". Adjust formatting for this context.";
  }

  if (shortcuts.length > 0) {
    const shortcutsInfo = shortcuts.map((s) => `"${s}"`).join(", ");
    prompt +=
      "\n\n=== CRITICAL INSTRUCTION ===\n" +
      "The input text contains voice shortcut expansions that MUST be output exactly as written, " +
      "word-for-word, with NO modifications, rewording, or style changes whatsoever.\n\n" +
      `Shortcut text to preserve EXACTLY: ${shortcutsInfo}\n\n` +
      "Do NOT paraphrase, rephrase, or alter these phrases in any way. Copy them verbatim into your output.\n" +
      "=== END CRITICAL INSTRUCTION ===";
  }

  return prompt;
}

export function buildInstructionPrompt(): string {
  return (
    "You are a ghostwriter. The user gives you a voice command describing what text to produce.\n\n" +
    "Examples:\n" +
    '- "reject this person" → Write a polite rejection message\n' +
    '- "say I\'m running late" → Write a message saying you\'re running late\n' +
    '- "make this professional: yo whats good" → Transform to professional tone\n' +
    '- "translate to Spanish: see you tomorrow" → Translate the text\n\n' +
    "IMPORTANT: You write the ACTUAL TEXT they want to send. Not a description, not an acknowledgment.\n" +
    'If they say "reject him", you write an actual rejection message like "Thanks for reaching out, but I\'ll have to pass."\n\n' +
    "Output ONLY the final text to send. Nothing else."
  );
}

export function buildValidationPrompt(): string {
  return (
    "You are a typo correction validator. You will receive pairs of words: an original (transcribed) " +
    "word and a proposed correction. Determine if the correction is a valid fix for a speech-to-text typo.\n\n" +
    "Valid corrections:\n" +
    "- Fixing common transcription errors (teh → the, recieve → receive)\n" +
    "- Fixing homophones chosen incorrectly (their → there, your → you're)\n" +
    "- Fixing phonetically similar words (definately → definitely)\n\n" +
    "Invalid corrections:\n" +
    "- Changing to a completely different word (cat → dog)\n" +
    "- Style preferences that aren't typos (awesome → cool)\n" +
    '- Proper nouns being "corrected" to common words\n' +
    "- Both words are valid and not similar (different meanings)\n\n" +
    "For each pair, respond with a JSON array where each item has:\n" +
    '- "valid": true/false\n' +
    '- "reason": brief explanation if invalid\n\n' +
    "Respond ONLY with the JSON array, no other text."
  );
}
