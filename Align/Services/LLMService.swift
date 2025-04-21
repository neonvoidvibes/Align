import Foundation

@MainActor
final class LLMService {
    static let shared = LLMService()

    private let apiGatewayEndpoint = URL(string: "https://x1vupvw2p5.execute-api.eu-north-1.amazonaws.com/v1/chat")! // ENSURE THIS IS YOUR CORRECT URL

    private init() {
         print("LLMService initialized to use API Gateway Proxy.")
    }

    func generateChatResponse(systemPrompt: String, userMessage: String, context: String? = nil) async throws -> String {
        // --- ADD TYPE PRINTING ---
        print("[LLMService] Type of 'context' received: \(type(of: context))")
        // --- END TYPE PRINTING ---
        print("LLMService: Calling API Gateway Proxy for user message: '\(userMessage.prefix(50))...'")

        var messagesPayload: [[String: String]] = []
        messagesPayload.append(["role": "system", "content": systemPrompt])
        if let ctx = context, !ctx.isEmpty {
             messagesPayload.append(["role": "user", "content": "Relevant Context:\n\(ctx)"])
             // Print context being sent (optional, for debugging)
             // print("[ChatViewModel] Combined Context for LLM:\n\(ctx)")
        }
        messagesPayload.append(["role": "user", "content": userMessage])

        let requestBodyPayload: [String: Any] = [
            "model": "gpt-4o", // Keep using gpt-4o for chat responses
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
                     // Specific handling for 429 and 502
                     if httpResponse.statusCode == 429 {
                         throw LLMError.rateLimitExceeded("Too many requests. Please wait a moment and try again.")
                     } else if httpResponse.statusCode == 502 {
                         throw LLMError.badGateway("The server encountered a temporary issue (Bad Gateway). Please try again shortly.")
                     } else {
                         throw LLMError.sdkError("Proxy Error (\(httpResponse.statusCode)): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                     }
                }
            }

            // Try decoding the expected structure { "reply": "..." }
            if let responsePayload = try? JSONDecoder().decode([String: String].self, from: data),
               let reply = responsePayload["reply"] {
                print("LLMService: Received and decoded 'reply' from proxy.")
                return reply
            } else {
                // If that fails, maybe the proxy returned the raw OpenAI response? Let's try decoding that.
                // Assuming OpenAI structure: { "choices": [ { "message": { "content": "..." } } ] }
                struct OpenAIResponse: Decodable {
                    struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
                    let choices: [Choice]?
                }
                if let openAIResponse = try? JSONDecoder().decode(OpenAIResponse.self, from: data),
                   let reply = openAIResponse.choices?.first?.message.content {
                    print("LLMService Warning: Decoded raw OpenAI structure from proxy instead of expected {'reply': ...}. Using content.")
                    return reply
                } else {
                    // If both fail, report the failure.
                    let responseString = String(data: data, encoding: .utf8) ?? "Invalid response body"
                    print("LLMService Error: Failed to decode proxy response. Raw data: \(responseString)")
                    throw LLMError.unexpectedResponse("Failed to decode proxy response.")
                }
            }

        } catch let error as LLMError {
             print("LLMService Error: \(error.localizedDescription)")
             throw error
        } catch {
            print("LLMService URLSession Error: \(error)")
            throw LLMError.sdkError("Network request failed: \(error.localizedDescription)")
        }
    }

     /// Generates structured data (JSON) based on a message and analysis prompt, considering previous day's values.
     func generateAnalysisData(messageContent: String, previousDayValues: [String: Double]?) async throws -> [String: Double] {
         let prevValuesString = previousDayValuesToString(previousDayValues)
         print("LLMService: Generating analysis data for message: '\(messageContent.prefix(50))...' with previous values context: \(prevValuesString)")

         // Define the categories for the analysis prompt
         let categories = Array(NODE_WEIGHTS.keys) // Get categories from shared weights
         // Get the prompt template string by calling the static function
         let systemPromptTemplate = SystemPrompts.analysisAgentPrompt(categories: categories)
         // Inject the actual message content and previous values into placeholders
         var systemPrompt = systemPromptTemplate.replacingOccurrences(of: "{message_content}", with: messageContent)
         systemPrompt = systemPrompt.replacingOccurrences(of: "{previous_day_values}", with: prevValuesString)


         // Prepare request body - Force JSON output mode with gpt-4o-mini (or latest supporting JSON mode)
          let messagesPayload: [[String: Any]] = [
              ["role": "system", "content": systemPrompt]
              // Note: We put the user message *inside* the system prompt template now.
              // No separate user message needed here for this specific prompt structure.
          ]

          let requestBodyPayload: [String: Any] = [
              "model": "gpt-4o-mini", // Keep using gpt-4o-mini for analysis
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

             // The proxy *should* return the JSON content directly.
             // Let's decode it directly into [String: Double].
             do {
                 // First, try to decode the data as if it's the direct JSON payload we want.
                  let decodedData = try JSONDecoder().decode([String: Double].self, from: data)
                  print("LLMService: Successfully decoded analysis JSON.")
                  return decodedData
             } catch let directDecodeError {
                 // If direct decoding fails, maybe the proxy wrapped it in `{"reply": "{...}"}`?
                 // Let's try decoding that structure and then parsing the inner JSON string.
                 print("LLMService Warning: Direct JSON decoding failed (\(directDecodeError.localizedDescription)). Trying to decode {\"reply\": \"{...}\"} structure...")
                 if let wrappedPayload = try? JSONDecoder().decode([String: String].self, from: data),
                    let jsonString = wrappedPayload["reply"],
                    let jsonData = jsonString.data(using: .utf8) {
                     do {
                         let innerDecodedData = try JSONDecoder().decode([String: Double].self, from: jsonData)
                         print("LLMService: Successfully decoded inner analysis JSON string from 'reply'.")
                         // Check if the inner JSON is empty and log appropriately
                         if innerDecodedData.isEmpty {
                             print("LLMService: Inner JSON is empty '{}'. Returning empty dictionary.")
                         }
                         return innerDecodedData
                     } catch let innerDecodeError {
                         print("LLMService Error: Failed to decode inner analysis JSON string.")
                         print("Inner JSON String Received: \(jsonString)")
                         throw LLMError.decodingError("Failed to decode inner analysis JSON: \(innerDecodeError.localizedDescription)")
                     }
                 } else {
                     // If both direct and wrapped decoding fail, report the original error.
                     print("LLMService Error: Failed to decode analysis JSON response in any expected format.")
                     print("Raw JSON Data Received: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")
                     throw LLMError.decodingError("Failed to decode analysis JSON: \(directDecodeError.localizedDescription)") // Report the initial error
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

    // Helper function to format the dictionary into a string suitable for the prompt
    private func previousDayValuesToString(_ values: [String: Double]?) -> String {
        guard let values = values, !values.isEmpty else {
            return "{}" // Provide an empty JSON object string for the LLM
        }
        // Format as a JSON string for better structure within the prompt
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys // Consistent order helps the LLM
        // Format numbers to one decimal place before encoding
        let formattedValues = values.mapValues { Double(String(format: "%.1f", $0)) ?? $0 }
        if let data = try? encoder.encode(formattedValues),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        } else {
            // Fallback to simpler format if JSON encoding fails (less likely now)
            return values.map { "\($0.key): \($0.value.formatted(.number.precision(.fractionLength(1))))" }.joined(separator: ", ")
        }
    }

     enum LLMError: Error, LocalizedError, Equatable {
         case sdkError(String)
         case unexpectedResponse(String)
         case decodingError(String)
         case rateLimitExceeded(String) // New case for 429
         case badGateway(String)      // New case for 502

         var errorDescription: String? {
             switch self {
             case .sdkError(let reason): return "LLM Service Error: \(reason)"
             case .unexpectedResponse(let reason): return "Unexpected LLM response: \(reason)"
             case .decodingError(let reason): return "LLM Decoding Error: \(reason)"
             case .rateLimitExceeded(let reason): return "LLM Rate Limit Error: \(reason)"
             case .badGateway(let reason): return "LLM Server Error: \(reason)"
             }
         }
     }
}