import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            // Use a ZStack for layering settings and main content
            ZStack(alignment: .leading) {
                
                // Dedicated Background Layer (Handles base color, blur, dim)
                Rectangle()
                    .fill(Color(UIColor.systemBackground)) // Base color
                    .ignoresSafeArea() // Cover entire screen including safe areas
                    .blur(radius: showSettings ? 10 : 0) // Apply blur conditionally
                    .overlay( // Apply dimming overlay conditionally
                        Color.black
                            .opacity(showSettings ? 0.4 : 0)
                            .ignoresSafeArea() // Ensure overlay also covers safe areas
                    )
                    // Animate the effects on the background layer
                    .animation(.easeInOut(duration: 0.3), value: showSettings)
                
                // Main content view (Sits on top of the background layer)
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
                    // No explicit top padding, rely on system safe area handling for initial position
                    
                    if appState.currentView == .journal {
                        JournalView()
                    } else {
                        CycleView()
                    }
                    
                    Spacer() // Push content to fill available space
                }
                // 1. Make the VStack background clear, so it reveals the blurred/dimmed layer underneath
                .background(.clear)
                 // 2. Apply rounded corners
                .cornerRadius(showSettings ? 20 : 0)
                 // 3. Apply offset
                .offset(x: showSettings ? geometry.size.width * 0.9 : 0)
                // 4. Opacity removed - main content remains opaque
                // 5. Animate transform changes on the main content view
                .animation(.easeInOut(duration: 0.3), value: showSettings)
                 // 6. Disable interaction when settings are open
                .disabled(showSettings)

                // Settings panel (conditionally shown on top)
                if showSettings {
                    SettingsView(isPresented: $showSettings)
                        .frame(width: geometry.size.width * 0.9) // Set width
                        // SettingsView itself provides its background
                        .transition(.move(edge: .leading)) // Slide in/out
                        .zIndex(1) // Ensure settings view is on top
                }
            }
            // No background modifier needed directly on ZStack anymore
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