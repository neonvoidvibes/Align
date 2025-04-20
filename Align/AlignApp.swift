import SwiftUI

@main
struct AlignApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    // Ensure theme is applied on app launch
                    applyTheme()
                }
                .onChange(of: themeManager.theme) { _ in
                    applyTheme()
                }
        }
    }
    
    private func applyTheme() {
        // Apply theme to UIKit components
        let userInterfaceStyle: UIUserInterfaceStyle
        switch themeManager.theme {
        case .dark:
            userInterfaceStyle = .dark
        case .light:
            userInterfaceStyle = .light
        case .system:
            userInterfaceStyle = .unspecified
        }
        
        UIApplication.shared.windows.forEach { window in
            window.overrideUserInterfaceStyle = userInterfaceStyle
        }
    }
}
