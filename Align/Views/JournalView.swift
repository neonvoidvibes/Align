import SwiftUI
import UIKit

struct JournalView: View {
    // Inject ChatViewModel via environment
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var scrollToBottom = false // Keep state for scroll logic if needed

    var body: some View {
        // Apply background to the whole VStack FIRST, ignoring bottom safe area
        VStack(spacing: 0) {
            // Extracted ScrollView content
            messageListView

            // Extracted Input Area
            inputAreaView
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        // Remove background modifier from the main VStack, use default system background
    }

    // Computed property for the message list ScrollView
    private var messageListView: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chatViewModel.messages) { message in
                        MessageView(message: message)
                    }

                    if chatViewModel.isTyping {
                        // Display only the typing indicator dots
                        HStack {
                            VStack(alignment: .leading) {
                                // REMOVED: Text(chatViewModel.currentStreamedText) display

                                // Keep the typing dots indicator
                                HStack {
                                    Circle()
                                        .frame(width: 4, height: 4)
                                        .opacity(0.8)
                                    Circle()
                                        .frame(width: 4, height: 4)
                                        .opacity(0.8)
                                    Circle()
                                        .frame(width: 4, height: 4)
                                        .opacity(0.8)
                                }
                                .foregroundColor(.gray)
                            }
                            .padding(.horizontal)

                            Spacer()
                        }
                    }

                    // Invisible view to scroll to
                    Color.clear
                        .frame(height: 1)
                        .id("bottomID")
                }
                .padding() // Keep original padding if needed
                .padding() // Keep original padding if needed
            }
            // Updated onChange syntax (ignoring parameters)
            .onChange(of: chatViewModel.messages) {
                withAnimation {
                    scrollView.scrollTo("bottomID", anchor: .bottom)
                }
            }
            // Updated onChange syntax (ignoring parameters)
            // Scroll when messages change
            .onChange(of: chatViewModel.messages) {
                withAnimation {
                    scrollView.scrollTo("bottomID", anchor: .bottom)
                }
            }
            // Scroll when typing indicator appears/disappears
            .onChange(of: chatViewModel.isTyping) {
                 withAnimation {
                     scrollView.scrollTo("bottomID", anchor: .bottom)
                 }
            }
        }
    }

    // Computed property for the input area HStack
    private var inputAreaView: some View {
        HStack(spacing: 12) {
            TextField("How's your day going?", text: $chatViewModel.inputText)
                .font(.futura(size: 20))
                .padding(12)
                // Make background transparent
                .background(.clear)
                .cornerRadius(20) // Keep corner radius for the shape

            Button(action: chatViewModel.sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20))
                    .fontWeight(.semibold) // Make the arrow icon thicker
                    .foregroundColor(themeManager.accentColor)
                    .frame(width: 40, height: 40)
            }
            .disabled(chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        // Apply padding for content positioning within the input area
        .padding(.horizontal)
        .padding(.vertical, 8)
        // No background needed for the HStack, it sits on the main view background
    }
}

// Renamed ChatBubble equivalent
struct MessageView: View {
    let message: ChatMessage
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        // Align based on role
        HStack {
            if message.role == .assistant {
                // Assistant message bubble
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.futura(size: 24))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(formatTime(message.timestamp))
                        .font(.futura(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                // Ensure assistant bubble takes max width if needed, or keep as is
                Spacer() // Pushes assistant bubble left
            } else { // User message
                Spacer() // Pushes user bubble right

                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.futura(size: 24))
                        .foregroundColor(themeManager.accentColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(formatTime(message.timestamp))
                        .font(.futura(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }
}

// Previews might need adjustment if ChatViewModel requires services
struct JournalView_Previews: PreviewProvider {
    // Create instances of services needed by ChatViewModel for the preview
     // Use try! for throwing initializer in preview context
     @StateObject static var previewDbService = try! DatabaseService()
    static let previewLlmService = LLMService.shared // Use singleton

    static var previews: some View {
        // Instantiate ChatViewModel with preview services
        let previewChatViewModel = ChatViewModel(databaseService: previewDbService, llmService: previewLlmService)

        // Add mock messages if needed for preview design
        // Example:
        let _ = {
             previewChatViewModel.messages = [
                 ChatMessage(role: .assistant, content: "Preview: How's it going?", timestamp: Date()),
                 ChatMessage(role: .user, content: "Feeling pretty good today.", timestamp: Date().addingTimeInterval(60))
             ]
             // Simulate typing state for preview if desired
             // previewChatViewModel.isTyping = true
         }()


        return JournalView()
            .environmentObject(previewChatViewModel) // Provide the view model
            .environmentObject(ThemeManager()) // Provide ThemeManager
            // Provide services if any subview needs them directly via environment
            .environmentObject(previewDbService)
    }
}