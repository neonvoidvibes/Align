import Foundation
import Libsql // Import the SDK
import SwiftUI // Needed for ObservableObject
import NaturalLanguage // Needed for embedding helpers

// --- Custom Error Enum ---
enum DatabaseError: Error {
    case initializationFailed(String)
    case schemaSetupFailed(String)
    case indexCreationFailed(String)
    case embeddingGenerationFailed(String)
    case saveDataFailed(String)
    case queryFailed(String)
    case decodingFailed(String)
    case dimensionMismatch(expected: Int, actual: Int)
    case deleteFailed(String)
    case noResultsFound
    case insightNotFound(String) // Specific error for insights (though not used in Align)
    case insightDecodingError(String) // Specific error for insights (though not used in Align)
}

// --- Service Class Definition ---
@MainActor
class DatabaseService: ObservableObject {
    // MARK: - Properties
    private let db: Database
    private let connection: Connection
    private let dbFileName = "AlignUserData_v1.sqlite"
    private let embeddingDimension = 512

    // MARK: - Initialization (Synchronous)
    init() throws {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = docsURL.appendingPathComponent(self.dbFileName).path
        print("Database path: \(dbPath)")

        // Initialize directly, handle potential errors via throws in init signature
        if !FileManager.default.fileExists(atPath: dbPath) {
            print("Database file does not exist at \(dbPath). Will create a new one.")
        }
        // Use initializer without 'path:' label
        self.db = try Database(dbPath)
        print("Database object created/opened.")
        // Use synchronous connect for local DB
        self.connection = try db.connect()
        print("Database connection established.")

        // Run schema setup synchronously using the established connection
        try setupSchemaAndIndexes() // This can throw
        print("Schema and index setup sequence completed successfully.")
    }

    // MARK: - Schema and Index Setup (Synchronous Helper)
    private func setupSchemaAndIndexes() throws {
        print("Setting up database schema and indexes...")
        // ChatMessages Table
        _ = try connection.execute(
            """
            CREATE TABLE IF NOT EXISTS ChatMessages (
                id TEXT PRIMARY KEY, chatId TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL,
                timestamp INTEGER NOT NULL, isStarred INTEGER NOT NULL DEFAULT 0,
                processed_for_analysis INTEGER NOT NULL DEFAULT 0,
                embedding FLOAT32(\(self.embeddingDimension))
            );
            """
        )
        // Migrations (safe to run multiple times)
        _ = try? connection.execute("ALTER TABLE ChatMessages ADD COLUMN processed_for_analysis INTEGER NOT NULL DEFAULT 0;")
        _ = try? connection.execute("ALTER TABLE ChatMessages ADD COLUMN chatId TEXT NOT NULL DEFAULT 'default_chat';")
        _ = try? connection.execute("ALTER TABLE ChatMessages ADD COLUMN isStarred INTEGER NOT NULL DEFAULT 0;")
        _ = try? connection.execute("ALTER TABLE ChatMessages DROP COLUMN isUser;") // Ignore error if column doesn't exist
        _ = try? connection.execute("ALTER TABLE ChatMessages ADD COLUMN role TEXT NOT NULL DEFAULT 'user';") // Ignore error if column exists
        print("ChatMessages table checked/updated for Align.")

         // Raw Values Table
         _ = try connection.execute(
             """
             CREATE TABLE IF NOT EXISTS RawValues (
                 date INTEGER NOT NULL, category TEXT NOT NULL, value REAL NOT NULL,
                 PRIMARY KEY (date, category)
             );
             """
         )
         print("RawValues table checked/created.")

         // Scores Table
         _ = try connection.execute(
             """
             CREATE TABLE IF NOT EXISTS Scores (
                 date INTEGER PRIMARY KEY NOT NULL, display_score INTEGER NOT NULL,
                 energy_score REAL NOT NULL, finance_score REAL NOT NULL, home_score REAL NOT NULL
             );
             """
         )
         print("Scores table checked/created.")

         // Priority Nodes Table
         _ = try connection.execute(
              """
              CREATE TABLE IF NOT EXISTS PriorityNodes (
                  date INTEGER PRIMARY KEY NOT NULL, node TEXT NOT NULL
              );
              """
         )
         print("PriorityNodes table checked/created.")

        // Indexes
        _ = try connection.execute("CREATE INDEX IF NOT EXISTS chat_embedding_idx ON ChatMessages( libsql_vector_idx(embedding) );")
        print("ChatMessages vector index checked/created.")
        _ = try connection.execute("CREATE INDEX IF NOT EXISTS raw_values_date_idx ON RawValues (date);")
        print("RawValues date index checked/created.")
    }

    // MARK: - Chat Message Operations

    // Save ChatMessage - Synchronous (triggers async analysis externally)
    // Needs to be called from a background thread by the caller (e.g., ChatViewModel)
    func saveChatMessage(_ message: ChatMessage, chatId: UUID, embedding: [Float]?) throws {
        let sql: String
        let params: [Value]
        let roleString = message.role.rawValue

        if let validEmbedding = embedding, validEmbedding.count == self.embeddingDimension {
            if let embJSON = embeddingToJson(validEmbedding) {
               sql = """
                   INSERT OR REPLACE INTO ChatMessages (id, chatId, role, content, timestamp, isStarred, processed_for_analysis, embedding)
                   VALUES (?, ?, ?, ?, ?, ?, 0, vector32('\(embJSON)'));
                   """
                params = [.text(message.id.uuidString), .text(chatId.uuidString), .text(roleString), .text(message.content),
                          .integer(Int64(message.timestamp.timeIntervalSince1970)), .integer(message.isStarred ? 1 : 0)]
                guard params.count == 6 else { throw DatabaseError.saveDataFailed("Param count mismatch (CM/Embed)") }
            } else {
                 print("Warning: Failed to convert CM embedding to JSON. Saving without embedding.")
                 sql = "INSERT OR REPLACE INTO ChatMessages (id, chatId, role, content, timestamp, isStarred, processed_for_analysis, embedding) VALUES (?, ?, ?, ?, ?, ?, 0, NULL);"
                 params = [.text(message.id.uuidString), .text(chatId.uuidString), .text(roleString), .text(message.content),
                           .integer(Int64(message.timestamp.timeIntervalSince1970)), .integer(message.isStarred ? 1 : 0)]
                  guard params.count == 6 else { throw DatabaseError.saveDataFailed("Param count mismatch (CM/NoEmbed/JSONFail)") }
            }
        } else {
            sql = "INSERT OR REPLACE INTO ChatMessages (id, chatId, role, content, timestamp, isStarred, processed_for_analysis, embedding) VALUES (?, ?, ?, ?, ?, ?, 0, NULL);"
            params = [.text(message.id.uuidString), .text(chatId.uuidString), .text(roleString), .text(message.content),
                      .integer(Int64(message.timestamp.timeIntervalSince1970)), .integer(message.isStarred ? 1 : 0)]
            guard params.count == 6 else { throw DatabaseError.saveDataFailed("Param count mismatch (CM/NoEmbed)") }
         }
        // Execute synchronously
        _ = try self.connection.execute(sql, params)
        print("✅ [DB] Saved message \(message.id)")
        // *** Analysis trigger moved to ChatViewModel ***
     }

      // Fetch a single chat message by ID - Synchronous
     func fetchChatMessage(withId id: UUID) throws -> ChatMessage? {
         let sql = "SELECT id, chatId, role, content, timestamp, isStarred, processed_for_analysis FROM ChatMessages WHERE id = ? LIMIT 1;"
         let params: [Value] = [.text(id.uuidString)]
         let rows = try self.connection.query(sql, params)
         guard let row = rows.first(where: { _ in true }) else { return nil }
         guard let idStr = try? row.getString(0), let id = UUID(uuidString: idStr),
               let _ = try? row.getString(1), // chatId
               let roleStr = try? row.getString(2),
               let content = try? row.getString(3),
               let timestampInt = try? row.getInt(4),
               let isStarredInt = try? row.getInt(5),
               let processedInt = try? row.getInt(6)
         else {
             print("Warning: Failed decode ChatMessage row during fetch for ID \(id.uuidString).")
             throw DatabaseError.decodingFailed("Failed to decode chat message \(id.uuidString)")
         }
         let role: MessageRole = (roleStr == "user") ? .user : .assistant
         let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))
         return ChatMessage(id: id, role: role, content: content, timestamp: timestamp, isStarred: isStarredInt == 1, processed_for_analysis: processedInt == 1)
     }

     // Mark a chat message as processed for analysis - Synchronous
     func markChatMessageProcessed(_ id: UUID) throws {
          let sql = "UPDATE ChatMessages SET processed_for_analysis = 1 WHERE id = ?;"
          let params: [Value] = [.text(id.uuidString)]
          let affectedRows = try self.connection.execute(sql, params)
          if affectedRows == 0 { print("⚠️ [DB] Attempted to mark message processed, but ID not found: \(id.uuidString)") }
          else { print("✅ [DB] Marked message processed: \(id.uuidString)") }
     }

    // Delete all messages for a specific Chat ID - Synchronous
    func deleteChatFromDB(id: UUID) throws {
        let sql = "DELETE FROM ChatMessages WHERE chatId = ?;"
        let params: [Value] = [.text(id.uuidString)]
        _ = try self.connection.execute(sql, params)
        print("Attempted delete for all messages in Chat ID: \(id.uuidString)")
    }

    // Delete a specific message by its ID - Synchronous
    func deleteMessageFromDB(id: UUID) throws {
        let sql = "DELETE FROM ChatMessages WHERE id = ?;"
        let params: [Value] = [.text(id.uuidString)]
        _ = try self.connection.execute(sql, params)
        print("Attempted delete for ChatMessage ID: \(id.uuidString)")
    }

    // Toggle star status for a specific message - Synchronous
    func toggleMessageStarInDB(id: UUID, isStarred: Bool) throws {
        let sql = "UPDATE ChatMessages SET isStarred = ? WHERE id = ?;"
        let params: [Value] = [.integer(isStarred ? 1 : 0), .text(id.uuidString)]
        _ = try self.connection.execute(sql, params)
        print("Attempted toggle star (\(isStarred)) for ChatMessage ID: \(id.uuidString)")
    }

    // Load all chats - Synchronous
     func loadAllChats() throws -> [UUID: Chat] {
         let sql = "SELECT id, chatId, role, content, timestamp, isStarred FROM ChatMessages ORDER BY chatId ASC, timestamp ASC;"
         let rows = try self.connection.query(sql)
         var messagesByChatId: [UUID: [ChatMessage]] = [:]
        for row in rows {
            guard let idStr = try? row.getString(0), let id = UUID(uuidString: idStr),
                  let chatIdStr = try? row.getString(1), let chatId = UUID(uuidString: chatIdStr),
                  let roleStr = try? row.getString(2), let content = try? row.getString(3),
                  let timestampInt = try? row.getInt(4), let isStarredInt = try? row.getInt(5)
            else { print("Warning: Failed to decode ChatMessage row during loadAllChats grouping."); continue }
            let role: MessageRole = (roleStr == "user") ? .user : .assistant
            let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))
            let message = ChatMessage(id: id, role: role, content: content, timestamp: timestamp, isStarred: isStarredInt == 1, processed_for_analysis: false)
            messagesByChatId[chatId, default: []].append(message)
        }
        var chats: [UUID: Chat] = [:]
        for (chatId, messages) in messagesByChatId {
            guard !messages.isEmpty else { continue }
            let sortedMessages = messages
            let createdAt = sortedMessages.first!.timestamp
            let lastUpdatedAt = sortedMessages.last!.timestamp
            let isChatStarred = sortedMessages.contains { $0.isStarred }
            var chat = Chat(id: chatId, messages: sortedMessages, createdAt: createdAt, lastUpdatedAt: lastUpdatedAt, isStarred: isChatStarred)
            if let firstUserMsg = sortedMessages.first(where: { $0.role == .user }) {
                chat.title = String(firstUserMsg.content.prefix(30)) + (firstUserMsg.content.count > 30 ? "..." : "")
            } else { chat.title = "Chat \(chatId.uuidString.prefix(4))..." }
            chats[chatId] = chat
        }
        print("Loaded and reconstructed \(chats.count) chats from DB messages.")
        return chats
    }

     // Find similar chat messages (used for RAG) - Keep async
     func findSimilarChatMessages(to queryVector: [Float], limit: Int = 5) async throws -> [ContextItem] {
         guard !queryVector.isEmpty else { return [] }
         guard queryVector.count == self.embeddingDimension else { throw DatabaseError.dimensionMismatch(expected: self.embeddingDimension, actual: queryVector.count) }
         guard let queryJSON = embeddingToJson(queryVector) else { throw DatabaseError.embeddingGenerationFailed("Failed to convert query vector to JSON.") }
         let sql = """
             SELECT M.id, M.chatId, M.role, M.content, M.timestamp, M.isStarred,
                    vector_distance_cos(M.embedding, vector32(?)) AS distance
             FROM ChatMessages AS M JOIN vector_top_k('chat_embedding_idx', vector32(?), ?) AS V ON M.rowid = V.id
             WHERE M.embedding IS NOT NULL ORDER BY distance ASC;
             """
         let params: [Value] = [.text(queryJSON), .text(queryJSON), .integer(Int64(limit))]
         print("[DB Search] Executing ChatMessages search for RAG...")
          // Use synchronous query, but keep function async for caller convenience
          let rows = try self.connection.query(sql, params)
          var results: [ContextItem] = []
          for row in rows {
              guard let idStr = try? row.getString(0), let id = UUID(uuidString: idStr),
                    let chatIdStr = try? row.getString(1), let chatId = UUID(uuidString: chatIdStr),
                    let roleStr = try? row.getString(2),
                    let content = try? row.getString(3),
                    let timestampInt = try? row.getInt(4),
                    let isStarredInt = try? row.getInt(5)
              else { print("Warning: Failed decode ChatMessage row for RAG."); continue }
              let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))
              let prefix = (roleStr == "user") ? "User" : "AI"
              let contextItem = ContextItem(id: id, text: "\(prefix): \(content)", sourceType: .chatMessage, date: timestamp, isStarred: isStarredInt == 1, relatedChatId: chatId)
              results.append(contextItem)
          }
          print("[DB Search] ChatMessages RAG search successful. Found \(results.count) context items.")
          return results
    }


     // MARK: - Raw Value Operations (for Analysis)

     // Save raw values - Synchronous
    func saveRawValues(values: [String: Double], for date: Date) throws {
        let dateInt = dateToInt(date)
        print("[DB-RawValues] Saving \(values.count) values for date \(dateInt)...")
        let sql = "INSERT OR REPLACE INTO RawValues (date, category, value) VALUES (?, ?, ?);"
        for (category, value) in values {
            let params: [Value] = [
                .integer(Int64(dateInt)),
                .text(category),
                .real(value)
            ]
            _ = try connection.execute(sql, params)
        }
        print("✅ [DB-RawValues] Saved values for date \(dateInt).")
    }

     // Fetch raw values for a specific date - Synchronous
     func fetchRawValues(for date: Date) throws -> [String: Double] {
         let dateInt = dateToInt(date)
         let sql = "SELECT category, value FROM RawValues WHERE date = ?;"
         let params: [Value] = [.integer(Int64(dateInt))]
         let rows = try connection.query(sql, params)
         var results: [String: Double] = [:]
         for row in rows {
             guard let category = try? row.getString(0), let value = try? row.getDouble(1) else {
                 print("⚠️ [DB-RawValues] Failed to decode row for date \(dateInt).")
                 continue
             }
             results[category] = value
         }
         print("[DB-RawValues] Fetched \(results.count) values for date \(dateInt).")
         return results
     }

     // Fetch raw values for a range of dates - Synchronous
     func fetchRawValues(forDates dates: [Date]) throws -> [Date: [String: Double]] {
         guard !dates.isEmpty else { return [:] }
         let dateInts = dates.map { dateToInt($0) }
         let placeholders = Array(repeating: "?", count: dateInts.count).joined(separator: ",")
         let sql = "SELECT date, category, value FROM RawValues WHERE date IN (\(placeholders)) ORDER BY date DESC;"
         let params: [Value] = dateInts.map { .integer(Int64($0)) }
         print("[DB-RawValues] Fetching values for dates: \(dateInts)...")
         let rows = try connection.query(sql, params)
         var results: [Date: [String: Double]] = [:]
         for row in rows {
             guard let dateInt = try? row.getInt(0),
                   let category = try? row.getString(1),
                   let value = try? row.getDouble(2) else {
                  print("⚠️ [DB-RawValues] Failed to decode row in multi-date fetch.")
                 continue
             }
             if let originalDate = dates.first(where: { dateToInt($0) == dateInt }) {
                 results[originalDate, default: [:]][category] = value
             }
         }
          print("[DB-RawValues] Fetched values for \(results.count) dates.")
         return results
     }


     // MARK: - Score & Priority Operations (for Analysis)

     // Save daily scores - Synchronous
     func saveScores(date: Date, displayScore: Int, energyScore: Double, financeScore: Double, homeScore: Double) throws {
         let dateInt = dateToInt(date)
         let sql = """
         INSERT OR REPLACE INTO Scores (date, display_score, energy_score, finance_score, home_score)
         VALUES (?, ?, ?, ?, ?);
         """
         let params: [Value] = [.integer(Int64(dateInt)), .integer(Int64(displayScore)), .real(energyScore), .real(financeScore), .real(homeScore)]
         _ = try connection.execute(sql, params)
         print("✅ [DB-Scores] Saved scores for date \(dateInt).")
     }

     // Save daily priority node - Synchronous
     func savePriorityNode(date: Date, node: String) throws {
         let dateInt = dateToInt(date)
         let sql = "INSERT OR REPLACE INTO PriorityNodes (date, node) VALUES (?, ?);"
         let params: [Value] = [.integer(Int64(dateInt)), .text(node)]
         _ = try connection.execute(sql, params)
         print("✅ [DB-Priority] Saved priority node '\(node)' for date \(dateInt).")
     }

     // Fetch the latest display score and priority node - Synchronous
     func getLatestDisplayScoreAndPriority() throws -> (displayScore: Int?, priorityNode: String?) {
         let scoresSql = "SELECT display_score FROM Scores ORDER BY date DESC LIMIT 1;"
         let prioritySql = "SELECT node FROM PriorityNodes ORDER BY date DESC LIMIT 1;"

         let scoreRows = try connection.query(scoresSql)
         let priorityRows = try connection.query(prioritySql)

         let scoreRow = scoreRows.first(where: { _ in true })
         let priorityRow = priorityRows.first(where: { _ in true })

         // Correct optional mapping using flatMap and try?
         let displayScore: Int? = scoreRow.flatMap { row -> Int? in
             guard let int64Value = try? row.getInt(0) else { return nil }
             return Int(int64Value) // Convert Int64 to Int
         }
         let priorityNode: String? = priorityRow.flatMap { row -> String? in
             try? row.getString(0) // Safely try to get String?
         }

         print("[DB-Read] Fetched latest - Score: \(displayScore ?? -1), Priority: \(priorityNode ?? "N/A")")
         return (displayScore, priorityNode)
     }

      // Helper to convert Date to YYYYMMDD Int
      private func dateToInt(_ date: Date) -> Int {
          let formatter = DateFormatter()
          formatter.dateFormat = "yyyyMMdd"
          formatter.locale = Locale(identifier: "en_US_POSIX")
          formatter.timeZone = TimeZone(secondsFromGMT: 0)
          return Int(formatter.string(from: date)) ?? 0
      }

      // Helper to convert YYYYMMDD Int back to Date
      private func intToDate(_ intDate: Int) -> Date? {
           let formatter = DateFormatter()
           formatter.dateFormat = "yyyyMMdd"
           formatter.locale = Locale(identifier: "en_US_POSIX")
           formatter.timeZone = TimeZone(secondsFromGMT: 0)
           return formatter.date(from: String(intDate))
      }

}
