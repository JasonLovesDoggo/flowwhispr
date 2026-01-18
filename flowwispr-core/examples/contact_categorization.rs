//! Contact Categorization Example
//!
//! This example demonstrates the complete contact categorization workflow:
//! 1. Detect active Messages contact
//! 2. Fetch contact metadata from macOS Contacts
//! 3. Classify contact into social bucket
//! 4. Get suggested writing mode
//!
//! Run with: cargo run --example contact_categorization

use flowwispr_core::contacts::{ContactClassifier, ContactInput};
use flowwispr_core::macos_messages::MessagesDetector;
use flowwispr_core::types::ContactCategory;

fn main() {
    println!("=== FlowWispr Contact Categorization Demo ===\n");

    // Initialize the classifier
    let classifier = ContactClassifier::new();

    // Test Case 1: Partner Detection
    println!("--- Test 1: Partner Detection ---");
    let test_cases_partner = vec![
        ContactInput {
            name: "Bae".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "❤️ Alex".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "My Love".to_string(),
            organization: String::new(),
        },
    ];

    for input in test_cases_partner {
        let category = classifier.classify(&input);
        println!(
            "  {} -> {:?} (expected: Partner)",
            input.name, category
        );
        assert_eq!(category, ContactCategory::Partner);
    }

    // Test Case 2: Close Family Detection
    println!("\n--- Test 2: Close Family Detection ---");
    let test_cases_family = vec![
        ContactInput {
            name: "Mom".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "ICE Dad".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "Grandma".to_string(),
            organization: String::new(),
        },
    ];

    for input in test_cases_family {
        let category = classifier.classify(&input);
        println!(
            "  {} -> {:?} (expected: CloseFamily)",
            input.name, category
        );
        assert_eq!(category, ContactCategory::CloseFamily);
    }

    // Test Case 3: Professional Detection (CRITICAL ORG RULE)
    println!("\n--- Test 3: Professional Detection ---");
    println!("CRITICAL: Organization field presence is highest priority!");

    let sarah = ContactInput {
        name: "Sarah".to_string(),
        organization: "Acme Inc".to_string(),
    };
    let category = classifier.classify(&sarah);
    println!("  Sarah (Acme Inc) -> {:?}", category);
    assert_eq!(category, ContactCategory::Professional);

    let doctor = ContactInput {
        name: "Dr. Smith".to_string(),
        organization: String::new(),
    };
    let category = classifier.classify(&doctor);
    println!("  Dr. Smith -> {:?}", category);
    assert_eq!(category, ContactCategory::Professional);

    // Test Case 4: Casual Peer Detection
    println!("\n--- Test 4: Casual Peer Detection ---");
    let test_cases_casual = vec![
        ContactInput {
            name: "dave from gym".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "Mike 🍺".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "alex lol".to_string(),
            organization: String::new(),
        },
    ];

    for input in test_cases_casual {
        let category = classifier.classify(&input);
        println!(
            "  {} -> {:?} (expected: CasualPeer)",
            input.name, category
        );
        assert_eq!(category, ContactCategory::CasualPeer);
    }

    // Test Case 5: Formal / Neutral (Default)
    println!("\n--- Test 5: Formal / Neutral (Default) ---");
    let test_cases_neutral = vec![
        ContactInput {
            name: "John Smith".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "Uber Driver".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "Plumber".to_string(),
            organization: String::new(),
        },
    ];

    for input in test_cases_neutral {
        let category = classifier.classify(&input);
        println!(
            "  {} -> {:?} (expected: FormalNeutral)",
            input.name, category
        );
        assert_eq!(category, ContactCategory::FormalNeutral);
    }

    // Test Case 6: Batch Classification with JSON
    println!("\n--- Test 6: Batch Classification (JSON) ---");
    let batch_inputs = vec![
        ContactInput {
            name: "Mom".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "❤️ Alex".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "Sarah Work".to_string(),
            organization: "Acme Inc".to_string(),
        },
        ContactInput {
            name: "Mike 🍺".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "John Smith".to_string(),
            organization: String::new(),
        },
        ContactInput {
            name: "Uber Driver".to_string(),
            organization: String::new(),
        },
    ];

    let json_result = classifier.classify_batch_json(&batch_inputs);
    println!("JSON Result:\n{}", json_result);

    // Verify all categories are correct
    let result_map = classifier.classify_batch(&batch_inputs);
    assert_eq!(
        result_map.get("Mom"),
        Some(&ContactCategory::CloseFamily)
    );
    assert_eq!(
        result_map.get("❤️ Alex"),
        Some(&ContactCategory::Partner)
    );
    assert_eq!(
        result_map.get("Sarah Work"),
        Some(&ContactCategory::Professional)
    );
    assert_eq!(
        result_map.get("Mike 🍺"),
        Some(&ContactCategory::CasualPeer)
    );
    assert_eq!(
        result_map.get("John Smith"),
        Some(&ContactCategory::FormalNeutral)
    );
    assert_eq!(
        result_map.get("Uber Driver"),
        Some(&ContactCategory::FormalNeutral)
    );

    println!("\n--- Test 7: Writing Mode Suggestions ---");
    for category in ContactCategory::all() {
        let mode = category.suggested_writing_mode();
        println!("  {:?} -> {:?}", category, mode);
    }

    // Test Case 8: Messages Detection (macOS only)
    println!("\n--- Test 8: Messages.app Detection ---");
    match MessagesDetector::is_messages_running() {
        Ok(true) => {
            println!("  Messages is running!");
            match MessagesDetector::get_active_contact() {
                Ok(Some(name)) => {
                    println!("  Active contact: {}", name);

                    // Classify the active contact
                    let input = ContactInput {
                        name: name.clone(),
                        organization: String::new(),
                    };
                    let category = classifier.classify(&input);
                    let mode = category.suggested_writing_mode();

                    println!("  Category: {:?}", category);
                    println!("  Suggested mode: {:?}", mode);
                }
                Ok(None) => println!("  No active conversation"),
                Err(e) => println!("  Error: {}", e),
            }
        }
        Ok(false) => println!("  Messages is not running"),
        Err(e) => println!("  Error checking Messages: {}", e),
    }

    println!("\n✅ All tests passed!");
    println!("\n=== Summary ===");
    println!("The contact categorization system successfully:");
    println!("  1. Detects partner relationships via romantic emojis and terms");
    println!("  2. Identifies family members via familial titles");
    println!("  3. Recognizes professional contacts via organization field (CRITICAL)");
    println!("  4. Catches casual peers via emojis and informal formatting");
    println!("  5. Defaults to formal/neutral for unknown contacts");
    println!("  6. Provides JSON batch classification for API integration");
    println!("  7. Maps categories to appropriate writing modes");
}
