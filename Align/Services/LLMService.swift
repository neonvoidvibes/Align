import Foundation

@MainActor
final class LLMService {
    static let shared = LLMService()

    private let apiGatewayEndpoint = URL(string: "https://x1vupvw2p5.execute-api.eu-north-1.amazonaws.com/v1/chat")! // ENSURE THIS IS YOUR CORRECT URL

    private init() {
         print("LLMService initialized to use API Gateway Proxy.")
    }

    func generateChatResponse(systemPrompt: String, userMessage: String, context: String? = nil) async throws -> String {
        print("LLMService: Calling API Gateway Proxy for user message: '\(userMessage.prefix(50))...'")

        var messagesPayload: [[String: String]] = []
        messagesPayload.append(["role": "system", "content": systemPrompt])
        if let ctx = context, !ctx.isEmpty {
             messagesPayload.append(["role": "user", "content": "Relevant Context:\n\(ctx)"])
        }
        messagesPayload.append(["role": "user", "content": userMessage])

        let requestBodyPayload: [String: Any] = [
            "model": "gpt-4o",
            "messages": messagesPayload
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBodyPayload) else {
            print("LLMService Error: Failed to serialize request body.")
            throw LLMError.sdkError("Failed to create request body.")
        }

        var request = URLRequest(url: apiGatewayEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // --- ADD API KEY HEADER ---
        let apiKey = APIConfiguration.apiGatewayApiKey // Retrieve the key
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key") // Add the header
        // --- END OF ADDED CODE ---

        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.unexpectedResponse("Invalid response from proxy server.")
            }

            print("Proxy Response Status Code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorData["error"] {
                     // Check for specific Forbidden message from API Gateway
                     if httpResponse.statusCode == 403 && errorMessage.lowercased().contains("forbidden") {
                          print("LLMService Error: Received 403 Forbidden. Check API Key in header and API Gateway configuration.")
                          throw LLMError.sdkError("Proxy Error (403): Forbidden. Check API Key setup.")
                     } else {
                          throw LLMError.sdkError("Proxy Error (\(httpResponse.statusCode)): \(errorMessage)")
                     }
                } else {
                     let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                     print("Raw Proxy Error Response: \(responseString)")
                     throw LLMError.sdkError("Proxy Error (\(httpResponse.statusCode)): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                }
            }

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
             throw error
        } catch {
            print("LLMService URLSession Error: \(error)")
            throw LLMError.sdkError("Network request failed: \(error.localizedDescription)")
        }
    }

     enum LLMError: Error, LocalizedError, Equatable {
         case sdkError(String)
         case unexpectedResponse(String)

         var errorDescription: String? {
             switch self {
             case .sdkError(let reason): return "LLM Service Error: \(reason)"
             case .unexpectedResponse(let reason): return "Unexpected LLM response: \(reason)"
             }
         }
     }
}
