import Foundation

enum MessageRole: Equatable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.timestamp == rhs.timestamp
    }
    
    static func mockMessages() -> [ChatMessage] {
        return [
            ChatMessage(
                role: .assistant,
                content: "How's your day going? Tell me about your energy, work, and home life.",
                timestamp: Date()
            )
        ]
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = ChatMessage.mockMessages()
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var currentStreamedText: String = ""
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(
            role: .user,
            content: inputText,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        let userInput = inputText
        inputText = ""
        
        // Simulate AI response
        isTyping = true
        currentStreamedText = ""
        
        // Generate response based on user input
        let action = getRecommendedAction(for: userInput)
        let responseText = "Based on your input, your priority is to focus on \(action.node). \(action.recommendation)"
        
        // Simulate typing effect
        var charIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if charIndex < responseText.count {
                let index = responseText.index(responseText.startIndex, offsetBy: charIndex)
                self.currentStreamedText.append(responseText[index])
                charIndex += 1
            } else {
                timer.invalidate()
                self.isTyping = false
                self.currentStreamedText = ""
                
                // Add the complete message
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: responseText,
                    timestamp: Date()
                )
                self.messages.append(assistantMessage)
            }
        }
    }
    
    private func getRecommendedAction(for input: String) -> (node: String, recommendation: String) {
        // In a real app, this would analyze the input and determine the best action
        // For now, we'll just return a fixed recommendation
        return (
            node: "Repay Debt",
            recommendation: "Set aside 30 minutes to review your budget and make a debt payment."
        )
    }
}
