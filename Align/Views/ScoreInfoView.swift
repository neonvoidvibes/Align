import SwiftUI

struct ScoreInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .blur(radius: 12)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Total Loop Score")
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
                
                Text("The Total Loop Score represents your overall progress in maintaining a healthy personal feedback cycle. It measures how well you're balancing the key areas of your life that form a self-reinforcing loop: energy, focus, productivity, income, debt management, home environment, and mental stability.")
                    .font(.futura(size: 18))
                    .lineSpacing(4)
                
                Text("How it's calculated")
                    .font(.futura(size: 20, weight: .bold))
                    .foregroundColor(themeManager.accentColor)
                    .padding(.top, 8)
                
                Text("Your score is a weighted average of all nodes in your personal loop:")
                    .font(.futura(size: 18))
                
                VStack(alignment: .leading, spacing: 12) {
                    ScoreCategoryView(
                        title: "Core Levers (65%)",
                        items: [
                            "Boost Energy: 15%",
                            "Repay Debt: 25%",
                            "Nurture Home: 25%"
                        ]
                    )
                    
                    ScoreCategoryView(
                        title: "Energy Inputs (30%)",
                        items: [
                            "Training: 7.5%",
                            "Sleep: 7.5%",
                            "Healthy Food: 7.5%",
                            "Supplements: 7.5%"
                        ]
                    )
                    
                    ScoreCategoryView(
                        title: "Secondary Nodes (20%)",
                        items: [
                            "Increase Focus: 5%",
                            "Execute Tasks: 5%",
                            "Generate Income: 5%",
                            "Mental Stability: 5%"
                        ]
                    )
                }
                
                Text("The maximum score is 100, representing perfect balance across all areas of your life.")
                    .font(.futura(size: 14))
                    .italic()
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground).opacity(0.9))
            )
            .frame(width: UIScreen.main.bounds.width * 0.9, height: 500)
        }
    }
}

struct ScoreCategoryView: View {
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.futura(size: 16, weight: .bold))
            
            ForEach(items, id: \.self) { item in
                HStack(spacing: 4) {
                    Text("•")
                    Text(item)
                        .font(.futura(size: 14))
                }
                .padding(.leading, 8)
            }
        }
    }
}
