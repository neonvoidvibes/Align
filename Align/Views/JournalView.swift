import SwiftUI

struct JournalView: View {
    @StateObject private var chatViewModel = ChatViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var scrollToBottom = false
    
    var body: some View {
        // Apply background to the whole VStack FIRST, ignoring bottom safe area
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chatViewModel.messages) { message in
                            MessageView(message: message)
                        }
                        
                        if chatViewModel.isTyping {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(chatViewModel.currentStreamedText)
                                        .font(.futura(size: 24))
                                        .foregroundColor(.primary)
                                        .padding(.bottom, 4)
                                    
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
                    .padding()
                }
                // Remove explicit background from ScrollView, it will inherit from VStack
                .onChange(of: chatViewModel.messages) { _ in
                    withAnimation {
                        scrollView.scrollTo("bottomID", anchor: .bottom)
                    }
                }
                .onChange(of: chatViewModel.currentStreamedText) { _ in
                    withAnimation {
                        scrollView.scrollTo("bottomID", anchor: .bottom)
                    }
                }
            }
            
            // HStack for input, sits on top of the VStack's background
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
        // Remove background modifier from the main VStack, use default system background
    }
}

struct MessageView: View {
    let message: ChatMessage
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            if message.role == .assistant {
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
                
                Spacer()
            } else {
                Spacer()
                
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