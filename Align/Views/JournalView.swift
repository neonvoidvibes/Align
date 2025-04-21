import SwiftUI
import UIKit

// REMOVED Preference Keys - Not needed for marker visibility logic

// Define a notification name for dismissing copy icons
extension Notification.Name {
    static let dismissAllCopyIcons = Notification.Name("dismissAllCopyIcons")
}

struct JournalView: View {
    // Inject ChatViewModel via environment
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme // For button styling

    // State for scroll arrow visibility
    @State private var showScrollButton = false
    @State private var isBottomMarkerVisible = true // Track visibility of the last item

    // State for ScrollViewProxy
    @State private var viewScrollViewProxy: ScrollViewProxy? = nil

    var body: some View {
        // Use a ZStack to layer the scroll button over the content
        ZStack(alignment: .bottom) {
            // Main content VStack
            VStack(spacing: 0) {
                messageListView
                inputAreaView
            }

            // Scroll to Bottom Button (conditionally visible)
            scrollToBottomButton
        }
    }

    // Computed property for the message list ScrollView
    private var messageListView: some View {
        // REMOVED outer GeometryReader
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                // Container VStack for content - Apply background tap gesture here
                VStack {
                    LazyVStack(spacing: 16) {
                        ForEach(chatViewModel.messages) { message in
                             MessageView(message: message) // Removed availableWidth passing
                        }
                        if chatViewModel.isTyping { typingIndicatorView }

                        // Invisible view to scroll to AND track visibility
                        Color.clear
                            .frame(height: 1)
                            .id("bottomID")
                            .onAppear {
                                // print("✅ bottomID appeared")
                                isBottomMarkerVisible = true
                                updateScrollButtonVisibility() // Call update
                            }
                            .onDisappear {
                                // print("❌ bottomID disappeared")
                                isBottomMarkerVisible = false
                                updateScrollButtonVisibility() // Call update
                            }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical)
                    // REMOVED Preference Key Backgrounds
                } // End LazyVStack wrapper VStack
                 // Apply tap gesture to the background of the scrollable content area
                .background(
                    Color.clear // Use clear color for tap detection layer
                        .contentShape(Rectangle()) // Make the whole area tappable
                        .onTapGesture {
                            // print("ScrollView Background Tapped - Dismissing")
                            // Dismiss both keyboard and any visible copy icons
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            dismissCopyIconsGlobally()
                        }
                )
            } // End ScrollView
            // REMOVED coordinateSpace and preference change handlers
            // Keep scroll-on-message/typing handlers
            .onChange(of: chatViewModel.messages) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    scrollViewProxy.scrollTo("bottomID", anchor: .bottom)
                }
                 // Check visibility after messages change layout
                 DispatchQueue.main.async {
                     updateScrollButtonVisibility()
                 }
            }
            .onChange(of: chatViewModel.isTyping) {
                 withAnimation(.easeInOut(duration: 0.1)) {
                     scrollViewProxy.scrollTo("bottomID", anchor: .bottom)
                 }
                 // Check visibility after typing indicator changes layout
                 DispatchQueue.main.async {
                     updateScrollButtonVisibility()
                 }
            }
             // REMOVED handler for scroll-on-load trigger
             // Capture the proxy and check initial state
             .onAppear {
                 self.viewScrollViewProxy = scrollViewProxy
                  // Check visibility state shortly after appear
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                     updateScrollButtonVisibility()
                 }
             }
        } // End ScrollViewReader
    } // End messageListView

    // Extracted view for the typing indicator
    private var typingIndicatorView: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Circle().frame(width: 4, height: 4).opacity(0.8)
                    Circle().frame(width: 4, height: 4).opacity(0.8)
                    Circle().frame(width: 4, height: 4).opacity(0.8)
                }
                .foregroundColor(.gray)
            }
            .padding(.horizontal)
            Spacer()
        }
    }

    // Computed property for the input area HStack
    private var inputAreaView: some View {
        HStack(spacing: 12) {
            TextField("How's your day going?", text: $chatViewModel.inputText)
                .font(.futura(size: 20))
                .padding(.vertical, 12)
                .padding(.leading, 5)
                .padding(.trailing, 12)
                .background(.clear)
                .cornerRadius(20)

            Button(action: chatViewModel.sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .semibold)) // Adjusted size/weight slightly
                     // Set icon color to contrast with accent background
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(width: 40, height: 40)
                     // Apply accent color background as a Circle
                    .background(Circle().fill(themeManager.accentColor))
            }
            .disabled(chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .padding(.bottom, 5)
    }

    // Reinstated scroll-to-bottom button view builder
    @ViewBuilder
    private var scrollToBottomButton: some View {
        if showScrollButton {
             Button {
                 withAnimation {
                     viewScrollViewProxy?.scrollTo("bottomID", anchor: .bottom)
                 }
             } label: {
                 Image(systemName: "arrow.down.circle.fill")
                     .font(.system(size: 39, weight: .medium))
                     .foregroundColor(themeManager.accentColor)
                     .background(Circle().fill(Color(UIColor.systemBackground).opacity(0.8)))
                     .shadow(radius: 3)
                     .opacity(0.5)
             }
             .padding(.bottom, 65)
             .transition(.scale.combined(with: .opacity))
             .id("ScrollButton")
        }
    }

    // Reinstated updateScrollButtonVisibility function using marker visibility
    private func updateScrollButtonVisibility() {
        // Show button only if the bottom marker is NOT visible
        let shouldShow = !isBottomMarkerVisible

        // print("--- Update Button ---")
        // print("Bottom Marker Visible: \(isBottomMarkerVisible)")
        // print(">>> Should Show Button: \(shouldShow) (Current: \(showScrollButton))")

        if showScrollButton != shouldShow {
            // print("!!! Button State Changing to: \(shouldShow)")
            withAnimation(.easeInOut(duration: 0.2)) {
                self.showScrollButton = shouldShow
            }
        }
    }


    // Helper to post notification to dismiss icons globally
    private func dismissCopyIconsGlobally(excluding messageId: UUID? = nil) {
        NotificationCenter.default.post(name: .dismissAllCopyIcons, object: nil, userInfo: ["exclude": messageId])
    }
}


// MessageView: Kept keyboard dismissal on tap, removed availableWidth
struct MessageView: View {
    let message: ChatMessage
    // REMOVED availableWidth prop
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var showCopyIcon = false
    @State private var showCheckmark = false
    @State private var copyIconTimer: DispatchWorkItem?

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 12) { // Spacing 12
                Text(message.content)
                    .font(.futura(size: 24))
                    .foregroundColor(message.role == .user ? themeManager.accentColor : .primary)
                    .fixedSize(horizontal: false, vertical: true)

                bottomRowContent
            }
            .frame(maxWidth: message.role == .user ? UIScreen.main.bounds.width * 0.75 : nil, // Approx 75%
                   alignment: message.role == .user ? .trailing : .leading)
            .contentShape(Rectangle()) // Make the entire VStack tappable
            .onTapGesture { // This gesture is for the message bubble itself
                // Explicitly dismiss keyboard when tapping a message bubble
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                // Handle copy icon logic
                copyIconTimer?.cancel()
                NotificationCenter.default.post(name: .dismissAllCopyIcons, object: nil, userInfo: ["exclude": message.id])
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopyIcon.toggle()
                    if !showCopyIcon { showCheckmark = false }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissAllCopyIcons)) { notification in
                let excludeId = notification.userInfo?["exclude"] as? UUID
                if excludeId != self.message.id {
                    if showCopyIcon {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopyIcon = false
                            showCheckmark = false
                        }
                        copyIconTimer?.cancel()
                    }
                }
            }

            if message.role == .assistant { Spacer() }
        }
    }

    @ViewBuilder
    private var bottomRowContent: some View {
        HStack(spacing: 4) {
            if message.role == .assistant {
                if showCopyIcon { iconView } else { timestampView }
                Spacer()
            } else { // User
                Spacer()
                if showCopyIcon { iconView } else { timestampView }
            }
        }
        .frame(height: 22) // Height for larger icon
    }

    private var timestampView: some View {
        Text(formatTime(message.timestamp))
            .font(.futura(size: 12))
            .foregroundColor(.gray)
    }

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            if showCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: 19)) // Icon size 19pt
                    .foregroundColor(themeManager.accentColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Image(systemName: "square.on.square")
                    .font(.system(size: 19)) // Icon size 19pt
                    .foregroundColor(.gray)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .contentShape(Rectangle()) // Make icon tappable area slightly larger if needed
                    .onTapGesture { // This gesture is ONLY for the icon itself
                        UIPasteboard.general.string = message.content
                        withAnimation(.easeInOut(duration: 0.2)) { showCheckmark = true }
                        copyIconTimer?.cancel()
                        let task = DispatchWorkItem {
                            withAnimation(.easeOut(duration: 0.5)) {
                                self.showCheckmark = false
                                self.showCopyIcon = false
                            }
                        }
                        self.copyIconTimer = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
                    }
            }
        }
        .frame(width: 28, height: 22, alignment: message.role == .user ? .trailing : .leading) // Frame for larger icon
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }
}


// Preview Provider
struct JournalView_Previews: PreviewProvider {
    @StateObject static var previewDbService = try! DatabaseService()
    static let previewLlmService = LLMService.shared

    static var previews: some View {
        let previewChatViewModel = ChatViewModel(databaseService: previewDbService, llmService: previewLlmService)
        let _ = {
             previewChatViewModel.messages = [
                 ChatMessage(role: .assistant, content: "Preview: How's it going?", timestamp: Date()),
                 ChatMessage(role: .user, content: "Feeling pretty good today. This is a slightly longer message to test the width constraint and wrapping behaviour.", timestamp: Date().addingTimeInterval(60)),
                 ChatMessage(role: .assistant, content: "That's great to hear!", timestamp: Date().addingTimeInterval(120)),
                 ChatMessage(role: .user, content: "Just wrapping up work.", timestamp: Date().addingTimeInterval(180)),
                 ChatMessage(role: .assistant, content: "Nice. Anything interesting happen?", timestamp: Date().addingTimeInterval(240)),
                 ChatMessage(role: .user, content: "Not really, just the usual.", timestamp: Date().addingTimeInterval(300)),
                 ChatMessage(role: .assistant, content: "Okay.", timestamp: Date().addingTimeInterval(360)),
                 ChatMessage(role: .user, content: "This message is here to make the content long enough to test scrolling.", timestamp: Date().addingTimeInterval(420)),
                 ChatMessage(role: .assistant, content: "Understood. This message also adds to the height.", timestamp: Date().addingTimeInterval(480)),
                 ChatMessage(role: .user, content: "One more user message.", timestamp: Date().addingTimeInterval(540)),
                 ChatMessage(role: .assistant, content: "And a final assistant message to ensure scrolling is needed.", timestamp: Date().addingTimeInterval(600)),
             ]
         }()

        return JournalView()
            .environmentObject(previewChatViewModel)
            .environmentObject(ThemeManager())
            .environmentObject(previewDbService)
            .previewLayout(.fixed(width: 375, height: 600))
    }
}
