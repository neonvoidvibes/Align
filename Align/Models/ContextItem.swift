import Foundation

/// Represents a piece of context retrieved for the AI, including metadata for weighting and understanding.
/// Simplified for Align - only using Chat Messages initially.
struct ContextItem: Identifiable {
    let id: UUID
    let text: String
    let sourceType: ContextSourceType
    let date: Date
    // Removed Mood/Intensity as ChatMessages don't have them
    let isStarred: Bool
    // Removed InsightCardType as Align doesn't generate insights yet
    let relatedChatId: UUID?

    // Calculated property for age in days (used for weighting)
    var ageInDays: Int {
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}

// Enum to identify the source of the context item
enum ContextSourceType: String {
    // Only Chat Messages for Align initially
    case chatMessage = "Chat Message"
    // case journalEntry = "Journal Entry" // Removed for Align
    // case insight = "AI Insight" // Removed for Align
}