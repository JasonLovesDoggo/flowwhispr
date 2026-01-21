/**
 * LangGraph state machine for the Flow worker.
 *
 * Graph structure:
 *
 * ┌─────────────┐
 * │  transcribe │  (call Base10 Whisper)
 * └──────┬──────┘
 *        │
 *        ▼
 * ┌──────────────────┐
 * │ detect_wake_phrase│  (check for "Hey Flow")
 * └────────┬─────────┘
 *          │
 *     ┌────┴────┐
 *     │         │
 *     ▼         ▼
 * ┌────────┐ ┌──────────┐
 * │ format │ │ instruct │  (ghostwriter)
 * └────┬───┘ └────┬─────┘
 *      │          │
 *      └────┬─────┘
 *           ▼
 *      ┌─────────┐
 *      │   END   │
 *      └─────────┘
 */

import { Annotation, StateGraph, END } from "@langchain/langgraph";
import type { FlowState, Env } from "./types.js";
import {
  transcribeNode,
  detectWakePhraseNode,
  routeByWakePhrase,
  formatNode,
  instructNode,
} from "./nodes.js";

/**
 * Define state schema using LangGraph's Annotation API.
 */
const FlowStateAnnotation = Annotation.Root({
  // Input
  audioB64: Annotation<string>(),
  audioLanguage: Annotation<string>(),
  promptHint: Annotation<string | undefined>(),
  mode: Annotation<string>(),
  appContext: Annotation<string | undefined>(),
  shortcutsTriggered: Annotation<string[]>(),
  voiceInstruction: Annotation<string | undefined>(),

  // Environment
  env: Annotation<Env>(),

  // Intermediate
  transcription: Annotation<string | undefined>(),
  detectedCommand: Annotation<string | undefined>(),

  // Output
  formattedText: Annotation<string | undefined>(),
  error: Annotation<string | undefined>(),
});

/**
 * Build and compile the transcription/formatting graph.
 */
function buildFlowGraph() {
  const graph = new StateGraph(FlowStateAnnotation)
    .addNode("transcribe", transcribeNode)
    .addNode("detect", detectWakePhraseNode)
    .addNode("format", formatNode)
    .addNode("instruct", instructNode)
    .addEdge("__start__", "transcribe")
    .addEdge("transcribe", "detect")
    .addConditionalEdges("detect", routeByWakePhrase, {
      format: "format",
      instruct: "instruct",
    })
    .addEdge("format", END)
    .addEdge("instruct", END);

  return graph.compile();
}

// Compile once and export
export const flowGraph = buildFlowGraph();

/**
 * Run the flow graph with the given input.
 */
export async function runFlowGraph(input: {
  audioB64: string;
  audioLanguage: string;
  promptHint?: string;
  mode: string;
  appContext?: string;
  shortcutsTriggered?: string[];
  voiceInstruction?: string;
  env: Env;
}): Promise<FlowState> {
  const initialState: FlowState = {
    audioB64: input.audioB64,
    audioLanguage: input.audioLanguage,
    promptHint: input.promptHint,
    mode: input.mode,
    appContext: input.appContext,
    shortcutsTriggered: input.shortcutsTriggered ?? [],
    voiceInstruction: input.voiceInstruction,
    env: input.env,
  };

  const result = await flowGraph.invoke(initialState);
  return result as FlowState;
}
