import SwiftUI

@main
struct AlignApp: App {
    // Instantiate Services and Managers
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    // Initialize DatabaseService synchronously using StateObject
    @StateObject private var databaseService: DatabaseService
    private let llmService = LLMService.shared // Use singleton pattern

    init() {
        // Initialize synchronous DatabaseService directly
        do {
            // This initialization now happens synchronously
            let dbService = try DatabaseService()
            _databaseService = StateObject(wrappedValue: dbService)
             print("AlignApp initialized. DatabaseService setup completed synchronously.")
        } catch {
             print("‼️ FATAL ERROR: Failed to initialize DatabaseService: \(error)")
             // Using fatalError as DB is critical for the app to function
             fatalError("Database initialization failed: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Instantiate CycleDataManager here, passing the DatabaseService
            // databaseService is guaranteed to be initialized here (or app would have crashed)
            let cycleDataManager = CycleDataManager(databaseService: databaseService)

            ContentView(databaseService: databaseService, llmService: llmService, cycleData: cycleDataManager)
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(cycleDataManager) // Provide CycleDataManager to environment
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear { applyTheme() }
                .onChange(of: themeManager.theme) { applyTheme() }
            // Removed .task for DB initialization
        }
    }

    private func applyTheme() {
        let userInterfaceStyle: UIUserInterfaceStyle
        switch themeManager.theme {
        case .dark: userInterfaceStyle = .dark
        case .light: userInterfaceStyle = .light
        case .system: userInterfaceStyle = .unspecified
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .forEach { windowScene in
                windowScene.windows.forEach { $0.overrideUserInterfaceStyle = userInterfaceStyle }
            }
    }
}

// Removed Placeholder as fatalError is used on init failure now
// @MainActor
// class DatabaseServicePlaceholder: DatabaseService { ... }
