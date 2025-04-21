import Foundation

struct APIConfiguration {
    // Function to read from plist or environment
    private static func value(forKey key: String, inFile: String = "Config") -> String? {
        // Try plist first
        if let filePath = Bundle.main.path(forResource: inFile, ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: filePath),
           let value = plist[key] as? String, !value.isEmpty {
            print("✅ Loaded '\(key)' from \(inFile).plist (Development Only).")
            return value
        }

        // Fallback to environment variable
        if let valueFromEnv = ProcessInfo.processInfo.environment[key], !valueFromEnv.isEmpty {
             print("⚠️ Loaded '\(key)' from environment variable (Fallback).")
             return valueFromEnv
        }

        print("❌ '\(key)' not found in \(inFile).plist or environment variables.")
        return nil
    }

    // Static property for the API Gateway Key
    static var apiGatewayApiKey: String {
        guard let key = value(forKey: "API_GATEWAY_API_KEY") else {
             fatalError("❌ API Gateway API Key not found. Ensure 'Config.plist' has key 'API_GATEWAY_API_KEY' or set environment variable.")
        }
        return key
    }

    // NOTE: OpenAI key property is intentionally omitted as it's handled by the backend proxy.
}