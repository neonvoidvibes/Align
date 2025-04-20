import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            // Use a ZStack for layering
            ZStack(alignment: .leading) {
                
                // Layer 1: Base Background (Always present, no effects)
                Rectangle()
                     .fill(Color(UIColor.systemBackground))
                     .ignoresSafeArea()

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
                // Background MUST be clear to see Layer 1 behind it
                .background(.clear)
                .cornerRadius(showSettings ? 20 : 0)
                .offset(x: showSettings ? geometry.size.width * 0.9 : 0)
                // Animate only transform changes here
                .animation(.easeInOut(duration: 0.3), value: showSettings)
                .disabled(showSettings) // Disable interaction when settings are open

                // Layer 3: Blur + Dimming Overlay (Conditional)
                // Sits ON TOP of main content.
                if showSettings {
                    Rectangle() // Base shape for effects
                        .fill(.clear) // Keep base clear for material
                        // Apply blur using a less intense system material
                        .background(.thinMaterial)
                        .overlay( // Apply dimming on top of blur
                            Color.black.opacity(0.4)
                        )
                        .ignoresSafeArea() // Cover entire screen uniformly
                        .allowsHitTesting(false) // Don't block interactions
                        .transition(.opacity) // Fade effects in/out
                }
                
                // Layer 4: Settings panel (Slides in on top)
                if showSettings {
                    SettingsView(isPresented: $showSettings)
                        .frame(width: geometry.size.width * 0.9)
                        .transition(.move(edge: .leading))
                        .zIndex(1) // Ensure settings view is visually on top
                }
            }
            // Animate the appearance/disappearance of conditional layers (Effect Overlay, Settings)
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