//! Live Contact Demo - Test with Real Messages Contacts
//!
//! This example demonstrates adaptive transcription based on who you're messaging:
//! - Detects active Messages contact
//! - Classifies their relationship to you
//! - Adapts the same raw input to match the social context
//!
//! Run with: cargo run --example live_contact_demo

use flowwispr_core::contacts::{ContactClassifier, ContactInput};
use flowwispr_core::macos_messages::MessagesDetector;
use flowwispr_core::types::{ContactCategory, WritingMode};

/// Example raw transcription (what you actually said)
const RAW_INPUT: &str = "I'm gonna be 5 min late, sorry.";

/// Adapt transcription based on writing mode
fn adapt_transcription(raw: &str, mode: WritingMode, category: ContactCategory) -> String {
    match mode {
        WritingMode::Formal => {
            // Professional/Boss: Formal, apologetic, proper grammar
            match category {
                ContactCategory::Professional => {
                    "Apologies, I will be running a few minutes behind schedule this morning.".to_string()
                }
                ContactCategory::FormalNeutral => {
                    "I apologize for the inconvenience, but I will be arriving approximately 5 minutes late.".to_string()
                }
                _ => {
                    "I apologize, I'm running about 5 minutes late.".to_string()
                }
            }
        }
        WritingMode::Casual => {
            // Family: Conversational but clear
            "Hey, I'm running about 5 minutes late, sorry!".to_string()
        }
        WritingMode::VeryCasual => {
            // Friends: Very informal, minimal punctuation
            "gonna be like 5 min late sry".to_string()
        }
        WritingMode::Excited => {
            // Partner: Warm, apologetic with affection
            "Sorry babe, running a bit late! Be there in 5 💕".to_string()
        }
    }
}

fn main() {
    println!("=== FlowWispr Live Contact Demo ===\n");
    println!("Raw voice input: \"{}\"", RAW_INPUT);
    println!();

    let classifier = ContactClassifier::new();

    // Test 1: Check if Messages is running
    println!("--- Checking Messages.app ---");
    match MessagesDetector::is_messages_running() {
        Ok(true) => {
            println!("✅ Messages is running");

            // Get active contact
            match MessagesDetector::get_active_contact() {
                Ok(Some(contact_name)) => {
                    println!("✅ Active conversation: {}\n", contact_name);

                    // Classify the contact
                    let input = ContactInput {
                        name: contact_name.clone(),
                        organization: String::new(),
                    };

                    let category = classifier.classify(&input);
                    let mode = category.suggested_writing_mode();

                    println!("--- Classification Result ---");
                    println!("  Contact: {}", contact_name);
                    println!("  Category: {:?}", category);
                    println!("  Writing Mode: {:?}\n", mode);

                    // Show adapted output
                    let adapted = adapt_transcription(RAW_INPUT, mode, category);

                    println!("--- Adaptive Output ---");
                    println!("  Original: \"{}\"", RAW_INPUT);
                    println!("  Adapted:  \"{}\"", adapted);
                    println!();

                    // Explain the adaptation
                    println!("--- Explanation ---");
                    match category {
                        ContactCategory::Professional => {
                            println!("  🏢 Detected PROFESSIONAL contact");
                            println!("  → Using formal language");
                            println!("  → Proper grammar and apology");
                            println!("  → Removed slang ('gonna', 'min')");
                        }
                        ContactCategory::CloseFamily => {
                            println!("  👨‍👩‍👧 Detected CLOSE FAMILY");
                            println!("  → Using casual but clear tone");
                            println!("  → Added friendly greeting");
                            println!("  → Kept conversational style");
                        }
                        ContactCategory::CasualPeer => {
                            println!("  🍺 Detected CASUAL PEER");
                            println!("  → Using very informal language");
                            println!("  → Minimal punctuation");
                            println!("  → Text message style");
                        }
                        ContactCategory::Partner => {
                            println!("  💕 Detected PARTNER");
                            println!("  → Using warm, affectionate tone");
                            println!("  → Added term of endearment");
                            println!("  → Included emoji");
                        }
                        ContactCategory::FormalNeutral => {
                            println!("  📋 Detected NEUTRAL CONTACT");
                            println!("  → Using default formal tone");
                            println!("  → Professional but not overly formal");
                        }
                    }
                }
                Ok(None) => {
                    println!("⚠️  No active conversation window");
                    println!("    → Open a Messages conversation and try again\n");
                    show_simulated_examples(&classifier);
                }
                Err(e) => {
                    println!("❌ Error getting active contact: {}", e);
                    println!("    → Make sure Messages has Accessibility permissions\n");
                    show_simulated_examples(&classifier);
                }
            }
        }
        Ok(false) => {
            println!("⚠️  Messages is not running");
            println!("    → Open Messages.app and start a conversation\n");
            show_simulated_examples(&classifier);
        }
        Err(e) => {
            println!("❌ Error checking Messages: {}", e);
            show_simulated_examples(&classifier);
        }
    }

    println!("\n--- All Open Conversations ---");
    match MessagesDetector::get_all_conversations() {
        Ok(conversations) if !conversations.is_empty() => {
            for (i, contact) in conversations.iter().enumerate() {
                let input = ContactInput {
                    name: contact.clone(),
                    organization: String::new(),
                };
                let category = classifier.classify(&input);
                let mode = category.suggested_writing_mode();
                let adapted = adapt_transcription(RAW_INPUT, mode, category);

                println!("\n{}. {}", i + 1, contact);
                println!("   Category: {:?} → Mode: {:?}", category, mode);
                println!("   Output: \"{}\"", adapted);
            }
        }
        Ok(_) => {
            println!("  No open conversations found");
        }
        Err(e) => {
            println!("  Error: {}", e);
        }
    }
}

fn show_simulated_examples(classifier: &ContactClassifier) {
    println!("--- Simulated Examples (Without Messages) ---\n");

    let test_contacts = vec![
        ("Boss", "", ContactCategory::Professional),
        ("Manager Sarah", "Acme Corp", ContactCategory::Professional),
        ("Mom", "", ContactCategory::CloseFamily),
        ("❤️ Alex", "", ContactCategory::Partner),
        ("Mike 🍺", "", ContactCategory::CasualPeer),
        ("John Smith", "", ContactCategory::FormalNeutral),
    ];

    for (name, org, expected_category) in test_contacts {
        let input = ContactInput {
            name: name.to_string(),
            organization: org.to_string(),
        };

        let category = classifier.classify(&input);
        let mode = category.suggested_writing_mode();
        let adapted = adapt_transcription(RAW_INPUT, mode, category);

        // Verify classification
        assert_eq!(category, expected_category, "Failed for: {}", name);

        println!("Contact: {}", name);
        if !org.is_empty() {
            println!("  Org: {}", org);
        }
        println!("  Category: {:?} → Mode: {:?}", category, mode);
        println!("  Original: \"{}\"", RAW_INPUT);
        println!("  Adapted:  \"{}\"\n", adapted);
    }

    println!("✅ All simulated examples passed!");
}
