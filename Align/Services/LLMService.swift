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
            "model": "gpt-4.1",
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

     /// Generates structured data (JSON) based on a message and analysis prompt.
     func generateAnalysisData(messageContent: String) async throws -> [String: Double] {
         print("LLMService: Generating analysis data for message: '\(messageContent.prefix(50))...'")

         // Define the categories for the analysis prompt
         let categories = Array(NODE_WEIGHTS.keys) // Get categories from shared weights
         // Get the prompt template string by calling the static function
         let systemPromptTemplate = SystemPrompts.analysisAgentPrompt(categories: categories)
         // Inject the actual message content into the placeholder within the template string
         let systemPrompt = systemPromptTemplate.replacingOccurrences(of: "{message_content}", with: messageContent)

         // Prepare request body - Force JSON output mode with gpt-4o-mini
          let messagesPayload: [[String: Any]] = [
              ["role": "system", "content": systemPrompt]
              // Note: We put the user message *inside* the system prompt template now.
          ]

          let requestBodyPayload: [String: Any] = [
              "model": "gpt-4.1-mini", // Use a model known to support JSON mode well
              "messages": messagesPayload,
              "response_format": ["type": "json_object"] // Enforce JSON output
          ]

         guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBodyPayload) else {
             print("LLMService Error: Failed to serialize analysis request body.")
             throw LLMError.sdkError("Failed to create analysis request body.")
         }

         var request = URLRequest(url: apiGatewayEndpoint)
         request.httpMethod = "POST"
         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
         request.setValue(APIConfiguration.apiGatewayApiKey, forHTTPHeaderField: "x-api-key")
         request.httpBody = httpBody

         do {
             let (data, response) = try await URLSession.shared.data(for: request)

             guard let httpResponse = response as? HTTPURLResponse else {
                 throw LLMError.unexpectedResponse("Invalid response from proxy server for analysis.")
             }

             print("Proxy Analysis Response Status Code: \(httpResponse.statusCode)")

             guard (200...299).contains(httpResponse.statusCode) else {
                  let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                  print("Raw Proxy Analysis Error Response: \(responseString)")
                 // Handle specific errors if needed
                 throw LLMError.sdkError("Proxy Error (\(httpResponse.statusCode)) during analysis: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
             }

             // Attempt to decode the outer proxy structure {"reply": "..."}
              struct ProxyResponse: Decodable { let reply: String }
              do {
                  let proxyResponse = try JSONDecoder().decode(ProxyResponse.self, from: data)
                  let innerJsonString = proxyResponse.reply
                  print("LLMService: Decoded proxy response. Inner JSON string received: \(innerJsonString)")

                  // Now decode the inner JSON string
                  guard let innerData = innerJsonString.data(using: .utf8) else {
                       print("LLMService Error: Failed to convert inner JSON string to Data.")
                       throw LLMError.decodingError("Failed to convert inner JSON string to Data.")
                  }

                  // Handle potential empty inner JSON {}
                  if innerJsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" {
                        print("LLMService: Inner JSON is empty '{}'. Returning empty dictionary.")
                        return [:]
                  }

                  do {
                      let decodedData = try JSONDecoder().decode([String: Double].self, from: innerData)
                      print("LLMService: Successfully decoded inner analysis JSON.")
                      return decodedData
                  } catch let innerDecodingError {
                       print("LLMService Error: Failed to decode INNER analysis JSON string.")
                       print("Inner JSON String: >>>\(innerJsonString)<<<")
                       throw LLMError.decodingError("Failed to decode inner analysis JSON: \(innerDecodingError.localizedDescription)")
                  }
              } catch let outerDecodingError {
                   // If decoding the ProxyResponse fails, maybe the response isn't wrapped?
                   // Try decoding directly as [String: Double] as a fallback.
                   print("LLMService Warning: Failed to decode outer ProxyResponse (\(outerDecodingError)). Attempting direct decode...")
                   print("Raw JSON Data Received: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")
                   do {
                        // Handle potential empty JSON {} directly as well
                        if String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" {
                            print("LLMService: Direct JSON is empty '{}'. Returning empty dictionary.")
                            return [:]
                        }
                        let decodedData = try JSONDecoder().decode([String: Double].self, from: data)
                        print("LLMService: Successfully decoded analysis JSON directly (fallback).")
                        return decodedData
                   } catch let directDecodingError {
                        print("LLMService Error: Direct decoding also failed (\(directDecodingError)). Giving up.")
                         throw LLMError.decodingError("Failed to decode analysis JSON (tried proxy wrapper and direct): \(directDecodingError.localizedDescription)")
                   }
              }

         } catch let error as LLMError {
              print("LLMService Analysis Error: \(error.localizedDescription)")
              throw error
         } catch {
             print("LLMService Analysis URLSession Error: \(error)")
             throw LLMError.sdkError("Analysis network request failed: \(error.localizedDescription)")
         }
     }


     enum LLMError: Error, LocalizedError, Equatable {
         case sdkError(String)
         case unexpectedResponse(String)
         case decodingError(String) // Add decoding error case

         var errorDescription: String? {
             switch self {
             case .sdkError(let reason): return "LLM Service Error: \(reason)"
             case .unexpectedResponse(let reason): return "Unexpected LLM response: \(reason)"
             case .decodingError(let reason): return "LLM Decoding Error: \(reason)"
             }
         }
     }
}
