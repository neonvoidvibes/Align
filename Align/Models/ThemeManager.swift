import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    enum AppTheme: String, CaseIterable {
        case dark
        case light
        case system
    }
    
    enum FontSize: String, CaseIterable {
        case standard
        case large
    }
    
    @Published var theme: AppTheme = .dark {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
            updateColorScheme()
        }
    }
    
    @Published var fontSize: FontSize = .standard {
        didSet {
            UserDefaults.standard.set(fontSize.rawValue, forKey: "fontSize")
        }
    }
    
    @Published var accentColor: Color = Color(hex: "00FFC2") {
        didSet {
            UserDefaults.standard.set(accentColor.hexString, forKey: "accentColor")
        }
    }
    
    @Published var colorScheme: ColorScheme?
    
    init() {
        // Load saved preferences
        if let savedTheme = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.theme = theme
        }
        
        if let savedFontSize = UserDefaults.standard.string(forKey: "fontSize"),
           let fontSize = FontSize(rawValue: savedFontSize) {
            self.fontSize = fontSize
        }
        
        if let savedAccentColor = UserDefaults.standard.string(forKey: "accentColor") {
            self.accentColor = Color(hex: savedAccentColor)
        }
        
        updateColorScheme()
    }
    
    private func updateColorScheme() {
        switch theme {
        case .dark:
            colorScheme = .dark
        case .light:
            colorScheme = .light
        case .system:
            colorScheme = nil // This will use the system setting
        }
        
        // Apply theme changes to UIKit components
        let userInterfaceStyle: UIUserInterfaceStyle
        switch theme {
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
    
    // Predefined accent colors
    let accentColors: [Color] = [
        Color(hex: "00FFC2"), // Teal
        Color(hex: "9D50FF"), // Purple
        Color(hex: "0099FF"), // Blue
        Color(hex: "FF9500"), // Orange
        Color(hex: "FF2D55")  // Pink
    ]
}
