import SwiftUI

struct StreakIndicatorView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7) { index in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(getColor(for: index))
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6).opacity(0.5))
        .cornerRadius(20)
        .padding(.bottom, 8)
    }
    
    private func getColor(for index: Int) -> Color {
        if index < 3 {
            return appState.moodColor
        } else if index == 3 {
            return Color.gray.opacity(0.7)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}
