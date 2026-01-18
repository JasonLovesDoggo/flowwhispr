//! Full Adaptive Transcription Pipeline Example
//!
//! This demonstrates how to integrate contact categorization with AI completion
//! to achieve actual adaptive transcription output.
//!
//! Flow:
//! 1. Detect active Messages contact
//! 2. Classify contact category
//! 3. Get appropriate writing mode
//! 4. Pass to AI with mode-specific system prompt
//! 5. Get adapted output
//!
//! Run with: cargo run --example full_adaptive_pipeline

use flowwispr_core::contacts::{ContactClassifier, ContactInput};
use flowwispr_core::macos_messages::MessagesDetector;
use flowwispr_core::types::{ContactCategory, WritingMode};

/// Simulated AI completion (replace with actual GPT-4/Gemini call)
async fn complete_with_ai(raw_input: &str, mode: WritingMode, category: ContactCategory) -> String {
    // In real implementation, this would call OpenAI/Gemini API
    // For now, we simulate the output based on the mode

    let system_prompt = match mode {
        WritingMode::Formal => {
            "You are a professional writing assistant. Rewrite the user's casual message \
             in formal, professional language with proper grammar and punctuation. \
             Remove slang and use complete sentences."
        }
        WritingMode::Casual => {
            "You are a friendly writing assistant. Rewrite the user's message in a \
             conversational but clear tone. Keep it natural and friendly."
        }
        WritingMode::VeryCasual => {
            "You are a casual texting assistant. Rewrite the user's message in very \
             informal language with minimal punctuation, like a text message to a friend."
        }
        WritingMode::Excited => {
            "You are an enthusiastic writing assistant. Rewrite the user's message with \
             warmth and affection, using terms of endearment where appropriate. Add emoji."
        }
    };

    println!("\n📝 AI System Prompt:");
    println!("   {}", system_prompt);
    println!("\n🎤 Raw Input: \"{}\"", raw_input);

    // Simulated AI output (in production, call actual API)
    let adapted = adapt_message_simulated(raw_input, mode, category);

    println!("🤖 AI Output: \"{}\"", adapted);

    adapted
}

/// Simulated message adaptation (replace with actual AI call)
fn adapt_message_simulated(raw: &str, mode: WritingMode, category: ContactCategory) -> String {
    // This mimics what GPT-4/Gemini would do
    match mode {
        WritingMode::Formal => {
            match category {
                ContactCategory::Professional => {
                    "Apologies, I will be running a few minutes behind schedule this morning.".to_string()
                }
                _ => {
                    "I apologize for the inconvenience, but I will be arriving approximately 5 minutes late.".to_string()
                }
            }
        }
        WritingMode::Casual => {
            "Hey, I'm running about 5 minutes late, sorry!".to_string()
        }
        WritingMode::VeryCasual => {
            "gonna be like 5 min late sry".to_string()
        }
        WritingMode::Excited => {
            "Sorry babe, running a bit late! Be there in 5 💕".to_string()
        }
    }
}

#[tokio::main]
async fn main() {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║   FlowWispr Full Adaptive Transcription Pipeline        ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();

    // Step 1: Get user input (in production, this comes from Whisper)
    let raw_transcription = "I'm gonna be 5 min late, sorry.";

    println!("🎙️  User Voice Input (from Whisper):");
    println!("   \"{}\"", raw_transcription);
    println!();

    // Step 2: Detect active Messages contact
    println!("📱 Step 1: Detecting Active Messages Contact...");
    println!("   ─────────────────────────────────────────────");

    let contact_name = match MessagesDetector::get_active_contact() {
        Ok(Some(name)) => {
            println!("   ✅ Detected: {}", name);
            name
        }
        Ok(None) => {
            println!("   ⚠️  No active conversation - using simulated contact");
            "Boss".to_string() // Fallback for demo
        }
        Err(e) => {
            println!("   ❌ Error: {} - using simulated contact", e);
            "Boss".to_string()
        }
    };
    println!();

    // Step 3: Classify the contact
    println!("🏷️  Step 2: Classifying Contact...");
    println!("   ─────────────────────────────────");

    let classifier = ContactClassifier::new();
    let input = ContactInput {
        name: contact_name.clone(),
        organization: String::new(), // In production, lookup from Contacts.app
    };

    let category = classifier.classify(&input);
    println!("   Contact: {}", contact_name);
    println!("   Category: {:?}", category);
    println!();

    // Step 4: Get appropriate writing mode
    println!("✍️  Step 3: Determining Writing Mode...");
    println!("   ──────────────────────────────────");

    let mode = category.suggested_writing_mode();
    println!("   {:?} → {:?}", category, mode);
    println!();

    // Step 5: Call AI completion with mode-specific prompt
    println!("🤖 Step 4: AI Completion with Adaptive Prompt...");
    println!("   ────────────────────────────────────────────");

    let adapted_output = complete_with_ai(raw_transcription, mode, category).await;
    println!();

    // Step 6: Display final result
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║                    FINAL RESULT                          ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    println!("📥 Raw Input:      \"{}\"", raw_transcription);
    println!("📤 Adapted Output: \"{}\"", adapted_output);
    println!();
    println!("🎯 Context-Aware Adaptation:");
    println!("   • Detected contact type: {:?}", category);
    println!("   • Applied writing style: {:?}", mode);
    println!("   • Message transformed for appropriate tone");
    println!();

    // Show what would happen with different contacts
    println!("──────────────────────────────────────────────────────────");
    println!("📊 Same Input, Different Contacts:");
    println!("──────────────────────────────────────────────────────────");
    println!();

    let test_contacts = vec![
        ("Boss", ContactCategory::Professional),
        ("Mom", ContactCategory::CloseFamily),
        ("❤️ Partner", ContactCategory::Partner),
        ("Mike 🍺", ContactCategory::CasualPeer),
    ];

    for (name, expected_cat) in test_contacts {
        let input = ContactInput {
            name: name.to_string(),
            organization: if name == "Boss" { "Acme Corp".to_string() } else { String::new() },
        };

        let cat = classifier.classify(&input);
        let mode = cat.suggested_writing_mode();
        let output = adapt_message_simulated(raw_transcription, mode, cat);

        println!("Contact: {}", name);
        println!("  → Category: {:?}", cat);
        println!("  → Output: \"{}\"", output);
        println!();
    }

    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║                 INTEGRATION GUIDE                        ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    println!("To integrate this into your FlowWispr app:");
    println!();
    println!("1. Replace simulated AI with real API call:");
    println!("   ```rust");
    println!("   let completion_request = CompletionRequest::new(raw_text)");
    println!("       .with_mode(mode)");
    println!("       .with_system_prompt(mode.prompt_modifier());");
    println!("   ");
    println!("   let result = completion_provider");
    println!("       .complete(completion_request)");
    println!("       .await?;");
    println!("   ```");
    println!();
    println!("2. Hook into your voice pipeline:");
    println!("   Voice → Whisper → Raw Text → [Classifier] → AI → Output");
    println!();
    println!("3. Test with real Messages contacts!");
    println!();
}
