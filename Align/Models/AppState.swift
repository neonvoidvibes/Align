import SwiftUI
import Combine

enum AppView {
    case notes // Renamed from history
    case journal
    case loop
}

class AppState: ObservableObject {
    // Start on Journal view by default
    @Published var currentView: AppView = .journal
    @Published var accentColor: Color = Color(hex: "00FFC2")
    // Removed streakCount and moodValue - These should come from analysis results eventually
    // @Published var streakCount: Int = 3
    // @Published var moodValue: Double = 75

    /* // Computed properties for mood removed - Handled by analysis / CycleView display
    var moodLabel: String {
        if moodValue < 25 { return "Reflective" }
        if moodValue < 50 { return "Calm" }
        if moodValue < 75 { return "Balanced" }
        if moodValue < 90 { return "Energized" }
        return "Inspired"
    }
    */
}
