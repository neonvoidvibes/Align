import SwiftUI

@main
struct AlignApp: App {
    // Instantiate Services and Managers
    // Use @StateObject for objects that need to survive view updates and publish changes
    // Use simple let for services that don't publish or need persistent view state
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var databaseService = DatabaseService() // DB Service needs to be @StateObject if it publishes changes or needs persistence
    private let llmService = LLMService.shared // Use singleton pattern

    init() {
        // Perform initial setup (like DB schema check)
        // Note: DatabaseService init now triggers schema setup asynchronously
        print("AlignApp initialized. DatabaseService setup initiated.")
    }

    var body: some Scene {
        WindowGroup {
            // Pass services down to ContentView environment
            ContentView(databaseService: databaseService, llmService: llmService)
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