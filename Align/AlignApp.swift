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
                // Updated onChange syntax (ignoring parameters)
                .onChange(of: themeManager.theme) {
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
        
        // Use modern API to access windows via scenes
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .forEach { windowScene in
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = userInterfaceStyle
                }
            }
    }
}