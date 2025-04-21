import SwiftUI

struct TabNavigationView: View {
    @Binding var currentView: AppView
    var onSettingsClick: () -> Void
    var onNewChatClick: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    private let views: [AppView] = [.notes, .journal, .loop]
    private let selectedNavBarWidth: CGFloat = 41
    private let unselectedNavBarWidth: CGFloat = 20
    private let navBarHeight: CGFloat = 3.75

    private var headerTitle: String {
        switch currentView {
        case .notes: return "Notes"
        case .journal: return "Journal"
        case .loop: return "Loop"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Navigation Bars
            HStack(spacing: 8) {
                ForEach(views, id: \.self) { targetView in
                    let isActive = (currentView == targetView)

                    Capsule()
                        .fill(isActive ? themeManager.accentColor : Color.gray.opacity(0.3))
                        .frame(width: isActive ? selectedNavBarWidth : unselectedNavBarWidth,
                               height: navBarHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if currentView != targetView {
                                currentView = targetView
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                }
            }

            // Header Row
            HStack(alignment: .center) {
                // Settings Button
                Button(action: onSettingsClick) {
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle()
                            .frame(width: 30, height: 2.5)
                            .foregroundColor(.primary)
                        Rectangle()
                            .frame(width: 25, height: 2.5)
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 38, height: 38)
                .padding(.leading)

                Spacer()

                // Title
                Text(headerTitle)
                    .font(.futura(size: 32, weight: .bold))

                Spacer()

                // New Chat Button (only in Journal)
                Button(action: onNewChatClick) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
                .frame(width: 38, height: 38)
                .padding(.trailing)
                .opacity(currentView == .journal ? 1.0 : 0.0)
                .disabled(currentView != .journal)
            } // End HStack for Header Row
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            if let idx = views.firstIndex(of: currentView), idx < views.count - 1 {
                                currentView = views[idx + 1]
                            }
                        } else if value.translation.width > 50 {
                            if let idx = views.firstIndex(of: currentView), idx > 0 {
                                currentView = views[idx - 1]
                            }
                        }
                    }
            )
        }
    }
}

// Preview Provider
struct TabNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TabNavigationView(
                currentView: .constant(.notes),
                onSettingsClick: { print("Settings Tapped") },
                onNewChatClick: { print("New Chat Tapped") }
            )
            TabNavigationView(
                currentView: .constant(.journal),
                onSettingsClick: { print("Settings Tapped") },
                onNewChatClick: { print("New Chat Tapped") }
            )
            TabNavigationView(
                currentView: .constant(.loop),
                onSettingsClick: { print("Settings Tapped") },
                onNewChatClick: { print("New Chat Tapped") }
            )
        }
        .environmentObject(ThemeManager())
        .padding()
        .background(Color(UIColor.systemGray6))
    }
}
