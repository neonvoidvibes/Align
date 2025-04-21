import Foundation
import SwiftUI // For ObservableObject
import Combine // For task management if needed

// Ensure this file is included in the Align App Target Membership

@MainActor // Mark the whole class as MainActor for safe UI updates
class ChatViewModel: ObservableObject {

    // Published properties for the UI
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var currentChatId: UUID = UUID() // ID for the current conversation thread
    @Published var chatTitle: String = "New Chat" // Title for the current chat

    // Dependencies
    // Ensure these service types are correctly defined and accessible
    private let databaseService: DatabaseService
    private let llmService: LLMService

    private var currentChat: Chat? // Keep track of the full Chat object internally

    // Initializer requires dependencies
    init(databaseService: DatabaseService, llmService: LLMService) {
        self.databaseService = databaseService
        self.llmService = llmService
        print("[ChatViewModel] Initialized with services.")
        loadOrCreateChat() // Load existing or start a new chat session
    }

    // Load the most recent chat or create a new one
    private func loadOrCreateChat() {
        Task { // Keep background task for potentially slow DB read
            do {
                // Call synchronous DB method from background task
                let chats = try databaseService.loadAllChats().values.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
                // Switch back to main actor to update published properties
                await MainActor.run {
                    if let mostRecentChat = chats.first {
                        self.currentChat = mostRecentChat
                        self.currentChatId = mostRecentChat.id
                        self.messages = mostRecentChat.messages
                        self.chatTitle = mostRecentChat.title
                        print("[ChatViewModel] Loaded most recent chat (ID: \(mostRecentChat.id)).")
                    } else {
                        startNewChatInternal() // Create a new chat if DB is empty
                        // Add initial assistant message
                        let initialMessage = ChatMessage(role: .assistant, content: "How's your day going? Tell me about your energy, work, and home life.", timestamp: Date())
                        self.messages.append(initialMessage)
                        // Save initial message? Or wait for user input? Let's wait.
                         print("[ChatViewModel] No existing chats found. Started a new chat session (ID: \(currentChatId)). Added initial prompt.")
                    }
                } // End MainActor.run
            } catch {
                print("‼️ [ChatViewModel] Error loading chats: \(error). Starting new chat.")
                // Update UI on MainActor in error case too
                await MainActor.run {
                     startNewChatInternal()
                     let initialMessage = ChatMessage(role: .assistant, content: "How's your day going? Tell me about your energy, work, and home life.", timestamp: Date())
                     self.messages.append(initialMessage)
                }
            }
        }
    }

    // Creates a new chat session state
    private func startNewChatInternal() {
        let newChat = Chat()
        self.currentChat = newChat
        self.currentChatId = newChat.id
        self.messages = [] // Start with empty messages for a new chat
        self.chatTitle = newChat.title
        self.inputText = ""
        self.isTyping = false
        print("[ChatViewModel] New chat session started (ID: \(currentChatId)).")
    }

    // Public function to start a new chat (e.g., from a button)
    // This should completely reset the state for the UI
    func startNewChat() {
         print("[ChatViewModel] Starting new chat via public func...")
         // Create a completely new Chat object
         let newChat = Chat()
         self.currentChat = newChat
         self.currentChatId = newChat.id
         // Create the standard initial message
         let initialMessage = ChatMessage(role: .assistant, content: "How's your day going? Tell me about your energy, work, and home life.", timestamp: Date())
         // Reset published properties
         self.messages = [initialMessage] // Reset messages with only the initial one
         self.chatTitle = newChat.title
         self.inputText = ""
         self.isTyping = false
         // NOTE: We are NOT saving the new Chat or initial message to DB here.
         // It will be saved implicitly when the user sends the *first* message of the new chat.
         // Or, we could explicitly save the empty chat stub if desired. Let's keep it implicit for now.
    }

    // Send message logic
    func sendMessage() {
        let userMessageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessageText.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: userMessageText, timestamp: Date())
        self.messages.append(userMessage) // Update UI immediately
        let textToSend = inputText // Capture before clearing
        self.inputText = "" // Clear input field
        self.isTyping = true

        // Ensure currentChat exists before proceeding
        if self.currentChat == nil {
             print("‼️ [ChatViewModel] currentChat is nil before saving. Creating new.")
             startNewChatInternal() // Ensure chat exists if somehow lost
        }
        // Update chat object internally
        self.currentChat?.messages.append(userMessage)
        self.currentChat?.lastUpdatedAt = userMessage.timestamp
        if self.currentChat?.title == "New Chat" || self.currentChat?.title.starts(with: "Chat ") == true {
            self.currentChat?.generateTitle() // Regenerate title based on first user message
            self.chatTitle = self.currentChat?.title ?? "Chat" // Update published title
        }

        let chatId = self.currentChatId // Capture current chat ID

        // Save user message to DB in background
        // *** Uncommented block below ***
        Task.detached(priority: .utility) { // Keep background task
            // *** Explicitly await and assign to variable ***
            let embeddingVector = await generateEmbedding(for: userMessage.content)
            do {
                // Call synchronous DB method, pass the variable
                try await self.databaseService.saveChatMessage(userMessage, chatId: chatId, embedding: embeddingVector)
                print("[ChatViewModel] User message saved to DB.")
            } catch {
                print("‼️ [ChatViewModel] Error saving user message: \(error)")
                // Handle error appropriately - maybe show UI indication?
            }
        }
        // *** End uncommented block ***

        // Call LLM for response in background
        Task {
            do {
                // NOTE: No RAG context for now as per initial instructions for basic chat functionality
                let systemPrompt = SystemPrompts.chatAgentPrompt
                let assistantReplyText = try await llmService.generateChatResponse(
                    systemPrompt: systemPrompt,
                    userMessage: textToSend // Use captured text
                )

                let assistantMessage = ChatMessage(role: .assistant, content: assistantReplyText, timestamp: Date())

                // Update UI on MainActor
                await MainActor.run {
                    self.messages.append(assistantMessage)
                    self.currentChat?.messages.append(assistantMessage)
                    self.currentChat?.lastUpdatedAt = assistantMessage.timestamp
                    self.isTyping = false
                }

                // Save assistant message to DB in background
                // *** Uncommented block below ***
                Task.detached(priority: .utility) { // Keep background task
                    // *** Explicitly await and assign to variable ***
                    let embeddingVector = await generateEmbedding(for: assistantMessage.content)
                    do {
                        // Call synchronous DB method, pass the variable
                        try await self.databaseService.saveChatMessage(assistantMessage, chatId: chatId, embedding: embeddingVector)
                        print("[ChatViewModel] Assistant message saved to DB.")
                    } catch {
                        print("‼️ [ChatViewModel] Error saving assistant message: \(error)")
                    }
                }
                 // *** End uncommented block ***

            } catch {
                print("‼️ [ChatViewModel] Error getting LLM response: \(error)")
                // Create an error message to display in chat
                let errorMessage = ChatMessage(
                    role: .assistant,
                    content: "Sorry, I encountered an error. Please try again. (\(error.localizedDescription.prefix(100))...)", // Limit error message length
                    timestamp: Date(),
                    isStarred: true // Star error messages?
                )
                await MainActor.run {
                    self.messages.append(errorMessage)
                    // Don't save this UI error message to DB? Or maybe do for history? Let's skip saving for now.
                    self.isTyping = false
                }
            }
        }
    }

    // --- Optional: Add Delete/Star functionality later if needed ---
    // func deleteMessage(_ message: ChatMessage) { ... }
    // func toggleStarMessage(_ message: ChatMessage) { ... }
}