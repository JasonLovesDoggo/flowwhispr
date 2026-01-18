//! Check AI Configuration
//!
//! This example verifies your AI provider is properly configured
//! and ready to adapt text based on contacts.
//!
//! Run with: cargo run --example check_ai_config

use flowwispr_core::storage::Storage;

fn main() {
    println!("╔══════════════════════════════════════════════════════╗");
    println!("║        FlowWispr AI Configuration Check             ║");
    println!("╚══════════════════════════════════════════════════════╝");
    println!();

    // Check if storage exists and has API keys
    let storage_path = dirs::data_local_dir()
        .unwrap_or_else(|| std::path::PathBuf::from("."))
        .join("flowwispr")
        .join("flowwispr.db");

    println!("📂 Storage Path:");
    println!("   {}", storage_path.display());
    println!();

    if !storage_path.exists() {
        println!("⚠️  Database not found!");
        println!();
        println!("   This is normal if you haven't run the app yet.");
        println!("   The database will be created on first run.");
        println!();
        println!("   If you have run the app, check your storage path.");
        println!();
        return;
    }

    println!("✅ Database exists");
    println!();

    // Try to open storage and check for API keys
    match Storage::open(&storage_path) {
        Ok(storage) => {
            println!("✅ Storage opened successfully");
            println!();

            // Check for API keys
            println!("🔑 Checking API Keys...");
            println!("   ─────────────────────");
            println!();

            let mut has_any_key = false;

            // OpenAI
            if let Ok(Some(key)) = storage.get_setting("openai_api_key") {
                let masked = mask_api_key(&key);
                println!("   ✅ OpenAI API Key: {}", masked);
                has_any_key = true;
            } else {
                println!("   ❌ OpenAI API Key: Not configured");
            }

            // Gemini
            if let Ok(Some(key)) = storage.get_setting("gemini_api_key") {
                let masked = mask_api_key(&key);
                println!("   ✅ Gemini API Key: {}", masked);
                has_any_key = true;
            } else {
                println!("   ❌ Gemini API Key: Not configured");
            }

            // OpenRouter
            if let Ok(Some(key)) = storage.get_setting("openrouter_api_key") {
                let masked = mask_api_key(&key);
                println!("   ✅ OpenRouter API Key: {}", masked);
                has_any_key = true;
            } else {
                println!("   ❌ OpenRouter API Key: Not configured");
            }

            println!();

            if has_any_key {
                println!("╔══════════════════════════════════════════════════════╗");
                println!("║               ✅ AI PROVIDER CONFIGURED              ║");
                println!("╚══════════════════════════════════════════════════════╝");
                println!();
                println!("Your AI provider is set up!");
                println!();
                println!("Contact-aware adaptation should be WORKING now!");
                println!();
                println!("📝 Next Steps:");
                println!("   1. Open Messages to a conversation");
                println!("   2. Run: cargo run --example test_real_integration");
                println!("   3. Verify contact detection is working");
                println!("   4. Test voice dictation with different contacts!");
                println!();
            } else {
                println!("╔══════════════════════════════════════════════════════╗");
                println!("║            ⚠️  NO API KEY CONFIGURED                 ║");
                println!("╚══════════════════════════════════════════════════════╝");
                println!();
                println!("Contact detection will work, but AI adaptation won't.");
                println!();
                println!("To configure an API key:");
                println!();
                println!("Option 1 - Via Swift/FFI:");
                println!("   flowwispr_set_api_key(handle, \"sk-...\")");
                println!();
                println!("Option 2 - Via Rust Storage:");
                println!("   storage.set_setting(\"openai_api_key\", \"sk-...\")?;");
                println!();
            }

            // Check completion provider setting
            if let Ok(Some(provider)) = storage.get_setting("completion_provider") {
                println!("🤖 Active Completion Provider: {}", provider);
                println!();
            }

            // Check contacts
            match storage.get_all_contacts() {
                Ok(contacts) if !contacts.is_empty() => {
                    println!("📇 Stored Contacts: {}", contacts.len());
                    println!();
                    println!("   Top contacts by frequency:");
                    let mut sorted = contacts;
                    sorted.sort_by(|a, b| b.frequency.cmp(&a.frequency));
                    for (i, contact) in sorted.iter().take(5).enumerate() {
                        println!("   {}. {} ({:?}, used {} times)",
                            i + 1, contact.name, contact.category, contact.frequency);
                    }
                    println!();
                }
                Ok(_) => {
                    println!("📇 Stored Contacts: None yet");
                    println!();
                    println!("   Contacts will be saved as you use them.");
                    println!();
                }
                Err(e) => {
                    println!("⚠️  Error reading contacts: {}", e);
                    println!();
                }
            }
        }
        Err(e) => {
            println!("❌ Failed to open storage: {}", e);
            println!();
        }
    }

    println!("──────────────────────────────────────────────────────");
    println!();
    println!("💡 Quick Tests:");
    println!();
    println!("   1. Check contact detection:");
    println!("      ./debug_messages.sh");
    println!();
    println!("   2. Test integration:");
    println!("      cargo run --example test_real_integration");
    println!();
    println!("   3. Test classification:");
    println!("      cargo test contacts::tests --lib");
    println!();
}

fn mask_api_key(key: &str) -> String {
    if key.len() <= 8 {
        return "***".to_string();
    }

    let prefix = &key[..4];
    let suffix = &key[key.len()-4..];
    format!("{}...{}", prefix, suffix)
}
