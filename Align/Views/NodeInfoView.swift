import SwiftUI

struct NodeInfoView: View {
    let title: String
    let description: String
    let importance: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .blur(radius: 12)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.futura(size: 24, weight: .bold))
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.bottom, 8)
                
                Divider()
                    .background(themeManager.accentColor)
                
                Text(description)
                    .font(.futura(size: 18))
                    .lineSpacing(4)
                
                Spacer()
                
                Text(importance)
                    .font(.futura(size: 16, weight: .medium))
                    .foregroundColor(themeManager.accentColor)
                    .padding(.top, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground).opacity(0.9))
            )
            .frame(width: UIScreen.main.bounds.width * 0.9, height: 300)
        }
    }
}
