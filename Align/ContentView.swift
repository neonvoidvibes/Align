import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            // Use a ZStack for layering settings and main content
            ZStack(alignment: .leading) {
                
                // Main content view
                VStack(spacing: 0) {
                    TabNavigationView(
                        currentView: $appState.currentView,
                        onSettingsClick: {
                            // Use withAnimation for smooth transitions
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSettings.toggle()
                            }
                        }
                    )
                    // Remove explicit top padding; ZStack safe area handling should position it correctly
                    // .padding(.top, 50)
                    
                    if appState.currentView == .journal {
                        JournalView()
                    } else {
                        CycleView()
                    }
                    
                    Spacer() // Push content to fill available space
                }
                // Apply transformations when settings are shown
                .offset(x: showSettings ? geometry.size.width * 0.9 : 0)
                // .scaleEffect(showSettings ? 0.95 : 1.0) // Removed scale effect
                .cornerRadius(showSettings ? 20 : 0) // Keep rounded corners when pushed aside
                .blur(radius: showSettings ? 10 : 0) // Add blur effect
                // Add dimming overlay
                .overlay(
                    Color.black
                        .opacity(showSettings ? 0.4 : 0)
                        .cornerRadius(showSettings ? 20 : 0) // Match corner radius
                        .allowsHitTesting(showSettings) // Allow tapping overlay to potentially dismiss settings (optional)
                )
                // Animate these changes (offset, cornerRadius, blur, overlay opacity)
                .animation(.easeInOut(duration: 0.3), value: showSettings)
                .disabled(showSettings) // Disable interaction when settings are open
                // Background for the VStack, ignoring safe area to fill behind rounded corners/scale
                .background(Color(UIColor.systemBackground).ignoresSafeArea(.container, edges: .all))
                
                // Settings panel (conditionally shown)
                if showSettings {
                    SettingsView(isPresented: $showSettings)
                        .frame(width: geometry.size.width * 0.9) // Set width
                        // Apply background here to ensure SettingsView is opaque
                        .background(Color(UIColor.systemGray6))
                        .transition(.move(edge: .leading)) // Slide in/out
                        .zIndex(1) // Ensure settings view is on top
                }
            }
            // Background for the ZStack, respecting safe areas
            .background(Color(UIColor.systemBackground))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
    }
}