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
    case insightNotFound(String) // Specific error for insights
    case insightDecodingError(String)
}

// --- Service Class Definition ---
@MainActor // Ensure DB operations that publish changes are on main thread if needed
class DatabaseService: ObservableObject {
    // MARK: - Properties
    private let db: Database // Libsql Database object
    private let connection: Connection // Active connection to the database
    private let dbFileName = "AlignUserData_v1.sqlite" // Database file name (versioned for Align)
    private let embeddingDimension = 512 // ** Confirmed Embedding Dimension **

    // MARK: - Initialization
    init() {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = docsURL.appendingPathComponent(self.dbFileName).path
        print("Database path: \(dbPath)")

        let tempDb: Database
        let tempConnection: Connection

        do {
            // Check if DB file exists, log if creating new
            if !FileManager.default.fileExists(atPath: dbPath) {
                print("Database file does not exist at \(dbPath). Will create a new one.")
            }

            tempDb = try Database(dbPath)
            print("Database object created/opened.")
            tempConnection = try tempDb.connect()
            print("Database connection established.")

            self.db = tempDb
            self.connection = tempConnection

            // Run schema setup synchronously in init
            try setupSchemaAndIndexes() // Call synchronous version directly
            print("Schema and index setup sequence completed successfully.")

        } catch {
            print("‼️ ERROR during DatabaseService initialization: \(error)")
            // Consider throwing the error or having a fallback mechanism
             // For now, fatalError is used as DB is critical
            fatalError("Failed to initialize DatabaseService: \(error.localizedDescription)")
        }
    } // End of init()

    // MARK: - Schema and Index Setup (Private Helper)
    // Now synchronous
    private func setupSchemaAndIndexes() throws {
        print("Setting up database schema and indexes...")
        do {
            // ChatMessages Table (Align uses ChatMessage model)
            _ = try self.connection.execute( // Use synchronous execute
                """
                CREATE TABLE IF NOT EXISTS ChatMessages (
                    id TEXT PRIMARY KEY,
                    chatId TEXT NOT NULL, -- Added chatId column
                    role TEXT NOT NULL,   -- Use role (user/assistant) instead of isUser
                    content TEXT NOT NULL,
                    timestamp INTEGER NOT NULL,
                    isStarred INTEGER NOT NULL DEFAULT 0,
                    embedding FLOAT32(\(self.embeddingDimension))
                );
                """
            )
             // Attempt to add chatId column if it doesn't exist (migration)
            _ = try? self.connection.execute("ALTER TABLE ChatMessages ADD COLUMN chatId TEXT NOT NULL DEFAULT 'default_chat';") // Use synchronous execute
            _ = try? self.connection.execute("ALTER TABLE ChatMessages ADD COLUMN isStarred INTEGER NOT NULL DEFAULT 0;") // Use synchronous execute
             // Attempt to drop old 'isUser' column if migrating
            _ = try? self.connection.execute("ALTER TABLE ChatMessages DROP COLUMN isUser;") // Use synchronous execute
             // Attempt to add new 'role' column if migrating
            _ = try? self.connection.execute("ALTER TABLE ChatMessages ADD COLUMN role TEXT NOT NULL DEFAULT 'user';") // Use synchronous execute

            print("ChatMessages table checked/updated for Align.")

            // Journal Entries (If Align introduces journaling later) - Placeholder
            /*
            _ = try self.connection.execute( // Use synchronous execute
                """
                CREATE TABLE IF NOT EXISTS JournalEntries (
                    id TEXT PRIMARY KEY, text TEXT NOT NULL, mood TEXT NOT NULL,
                    date INTEGER NOT NULL, intensity INTEGER NOT NULL,
                    isStarred INTEGER NOT NULL DEFAULT 0, -- Added isStarred column
                    embedding FLOAT32(\(self.embeddingDimension))
                );
                """
            )
            _ = try? self.connection.execute("ALTER TABLE JournalEntries ADD COLUMN isStarred INTEGER NOT NULL DEFAULT 0;") // Use synchronous execute
            print("JournalEntries table checked/updated.")
            */

            // Chat Message Vector Index
            _ = try self.connection.execute( // Use synchronous execute
                """
                CREATE INDEX IF NOT EXISTS chat_embedding_idx
                ON ChatMessages( libsql_vector_idx(embedding) );
                """
            )
            print("ChatMessages vector index checked/created.")

            // Journal Entry Index (Placeholder)
            /*
            _ = try self.connection.execute( // Use synchronous execute
                """
                CREATE INDEX IF NOT EXISTS journal_embedding_idx
                ON JournalEntries( libsql_vector_idx(embedding) );
                """
            )
            print("JournalEntries vector index checked/created.")
            */

        } catch {
            print("Error during schema/index setup: \(error)")
            throw DatabaseError.schemaSetupFailed(error.localizedDescription)
        }
    }

    // MARK: - Chat Message Operations

    // Save ChatMessage (Align version)
    func saveChatMessage(_ message: ChatMessage, chatId: UUID, embedding: [Float]?) async throws {
        let sql: String
        let params: [Value]

        let roleString: String
        switch message.role {
        case .user: roleString = "user"
        case .assistant: roleString = "assistant"
        }

         if let validEmbedding = embedding, validEmbedding.count == self.embeddingDimension {
            guard let embJSON = embeddingToJson(validEmbedding) else {
                 print("Warning: Failed to convert CM embedding to JSON. Saving without embedding.")
                 sql = "INSERT OR REPLACE INTO ChatMessages (id, chatId, role, content, timestamp, isStarred, embedding) VALUES (?, ?, ?, ?, ?, ?, NULL);"
                 params = [.text(message.id.uuidString), .text(chatId.uuidString), .text(roleString), .text(message.content),
                           .integer(Int64(message.timestamp.timeIntervalSince1970)), .integer(message.isStarred ? 1 : 0)]
                  guard params.count == 6 else { throw DatabaseError.saveDataFailed("Param count mismatch (CM/NoEmbed/JSONFail)") }
                 _ = try self.connection.execute(sql, params) // Use synchronous execute
                 return
             }
             // Use sql string interpolation for vector function as parameter binding doesn't work directly
            sql = """
                INSERT OR REPLACE INTO ChatMessages (id, chatId, role, content, timestamp, isStarred, embedding)
                VALUES (?, ?, ?, ?, ?, ?, vector32('\(embJSON)'));
                """
            params = [.text(message.id.uuidString), .text(chatId.uuidString), .text(roleString), .text(message.content),
                      .integer(Int64(message.timestamp.timeIntervalSince1970)), .integer(message.isStarred ? 1 : 0)]
             guard params.count == 6 else { throw DatabaseError.saveDataFailed("Param count mismatch (CM/Embed)") }
         } else {
             if embedding != nil { print("Warning: Dim mismatch CM \(message.id). Saving without embedding.") }
             else { print("Warning: Saving CM \(message.id) without embedding (nil).") }
             sql = "INSERT OR REPLACE INTO ChatMessages (id, chatId, role, content, timestamp, isStarred, embedding) VALUES (?, ?, ?, ?, ?, ?, NULL);"
             params = [.text(message.id.uuidString), .text(chatId.uuidString), .text(roleString), .text(message.content),
                       .integer(Int64(message.timestamp.timeIntervalSince1970)), .integer(message.isStarred ? 1 : 0)]
               guard params.count == 6 else { throw DatabaseError.saveDataFailed("Param count mismatch (CM/NoEmbed)") }
          }
         _ = try self.connection.execute(sql, params) // Use synchronous execute
     }

    // Delete all messages for a specific Chat ID
    func deleteChatFromDB(id: UUID) throws { // Mark synchronous
        let sql = "DELETE FROM ChatMessages WHERE chatId = ?;"
        let params: [Value] = [.text(id.uuidString)]
        _ = try self.connection.execute(sql, params) // Use synchronous execute
        print("Attempted delete for all messages in Chat ID: \(id.uuidString)")
    }

    // Delete a specific message by its ID
    func deleteMessageFromDB(id: UUID) throws { // Mark synchronous
        let sql = "DELETE FROM ChatMessages WHERE id = ?;"
        let params: [Value] = [.text(id.uuidString)]
        _ = try self.connection.execute(sql, params) // Use synchronous execute
        print("Attempted delete for ChatMessage ID: \(id.uuidString)")
    }

    // Toggle star status for a specific message
    func toggleMessageStarInDB(id: UUID, isStarred: Bool) throws { // Mark synchronous
        let sql = "UPDATE ChatMessages SET isStarred = ? WHERE id = ?;"
        let params: [Value] = [.integer(isStarred ? 1 : 0), .text(id.uuidString)]
        _ = try self.connection.execute(sql, params) // Use synchronous execute
        print("Attempted toggle star (\(isStarred)) for ChatMessage ID: \(id.uuidString)")
    }

     // Find similar chat messages (used for RAG later, but good to have)
     func findSimilarChatMessages(to queryVector: [Float], limit: Int = 5) throws -> [ChatMessage] { // Mark synchronous
          guard !queryVector.isEmpty else { return [] }
         guard queryVector.count == self.embeddingDimension else {
              throw DatabaseError.dimensionMismatch(expected: self.embeddingDimension, actual: queryVector.count)
         }
         guard let queryJSON = embeddingToJson(queryVector) else {
              throw DatabaseError.embeddingGenerationFailed("Failed to convert query vector to JSON.")
         }

         let sql = """
             SELECT M.id, M.chatId, M.role, M.content, M.timestamp, M.isStarred,
                    vector_distance_cos(M.embedding, vector32(?)) AS distance
             FROM ChatMessages AS M
             JOIN vector_top_k('chat_embedding_idx', vector32(?), ?) AS V
               ON M.rowid = V.id
             WHERE M.embedding IS NOT NULL
             ORDER BY distance ASC;
             """
         let params: [Value] = [.text(queryJSON), .text(queryJSON), .integer(Int64(limit))]

          print("[DB Search] Executing ChatMessages search...")
         let rows = try self.connection.query(sql, params) // Use synchronous query
         var results: [ChatMessage] = [] // Return ChatMessage
         for row in rows {
             guard let idStr = try? row.getString(0), let id = UUID(uuidString: idStr),
                   let _ = try? row.getString(1), // chatId - not needed for ChatMessage itself
                   let roleStr = try? row.getString(2),
                   let content = try? row.getString(3),
                   let timestampInt = try? row.getInt(4),
                   let isStarredInt = try? row.getInt(5)
             else { print("Warning: Failed decode ChatMessage row for RAG: \(row)"); continue }

             let role: MessageRole = (roleStr == "user") ? .user : .assistant
             let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))

             results.append(ChatMessage(id: id, role: role, content: content, timestamp: timestamp, isStarred: isStarredInt == 1))
        }
        print("[DB Search] ChatMessages RAG search successful. Found \(results.count) items.")
        return results
    }

    // Load all chats (reconstructing Chat objects from messages)
     // Returns a dictionary mapping Chat ID to a Chat object
     func loadAllChats() throws -> [UUID: Chat] { // Mark synchronous
         let sql = "SELECT id, chatId, role, content, timestamp, isStarred FROM ChatMessages ORDER BY chatId ASC, timestamp ASC;"
         let rows = try self.connection.query(sql) // Use synchronous query
         var messagesByChatId: [UUID: [ChatMessage]] = [:]

        for row in rows {
            guard let idStr = try? row.getString(0), let id = UUID(uuidString: idStr),
                  let chatIdStr = try? row.getString(1), let chatId = UUID(uuidString: chatIdStr),
                  let roleStr = try? row.getString(2),
                  let content = try? row.getString(3),
                  let timestampInt = try? row.getInt(4),
                  let isStarredInt = try? row.getInt(5)
            else {
                print("Warning: Failed to decode ChatMessage row during loadAllChats grouping: \(row)")
                continue
            }
            let role: MessageRole = (roleStr == "user") ? .user : .assistant
            let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))
            let message = ChatMessage(id: id, role: role, content: content, timestamp: timestamp, isStarred: isStarredInt == 1)
            messagesByChatId[chatId, default: []].append(message)
        }

        var chats: [UUID: Chat] = [:]
        for (chatId, messages) in messagesByChatId {
            guard !messages.isEmpty else { continue }
            // Chat objects don't exist separately in DB yet, reconstruct
            let sortedMessages = messages // Already sorted by query
            let createdAt = sortedMessages.first!.timestamp
            let lastUpdatedAt = sortedMessages.last!.timestamp
            let isChatStarred = sortedMessages.contains { $0.isStarred } // Determine chat star status
            var chat = Chat(id: chatId, messages: sortedMessages, createdAt: createdAt, lastUpdatedAt: lastUpdatedAt, isStarred: isChatStarred)
            // Simple title generation (first user message)
            if let firstUserMsg = sortedMessages.first(where: { $0.role == .user }) {
                chat.title = String(firstUserMsg.content.prefix(30)) + (firstUserMsg.content.count > 30 ? "..." : "")
            } else {
                chat.title = "Chat \(chatId.uuidString.prefix(4))..." // Fallback title
            }
            chats[chatId] = chat
        }
        // Sort dictionary by last updated date before returning? Dictionary has no order.
        // Caller will need to sort the values if order is needed.
        print("Loaded and reconstructed \(chats.count) chats from DB messages.")
        return chats
    }

} // --- End of DatabaseService class ---