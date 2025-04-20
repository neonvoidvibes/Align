import SwiftUI

struct TabNavigationView: View {
    @Binding var currentView: AppView
    var onSettingsClick: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Define constants for nav bar dimensions
    private let selectedNavBarWidth: CGFloat = 54
    private let unselectedNavBarWidth: CGFloat = 27
    private let navBarHeight: CGFloat = 3

    var body: some View {
        VStack(spacing: 12) { // Adjust vertical spacing as needed

            // Row 1: Navigation Bars (Centered) - PLACED FIRST
            HStack(spacing: 8) {
                ForEach(0..<2) { index in
                    let isActive = (index == 0 && currentView == .journal) || (index == 1 && currentView == .loop)
                    let targetView: AppView = index == 0 ? .journal : .loop
                    
                    Capsule()
                        .fill(isActive ? themeManager.accentColor : Color.gray.opacity(0.3))
                        .frame(width: isActive ? selectedNavBarWidth : unselectedNavBarWidth, height: navBarHeight)
                        .contentShape(Rectangle()) // Increase tap area
                        .onTapGesture {
                            if currentView != targetView {
                                currentView = targetView
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                }
            }
            // Centered by default

            // Row 2: Settings Icon and Header Title (Aligned Vertically) - PLACED SECOND (BELOW BARS)
            HStack(alignment: .firstTextBaseline) {
                // Settings Button
                Button(action: onSettingsClick) {
                    // Align the rectangles to the leading edge (left)
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle()
                            .frame(width: 24, height: 2)
                            .foregroundColor(.primary)
                        Rectangle()
                            .frame(width: 20, height: 2)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 30, height: 30)
                }
                .padding(.leading)

                Spacer() // Pushes title towards center/right

                // Header Title
                Text(currentView == .journal ? "Journal" : "Loop")
                   .font(.futura(size: 32, weight: .bold))

                Spacer() // Pushes title towards center/left

                // Invisible Placeholder to balance the settings button
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
                    .padding(.trailing)
            }
            // .firstTextBaseline alignment handles vertical alignment
            
        }
        // Overall top positioning handled by ContentView
    }
}