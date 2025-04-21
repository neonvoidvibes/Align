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

        // Enable Write-Ahead Logging (WAL) mode for better performance/concurrency
        // Use query() instead of execute() for PRAGMA as it might return a status row
        _ = try connection.query("PRAGMA journal_mode=WAL;")
        print("WAL mode enabled.")

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
        // Migrations (safe to run multiple times) - Use try, log potential errors
        do {
            _ = try connection.execute("ALTER TABLE ChatMessages ADD COLUMN processed_for_analysis INTEGER NOT NULL DEFAULT 0;")
            _ = try connection.execute("ALTER TABLE ChatMessages ADD COLUMN chatId TEXT NOT NULL DEFAULT 'default_chat';")
            _ = try connection.execute("ALTER TABLE ChatMessages ADD COLUMN isStarred INTEGER NOT NULL DEFAULT 0;")
            // Allow DROP COLUMN to fail silently if column doesn't exist
            _ = try? connection.execute("ALTER TABLE ChatMessages DROP COLUMN isUser;")
             // Allow ADD COLUMN role to fail silently if it already exists
            _ = try? connection.execute("ALTER TABLE ChatMessages ADD COLUMN role TEXT NOT NULL DEFAULT 'user';")
        } catch {
             // Log migration errors but don't crash the app unless critical
             print("⚠️ [DB Schema] Non-critical migration error (may be expected if column already exists/dropped): \(error)")
        }
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
        // Assign to _ to silence unused result warning
        _ = try connection.execute("CREATE INDEX IF NOT EXISTS chat_embedding_idx ON ChatMessages( libsql_vector_idx(embedding) );")
        print("ChatMessages vector index checked/created.")
        // Assign to _ to silence unused result warning
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
                   VALUES (?, ?, ?, ?, ?, ?, 0, vector32('\(embJSON.replacingOccurrences(of: "'", with: "''"))'));
                   """ // Added basic single-quote escaping for safety
            // Explicitly cast TimeInterval to Int64 for timestamp
            params = [.text(message.id.uuidString), .text(chatId.uuidString), .text(roleString), .text(message.content),
                      .integer(Int64(message.timestamp.timeIntervalSince1970)), .integer(message.isStarred ? 1 : 0)]
            guard params.count == 6 else { throw DatabaseError.saveDataFailed("Param count mismatch (CM/Embed)") }
            } else {
                 print("Warning: Failed to convert CM embedding to JSON. Saving without embedding.")
                 sql = "INSERT OR REPLACE INTO ChatMessages (id, chatId, role, content, timestamp, isStarred, processed_for_analysis, embedding) VALUES (?, ?, ?, ?, ?, ?, 0, NULL);"
                 // Explicitly cast TimeInterval to Int64 for timestamp
                 params = [.text(message.id.uuidString), .text(chatId.uuidString), .text(roleString), .text(message.content),
                           .integer(Int64(message.timestamp.timeIntervalSince1970)), .integer(message.isStarred ? 1 : 0)]
                  guard params.count == 6 else { throw DatabaseError.saveDataFailed("Param count mismatch (CM/NoEmbed/JSONFail)") }
            }
        } else {
            sql = "INSERT OR REPLACE INTO ChatMessages (id, chatId, role, content, timestamp, isStarred, processed_for_analysis, embedding) VALUES (?, ?, ?, ?, ?, ?, 0, NULL);"
            // Explicitly cast TimeInterval to Int64 for timestamp
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
         let sql = """
             SELECT id, chatId, role, content, timestamp, isStarred, processed_for_analysis
             FROM ChatMessages WHERE id = ? LIMIT 1;
             """
         let params: [Value] = [.text(id.uuidString)]
         let rows = try connection.query(sql, params)

         // LEARNING (Reference App): Iterate even for LIMIT 1 queries.
         // The .first property on Rows can be unreliable or ambiguous with throwing functions.
         // Iteration is the documented and safer pattern for libsql-swift.
         for row in rows {
             // Attempt extraction within the loop
             // LEARNING (Reference App): Use explicit Int32 indices for column access.
             guard
                 let idStr = try? row.getString(Int32(0)), let uuid = UUID(uuidString: idStr), // Use Int32 index
                 // Skip chatId (index 1) as it's not needed for the ChatMessage struct itself
                 let roleStr = try? row.getString(Int32(2)), // Use Int32 index
                 let content = try? row.getString(Int32(3)), // Use Int32 index
                 let timestampInt = try? row.getInt(Int32(4)), // Use Int32 index
                 let isStarredInt = try? row.getInt(Int32(5)), // Use Int32 index
                 let processedInt = try? row.getInt(Int32(6)) // Use Int32 index
             else {
                  // If decoding fails for the single row, throw error
                  // Ensure we log the specific row issue if possible, or just throw
                  print("⚠️ [DB] Decoding failed for ChatMessage ID: \(id.uuidString)")
                  throw DatabaseError.decodingFailed("Failed to decode ChatMessage \(id.uuidString)")
             }

             let role: MessageRole = (roleStr == "user") ? .user : .assistant
             let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))

             // If successful, return the message
             return ChatMessage(
                 id: uuid,
                 role: role,
                 content: content,
                 timestamp: timestamp,
                 isStarred: isStarredInt == 1,
                 processed_for_analysis: processedInt == 1
             )
         }

         // If loop did not execute (no rows found)
         return nil
     }


     // Mark a chat message as processed for analysis - Synchronous
     func markChatMessageProcessed(_ id: UUID) throws {
          let sql = "UPDATE ChatMessages SET processed_for_analysis = 1 WHERE id = ?;"
          let params: [Value] = [.text(id.uuidString)]
          let count = try self.connection.execute(sql, params) // Use count for logging
          if count == 0 {
              print("⚠️ [DB] No message found for id \(id.uuidString) to mark processed.") // Added detail
          } else {
               print("✅ [DB] Marked message processed: \(id.uuidString)")
          }
     }

    // Delete all messages for a specific Chat ID - Synchronous
    func deleteChatFromDB(id: UUID) throws {
        let sql = "DELETE FROM ChatMessages WHERE chatId = ?;"
        let params: [Value] = [.text(id.uuidString)]
        // Assign to _ to silence unused result warning
        _ = try self.connection.execute(sql, params)
        print("Attempted delete for all messages in Chat ID: \(id.uuidString)") // Keep log
    }

    // Delete a specific message by its ID - Synchronous
    func deleteMessageFromDB(id: UUID) throws {
        let sql = "DELETE FROM ChatMessages WHERE id = ?;"
        let params: [Value] = [.text(id.uuidString)]
        // Assign to _ to silence unused result warning
        _ = try self.connection.execute(sql, params)
        print("Attempted delete for ChatMessage ID: \(id.uuidString)") // Keep log
    }

    // Toggle star status for a specific message - Synchronous
    func toggleMessageStarInDB(id: UUID, isStarred: Bool) throws {
        let sql = "UPDATE ChatMessages SET isStarred = ? WHERE id = ?;"
        let params: [Value] = [.integer(isStarred ? 1 : 0), .text(id.uuidString)]
        // Assign to _ to silence unused result warning
        _ = try self.connection.execute(sql, params)
         print("Attempted toggle star (\(isStarred)) for ChatMessage ID: \(id.uuidString)") // Keep log
    }

    // Load all chats - Synchronous
     func loadAllChats() throws -> [UUID: Chat] {
         let sql = "SELECT id, chatId, role, content, timestamp, isStarred FROM ChatMessages ORDER BY chatId ASC, timestamp ASC;"
         let rows = try self.connection.query(sql)
         var messagesByChatId: [UUID: [ChatMessage]] = [:]

         // LEARNING (Reference App): Iterate over rows, don't assume other access patterns work reliably.
         for row in rows {
             // LEARNING (Reference App): Use explicit Int32 indices for column access.
             guard
                 let idStr = try? row.getString(Int32(0)), let msgId = UUID(uuidString: idStr),
                 let chatIdStr = try? row.getString(Int32(1)), let chatId = UUID(uuidString: chatIdStr),
                 let roleStr = try? row.getString(Int32(2)),
                 let content = try? row.getString(Int32(3)),
                 let tsInt = try? row.getInt(Int32(4)),
                 let starred = try? row.getInt(Int32(5))
             else {
                  print("Warning: Failed to decode ChatMessage row during loadAllChats grouping.");
                  continue // Skip problematic row
             }

             let timestamp = Date(timeIntervalSince1970: TimeInterval(tsInt))
             let message = ChatMessage(id: msgId, role: MessageRole(rawValue: roleStr) ?? .user, content: content, timestamp: timestamp, isStarred: starred == 1, processed_for_analysis: false) // Assume false when loading
             messagesByChatId[chatId, default: []].append(message)
         }

         var chats: [UUID: Chat] = [:]
         for (chatId, messages) in messagesByChatId {
             guard !messages.isEmpty else { continue }
             // SQL already ordered by timestamp, no need to sort again
             let createdAt = messages.first!.timestamp
             let lastUpdatedAt = messages.last!.timestamp
             let isChatStarred = messages.contains { $0.isStarred }
             var chat = Chat(id: chatId, messages: messages, createdAt: createdAt, lastUpdatedAt: lastUpdatedAt, isStarred: isChatStarred)
             // Regenerate title (consistent with ChatViewModel logic)
             if let firstUserMsg = messages.first(where: { $0.role == .user }) {
                  chat.title = String(firstUserMsg.content.prefix(30)) + (firstUserMsg.content.count > 30 ? "..." : "")
             } else {
                  chat.title = "Chat \(chatId.uuidString.prefix(4))..."
             }
             chats[chatId] = chat
         }
         print("Loaded and reconstructed \(chats.count) chats from DB messages.")
         return chats
     }

     // Find similar chat messages (used for RAG) - Keep async
     func findSimilarChatMessages(to queryVector: [Float], limit: Int = 5) async throws -> [ContextItem] {
         guard !queryVector.isEmpty else { return [] }
         guard queryVector.count == self.embeddingDimension else { throw DatabaseError.dimensionMismatch(expected: self.embeddingDimension, actual: queryVector.count) }
         guard let json = embeddingToJson(queryVector) else { throw DatabaseError.embeddingGenerationFailed("Embedding JSON failed") }

         // LEARNING (Reference App): Correct parameter usage for vector_top_k and vector_distance_cos
         let sql = """
             SELECT M.id, M.chatId, M.role, M.content, M.timestamp, M.isStarred
             FROM ChatMessages AS M
             JOIN vector_top_k('chat_embedding_idx', vector32(?), ?) AS V
               ON M.rowid = V.id
             WHERE M.embedding IS NOT NULL
             ORDER BY vector_distance_cos(M.embedding, vector32(?)) ASC;
             -- Removed LIMIT ? here, handled by vector_top_k
             """
         // Parameters for vector_top_k: index name (string - handled in SQL), query vector (text), K (integer)
         // Parameter for vector_distance_cos: query vector (text)
         let params: [Value] = [
             .text(json),         // For vector_top_k query_vector
             .integer(Int64(limit)), // For vector_top_k K
             .text(json)          // For vector_distance_cos query_vector
         ]
         print("[DB Search] Executing ChatMessages search for RAG...")
         let rows = try self.connection.query(sql, params)
         var items: [ContextItem] = []

         // LEARNING (Reference App): Iterate over rows, don't assume other access patterns work reliably.
         for row in rows {
               // LEARNING (Reference App): Use explicit Int32 indices for column access.
               guard let idStr = try? row.getString(Int32(0)), let id = UUID(uuidString: idStr),
                     let chatIdStr = try? row.getString(Int32(1)), let chatId = UUID(uuidString: chatIdStr),
                     let roleStr = try? row.getString(Int32(2)),
                     let content = try? row.getString(Int32(3)),
                     let timestampInt = try? row.getInt(Int32(4)),
                     let isStarredInt = try? row.getInt(Int32(5))
               else { print("Warning: Failed decode ChatMessage row for RAG."); continue }
               let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))
               // Use role enum directly for prefix for consistency
               let prefix = (MessageRole(rawValue: roleStr) == .user) ? "User" : "AI"

             let contextItem = ContextItem(
                 id: id,
                 text: "\(prefix): \(content)", // Include prefix
                 sourceType: .chatMessage,
                 date: timestamp,
                 isStarred: isStarredInt == 1,
                 relatedChatId: chatId
             )
             items.append(contextItem)
         }
         print("[DB Search] ChatMessages RAG search successful. Found \(items.count) context items.")
         return items
     }


     // MARK: - Raw Value Operations (for Analysis)

     // Save raw values - Synchronous
    func saveRawValues(values: [String: Double], for date: Date) throws {
        let dateInt = dateToInt(date)
        print("[DB-RawValues] Saving \(values.count) values for date \(dateInt)...") // Keep log
        let sql = "INSERT OR REPLACE INTO RawValues (date, category, value) VALUES (?, ?, ?);"
        for (cat, val) in values {
            let params: [Value] = [.integer(Int64(dateInt)), .text(cat), .real(val)]
            // Assign to _ to silence unused result warning
            _ = try connection.execute(sql, params)
        }
         print("✅ [DB-RawValues] Saved values for date \(dateInt).") // Keep log
    }

     // Fetch raw values for a specific date - Synchronous
     func fetchRawValues(for date: Date) throws -> [String: Double] {
         let dateInt = dateToInt(date)
         let sql = "SELECT category, value FROM RawValues WHERE date = ?;"
         let params: [Value] = [.integer(Int64(dateInt))]
         let rows = try connection.query(sql, params)
         var dict: [String: Double] = [:]

         // LEARNING (Reference App): Iterate over rows.
         for row in rows {
              // LEARNING (Reference App): Use explicit Int32 indices for column access.
             if let cat = try? row.getString(Int32(0)), let val = try? row.getDouble(Int32(1)) {
                 dict[cat] = val
             } else {
                  print("⚠️ [DB-RawValues] Failed to decode row for date \(dateInt).")
             }
         }
         print("[DB-RawValues] Fetched \(dict.count) values for date \(dateInt).") // Keep log
         return dict
     }

     // Fetch raw values for a range of dates - Synchronous
     func fetchRawValues(forDates dates: [Date]) throws -> [Date: [String: Double]] {
         guard !dates.isEmpty else { return [:] }
         let dateInts = dates.map { dateToInt($0) }
         let placeholders = dateInts.map { _ in "?" }.joined(separator: ",")
         let sql = "SELECT date, category, value FROM RawValues WHERE date IN (\(placeholders)) ORDER BY date DESC;" // Keep ORDER BY
         let params: [Value] = dateInts.map { .integer(Int64($0)) }
         print("[DB-RawValues] Fetching values for dates: \(dateInts)...") // Keep log
         let rows = try connection.query(sql, params)
         var dict: [Date: [String: Double]] = [:]

         // LEARNING (Reference App): Iterate over rows.
         for row in rows {
             // LEARNING (Reference App): Use explicit Int32 indices for column access.
             if let d = try? row.getInt(Int32(0)),
                let cat = try? row.getString(Int32(1)),
                let val = try? row.getDouble(Int32(2)),
                let date = intToDate(Int(d)) {
                 dict[date, default: [:]][cat] = val
             } else {
                  print("⚠️ [DB-RawValues] Failed to decode row in multi-date fetch.")
             }
         }
          print("[DB-RawValues] Fetched values for \(dict.count) dates.") // Keep log
         return dict
     }

    // Fetch the latest raw values and the date they correspond to - Synchronous
    func fetchLatestRawValuesAndDate() throws -> (date: Date, values: [String: Double])? {
        let sql = "SELECT MAX(date) FROM RawValues;"
        let dateRows = try connection.query(sql)

        var latestDateInt64: Int64? = nil

        // LEARNING (Reference App): Iterate even for aggregate/LIMIT 1 queries.
        for row in dateRows {
            // Try to get the Int64 value, explicitly casting result to Int64 within try?
            // This explicit cast was the key fix for the persistent compiler error.
            if let maxVal = try? Int64(row.getInt(Int32(0))) {
                latestDateInt64 = maxVal
            } else {
                // MAX(date) returned NULL or getInt failed
                print("[DB-RawValues] MAX(date) query returned NULL or failed to extract Int64.")
            }
            break // Since MAX() returns at most one row, break after processing it
        }

        // Check if we successfully extracted a non-null date
        guard let unwrappedLatestDateInt64 = latestDateInt64 else {
            print("[DB-RawValues] No latest date found (query returned no rows or NULL value).")
            return nil
        }
        // If guard passes, unwrappedLatestDateInt64 is a non-optional Int64

        // Convert Int64 -> Int for Date helper
        let latestDateInt = Int(unwrappedLatestDateInt64)

        // Convert the integer date back to a Date object
        guard let date = intToDate(latestDateInt) else {
             print("⚠️ [DB-RawValues] Could not parse dateInt \(latestDateInt).")
            return nil
        }

        // Fetch values for the found date
        let valsSql = "SELECT category, value FROM RawValues WHERE date = ?;"
        // Pass the unwrapped Int64 directly - matching reference app pattern
        let params: [Value] = [.integer(unwrappedLatestDateInt64)]
        let valRows = try connection.query(valsSql, params)
        var dict: [String: Double] = [:]

        // LEARNING (Reference App): Iterate over rows.
        for vr in valRows {
            // LEARNING (Reference App): Use explicit Int32 indices for column access.
            if let cat = try? vr.getString(Int32(0)), let v = try? vr.getDouble(Int32(1)) {
                dict[cat] = v
            } else {
                print("⚠️ [DB-RawValues] Failed to decode category/value row for date \(latestDateInt).")
            }
        }

         // Check if results are empty (could happen if values were deleted for the max date)
        if dict.isEmpty && latestDateInt != 0 {
            print("⚠️ [DB-RawValues] Found latest date \(latestDateInt) but no values associated?")
            // Return nil as the state is inconsistent
            return nil
        }

        // Log via DateFormatter
        let formatter = DateFormatter()
        formatter.dateStyle = .short // Use .short as requested
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: date)
        print("[DB-RawValues] Fetched \(dict.count) values for date \(dateStr).")

        return (date, dict)
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
         // Assign to _ to silence unused result warning
         _ = try connection.execute(sql, params)
         print("✅ [DB-Scores] Saved scores for date \(dateInt).") // Keep original log format
     }

     // Save daily priority node - Synchronous
     func savePriorityNode(date: Date, node: String) throws {
         let dateInt = dateToInt(date)
         let sql = "INSERT OR REPLACE INTO PriorityNodes (date, node) VALUES (?, ?);"
         let params: [Value] = [.integer(Int64(dateInt)), .text(node)]
         // Assign to _ to silence unused result warning
         _ = try connection.execute(sql, params)
         print("✅ [DB-Priority] Saved priority node '\(node)' for date \(dateInt).") // Keep original log format
     }

     // Fetch the latest display score and priority node - Synchronous
     func getLatestDisplayScoreAndPriority() throws -> (displayScore: Int?, priorityNode: String?) {
         let scoresSql = "SELECT display_score FROM Scores ORDER BY date DESC LIMIT 1;"
         let prioritySql = "SELECT node FROM PriorityNodes ORDER BY date DESC LIMIT 1;"

         let scoreRows = try connection.query(scoresSql)
         let priorityRows = try connection.query(prioritySql)

         var displayScore: Int? = nil
         var priorityNode: String? = nil

         // Iterate for score (max 1 row due to LIMIT 1)
         // LEARNING (Reference App): Iterate even for LIMIT 1 queries.
         for row in scoreRows {
             // LEARNING (Reference App): Use explicit Int32 index.
             if let scoreInt64 = try? row.getInt(Int32(0)) {
                 displayScore = Int(scoreInt64)
             }
             break // Exit loop after processing the first (only) row
         }

         // Iterate for priority (max 1 row due to LIMIT 1)
         // LEARNING (Reference App): Iterate even for LIMIT 1 queries.
         for row in priorityRows {
             // LEARNING (Reference App): Use explicit Int32 index.
             priorityNode = try? row.getString(Int32(0))
             break // Exit loop after processing the first (only) row
         }

         // Log the fetched values (or defaults)
         print("[DB-Read] Fetched latest - Score: \(displayScore ?? -1), Priority: \(priorityNode ?? "N/A")")

         return (displayScore, priorityNode)
     }


    // MARK: - Helper Functions

    private func dateToInt(_ date: Date) -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return Int(fmt.string(from: date)) ?? 0
    }

    private func intToDate(_ intDate: Int) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return fmt.date(from: String(intDate))
    }
}