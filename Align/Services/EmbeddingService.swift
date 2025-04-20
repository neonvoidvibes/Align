import Foundation
import NaturalLanguage

// Actor to manage NLEmbedding instance and ensure thread-safe access
@available(iOS 16.0, *)
actor EmbeddingService {
    static let shared = EmbeddingService() // Singleton instance

    private let embeddingDimension = 512 // Expected dimension
    private let embeddingModel: NLEmbedding? // Make it constant after init

    // Helper function to load the model synchronously without accessing actor state
    private static func loadEmbeddingModel(dimension: Int) -> NLEmbedding? {
        print("[EmbeddingService Helper] Attempting to load NLEmbedding model...")
        guard let model = NLEmbedding.sentenceEmbedding(for: .english) else {
            print("‼️ [EmbeddingService Helper] NLEmbedding.sentenceEmbedding returned nil.")
            return nil
        }
        guard model.dimension == dimension else {
            print("‼️ [EmbeddingService Helper] Loaded NLEmbedding dimension (\(model.dimension)) doesn't match EXPECTED (\(dimension)).")
            return nil
        }
        print("[EmbeddingService Helper] NLEmbedding model loaded successfully.")
        return model
    }

    private init() {
        // Call the static helper function to load the model synchronously during initialization.
        // This runs before the actor is fully initialized and isolated.
        print("[EmbeddingService] Initializing...")
        self.embeddingModel = EmbeddingService.loadEmbeddingModel(dimension: self.embeddingDimension)
        if embeddingModel == nil {
             print("‼️ [EmbeddingService] Failed to load NLEmbedding model during initialization.")
             // Consider how to handle this failure - maybe throw or log prominently.
        }
    }

    /// Generates a sentence embedding for the given text using the managed NLEmbedding instance.
    /// This method is safe to call from any thread due to the actor isolation.
    func generateEmbedding(for text: String) -> [Float]? {
        guard let model = self.embeddingModel else {
            print("‼️ [EmbeddingService] Embedding model not available (was nil during init?).")
            return nil
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // print("[EmbeddingService] Input text is empty, skipping embedding generation.") // Reduced logging noise
            return nil
        }

        // Calling vector(for:) within the actor ensures serial access.
        guard let vector = model.vector(for: text) else {
            print("⚠️ [EmbeddingService] Could not generate vector for text: '\(text.prefix(50))...'")
            return nil
        }

        // NLEmbedding returns [Double], convert to [Float]
        let floatVector = vector.map { Float($0) }
        // print("[EmbeddingService] Generated \(floatVector.count)-dim vector.")
        return floatVector
    }
}

// Global async function to access the embedding service easily, handling availability check.
func generateEmbedding(for text: String) async -> [Float]? {
    if #available(iOS 16.0, *) {
        // Call the actor's method
        return await EmbeddingService.shared.generateEmbedding(for: text)
    } else {
        print("‼️ [Embedding] NLEmbedding requires iOS 16.0 or later.")
        return nil
    }
}

// Global function for JSON conversion, handling availability check.
// This doesn't access shared mutable state, so it doesn't need to be part of the actor.
func embeddingToJson(_ embedding: [Float]) -> String? {
     if #available(iOS 16.0, *) {
         // Use higher precision format specifier if needed, but %.8f is usually sufficient
         let numberStrings = embedding.map { String(format: "%.8f", $0) }
         return "[" + numberStrings.joined(separator: ",") + "]"
     } else {
         print("‼️ [Embedding] Embedding requires iOS 16.0 or later.")
         return nil
     }
}