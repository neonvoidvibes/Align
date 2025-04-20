import SwiftUI

struct TabNavigationView: View {
    @Binding var currentView: AppView
    var onSettingsClick: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    // Selected: Original 54 * 0.75 = 40.5 -> 41
    // Unselected: Half of new selected = 40.5 / 2 = 20.25 -> 20
    // Height: Original 3 * 1.25 = 3.75
    private let selectedNavBarWidth: CGFloat = 41
    private let unselectedNavBarWidth: CGFloat = 20
    private let navBarHeight: CGFloat = 3.75

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
                    VStack(alignment: .leading, spacing: 4) { // Adjust spacing if needed for larger bars
                        // Increase bar size by 25% (width and height)
                        Rectangle()
                            .frame(width: 30, height: 2.5) // 24 * 1.25 = 30, 2 * 1.25 = 2.5
                            .foregroundColor(.primary)
                        Rectangle()
                            .frame(width: 25, height: 2.5) // 20 * 1.25 = 25, 2 * 1.25 = 2.5
                            .foregroundColor(.primary)
                    }
                    // Increase frame size by 25% (30 * 1.25 = 37.5 -> 38)
                    .frame(width: 38, height: 38)
                }
                .padding(.leading) // Keep padding for spacing from edge
                // Remove padding, use offset instead for visual shift only
                // .padding(.top, 8)
                .offset(y: 6) // Apply vertical offset to shift icon down

                Spacer() // Pushes title towards center/right

                // Header Title
                Text(currentView == .journal ? "Journal" : "Loop")
                   .font(.futura(size: 32, weight: .bold))

                Spacer() // Pushes title towards center/left

                // This helps keep the title visually centered.
                Rectangle()
                    .fill(Color.clear)
                    // Match new larger settings button frame size
                    .frame(width: 38, height: 38)
                    .padding(.trailing) // Keep padding consistent

            }
            
        }
        // Overall top positioning handled by ContentView
    }
}