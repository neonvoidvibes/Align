import Foundation

// Role enum matches notetoself
enum MessageRole: String, Codable, Equatable {
    case user
    case assistant
}

// Updated ChatMessage struct - Added isStarred, Codable conformance
struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let role: MessageRole // Changed from isUser: Bool
    let content: String
    let timestamp: Date
    var isStarred: Bool // Added isStarred

    // Initializer with default isStarred
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), isStarred: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStarred = isStarred
    }

    // Equatable conformance based on ID
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }

    // Hashable conformance based on ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Mock messages removed, will load from DB or start fresh.
    // If needed for previews, create a static mock function here.
    /*
    static func mockMessages() -> [ChatMessage] {
        return [
            ChatMessage(
                role: .assistant,
                content: "How's your day going? Tell me about your energy, work, and home life.", // Initial prompt
                timestamp: Date(),
                isStarred: false
            )
        ]
    }
    */
}

// New Chat model, needed by ChatViewModel rewrite
struct Chat: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var messages: [ChatMessage]
    let createdAt: Date
    var lastUpdatedAt: Date
    var title: String
    var isStarred: Bool

    init(id: UUID = UUID(), messages: [ChatMessage] = [], createdAt: Date = Date(), lastUpdatedAt: Date = Date(), title: String = "New Chat", isStarred: Bool = false) {
        self.id = id
        self.messages = messages
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.title = title
        self.isStarred = isStarred
    }

    // Simple title generation based on the first user message
    mutating func generateTitle() {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let maxLength = min(firstUserMessage.content.count, 30)
            let truncatedText = String(firstUserMessage.content.prefix(maxLength))
            title = truncatedText + (maxLength < firstUserMessage.content.count ? "..." : "")
        } else {
            // Fallback if no user message yet
            title = "Chat \(id.uuidString.prefix(4))..."
        }
    }

    // Equatable conformance
    static func == (lhs: Chat, rhs: Chat) -> Bool {
         return lhs.id == rhs.id
     }

     // Hashable conformance
     func hash(into hasher: inout Hasher) {
         hasher.combine(id)
     }
}