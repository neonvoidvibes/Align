import SwiftUI
import Combine

enum AppView {
    case history // Add history as the first view
    case journal
    case loop
}

class AppState: ObservableObject {
    // Start on the new History view by default
    @Published var currentView: AppView = .history
    @Published var accentColor: Color = Color(hex: "00FFC2")
    @Published var streakCount: Int = 3
    @Published var moodValue: Double = 75
    
    // Computed property for mood label
    var moodLabel: String {
        if moodValue < 25 { return "Reflective" }
        if moodValue < 50 { return "Calm" }
        if moodValue < 75 { return "Balanced" }
        if moodValue < 90 { return "Energized" }
        return "Inspired"
    }
    
    // Computed property for mood color
    var moodColor: Color {
        if moodValue < 25 { return .blue }
        if moodValue < 50 { return .teal }
        if moodValue < 75 { return .green }
        if moodValue < 90 { return .orange }
        return .pink
    }
}