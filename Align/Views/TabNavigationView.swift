import SwiftUI

struct TabNavigationView: View {
    @Binding var currentView: AppView
    var onSettingsClick: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) { // Reduced spacing
            HStack {
                Button(action: onSettingsClick) {
                    VStack(spacing: 4) {
                        Rectangle()
                            .frame(width: 24, height: 2)
                            .foregroundColor(.primary)
                        Rectangle()
                            .frame(width: 20, height: 2)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 30, height: 20)
                }
                .padding(.leading)
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach(0..<2) { index in
                    let isActive = (index == 0 && currentView == .journal) || (index == 1 && currentView == .loop)
                    
                    Capsule()
                        .frame(width: 80, height: 4)
                        .foregroundColor(isActive ? themeManager.accentColor : Color.gray.opacity(0.3))
                        .onTapGesture {
                            currentView = index == 0 ? .journal : .loop
                        }
                }
            }
            
            Text(currentView == .journal ? "Journal" : "Loop")
                .font(.futura(size: 32, weight: .bold))
                .padding(.bottom, 4) // Reduced bottom padding
        }
        .padding(.top, 0) // Remove top padding
    }
}
