import Foundation
// Remove: import OpenAI

@MainActor
final class LLMService {
    static let shared = LLMService()

    // Store your API Gateway Invoke URL here
    // IMPORTANT: Replace with the ACTUAL Invoke URL you copied from API Gateway Step 7!
    private let apiGatewayEndpoint = URL(string: "YOUR_API_GATEWAY_INVOKE_URL_HERE/chat")! // Example: https://abc123xyz.execute-api.us-east-1.amazonaws.com/v1/chat

    // Remove OpenAI client initialization
    private init() {
         print("LLMService initialized to use API Gateway Proxy.")
    }

    // Remove createModel helper if no longer needed

    /// Generates a conversational response by calling the backend proxy.
    func generateChatResponse(systemPrompt: String, userMessage: String, context: String? = nil) async throws -> String {
        print("LLMService: Calling API Gateway Proxy for user message: '\(userMessage.prefix(50))...'")

        // Construct the messages array expected by OpenAI (and your proxy)
        var messagesPayload: [[String: String]] = []
        messagesPayload.append(["role": "system", "content": systemPrompt])
        if let ctx = context, !ctx.isEmpty {
            // Add context as a pseudo-user message? Or combine with system prompt?
            // Let's add it before the actual user message for clarity
             messagesPayload.append(["role": "user", "content": "Relevant Context:\n\(ctx)"])
        }
        messagesPayload.append(["role": "user", "content": userMessage])

        // Construct the request body for YOUR proxy
        let requestBodyPayload: [String: Any] = [
            // Match the model expected by your Lambda or OpenAI
            "model": "gpt-4o",
            "messages": messagesPayload
            // Add other parameters like temperature if your Lambda forwards them
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBodyPayload) else {
            print("LLMService Error: Failed to serialize request body.")
            throw LLMError.sdkError("Failed to create request body.") // Use sdkError for internal issues too
        }

        var request = URLRequest(url: apiGatewayEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Add any necessary authentication headers for YOUR API Gateway endpoint here (e.g., API Key if configured)
        // request.setValue("YOUR_API_GATEWAY_API_KEY", forHTTPHeaderField: "x-api-key")
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.unexpectedResponse("Invalid response from proxy server.")
            }

            print("Proxy Response Status Code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from proxy if available
                if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorData["error"] {
                    throw LLMError.sdkError("Proxy Error (\(httpResponse.statusCode)): \(errorMessage)")
                } else {
                    // Fallback if error decoding fails
                     let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                     print("Raw Proxy Error Response: \(responseString)")
                    throw LLMError.sdkError("Proxy Error (\(httpResponse.statusCode)): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                }
            }

            // Decode the successful response { "reply": "..." } from YOUR proxy
            guard let responsePayload = try? JSONDecoder().decode([String: String].self, from: data),
                  let reply = responsePayload["reply"] else {
                 let responseString = String(data: data, encoding: .utf8) ?? "Invalid response body"
                 print("Raw Proxy Success Response (but failed decode): \(responseString)")
                throw LLMError.unexpectedResponse("Failed to decode 'reply' from proxy response.")
            }

            print("LLMService: Received response from proxy.")
            return reply

        } catch let error as LLMError {
             print("LLMService Error: \(error.localizedDescription)")
             throw error // Re-throw known LLMError types
        } catch {
            print("LLMService URLSession Error: \(error)")
            throw LLMError.sdkError("Network request failed: \(error.localizedDescription)")
        }
    }

    // Keep LLMError enum, remove types not used (decodingError) if structured output isn't implemented
     enum LLMError: Error, LocalizedError, Equatable {
         case sdkError(String)
         case unexpectedResponse(String)
         // case decodingError(String) // Remove if not generating structured output

         var errorDescription: String? {
             switch self {
             case .sdkError(let reason): return "LLM Service Error: \(reason)"
             case .unexpectedResponse(let reason): return "Unexpected LLM response: \(reason)"
             // case .decodingError(let reason): return "JSON Decoding Error: \(reason)"
             }
         }
     }
}
