import Foundation

struct APIConfiguration {
    static var openAIAPIKey: String {
        // TODO: [SECURITY] Replace Config.plist key loading with a secure production method (e.g., Remote Configuration service or Backend Proxy) before App Store submission.

        // Attempts to load the API key from Config.plist for DEVELOPMENT
        // Ensure Config.plist exists in the project root, contains a key named "OPENAI_API_KEY",
        // and is included in the target's "Copy Bundle Resources" build phase.
        // IMPORTANT: Add Config.plist to your .gitignore file.
        guard let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let apiKey = plist["OPENAI_API_KEY"] as? String,
              !apiKey.isEmpty else {

            // Fallback to environment variable if plist fails
            if let apiKeyFromEnv = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKeyFromEnv.isEmpty {
                 print("⚠️ Loaded OpenAI API Key from environment variable (Fallback).")
                 return apiKeyFromEnv
            }

            // If neither works, crash loudly during development.
            fatalError("❌ OpenAI API Key not found. Ensure 'Config.plist' with key 'OPENAI_API_KEY' exists and is added to the target, OR set the OPENAI_API_KEY environment variable for development.")
        }
        print("✅ Loaded OpenAI API Key from Config.plist (Development Only).")
        return apiKey
    }
}