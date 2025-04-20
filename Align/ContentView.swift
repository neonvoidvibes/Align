import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            // Use a ZStack for layering
            ZStack(alignment: .leading) {
                
                // Layer 1: Background Blur Layer (Conditional)
                // Sits behind everything, provides blur when settings are open.
                if showSettings {
                    Rectangle()
                        // Use clear fill, the material provides the visual. Or use .regularMaterial directly.
                        .fill(.clear)
                        // Apply blur using system material for standard look
                        .background(.regularMaterial)
                        .ignoresSafeArea() // Cover entire screen
                        .transition(.opacity) // Fade blur in/out
                } else {
                    // Non-blurred background when settings are closed
                    Rectangle()
                         .fill(Color(UIColor.systemBackground))
                         .ignoresSafeArea()
                }

                // Layer 2: Main content view (Moves aside)
                VStack(spacing: 0) {
                    TabNavigationView(
                        currentView: $appState.currentView,
                        onSettingsClick: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSettings.toggle()
                            }
                        }
                    )
                    
                    if appState.currentView == .journal {
                        JournalView()
                    } else {
                        CycleView()
                    }
                    
                    Spacer()
                }
                // Background MUST be clear to see blur layer behind it
                .background(.clear)
                .cornerRadius(showSettings ? 20 : 0)
                .offset(x: showSettings ? geometry.size.width * 0.9 : 0)
                // Animate only transform changes here
                .animation(.easeInOut(duration: 0.3), value: showSettings)
                .disabled(showSettings) // Disable interaction when settings are open

                // Layer 3: Dimming Overlay (Conditional)
                // Sits ON TOP of main content and background blur layer.
                if showSettings {
                    Color.black
                        .opacity(0.4) // Dimming level
                        .ignoresSafeArea() // Cover entire screen uniformly
                        .allowsHitTesting(false) // Don't block interactions
                        .transition(.opacity) // Fade dim in/out
                }
                
                // Layer 4: Settings panel (Slides in on top)
                if showSettings {
                    SettingsView(isPresented: $showSettings)
                        .frame(width: geometry.size.width * 0.9)
                        .transition(.move(edge: .leading))
                        .zIndex(1) // Ensure settings view is visually on top
                }
            }
            // Animate the appearance/disappearance of conditional layers (Blur, Dim, Settings)
            .animation(.easeInOut(duration: 0.3), value: showSettings)
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