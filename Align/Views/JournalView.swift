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
        // Use GeometryReader to get available width for percentage calculation
        GeometryReader { geometry in
            ScrollViewReader { scrollView in
                ScrollView {
                    // IMPORTANT: Keep existing padding here
                    LazyVStack(spacing: 16) {
                        ForEach(chatViewModel.messages) { message in
                            // Pass the available width to MessageView
                            MessageView(message: message, availableWidth: geometry.size.width)
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
                                .padding(.horizontal) // This padding is for the typing indicator itself, not the messages

                                Spacer()
                            }
                        }

                        // Invisible view to scroll to
                        Color.clear
                            .frame(height: 1)
                            .id("bottomID")
                    }
                    .padding(.horizontal, 18) // Main padding for the list content
                    .padding(.vertical) // Apply vertical padding
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
    }


    // Computed property for the input area HStack
    private var inputAreaView: some View {
        HStack(spacing: 12) {
            TextField("How's your day going?", text: $chatViewModel.inputText)
                .font(.futura(size: 20))
                // Adjust internal padding: reduce leading further
                .padding(.vertical, 12)
                .padding(.leading, 5)
                .padding(.trailing, 12)
                // Make background transparent
                .background(.clear)
                .cornerRadius(20) // Keep corner radius for the shape

            Button(action: chatViewModel.sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 24)) // Increased size further
                    .fontWeight(.bold) // Make the arrow icon thicker (bold)
                    .foregroundColor(themeManager.accentColor)
                    .frame(width: 40, height: 40)
            }
            // Removed specific button padding
            .disabled(chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        // Apply standard padding for content positioning within the input area
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        // No background needed for the HStack, it sits on the main view background
    }
}

// Renamed ChatBubble equivalent
struct MessageView: View {
    let message: ChatMessage
    let availableWidth: CGFloat // Receive available width from parent
    @EnvironmentObject private var themeManager: ThemeManager

    // State for copy interaction
    @State private var showCopyIcon = false
    @State private var showCheckmark = false
    @State private var copyIconTimer: DispatchWorkItem?

    var body: some View {
        // Outer HStack for overall alignment (pushing bubble left/right)
        HStack {
            if message.role == .user {
                Spacer() // Push user bubble right
            }

            // Content VStack (the bubble itself)
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message Text
                Text(message.content)
                    .font(.futura(size: 24))
                    .foregroundColor(message.role == .user ? themeManager.accentColor : .primary)
                    .fixedSize(horizontal: false, vertical: true) // Allow text to wrap

                // Bottom Row: Timestamp OR Copy/Checkmark Icon
                bottomRowContent
            }
            // Apply max width constraint HERE
            // User messages: 70% of available width
            // Assistant messages: No explicit constraint (allow flexibility, but usually less than user max)
            .frame(maxWidth: message.role == .user ? availableWidth * 0.70 : nil, // Apply 70% width to user messages
                   alignment: message.role == .user ? .trailing : .leading)
            // Add padding *inside* the bubble shape if needed (e.g., for background)
            // .padding(.horizontal, 10) // Example if a background were applied
            // .padding(.vertical, 8)
            // .background(message.role == .user ? themeManager.accentColor.opacity(0.1) : Color(UIColor.systemGray5)) // Example Background
            // .cornerRadius(12)
            .contentShape(Rectangle()) // Make the VStack tappable
            .onTapGesture {
                // Cancel any pending timer if tapped again
                copyIconTimer?.cancel()

                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopyIcon.toggle()
                    // If hiding copy icon, always hide checkmark too
                    if !showCopyIcon {
                        showCheckmark = false
                    }
                }
            }

            if message.role == .assistant {
                Spacer() // Push assistant bubble left
            }
        }
    }

    // ViewBuilder for the bottom row content (Timestamp or Icon)
    @ViewBuilder
    private var bottomRowContent: some View {
        HStack(spacing: 4) { // Use HStack to control alignment within the bottom row
            // Assistant: Icon on the left
            if message.role == .assistant {
                if showCopyIcon {
                    iconView // Show icon if state allows
                } else {
                    // Show timestamp if not showing icon
                    Text(formatTime(message.timestamp))
                        .font(.futura(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer() // Push timestamp/icon left
            }
            // User: Icon on the right
            else { // message.role == .user
                Spacer() // Push timestamp/icon right
                if showCopyIcon {
                    iconView // Show icon if state allows
                } else {
                    // Show timestamp if not showing icon
                    Text(formatTime(message.timestamp))
                        .font(.futura(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(height: 15) // Ensure consistent height for the bottom row
    }

    // ViewBuilder for the actual icon (Copy or Checkmark)
    @ViewBuilder
    private var iconView: some View {
        ZStack { // ZStack allows smooth transition between icons
            if showCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: 12)) // Small icon
                    .foregroundColor(themeManager.accentColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Image(systemName: "square.on.square")
                    .font(.system(size: 12)) // Small icon
                    .foregroundColor(.gray) // Subtle color
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .onTapGesture {
                        // 1. Copy
                        UIPasteboard.general.string = message.content

                        // 2. Show Checkmark
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCheckmark = true
                        }

                        // 3. Schedule hiding checkmark and copy icon
                        // Cancel previous timer if exists
                        copyIconTimer?.cancel()

                        // Create new timer
                        let task = DispatchWorkItem {
                            withAnimation(.easeOut(duration: 0.5)) {
                                self.showCheckmark = false
                                self.showCopyIcon = false // Hide icon state completely
                            }
                        }
                        self.copyIconTimer = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
                    }
            }
        }
        .frame(width: 20, height: 15, alignment: message.role == .user ? .trailing : .leading) // Consistent frame, align icon within frame
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
                 ChatMessage(role: .user, content: "Feeling pretty good today. This is a slightly longer message to test the width constraint and wrapping behaviour.", timestamp: Date().addingTimeInterval(60)),
                 ChatMessage(role: .assistant, content: "That's great to hear!", timestamp: Date().addingTimeInterval(120))

             ]
             // Simulate typing state for preview if desired
             // previewChatViewModel.isTyping = true
         }()


        // Provide a realistic width for the preview
        return JournalView()
            .environmentObject(previewChatViewModel) // Provide the view model
            .environmentObject(ThemeManager()) // Provide ThemeManager
            // Provide services if any subview needs them directly via environment
            .environmentObject(previewDbService)
            .previewLayout(.fixed(width: 375, height: 600)) // Example width for layout testing
    }
}
