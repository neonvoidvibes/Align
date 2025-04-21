import SwiftUI

struct NotesView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    private var groupedChats: [(String, [Chat])] {
        chatViewModel.groupChatsByTimePeriod()
    }

    var body: some View {
        VStack(spacing: 0) {
            buildList()
        }
        // Removed explicit black background to use system default
        .onAppear {
            // Optionally refresh chat list
        }
    }

    @ViewBuilder
    private func buildList() -> some View {
        let baseList = List {
            if groupedChats.isEmpty {
                Text("No previous notes found.")
                    .font(.futura(size: 18))
                    .foregroundColor(.gray)
                    // Removed listRowBackground
                    .listRowSeparator(.hidden)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 50)
            } else {
                ForEach(groupedChats, id: \.0) { sectionTitle, chatsInSection in
                    Section(header: StickyHeader(title: sectionTitle)) {
                        ForEach(chatsInSection) { chat in
                            NoteRow(chat: chat)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                // Removed listRowBackground
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    chatViewModel.loadChat(withId: chat.id)
                                    appState.currentView = .journal
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        // Removed explicit black background
        .environment(\.defaultMinListRowHeight, 50)

        if #available(iOS 16.0, *) {
            baseList.scrollContentBackground(.hidden)
        } else {
            baseList
        }
    }
}

struct StickyHeader: View {
    let title: String
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack {
            Text(title)
                .font(.futura(size: 18, weight: .bold))
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        // Removed explicit black background
        .listRowInsets(EdgeInsets())
    }
}

struct NoteRow: View {
    let chat: Chat
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading) {
            Text(chat.title)
                .font(.futura(size: 24))
                .foregroundColor(themeManager.accentColor)
                .lineLimit(1)
            Text(chat.lastUpdatedAt, style: .relative)
                .font(.futura(size: 14))
                .foregroundColor(.gray)
        }
    }
}

struct NotesView_Previews: PreviewProvider {
    @StateObject static var previewDbService = try! DatabaseService()
    static let previewLlmService = LLMService.shared
    @StateObject static var previewChatViewModel = ChatViewModel(databaseService: previewDbService, llmService: previewLlmService)
    @StateObject static var previewAppState = AppState()

    static var previews: some View {
        // Mock some chats
        let chat1 = Chat(id: UUID(), messages: [], lastUpdatedAt: Date().addingTimeInterval(-3600*25), title: "First Chat")
        let chat2 = Chat(id: UUID(), messages: [], lastUpdatedAt: Date().addingTimeInterval(-3600*24*5), title: "Last Week Thoughts")
        let chat3 = Chat(id: UUID(), messages: [], lastUpdatedAt: Date().addingTimeInterval(-3600*2), title: "Recent Entry")
        previewChatViewModel.chats = [chat1.id: chat1, chat2.id: chat2, chat3.id: chat3]
        previewChatViewModel.currentChatId = chat3.id
        previewChatViewModel.currentChat = chat3

        return NotesView()
            .environmentObject(previewChatViewModel)
            .environmentObject(previewAppState)
            .environmentObject(ThemeManager())
            .preferredColorScheme(.dark)
    }
}