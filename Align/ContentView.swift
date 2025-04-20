import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                HStack(spacing: 0) {
                    // Settings panel
                    if showSettings {
                        SettingsView(isPresented: $showSettings)
                            .frame(width: geometry.size.width * 0.8)
                            .transition(.move(edge: .leading))
                    }
                    
                    // Main content
                    VStack(spacing: 0) {
                        TabNavigationView(
                            currentView: $appState.currentView,
                            onSettingsClick: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSettings.toggle()
                                }
                            }
                        )
                        // .padding(.top, 0) // Removed explicit top padding to place it right below the safe area/notch
                        
                        if appState.currentView == .journal {
                            JournalView()
                        } else {
                            CycleView()
                        }
                        
                        Spacer() // Push content to fill available space
                    }
                    .padding(.top, 50) // Added padding to push content down
                    .frame(width: geometry.size.width)
                    .offset(x: showSettings ? geometry.size.width * 0.8 : 0)
                }
                .animation(.easeInOut(duration: 0.3), value: showSettings)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
    }
}