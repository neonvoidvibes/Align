import SwiftUI
import UIKit

// --- Preference Keys for ScrollView ---
// Back to using CGPoint for offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Define a notification name for dismissing copy icons
extension Notification.Name {
    static let dismissAllCopyIcons = Notification.Name("dismissAllCopyIcons")
}

struct JournalView: View {
    // Inject ChatViewModel via environment
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    // State for scroll tracking and button visibility
    @State private var scrollOffset: CGPoint = .zero
    @State private var contentHeight: CGFloat = 0
    @State private var showScrollButton = false
    private let scrollButtonThreshold: CGFloat = 100 // Keep threshold

    @State private var viewScrollViewProxy: ScrollViewProxy? = nil
    @State private var viewVisibleHeight: CGFloat = 0 // Store visible height

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
        // REMOVED .keyboardDismissMode - Compiler issue
    }

    // Computed property for the message list ScrollView
    private var messageListView: some View {
        GeometryReader { geometry in // Capture geometry proxy
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    // Container VStack for content - Apply background tap gesture here
                    VStack {
                        LazyVStack(spacing: 16) {
                            ForEach(chatViewModel.messages) { message in
                                MessageView(message: message, availableWidth: geometry.size.width)
                            }
                            if chatViewModel.isTyping { typingIndicatorView }

                            // Invisible view to scroll to
                            Color.clear
                                .frame(height: 1)
                                .id("bottomID")
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical)
                        // Track Content Height
                        .background(GeometryReader { contentProxy in
                            Color.clear.preference(key: ContentHeightPreferenceKey.self, value: contentProxy.size.height)
                        })
                    }
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
                    // Track Scroll Offset using background GeometryReader relative to named coordinate space
                    .background(GeometryReader { offsetProxy in
                        Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: offsetProxy.frame(in: .named("scrollView")).origin)
                    })
                }
                // REMOVED .keyboardDismissMode from ScrollView
                .coordinateSpace(name: "scrollView")
                // Update state based on preference changes
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    self.scrollOffset = value
                    updateScrollButtonVisibility() // Use stored visibleHeight
                }
                .onPreferenceChange(ContentHeightPreferenceKey.self) { value in
                     // Filter out minor changes potentially caused by typing indicator
                     if abs(self.contentHeight - value) > 5 {
                         self.contentHeight = value
                         updateScrollButtonVisibility() // Use stored visibleHeight
                     }
                }
                // Existing onChange handlers for scrolling
                .onChange(of: chatViewModel.messages) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        scrollViewProxy.scrollTo("bottomID", anchor: .bottom)
                    }
                    DispatchQueue.main.async { // Check visibility after layout
                       updateScrollButtonVisibility()
                    }
                }
                .onChange(of: chatViewModel.isTyping) {
                     withAnimation(.easeInOut(duration: 0.1)) {
                         scrollViewProxy.scrollTo("bottomID", anchor: .bottom)
                     }
                     DispatchQueue.main.async { // Check visibility after layout
                        updateScrollButtonVisibility()
                     }
                }
                 // Capture the proxy and geometry, check initial state
                 .onAppear {
                     self.viewScrollViewProxy = scrollViewProxy
                     self.viewVisibleHeight = geometry.size.height // Store initial height
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Keep delay for initial check
                         updateScrollButtonVisibility()
                     }
                 }
                 // Update stored height if geometry changes (e.g., rotation)
                 .onChange(of: geometry.size.height) { newHeight in
                      self.viewVisibleHeight = newHeight
                      updateScrollButtonVisibility()
                 }
            }
        }
        // REMOVED .keyboardDismissMode from GeometryReader
    }

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
                    .font(.system(size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.accentColor)
                    .frame(width: 40, height: 40)
            }
            .disabled(chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .padding(.bottom, 5)
    }

    // Computed property for the scroll-to-bottom button
    @ViewBuilder
    private var scrollToBottomButton: some View {
        if showScrollButton {
             Button {
                 withAnimation {
                     viewScrollViewProxy?.scrollTo("bottomID", anchor: .bottom)
                 }
             } label: {
                 Image(systemName: "arrow.down.circle.fill")
                     .font(.system(size: 39, weight: .medium)) // Kept increased size
                     .foregroundColor(themeManager.accentColor)
                     .background(Circle().fill(Color(UIColor.systemBackground).opacity(0.8)))
                     .shadow(radius: 3)
                     .opacity(0.5) // Kept 50% opacity
             }
             .padding(.bottom, 65)
             .transition(.scale.combined(with: .opacity))
             .id("ScrollButton")
        }
    }


    // Function to update scroll button visibility using offset and height
    private func updateScrollButtonVisibility() {
        // Use stored visibleHeight
        guard viewVisibleHeight > 0, contentHeight > 0 else {
            // Ensure button is hidden if dimensions aren't ready
            if showScrollButton {
                 // print("❌ Hiding Button: Invalid dimensions (VisibleH: \(viewVisibleHeight), ContentH: \(contentHeight))")
                 withAnimation(.easeInOut(duration: 0.2)) { showScrollButton = false }
            }
            return
        }

        // scrollOffset.y is the Y coordinate of the top of the scrollable content
        // relative to the top of the ScrollView frame. It's 0 or negative when scrolled down.
        let scrollY = abs(scrollOffset.y) // Distance scrolled from top (positive)

        // Calculate how much content height is currently *below* the bottom edge of the visible frame
        let contentBelowBottom = contentHeight - scrollY - viewVisibleHeight

        // Show button if the content below the bottom edge exceeds the threshold
        let shouldShow = contentBelowBottom > scrollButtonThreshold

        // --- DEBUGGING ---
        // print("--- Update Button ---")
        // print("Visible Height: \(viewVisibleHeight.rounded())")
        // print("Content Height: \(contentHeight.rounded())")
        // print("Scroll Offset Y (abs): \(scrollY.rounded())")
        // print("Content Below Bottom: \(contentBelowBottom.rounded())")
        // print("Threshold: \(scrollButtonThreshold)")
        // print(">>> Should Show Button: \(shouldShow) (Current: \(showScrollButton))")
        // --- END DEBUGGING ---

        if showScrollButton != shouldShow {
            // print("!!! Button State Changing to: \(shouldShow)")
            withAnimation(.easeInOut(duration: 0.2)) {
                showScrollButton = shouldShow
            }
        }
    }

    // Helper to post notification to dismiss icons globally
    private func dismissCopyIconsGlobally(excluding messageId: UUID? = nil) {
        NotificationCenter.default.post(name: .dismissAllCopyIcons, object: nil, userInfo: ["exclude": messageId])
    }
}


// MessageView: Added keyboard dismissal to its onTapGesture
struct MessageView: View {
    let message: ChatMessage
    let availableWidth: CGFloat
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
            .frame(maxWidth: message.role == .user ? availableWidth * 0.75 : nil,
                   alignment: message.role == .user ? .trailing : .leading)
            .contentShape(Rectangle()) // Make the entire VStack tappable
            .onTapGesture { // This gesture is for the message bubble itself
                // print("Message Tapped: \(message.id). Current showCopyIcon: \(showCopyIcon)")

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
                        // print("Copy Icon Tapped: \(message.id)")
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