import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var currentChatId: UUID = UUID()
    @Published var chatTitle: String = "New Chat"

    private let databaseService: DatabaseService
    private let llmService: LLMService
    private let analysisService: AnalysisService

    var currentChat: Chat?
    var chats: [UUID: Chat] = [:]

    init(databaseService: DatabaseService, llmService: LLMService) {
        self.databaseService = databaseService
        self.llmService = llmService
        self.analysisService = AnalysisService(databaseService: databaseService, llmService: llmService)
        print("[ChatViewModel] Initialized with services.")
        loadOrCreateChat()
    }

    private func loadOrCreateChat() {
        do {
            let chatsDict = try databaseService.loadAllChats()
            let chatsList = chatsDict.values.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }

            self.chats = chatsDict
            if let mostRecent = chatsList.first {
                self.currentChat = mostRecent
                self.currentChatId = mostRecent.id
                self.messages = mostRecent.messages
                self.chatTitle = mostRecent.title
                print("[ChatViewModel] Loaded chat ID: \(mostRecent.id).")
            } else {
                startNewChatInternal()
                let initial = ChatMessage(
                    role: .assistant,
                    content: "How's your day going? Tell me about your energy, work, and home life.",
                    timestamp: Date()
                )
                self.messages.append(initial)
                print("[ChatViewModel] No chats found. Started new chat ID: \(currentChatId).")
            }
        } catch {
            print("‼️ [ChatViewModel] Error loading chats: \(error). Starting new chat.")
            startNewChatInternal()
            let initial = ChatMessage(
                role: .assistant,
                content: "How's your day going? Tell me about your energy, work, and home life.",
                timestamp: Date()
            )
            self.messages.append(initial)
        }
    }

    private func startNewChatInternal() {
        let newChat = Chat()
        self.currentChat = newChat
        self.currentChatId = newChat.id
        self.messages = []
        self.chatTitle = newChat.title
        self.inputText = ""
        self.isTyping = false
        print("[ChatViewModel] New chat session started internally ID: \(currentChatId).")
    }

    func startNewChat() {
        print("[ChatViewModel] Starting new chat via public func...")
        let newChat = Chat()
        self.currentChat = newChat
        self.currentChatId = newChat.id
        let initial = ChatMessage(
            role: .assistant,
            content: "How's your day going? Tell me about your energy, work, and home life.",
            timestamp: Date()
        )
        self.messages = [initial]
        self.chatTitle = newChat.title
        self.inputText = ""
        self.isTyping = false
        self.chats[newChat.id] = newChat
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = ChatMessage(role: .user, content: text, timestamp: Date())
        let capturedId = userMsg.id
        messages.append(userMsg)
        inputText = ""
        isTyping = true

        if currentChat == nil {
            print("‼️ [ChatViewModel] currentChat nil before save. Resetting.")
            startNewChatInternal()
            messages.append(userMsg)
        }

        currentChat?.messages.append(userMsg)
        currentChat?.lastUpdatedAt = userMsg.timestamp
        if currentChat?.title == "New Chat" || currentChat?.title.starts(with: "Chat ") == true {
            currentChat?.generateTitle()
            chatTitle = currentChat?.title ?? "Chat"
        }
        if let chat = currentChat {
            chats[chat.id] = chat
        }

        let chatId = currentChatId

        // Save user message and trigger analysis
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            let embedding = await generateEmbedding(for: userMsg.content)
            do {
                try await self.databaseService.saveChatMessage(userMsg, chatId: chatId, embedding: embedding)
                print("[ChatViewModel] User message saved.")

                print("[ChatViewModel] Triggering analysis for \(capturedId)...")
                await self.analysisService.generateAnalysis(for: capturedId)
                print("[ChatViewModel] Analysis triggered for \(capturedId).")
            } catch {
                print("‼️ [ChatViewModel] Error saving or analyzing user message: \(error)")
            }
        }

        // Retrieve RAG context, fetch score/priority, call LLM
        Task {
            var ragContext = ""
            let queryEmb = await generateEmbedding(for: text)
            if let emb = queryEmb {
                do {
                    let items = try await databaseService.findSimilarChatMessages(to: emb, limit: 5)
                    // Make header clearer about RAG source
                    var ctx = ["Context from Past Entries (most relevant first):"]
                    for item in items {
                        let filtered = filterPII(text: item.text)
                        // Ensure (STARRED) is prominent if present
                        let starredMarker = item.isStarred ? " **(STARRED)**" : ""
                        let meta = "(\(item.sourceType.rawValue), \(item.date.formatted(date: .numeric, time: .shortened))\(starredMarker))"
                        ctx.append("- \(meta): \(filtered)") // Add marker to metadata
                    }
                    if items.count > 0 { // Only add context if items were found
                        ragContext = ctx.joined(separator: "\n")
                    } else {
                         print("[ChatViewModel] RAG search successful, but no similar past entries found.")
                    }
                } catch {
                    print("‼️ [ChatViewModel] RAG retrieval failed: \(error)")
                }
            }

            var scoreCtx = ""
            do {
                let (_, _, p) = try databaseService.getLatestDisplayScoreAndPriority()
                scoreCtx = p
                  .map { "Current Priority: \($0)." }
                  ?? "Current Priority: Not set."
            } catch {
                print("‼️ [ChatViewModel] Error fetching score/priority: \(error)")
            }

             // --- REMOVED Fetch Previous Day Context ---
             // RAG context + prompt guidance handles historical relevance better


             let systemPrompt = SystemPrompts.chatAgentPrompt
              // Combine RAG context and Current Priority context
             let combined = [ragContext, scoreCtx].filter { !$0.isEmpty }.joined(separator: "\n---\n")

             print("[ChatViewModel] Combined Context for LLM:\n\(combined)") // Log combined context

             do {
                 let reply = try await llmService.generateChatResponse(
                    systemPrompt: systemPrompt,
                    userMessage: text, // Send original user message
                    context: combined.isEmpty ? nil : combined // Pass combined context
                )
                let assistantMsg = ChatMessage(role: .assistant, content: reply, timestamp: Date())
                self.messages.append(assistantMsg)
                self.currentChat?.messages.append(assistantMsg)
                self.currentChat?.lastUpdatedAt = assistantMsg.timestamp
                if let chat = self.currentChat {
                    self.chats[chat.id] = chat
                }
                self.isTyping = false

                // Save assistant message
                Task.detached(priority: .utility) { [weak self] in
                    guard let self = self else { return }
                    let emb = await generateEmbedding(for: assistantMsg.content)
                    do {
                        try await self.databaseService.saveChatMessage(assistantMsg, chatId: chatId, embedding: emb)
                        print("[ChatViewModel] Assistant message saved.")
                    } catch {
                        print("‼️ [ChatViewModel] Error saving assistant message: \(error)")
                    }
                }
            } catch {
                print("‼️ [ChatViewModel] LLM error: \(error)")
                let errorMsg = ChatMessage(
                    role: .assistant,
                    content: "Sorry, I encountered an error. Please try again. (\(error.localizedDescription.prefix(100))...)",
                    timestamp: Date(),
                    isStarred: true // Optionally star error messages
                )
                self.messages.append(errorMsg)
                self.isTyping = false
            }
        }
    }

    func deleteMessage(_ message: ChatMessage) {
        print("[ChatViewModel] Deleting message ID: \(message.id)")
        let idToDelete = message.id

        if let idx = self.chats.firstIndex(where: { $0.value.messages.contains(where: { $0.id == idToDelete }) }) {
            let chatId = self.chats[idx].key
            self.chats[chatId]?.messages.removeAll { $0.id == idToDelete }
            if self.currentChat?.id == chatId {
                self.currentChat = self.chats[chatId]
                self.messages.removeAll { $0.id == idToDelete }
            }
        } else if var current = self.currentChat,
                  current.messages.contains(where: { $0.id == idToDelete }) {
            current.messages.removeAll { $0.id == idToDelete }
            self.currentChat = current
            self.messages.removeAll { $0.id == idToDelete }
            let chatId = current.id
            if self.chats[chatId] != nil {
                self.chats[chatId] = current
            }
        } else {
            print("⚠️ [ChatViewModel] Could not find message \(idToDelete) to delete.")
            return
        }

        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            do {
                try await self.databaseService.deleteMessageFromDB(id: idToDelete)
                print("✅ [ChatViewModel] Deleted message \(idToDelete) from DB.")
            } catch {
                print("‼️ [ChatViewModel] Error deleting message \(idToDelete): \(error)")
            }
        }
    }

    func toggleStarMessage(_ message: ChatMessage) {
        let id = message.id
        var newStatus: Bool?
        var chatKey: UUID?

        if let idx = self.chats.firstIndex(where: { $0.value.messages.contains(where: { $0.id == id }) }) {
            let chatId = self.chats[idx].key
            if let mIdx = self.chats[chatId]?.messages.firstIndex(where: { $0.id == id }) {
                self.chats[chatId]?.messages[mIdx].isStarred.toggle()
                newStatus = self.chats[chatId]?.messages[mIdx].isStarred
                chatKey = chatId
                if self.currentChat?.id == chatId { self.currentChat = self.chats[chatId] }
                if self.currentChatId == chatId,
                   let uiIdx = self.messages.firstIndex(where: { $0.id == id }) {
                    self.messages[uiIdx].isStarred.toggle()
                }
            }
        } else if var current = self.currentChat,
                  let mIdx = current.messages.firstIndex(where: { $0.id == id }) {
            current.messages[mIdx].isStarred.toggle()
            newStatus = current.messages[mIdx].isStarred
            self.currentChat = current
            chatKey = current.id
            if let key = chatKey { self.chats[key] = current }
            if let uiIdx = self.messages.firstIndex(where: { $0.id == id }) {
                self.messages[uiIdx].isStarred.toggle()
            }
        }

        if let key = chatKey, let status = newStatus {
            let chatStarred = self.chats[key]?.messages.contains { $0.isStarred } ?? false
            if self.chats[key]?.isStarred != chatStarred {
                self.chats[key]?.isStarred = chatStarred
                if self.currentChat?.id == key { self.currentChat?.isStarred = chatStarred }
            }

            print("[ChatViewModel] Toggling star \(id) to \(status)")
            Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.databaseService.toggleMessageStarInDB(id: id, isStarred: status)
                    print("✅ [ChatViewModel] Toggled star for \(id).")
                } catch {
                    print("‼️ [ChatViewModel] Error toggling star \(id): \(error)")
                }
            }
        } else {
            print("⚠️ [ChatViewModel] Could not find message \(id) to star.")
        }
    }

    func loadChat(withId chatId: UUID) {
        guard let chat = chats[chatId] else {
            print("‼️ [ChatViewModel] Chat \(chatId) not found.")
            return
        }
        print("[ChatViewModel] Loading chat ID: \(chatId)")
        self.currentChat = chat
        self.currentChatId = chat.id
        self.messages = chat.messages
        self.chatTitle = chat.title
        self.inputText = ""
        self.isTyping = false
    }

    func refreshChatsFromDB() {
        do {
            self.chats = try databaseService.loadAllChats()
            print("[ChatViewModel] Refreshed chats. Count: \(self.chats.count)")
            if chats[self.currentChatId] == nil {
                print("[ChatViewModel] Current chat missing after refresh. Starting new.")
                startNewChat()
            }
        } catch {
            print("‼️ [ChatViewModel] Error refreshing chats: \(error)")
        }
    }

    func groupChatsByTimePeriod() -> [(String, [Chat])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        var dict: [String: [Chat]] = [:]

        for chat in chats.values {
            let d = cal.startOfDay(for: chat.lastUpdatedAt)
            let year = cal.component(.year, from: chat.lastUpdatedAt)
            let currentYear = cal.component(.year, from: today)
            let key: String
            if cal.isDate(d, inSameDayAs: today) { key = "Today" }
            else if cal.isDate(d, inSameDayAs: yesterday) { key = "Yesterday" }
            else if d >= weekStart { key = "This Week" }
            else if d >= lastWeek { key = "Last Week" }
            else if d >= monthStart { key = "This Month" }
            else if year == currentYear {
                let fmt = DateFormatter(); fmt.dateFormat = "MMMM"
                key = fmt.string(from: chat.lastUpdatedAt)
            } else {
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy"
                key = fmt.string(from: chat.lastUpdatedAt)
            }
            dict[key, default: []].append(chat)
        }

        for (k, v) in dict {
            dict[k] = v.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
        }
        let order = ["Today","Yesterday","This Week","Last Week","This Month"]
        let sorted = dict.sorted { lhs, rhs in
            if let i1 = order.firstIndex(of: lhs.key),
               let i2 = order.firstIndex(of: rhs.key) {
                return i1 < i2
            }
            // Handle nil or empty values for dates more robustly
            let lhsDate = lhs.value.first?.lastUpdatedAt ?? .distantPast
            let rhsDate = rhs.value.first?.lastUpdatedAt ?? .distantPast
            // If dates are equal (or both nil), sort alphabetically by key as a fallback
            if lhsDate == rhsDate {
                 return lhs.key < rhs.key
            }
            return lhsDate > rhsDate
        }
        return sorted
    }
}
