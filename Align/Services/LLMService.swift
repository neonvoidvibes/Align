import Foundation
import OpenAI // Using the swift-openai-responses SDK module

@MainActor // Ensure service methods are called on the main actor
final class LLMService {
    static let shared = LLMService()

    // Client from swift-openai-responses SDK
    private let openAIClient: ResponsesAPI

    private init() {
        // TODO: [SECURITY] In production, the API key should ideally be fetched securely at runtime (e.g., Remote Config) or requests proxied through your own backend, not loaded directly here even via APIConfiguration.
        let apiKey = APIConfiguration.openAIAPIKey
        self.openAIClient = ResponsesAPI(authToken: apiKey)
        print("LLMService initialized with ResponsesAPI client (using development key loading).")
    }

    // Helper function to create a Model type from its ID string
    private func createModel(from id: String) -> Model {
        // Add validation for supported model IDs
        // Align PRD/Analysis uses gpt-4o specifically for chat agent
        guard ["gpt-4o"].contains(id) else {
             fatalError("❌ Unsupported model ID requested: \(id). Only 'gpt-4o' is currently configured for Align.")
        }

        guard let data = "\"\(id)\"".data(using: .utf8),
              let model = try? JSONDecoder().decode(Model.self, from: data) else {
             // This might indicate an issue with the SDK's Model type or the ID string format
            fatalError("❌ Failed to create Model enum/struct from validated id string: \(id)")
        }
        print("[LLMService] Using model: \(id)") // Log which model is being used
        return model
    }

    /// Generates a conversational response (plain text).
    func generateChatResponse(systemPrompt: String, userMessage: String, context: String? = nil) async throws -> String {
        let fullUserMessage = (context != nil && !context!.isEmpty) ? "\(context!)\n\n---\n\nUser: \(userMessage)" : "User: \(userMessage)"
        print("LLMService: Generating chat response for user message: '\(userMessage.prefix(50))...' (Context included: \(context != nil && !context!.isEmpty))")

        let model = createModel(from: "gpt-4o") // Align uses gpt-4o for chat

        let request = Request(
            model: model,
            input: .text(fullUserMessage), // Pass combined context + user message
            instructions: systemPrompt
        )

        do {
            // Add 'try' before the await call
            let result: Result<Response, Response.Error> = try await openAIClient.create(request)

            // Handle the Result
            switch result {
            case .success(let response):
                let replyContent = response.outputText

                // Check if the non-optional content is empty
                if replyContent.isEmpty {
                     print("LLMService: Received empty outputText, potentially a refusal or empty response.")
                     throw LLMError.unexpectedResponse("Received empty text content from LLM")
                }

                print("LLMService: Received chat response.")
                return replyContent

            case .failure(let error):
                print("LLMService: OpenAI API Error - \(error)")
                throw LLMError.sdkError("API Error: \(error.localizedDescription)")
            }
        } catch let error as LLMError {
             throw error
        } catch {
            print("LLMService: Error during chat generation - \(error)")
            throw LLMError.sdkError("Network or other error: \(error.localizedDescription)")
        }
    }

    // Note: generateStructuredOutput is not needed for Align's current requirement (basic chat)
    // It can be added later if insight generation is implemented.

    // Define potential errors - Added Equatable conformance
    enum LLMError: Error, LocalizedError, Equatable {
        case sdkError(String)
        case unexpectedResponse(String)
        // case decodingError(String) // Not needed for basic chat

        var errorDescription: String? {
            switch self {
            case .sdkError(let reason): return "LLM Service Error: \(reason)"
            case .unexpectedResponse(let reason): return "Unexpected LLM response: \(reason)"
            // case .decodingError(let reason): return "JSON Decoding Error: \(reason)"
            }
        }
    }
}