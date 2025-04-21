import SwiftUI

struct ChatHistoryView: View {
    @Binding var isPresented: Bool // To control visibility
    // @EnvironmentObject var chatViewModel: ChatViewModel // Add later
    @EnvironmentObject private var themeManager: ThemeManager

    // Placeholder data structure (replace with real Chat later)
    struct HistoryItem: Identifiable {
        let id = UUID()
        let title: String
        let date: Date
    }
    let historyItems: [HistoryItem] = [
        HistoryItem(title: "Reflection on project...", date: Date().addingTimeInterval(-86400 * 1)),
        HistoryItem(title: "Feeling tired today...", date: Date().addingTimeInterval(-86400 * 2)),
        HistoryItem(title: "Weekend plans", date: Date().addingTimeInterval(-86400 * 5)),
        HistoryItem(title: "Thoughts on energy levels", date: Date().addingTimeInterval(-86400 * 8)),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                // Back Button (or Close)
                 Button(action: {
                     withAnimation {
                         isPresented = false
                     }
                 }) {
                     Image(systemName: "chevron.backward") // Use back chevron
                         .font(.title2)
                         .foregroundColor(themeManager.accentColor)
                 }

                Spacer()

                Text("History")
                    .font(.futura(size: 32, weight: .bold))

                Spacer()

                // Placeholder to balance title
                 Rectangle().fill(Color.clear).frame(width: 40, height: 40)

            }
            .padding()
            .background(Color(UIColor.systemGray6)) // Match Settings background

            // List of History Items (Grouped later)
            List {
                // Example grouping (replace with actual logic later)
                Section("This Week") {
                     ForEach(historyItems.filter { $0.date > Date().addingTimeInterval(-86400 * 7)}) { item in
                         HistoryRow(item: item)
                            .onTapGesture {
                                print("Tapped on: \(item.title)")
                                // Action: Load this chat - Implement later
                                withAnimation { isPresented = false } // Close history for now
                            }
                     }
                }
                 Section("Older") {
                     ForEach(historyItems.filter { $0.date <= Date().addingTimeInterval(-86400 * 7)}) { item in
                         HistoryRow(item: item)
                            .onTapGesture {
                                print("Tapped on: \(item.title)")
                                // Action: Load this chat - Implement later
                                withAnimation { isPresented = false } // Close history for now
                            }
                     }
                 }
            }
            .listStyle(.plain) // Use plain style
        }
        .background(Color(UIColor.systemGray6))
        .edgesIgnoringSafeArea(.bottom)
    }
}

// Simple Row View for History Items
struct HistoryRow: View {
    let item: ChatHistoryView.HistoryItem // Use nested type
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.futura(size: 18, weight: .medium))
                    .lineLimit(1)
                Text(item.date, style: .relative) // Relative date for context
                    .font(.futura(size: 14))
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8) // Add some vertical padding
    }
}

// Preview
struct ChatHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ChatHistoryView(isPresented: .constant(true))
            .environmentObject(ThemeManager())
    }
}