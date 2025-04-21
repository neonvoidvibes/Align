import SwiftUI

struct TabNavigationView: View {
    @Binding var currentView: AppView
    var onSettingsClick: () -> Void
    var onNewChatClick: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    // Define views array and geometry constants
    private let views: [AppView] = [.notes, .journal, .loop] // Use .notes
    private let selectedNavBarWidth: CGFloat = 41
    private let unselectedNavBarWidth: CGFloat = 20
    private let navBarHeight: CGFloat = 3.75

    // Computed property for header title based on currentView
    private var headerTitle: String {
        switch currentView {
        case .notes: return "Notes" // Renamed
        case .journal: return "Journal"
        case .loop: return "Loop"
        }
    }

    var body: some View {
        VStack(spacing: 12) { // Adjust vertical spacing as needed

            // Row 1: Navigation Bars (Refactored ForEach)
            HStack(spacing: 8) {
                ForEach(views, id: \.self) { targetView in // Iterate over the views array
                    let isActive = (currentView == targetView) // Calculate active state inline

                    Capsule()
                         // Use ternary operator for fill
                        .fill(isActive ? themeManager.accentColor : Color.gray.opacity(0.3))
                         // Use ternary operator for frame width
                        .frame(width: isActive ? selectedNavBarWidth : unselectedNavBarWidth, height: navBarHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Update currentView directly to the targetView from the loop
                            if currentView != targetView {
                                currentView = targetView
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                }
            }

            // Row 2: Settings Icon and Header Title (Using previous fix with opacity)
            HStack(alignment: .center) {
                // Settings Button
                Button(action: onSettingsClick) {
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle().frame(width: 30, height: 2.5).foregroundColor(.primary)
                        Rectangle().frame(width: 25, height: 2.5).foregroundColor(.primary)
                    }
                }
                .frame(width: 38, height: 38) // Consistent frame
                .padding(.leading)

                Spacer()

                // Header Title
                Text(headerTitle)
                    .font(.futura(size: 32, weight: .bold))

                Spacer()

                // New Chat Button Area (always present for layout, hidden with opacity)
                Button(action: onNewChatClick) {
                     Image(systemName: "square.and.pencil")
                         .font(.system(size: 22))
                         .foregroundColor(.primary) // Use primary text color
                }
                .frame(width: 38, height: 38) // Consistent frame
                .padding(.trailing)
                .opacity(currentView == .journal ? 1.0 : 0.0) // Control visibility
                .disabled(currentView != .journal) // Disable interaction when hidden

            } // End HStack for Header Row

        } // End Main VStack
    } // End body
} // End struct

// Preview Provider (can remain as is, showing different states)
struct TabNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TabNavigationView(
                currentView: .constant(.notes), // Start at notes
                onSettingsClick: { print("Settings Tapped") },
                onNewChatClick: { print("New Chat Tapped") }
            )
            TabNavigationView(
                currentView: .constant(.journal), // Show journal state
                onSettingsClick: { print("Settings Tapped") },
                onNewChatClick: { print("New Chat Tapped") }
            )
            TabNavigationView(
                currentView: .constant(.loop), // Show loop state
                onSettingsClick: { print("Settings Tapped") },
                onNewChatClick: { print("New Chat Tapped") }
            )
        }
        .environmentObject(ThemeManager())
        .padding()
        .background(Color(UIColor.systemGray6))
    }
}
