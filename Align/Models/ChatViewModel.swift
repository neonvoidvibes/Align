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
    @Published var chatTitle: String = "New Chat"

    // Dependencies
    private let databaseService: DatabaseService
    private let llmService: LLMService
    private let analysisService: AnalysisService // Keep AnalysisService reference

    var currentChat: Chat? // Keep track of the full Chat object internally
    var chats: [UUID: Chat] = [:]

    // Initializer requires dependencies
    init(databaseService: DatabaseService, llmService: LLMService) {
        self.databaseService = databaseService
        self.llmService = llmService
        // Initialize AnalysisService here
        self.analysisService = AnalysisService(databaseService: databaseService, llmService: llmService)
        print("[ChatViewModel] Initialized with services.")
        loadOrCreateChat() // Load existing or start a new chat session
    }

    // Load the most recent chat or create a new one
    private func loadOrCreateChat() {
        // Use synchronous DB load
        do {
            let chatsDict = try databaseService.loadAllChats() // Load dictionary (synchronous)
            let chatsList = chatsDict.values.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }

            self.chats = chatsDict
            if let mostRecentChat = chatsList.first {
                self.currentChat = mostRecentChat
                self.currentChatId = mostRecentChat.id
                self.messages = mostRecentChat.messages
                self.chatTitle = mostRecentChat.title
                print("[ChatViewModel] Loaded most recent chat (ID: \(mostRecentChat.id)).")
            } else {
                startNewChatInternal()
                let initialMessage = ChatMessage(role: .assistant, content: "How's your day going? Tell me about your energy, work, and home life.", timestamp: Date())
                self.messages.append(initialMessage)
                 print("[ChatViewModel] No existing chats found. Started a new chat session (ID: \(currentChatId)). Added initial prompt.")
            }
        } catch {
            print("‼️ [ChatViewModel] Error loading chats: \(error). Starting new chat.")
            startNewChatInternal()
            let initialMessage = ChatMessage(role: .assistant, content: "How's your day going? Tell me about your energy, work, and home life.", timestamp: Date())
            self.messages.append(initialMessage)
        }
    }


    // Creates a new chat session state
    private func startNewChatInternal() {
        let newChat = Chat()
        self.currentChat = newChat
        self.currentChatId = newChat.id
        self.messages = []
        self.chatTitle = newChat.title
        self.inputText = ""
        self.isTyping = false
        print("[ChatViewModel] New chat session started internally (ID: \(currentChatId)).")
    }

    // Public function to start a new chat (e.g., from a button)
    func startNewChat() {
         print("[ChatViewModel] Starting new chat via public func...")
         let newChat = Chat()
         self.currentChat = newChat
         self.currentChatId = newChat.id
         let initialMessage = ChatMessage(role: .assistant, content: "How's your day going? Tell me about your energy, work, and home life.", timestamp: Date())
         self.messages = [initialMessage]
         self.chatTitle = newChat.title
         self.inputText = ""
         self.isTyping = false
         self.chats[newChat.id] = newChat
    }

    // Send message logic
    func sendMessage() {
        let userMessageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessageText.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: userMessageText, timestamp: Date())
        let capturedMessageId = userMessage.id // Capture ID for analysis trigger
        self.messages.append(userMessage)
        let textToSend = inputText
        self.inputText = ""
        self.isTyping = true

        if self.currentChat == nil {
             print("‼️ [ChatViewModel] currentChat is nil before saving. Creating new.")
             startNewChatInternal()
             self.messages.append(userMessage) // Re-add user message after reset
        }

        // Add message to internal chat object and update state
        self.currentChat?.messages.append(userMessage)
        self.currentChat?.lastUpdatedAt = userMessage.timestamp
        if self.currentChat?.title == "New Chat" || self.currentChat?.title.starts(with: "Chat ") == true {
            self.currentChat?.generateTitle()
            self.chatTitle = self.currentChat?.title ?? "Chat"
        }
        if let updatedChat = self.currentChat {
             self.chats[updatedChat.id] = updatedChat
        }

        let chatId = self.currentChatId

        // --- Save user message & Trigger Analysis in Background Task ---
        Task.detached(priority: .utility) { [weak self] in // Capture self weakly
             guard let self = self else { return }
            let embeddingVector = await generateEmbedding(for: userMessage.content)
            do {
                // Call synchronous save function
                try self.databaseService.saveChatMessage(userMessage, chatId: chatId, embedding: embeddingVector)
                print("[ChatViewModel] User message save attempt finished.")

                // Trigger analysis AFTER successful save attempt
                print("[ChatViewModel] Triggering analysis for message \(capturedMessageId)...")
                // Instantiate AnalysisService here if needed or use shared instance pattern if appropriate
                 await self.analysisService.generateAnalysis(for: capturedMessageId) // Await the async analysis
                 print("[ChatViewModel] Analysis task for message \(capturedMessageId) potentially finished.")

            } catch {
                print("‼️ [ChatViewModel] Error saving user message or triggering analysis: \(error)")
            }
        }
        // --- End Save & Analysis Trigger ---


        // --- Call LLM for Response (RAG + Score/Priority Context) ---
        Task { // Keep this Task on the MainActor (default for ChatViewModel)
            var ragContextString = ""
            // retrievalError is unused // var retrievalError: Error? = nil

             // --- RAG Context Retrieval ---
             print("[ChatViewModel] Attempting embedding generation for RAG...")
             let queryEmbedding = await generateEmbedding(for: textToSend)
             if let queryEmbedding = queryEmbedding {
                 print("[ChatViewModel] Embedding generated. Retrieving RAG context...")
                 do {
                      // Call async findSimilarChatMessages
                      let messages = try await databaseService.findSimilarChatMessages(to: queryEmbedding, limit: 5)
                      print("[ChatViewModel] RAG retrieval success: \(messages.count) messages.")

                      var contextStrings: [String] = ["Context items (most relevant first):"]
                      for item in messages {
                          let filteredText = filterPII(text: item.text)
                          var metadataString = "(\(item.sourceType.rawValue), \(item.date.formatted(date: .numeric, time: .shortened))"
                           if item.isStarred { metadataString += ", STARRED" }
                          metadataString += ")"
                          contextStrings.append("- \(metadataString): \(filteredText)")
                      }
                      ragContextString = contextStrings.joined(separator: "\n")
                      print("[ChatViewModel] Context formatting complete. Length: \(ragContextString.count) chars.")

                 } catch {
                      print("‼️ [ChatViewModel] RAG DB retrieval or processing failed: \(error)")
                      ragContextString = ""
                 }
             } else {
                  print("‼️ [ChatViewModel] Embedding generation failed for RAG.")
             }
             // --- End RAG ---

             // --- Fetch Latest Score/Priority for LLM Context (Synchronous) ---
             var scorePriorityContext = ""
             do {
                  // Call synchronous DB function
                  let (score, priority) = try databaseService.getLatestDisplayScoreAndPriority()
                  if let s = score, let p = priority {
                       scorePriorityContext = "Current Score: \(s)/100. Priority: \(p)."
                  } else if let s = score {
                       scorePriorityContext = "Current Score: \(s)/100."
                  } else if let p = priority {
                       scorePriorityContext = "Priority: \(p)."
                  }
                   print("[ChatViewModel] Fetched Score/Priority Context: \(scorePriorityContext)")
             } catch {
                  print("‼️ [ChatViewModel] Error fetching score/priority for LLM context: \(error)")
             }
             // --- End Score/Priority Fetch ---


             // --- Construct Final Prompt & Call LLM ---
             let systemPrompt = SystemPrompts.chatAgentPrompt
             let combinedContext = "\(ragContextString)\n\(scorePriorityContext)".trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                // LLM call remains async
                let assistantReplyText = try await llmService.generateChatResponse(
                    systemPrompt: systemPrompt,
                    userMessage: textToSend,
                    context: combinedContext.isEmpty ? nil : combinedContext
                )

                let assistantMessage = ChatMessage(role: .assistant, content: assistantReplyText, timestamp: Date())

                // Update UI (already on MainActor)
                self.messages.append(assistantMessage)
                self.currentChat?.messages.append(assistantMessage)
                self.currentChat?.lastUpdatedAt = assistantMessage.timestamp
                 if let updatedChat = self.currentChat {
                      self.chats[updatedChat.id] = updatedChat
                 }
                self.isTyping = false


                // Save assistant message to DB in background (synchronously)
                Task.detached(priority: .utility) { [weak self] in
                    guard let self = self else { return }
                    let embeddingVector = await generateEmbedding(for: assistantMessage.content)
                    do {
                        // Call synchronous save
                        try self.databaseService.saveChatMessage(assistantMessage, chatId: chatId, embedding: embeddingVector)
                        print("[ChatViewModel] Assistant message saved to DB.")
                    } catch {
                        print("‼️ [ChatViewModel] Error saving assistant message: \(error)")
                    }
                }

            } catch {
                print("‼️ [ChatViewModel] Error getting LLM response: \(error)")
                let errorMessage = ChatMessage(
                    role: .assistant,
                    content: "Sorry, I encountered an error. Please try again. (\(error.localizedDescription.prefix(100))...)",
                    timestamp: Date(),
                    isStarred: true
                )
                // Update UI (already on MainActor)
                self.messages.append(errorMessage)
                self.isTyping = false
            }
        } // End LLM Task
    }


    // --- Delete/Star functionality (Synchronous DB calls) ---
    func deleteMessage(_ message: ChatMessage) {
         print("[ChatViewModel] Deleting message ID: \(message.id)")
         let messageIdToDelete = message.id

         // Find and remove from the main chats dictionary and current chat
         if let chatIndex = self.chats.firstIndex(where: { $0.value.messages.contains(where: { $0.id == messageIdToDelete }) }) {
              let chatId = self.chats[chatIndex].key
              self.chats[chatId]?.messages.removeAll { $0.id == messageIdToDelete }
              if self.currentChat?.id == chatId { self.currentChat = self.chats[chatId] }
              if self.currentChatId == chatId { self.messages.removeAll { $0.id == messageIdToDelete } }
         } else if var currentChat = self.currentChat, currentChat.messages.contains(where: { $0.id == messageIdToDelete }) { // Use var for mutable copy
              currentChat.messages.removeAll { $0.id == messageIdToDelete }
              self.currentChat = currentChat // Assign back
              self.messages.removeAll { $0.id == messageIdToDelete }
              if let chatId = currentChat.id, self.chats[chatId] != nil { self.chats[chatId] = currentChat }
         } else {
              print("⚠️ [ChatViewModel] Could not find message \(messageIdToDelete) to delete in local state.")
              return
         }

         // Delete from DB synchronously on background thread
         Task.detached(priority: .background) { [weak self] in
              guard let self = self else { return }
              do {
                  try self.databaseService.deleteMessageFromDB(id: messageIdToDelete)
                  print("✅ [ChatViewModel] Successfully deleted message \(messageIdToDelete) from DB.")
              } catch {
                  print("‼️ [ChatViewModel] Error deleting message \(messageIdToDelete) from DB: \(error)")
              }
         }
    }

     func toggleStarMessage(_ message: ChatMessage) {
         let messageId = message.id
         var newStarStatus: Bool? = nil
         var chatKeyToUpdate: UUID? = nil

         // Update logic to handle dictionary access correctly
         if let chatIndex = self.chats.firstIndex(where: { $0.value.messages.contains(where: { $0.id == messageId }) }) {
              let chatId = self.chats[chatIndex].key
              if let msgIdx = self.chats[chatId]?.messages.firstIndex(where: { $0.id == messageId }) {
                  self.chats[chatId]?.messages[msgIdx].isStarred.toggle()
                  newStarStatus = self.chats[chatId]?.messages[msgIdx].isStarred
                  chatKeyToUpdate = chatId
                  if self.currentChat?.id == chatKeyToUpdate { self.currentChat = self.chats[chatId] }
                  if self.currentChatId == chatKeyToUpdate {
                      if let uiMsgIdx = self.messages.firstIndex(where: { $0.id == messageId }) {
                          self.messages[uiMsgIdx].isStarred.toggle()
                      }
                  }
              }
         } else if var currentChat = self.currentChat, let msgIdx = currentChat.messages.firstIndex(where: { $0.id == messageId }) {
              currentChat.messages[msgIdx].isStarred.toggle()
              newStarStatus = currentChat.messages[msgIdx].isStarred
              self.currentChat = currentChat
              chatKeyToUpdate = currentChat.id
              if let key = chatKeyToUpdate { self.chats[key] = currentChat }
              if let uiMsgIdx = self.messages.firstIndex(where: { $0.id == messageId }) {
                  self.messages[uiMsgIdx].isStarred.toggle()
              }
         }

         if let key = chatKeyToUpdate, let chat = self.chats[key], let status = newStarStatus {
             let chatIsNowStarred = chat.messages.contains { $0.isStarred }
             if chat.isStarred != chatIsNowStarred {
                  self.chats[key]?.isStarred = chatIsNowStarred
                 if self.currentChat?.id == key { self.currentChat?.isStarred = chatIsNowStarred }
             }

             print("[ChatViewModel] Toggling star for message \(messageId) to \(status)")
             Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                 do {
                     try self.databaseService.toggleMessageStarInDB(id: messageId, isStarred: status)
                     print("✅ [ChatViewModel] Successfully toggled star for message \(messageId) in DB.")
                 } catch {
                     print("‼️ [ChatViewModel] Error toggling star for message \(messageId) in DB: \(error)")
                 }
             }
         } else if newStarStatus == nil {
             print("⚠️ [ChatViewModel] Could not find message \(messageId) to star.")
         }
     }


    // --- Chat Loading ---
    func loadChat(withId chatId: UUID) {
        guard let chatToLoad = chats[chatId] else {
            print("‼️ [ChatViewModel] Error: Chat with ID \(chatId) not found in loaded chats.")
            return
        }
        print("[ChatViewModel] Loading chat ID: \(chatId)")
        self.currentChat = chatToLoad
        self.currentChatId = chatToLoad.id
        self.messages = chatToLoad.messages
        self.chatTitle = chatToLoad.title
        self.inputText = ""
        self.isTyping = false
    }

    // Reload all chats from DB - Synchronous
    func refreshChatsFromDB() {
         do {
             self.chats = try databaseService.loadAllChats()
             print("[ChatViewModel] Refreshed chats from DB. Count: \(self.chats.count)")
             if chats[self.currentChatId] == nil {
                  print("[ChatViewModel] Current chat \(self.currentChatId) not found after refresh. Starting new chat.")
                  startNewChat()
             }
         } catch {
              print("‼️ [ChatViewModel] Error refreshing chats from DB: \(error)")
         }
    }

    // --- Chat Grouping ---
    func groupChatsByTimePeriod() -> [(String, [Chat])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        var chatsBySection: [String: [Chat]] = [:]

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
                let yearMonthFormatter = DateFormatter(); yearMonthFormatter.dateFormat = "yyyy"; sectionKey = yearMonthFormatter.string(from: chat.lastUpdatedAt)
            }
            chatsBySection[sectionKey, default: []].append(chat)
        }

        for (key, value) in chatsBySection { chatsBySection[key] = value.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt } }
        let sectionOrder: [String] = ["Today", "Yesterday", "This Week", "Last Week", "This Month"]
        let sortedSections = chatsBySection.sorted { (section1, section2) -> Bool in
            let index1 = sectionOrder.firstIndex(of: section1.key)
            let index2 = sectionOrder.firstIndex(of: section2.key)
            if let idx1 = index1, let idx2 = index2 { return idx1 < idx2 }
            if index1 != nil { return true }
            if index2 != nil { return false }
            let date1 = section1.value.first?.lastUpdatedAt ?? .distantPast
            let date2 = section2.value.first?.lastUpdatedAt ?? .distantPast
            if date1 == date2 { return section1.key > section2.key }
            return date1 > date2
        }
        return sortedSections
    }
}
