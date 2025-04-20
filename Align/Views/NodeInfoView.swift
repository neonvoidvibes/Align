import SwiftUI

struct NodeInfoView: View {
    // Use Binding for presentation control
    @Binding var isPresented: Bool
    
    let title: String
    let description: String
    let importance: String
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        // Removed outer ZStack with background blur effect
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.futura(size: 24, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    // Use the binding to dismiss
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(themeManager.accentColor) // Keep accent color for 'X'
                }
            }
            .padding(.bottom, 8)
            
            Divider()
                .background(themeManager.accentColor)
            
            Text(description)
                .font(.futura(size: 18))
                .lineSpacing(4)
            
            Spacer() // Pushes importance text to bottom
            
            Text(importance)
                .font(.futura(size: 16, weight: .medium))
                .foregroundColor(themeManager.accentColor)
                .padding(.top, 8)
        }
        .padding()
        // Apply solid background to the content VStack
        .background(
            RoundedRectangle(cornerRadius: 16)
                // Use system background for the modal panel itself
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 10) // Optional shadow for depth
        )
        // Constrain the size of the modal panel
        .frame(width: UIScreen.main.bounds.width * 0.9, height: 350) // Adjusted height slightly
    }
}