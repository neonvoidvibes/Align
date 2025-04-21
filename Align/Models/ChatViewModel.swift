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
    @Published var chatTitle: String = "New Chat" // *** ENSURE THIS IS THE ONLY DECLARATION ***

    // Dependencies
    // Ensure these service types are correctly defined and accessible
    private let databaseService: DatabaseService
    private let llmService: LLMService

    // Remove private access control to allow preview access (internal by default)
    var currentChat: Chat? // Keep track of the full Chat object internally
    // Internal dictionary to hold loaded chats
    var chats: [UUID: Chat] = [:]

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
                let chatsDict = try databaseService.loadAllChats() // Load dictionary
                let chatsList = chatsDict.values.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
                // Switch back to main actor to update published properties
                await MainActor.run {
                    self.chats = chatsDict // Store the loaded dictionary
                    if let mostRecentChat = chatsList.first {
                        self.currentChat = mostRecentChat
                        self.currentChatId = mostRecentChat.id
                        self.messages = mostRecentChat.messages
                        self.chatTitle = mostRecentChat.title // Update title from loaded chat
                        print("[ChatViewModel] Loaded most recent chat (ID: \(mostRecentChat.id)).")
                    } else {
                        startNewChatInternal() // Create a new chat if DB is empty
                        // Add initial assistant message
                        let initialMessage = ChatMessage(role: .assistant, content: "How's your day going? Tell me about your energy, work, and home life.", timestamp: Date())
                        self.messages.append(initialMessage)
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
        self.chatTitle = newChat.title // Set title for new chat
        self.inputText = ""
        self.isTyping = false
        print("[ChatViewModel] New chat session started internally (ID: \(currentChatId)).")
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
         self.chatTitle = newChat.title // Update published title
         self.inputText = ""
         self.isTyping = false
         // Add the new (empty) chat to our internal dictionary
         self.chats[newChat.id] = newChat
         // NOTE: We are NOT saving the new Chat or initial message to DB here.
         // It will be saved implicitly when the user sends the *first* message of the new chat.
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
             // Since startNewChatInternal resets messages, re-add the user message
             self.messages.append(userMessage)
        }

        // Add message to internal chat object and update its state
        self.currentChat?.messages.append(userMessage)
        self.currentChat?.lastUpdatedAt = userMessage.timestamp
        if self.currentChat?.title == "New Chat" || self.currentChat?.title.starts(with: "Chat ") == true {
            self.currentChat?.generateTitle() // Regenerate title based on first user message
            self.chatTitle = self.currentChat?.title ?? "Chat" // Update published title
        }
        // Update the chat in the internal dictionary
        if let updatedChat = self.currentChat {
             self.chats[updatedChat.id] = updatedChat
        }


        let chatId = self.currentChatId // Capture current chat ID

        // Save user message to DB in background
        Task.detached(priority: .utility) { // Keep background task
            // *** Explicitly await and assign to variable ***
            let embeddingVector = await generateEmbedding(for: userMessage.content)
            do {
                // Call DB method using try await
                try await self.databaseService.saveChatMessage(userMessage, chatId: chatId, embedding: embeddingVector)
                print("[ChatViewModel] User message saved to DB.")
            } catch {
                print("‼️ [ChatViewModel] Error saving user message: \(error)")
                // Handle error appropriately - maybe show UI indication?
            }
        }

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
                    // Update the chat in the internal dictionary
                     if let updatedChat = self.currentChat {
                          self.chats[updatedChat.id] = updatedChat
                     }
                    self.isTyping = false
                }

                // Save assistant message to DB in background
                Task.detached(priority: .utility) { // Keep background task
                    // *** Explicitly await and assign to variable ***
                    let embeddingVector = await generateEmbedding(for: assistantMessage.content)
                    do {
                        // Call DB method using try await
                        try await self.databaseService.saveChatMessage(assistantMessage, chatId: chatId, embedding: embeddingVector)
                        print("[ChatViewModel] Assistant message saved to DB.")
                    } catch {
                        print("‼️ [ChatViewModel] Error saving assistant message: \(error)")
                    }
                }

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

    // --- Chat Loading ---
    // (loadChat function remains)
    func loadChat(withId chatId: UUID) {
        guard let chatToLoad = chats[chatId] else {
            print("‼️ [ChatViewModel] Error: Chat with ID \(chatId) not found in loaded chats.")
            // Optionally start a new chat or show an error
            // startNewChatInternal()
            return
        }
        print("[ChatViewModel] Loading chat ID: \(chatId)")
        self.currentChat = chatToLoad
        self.currentChatId = chatToLoad.id
        self.messages = chatToLoad.messages
        self.chatTitle = chatToLoad.title
        self.inputText = "" // Clear input when loading chat
        self.isTyping = false
    }

    // Reload all chats from DB - can be called on appear or refresh
    func refreshChatsFromDB() {
         Task {
             do {
                 self.chats = try databaseService.loadAllChats()
                 print("[ChatViewModel] Refreshed chats from DB. Count: \(self.chats.count)")
                 // If current chat no longer exists, start new one?
                 if chats[self.currentChatId] == nil {
                      print("[ChatViewModel] Current chat \(self.currentChatId) not found after refresh. Starting new chat.")
                      await MainActor.run { startNewChat() }
                 }
             } catch {
                  print("‼️ [ChatViewModel] Error refreshing chats from DB: \(error)")
             }
         }
    }

    // --- Chat Grouping ---
    // (groupChatsByTimePeriod function remains)
    func groupChatsByTimePeriod() -> [(String, [Chat])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        var chatsBySection: [String: [Chat]] = [:]

        // Use the internal chats dictionary
        for chat in chats.values {
            let chatDate = calendar.startOfDay(for: chat.lastUpdatedAt)
            let chatYear = calendar.component(.year, from: chat.lastUpdatedAt)
            let currentYear = calendar.component(.year, from: today)

            let sectionKey: String
            if calendar.isDate(chatDate, inSameDayAs: today) { sectionKey = "Today" }
            else if calendar.isDate(chatDate, inSameDayAs: yesterday) { sectionKey = "Yesterday" }
            else if chatDate >= currentWeekStart { sectionKey = "This Week" }
            else if chatDate >= lastWeekStart { sectionKey = "Last Week" }
            else if chatDate >= currentMonthStart { sectionKey = "This Month" }
            else if chatYear == currentYear {
                let monthFormatter = DateFormatter(); monthFormatter.dateFormat = "MMMM"; sectionKey = monthFormatter.string(from: chat.lastUpdatedAt)
            } else {
                let yearMonthFormatter = DateFormatter(); yearMonthFormatter.dateFormat = "yyyy"; sectionKey = yearMonthFormatter.string(from: chat.lastUpdatedAt) // Just year for older
            }
            chatsBySection[sectionKey, default: []].append(chat)
        }

        // Sort chats within each section by date (newest first)
        for (key, value) in chatsBySection { chatsBySection[key] = value.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt } }

        // Define fixed order for recent sections
        let sectionOrder: [String] = ["Today", "Yesterday", "This Week", "Last Week", "This Month"]

        // Sort sections: recent fixed order first, then by month/year descending date of newest chat in section
        let sortedSections = chatsBySection.sorted { (section1, section2) -> Bool in
            let index1 = sectionOrder.firstIndex(of: section1.key)
            let index2 = sectionOrder.firstIndex(of: section2.key)

            if let idx1 = index1, let idx2 = index2 { return idx1 < idx2 } // Both in fixed order
            if index1 != nil { return true } // Only section1 is in fixed order
            if index2 != nil { return false } // Only section2 is in fixed order

            // Neither in fixed order, sort by date of newest chat (descending)
            let date1 = section1.value.first?.lastUpdatedAt ?? .distantPast
            let date2 = section2.value.first?.lastUpdatedAt ?? .distantPast
            if date1 == date2 { return section1.key > section2.key } // Fallback sort by key if dates match
            return date1 > date2
        }
        return sortedSections
    }

}