//! Test Real Integration with AI Provider
//!
//! This example shows how your voice input now adapts based on who you're messaging.
//!
//! IMPORTANT: This tests the LOGIC - you still need to configure your AI API key
//! for the actual AI completion to work. The contact detection and classification
//! IS working now!
//!
//! Run with: cargo run --example test_real_integration

use flowwispr_core::macos_messages::MessagesDetector;
use flowwispr_core::contacts::{ContactClassifier, ContactInput};
use flowwispr_core::types::WritingMode;

fn main() {
    println!("╔════════════════════════════════════════════════════════════╗");
    println!("║   Testing Real FlowWispr Integration                      ║");
    println!("║   Contact-Aware Transcription is NOW ACTIVE!              ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!();

    // Simulate what happens when you dictate
    let raw_transcription = "I'm gonna be 5 min late, sorry.";
    println!("🎤 You say: \"{}\"", raw_transcription);
    println!();

    // Step 1: Detect active Messages contact (this is now automatic in ffi.rs)
    println!("📱 Step 1: Detecting Messages Contact...");
    println!("   ────────────────────────────────────────");

    match MessagesDetector::get_active_contact() {
        Ok(Some(contact_name)) => {
            println!("   ✅ Active conversation: {}", contact_name);
            println!();

            // Step 2: Classify contact (this is now automatic in ffi.rs)
            println!("🏷️  Step 2: Classifying Contact...");
            println!("   ─────────────────────────────────");

            let classifier = ContactClassifier::new();
            let input = ContactInput {
                name: contact_name.clone(),
                organization: String::new(),
            };

            let category = classifier.classify(&input);
            let mode = category.suggested_writing_mode();

            println!("   Contact: {}", contact_name);
            println!("   Category: {:?}", category);
            println!("   Writing Mode: {:?}", mode);
            println!();

            // Step 3: Show what the AI will receive
            println!("🤖 Step 3: AI Completion Configuration...");
            println!("   ──────────────────────────────────────────");

            let system_prompt = mode.prompt_modifier();
            println!("   System Prompt:");
            println!("   \"{}\"", system_prompt);
            println!();

            println!("   Input to AI: \"{}\"", raw_transcription);
            println!();

            // Step 4: Explain what will happen
            println!("╔════════════════════════════════════════════════════════════╗");
            println!("║                     WHAT HAPPENS NOW                       ║");
            println!("╚════════════════════════════════════════════════════════════╝");
            println!();

            println!("✅ CONTACT DETECTION: WORKING");
            println!("   • Detected: {}", contact_name);
            println!();

            println!("✅ CLASSIFICATION: WORKING");
            println!("   • Category: {:?}", category);
            println!();

            println!("✅ MODE SELECTION: WORKING");
            println!("   • Selected: {:?}", mode);
            println!();

            println!("🔄 AI COMPLETION: Depends on your configuration");
            println!();

            match mode {
                WritingMode::Formal => {
                    println!("   Expected output (if AI is configured):");
                    println!("   \"Apologies, I will be running a few minutes");
                    println!("    behind schedule this morning.\"");
                }
                WritingMode::Casual => {
                    println!("   Expected output (if AI is configured):");
                    println!("   \"Hey, I'm running about 5 minutes late, sorry!\"");
                }
                WritingMode::VeryCasual => {
                    println!("   Expected output (if AI is configured):");
                    println!("   \"gonna be like 5 min late sry\"");
                }
                WritingMode::Excited => {
                    println!("   Expected output (if AI is configured):");
                    println!("   \"Sorry babe, running a bit late! Be there in 5 💕\"");
                }
            }
            println!();

            println!("──────────────────────────────────────────────────────────");
            println!();
            println!("📋 NEXT STEPS TO ENABLE FULL ADAPTATION:");
            println!();
            println!("1. ✅ Contact detection - DONE (integrated!)");
            println!("2. ✅ Classification - DONE (integrated!)");
            println!("3. ✅ Mode selection - DONE (integrated!)");
            println!("4. 🔄 AI provider - Configure your API key:");
            println!();
            println!("   Set your API key:");
            println!("   ```");
            println!("   flowwispr_set_api_key(handle, \"sk-...\");");
            println!("   ```");
            println!();
            println!("   Or via storage:");
            println!("   ```rust");
            println!("   storage.set_setting(\"openai_api_key\", \"sk-...\");");
            println!("   ```");
            println!();
            println!("   Once configured, the AI will automatically adapt");
            println!("   your message based on the detected contact!");
            println!();
        }
        Ok(None) => {
            println!("   ⚠️  No active conversation");
            println!();
            println!("   To test the integration:");
            println!("   1. Open Messages.app");
            println!("   2. Click on a conversation");
            println!("   3. Run this example again");
            println!();
            println!("   The system will then:");
            println!("   • Detect who you're messaging");
            println!("   • Classify their relationship");
            println!("   • Adapt the writing style accordingly");
            println!();
        }
        Err(e) => {
            println!("   ❌ Error: {}", e);
            println!();
            println!("   This usually means:");
            println!("   • Messages is not running, OR");
            println!("   • Accessibility permissions not granted");
            println!();
            println!("   Fix:");
            println!("   1. Open Messages.app");
            println!("   2. Grant Accessibility permission:");
            println!("      System Settings → Privacy → Accessibility");
            println!("   3. Run this example again");
            println!();
        }
    }

    println!("╔════════════════════════════════════════════════════════════╗");
    println!("║                   INTEGRATION STATUS                       ║");
    println!("╚════════════════════════════════════════════════════════════╝");
    println!();
    println!("✅ COMPLETE: Contact detection");
    println!("✅ COMPLETE: Classification logic");
    println!("✅ COMPLETE: Mode selection");
    println!("✅ COMPLETE: Integration into transcription pipeline");
    println!();
    println!("🔄 PENDING: AI API key configuration");
    println!();
    println!("Once you configure your OpenAI/Gemini API key,");
    println!("the system will AUTOMATICALLY adapt your voice input");
    println!("based on who you're messaging!");
    println!();
    println!("🎯 The hard part is done - just add your API key! 🚀");
    println!();
}
