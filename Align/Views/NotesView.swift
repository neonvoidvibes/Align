import SwiftUI

// Renamed from ChatHistoryView
struct NotesView: View {
    // Inject ViewModel to get real chat data
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var appState: AppState // Needed to switch back to journal view
    @EnvironmentObject private var themeManager: ThemeManager

    // Grouped chats fetched from ViewModel
    private var groupedChats: [(String, [Chat])] {
        chatViewModel.groupChatsByTimePeriod()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header is now part of TabNavigationView

            // List of History Items using real data
            List {
                if groupedChats.isEmpty {
                    Text("No previous notes found.")
                        .font(.futura(size: 18))
                        .foregroundColor(.gray)
                        .listRowBackground(Color.black) // Assuming dark theme default, might need themeManager adaptation later
                        .listRowSeparator(.hidden)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)
                } else {
                    ForEach(groupedChats, id: \.0) { sectionTitle, chatsInSection in
                        Section(header: StickyHeader(title: sectionTitle)) {
                            ForEach(chatsInSection) { chat in
                                NoteRow(chat: chat)
                                    .listRowSeparator(.hidden) // Hide separators
                                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)) // Adjust padding
                                    .listRowBackground(Color.black) // Ensure row background matches list background
                                    .contentShape(Rectangle()) // Make whole row tappable
                                    .onTapGesture {
                                        print("Tapped on chat: \(chat.title)")
                                        chatViewModel.loadChat(withId: chat.id) // Load selected chat
                                        appState.currentView = .journal // Switch back to journal view
                                    }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain) // Use plain style
            .background(Color.black) // List background - Consider using themeManager.colors.appBackground
            .environment(\.defaultMinListRowHeight, 50) // Adjust row height if needed
            // Add scroll content background modifier for iOS 16+ if needed
            .if(true) { view in // Use #available check later if targeting older iOS
                 if #available(iOS 16.0, *) {
                     view.scrollContentBackground(.hidden) // Hide default background behind list rows
                 } else {
                     view // Fallback on earlier versions
                 }
            }
        }
        .background(Color.black.ignoresSafeArea()) // Ensure entire view background is black - Use themeManager later
        .onAppear {
            // Optionally refresh chat list on appear if needed
             print("NotesView appeared. Grouped chats: \(groupedChats.count) sections.")
             // chatViewModel.refreshChatsFromDB() // Uncomment if you want to force refresh on appear
        }
    }
}

// Custom Sticky Header View for Notes
struct StickyHeader: View {
    let title: String
    @EnvironmentObject private var themeManager: ThemeManager // Access theme if needed

    var body: some View {
        HStack {
            Text(title)
                .font(.futura(size: 18, weight: .bold)) // Use Futura font, adjust size/weight
                .foregroundColor(.gray) // Use gray or a theme color
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20) // Standard padding
        .background(Color.black) // Ensure header background matches list - Use themeManager later
        .listRowInsets(EdgeInsets()) // Critical for List sticky behavior
    }
}


// Updated Row View using Chat model
struct NoteRow: View {
    let chat: Chat
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading) {
            Text(chat.title) // Display generated chat title
                .font(.futura(size: 24)) // Match JournalView message font
                .foregroundColor(themeManager.accentColor) // Use accent color
                .lineLimit(1)
            Text(chat.lastUpdatedAt, style: .relative) // Relative date
                .font(.futura(size: 14)) // Smaller font for date
                .foregroundColor(.gray)
        }
        // Removed HStack and chevron
    }
}

// Preview
struct NotesView_Previews: PreviewProvider {
    @StateObject static var previewDbService = DatabaseService()
    static let previewLlmService = LLMService.shared
    // Initialize ChatViewModel directly as non-optional
    @StateObject static var previewChatViewModel = ChatViewModel(databaseService: previewDbService, llmService: previewLlmService)
    @StateObject static var previewAppState = AppState()

    static var previews: some View {
        // Add some mock chats to the view model for preview
        let _ = {
            // Correct argument order: id, messages, createdAt, lastUpdatedAt, title, isStarred
            let chat1 = Chat(id: UUID(), messages: [], lastUpdatedAt: Date().addingTimeInterval(-3600*25), title: "First Chat Example")
            let chat2 = Chat(id: UUID(), messages: [], lastUpdatedAt: Date().addingTimeInterval(-3600*24*5), title: "Another Reflection Topic from last week...")
            let chat3 = Chat(id: UUID(), messages: [], lastUpdatedAt: Date().addingTimeInterval(-3600*2), title: "Today's thoughts")
            previewChatViewModel?.chats = [chat1.id: chat1, chat2.id: chat2, chat3.id: chat3]
            previewChatViewModel?.currentChatId = chat3.id // Set a current chat
            previewChatViewModel?.currentChat = chat3
        }()

        // ViewModel is guaranteed non-optional now
        NotesView()
            .environmentObject(previewChatViewModel) // Pass directly
            .environmentObject(previewAppState)
            .environmentObject(ThemeManager())
            .preferredColorScheme(.dark) // Ensure dark mode for preview
    }
}

// Helper for conditional modifiers (like scrollContentBackground)
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}