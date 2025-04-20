import SwiftUI

struct TabNavigationView: View {
    @Binding var currentView: AppView
    var onSettingsClick: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Define constants for nav bar dimensions
    private let selectedNavBarWidth: CGFloat = 80
    private let unselectedNavBarWidth: CGFloat = 40
    private let navBarHeight: CGFloat = 3 // Slightly shorter height

    var body: some View {
        VStack(spacing: 12) { // Adjust overall vertical spacing if needed
            // Row 1: Settings Icon (Aligned to the left)
            HStack {
                Button(action: onSettingsClick) {
                    VStack(spacing: 4) {
                        Rectangle()
                            .frame(width: 24, height: 2)
                            .foregroundColor(.primary)
                        Rectangle()
                            .frame(width: 20, height: 2)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 30, height: 30) // Keep adjusted frame
                }
                .padding(.leading)
                
                Spacer() // Pushes the button to the left
            }
            // No specific vertical alignment needed here as it's alone in the HStack

            // Row 2: Navigation Bars (Centered)
            HStack(spacing: 8) {
                ForEach(0..<2) { index in
                    let isActive = (index == 0 && currentView == .journal) || (index == 1 && currentView == .loop)
                    let targetView: AppView = index == 0 ? .journal : .loop
                    
                    Capsule()
                        .fill(isActive ? themeManager.accentColor : Color.gray.opacity(0.3))
                        .frame(width: isActive ? selectedNavBarWidth : unselectedNavBarWidth, height: navBarHeight)
                        .contentShape(Rectangle()) // Increase tap area
                        .onTapGesture {
                            // Only change view if it's not the current one
                            if currentView != targetView {
                                currentView = targetView
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isActive) // Animate width change
                }
            }
            // This HStack is centered by default within the VStack

            // Row 3: Header Title (Centered, aligned with Settings icon vertically if needed)
            HStack(alignment: .firstTextBaseline) { // Use HStack for potential future alignment needs
                 Spacer() // Center the text
                 Text(currentView == .journal ? "Journal" : "Loop")
                    .font(.futura(size: 32, weight: .bold))
                 Spacer() // Center the text
            }
             // Add padding if needed, e.g., .padding(.bottom, 4)
             // Note: Vertical alignment with the settings icon is now implicit due to VStack structure
             // We align the settings icon within its own row and the title within its own row.
        }
        // Parent view's padding (.padding(.top, 50) in ContentView) handles the overall top positioning
    }
}