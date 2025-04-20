import SwiftUI

struct CycleView: View {
    @StateObject private var cycleData = CycleDataManager()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showScoreInfo = false
    @State private var showNodeInfo = false
    @State private var nodeInfoData: (title: String, description: String, importance: String) = ("", "", "")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Priority Card
                PriorityCardView(
                    priority: cycleData.priorities[cycleData.currentPriorityIndex],
                    isHighestPriority: cycleData.currentPriorityIndex == 0,
                    onPrevious: cycleData.previousPriority,
                    onNext: cycleData.nextPriority
                )
                
                // Total Loop Score
                TotalScoreView(
                    score: cycleData.totalScore,
                    onInfoTap: {
                        showScoreInfo = true
                    }
                )
                
                // Energy Inputs Card
                EnergyInputsCardView(
                    inputs: cycleData.energyInputs,
                    onInputTap: { inputId in
                        nodeInfoData = cycleData.getNodeInfo(for: inputId)
                        showNodeInfo = true
                    }
                )
                
                // Flow Steps Card
                FlowStepsCardView(
                    steps: cycleData.flowSteps,
                    priorityNode: cycleData.priorities[cycleData.currentPriorityIndex].node,
                    onStepTap: { stepId in
                        nodeInfoData = cycleData.getNodeInfo(for: stepId)
                        showNodeInfo = true
                    }
                )
            }
            .padding()
        }
        .sheet(isPresented: $showScoreInfo) {
            ScoreInfoView()
        }
        .sheet(isPresented: $showNodeInfo) {
            NodeInfoView(
                title: nodeInfoData.title,
                description: nodeInfoData.description,
                importance: nodeInfoData.importance
            )
        }
    }
}

struct PriorityCardView: View {
    let priority: Priority
    let isHighestPriority: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighestPriority ? themeManager.accentColor : Color(UIColor.systemGray6))
            
            VStack(spacing: 8) {
                if isHighestPriority {
                    Text("HIGHEST PRIORITY")
                        .font(.futura(size: 14, weight: .bold))
                        .foregroundColor(.black)
                }
                
                HStack {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Priority: \(priority.node)")
                            .font(.futura(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : .primary)
                        
                        Text(priority.recommendation)
                            .font(.futura(size: 18))
                            .multilineTextAlignment(.center)
                            .foregroundColor(isHighestPriority ? .black.opacity(0.8) : .gray)
                    }
                    .padding(.horizontal)
                    
                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                    }
                }
                
                // Priority indicators
                HStack(spacing: 6) {
                    ForEach(0..<7) { index in
                        Circle()
                            .frame(width: index == cycleData.currentPriorityIndex ? 12 : 6, height: 6)
                            .foregroundColor(
                                index == cycleData.currentPriorityIndex
                                ? (isHighestPriority ? .black : themeManager.accentColor)
                                : (isHighestPriority ? .black.opacity(0.3) : Color.gray.opacity(0.3))
                            )
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(height: 180)
    }
    
    private var cycleData: CycleDataManager {
        return CycleDataManager()
    }
}

struct TotalScoreView: View {
    let score: Int
    let onInfoTap: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemGray6))
            
            VStack(spacing: 8) {
                Text("Total Loop Score")
                    .font(.futura(size: 18))
                    .foregroundColor(.gray)
                
                Text("\(score)")
                    .font(.futura(size: 64, weight: .bold))
                    .foregroundColor(themeManager.accentColor)
                
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .position(x: 280, y: -40)
            }
            .padding()
        }
        .frame(height: 120)
    }
}

struct EnergyInputsCardView: View {
    let inputs: [EnergyInput]
    let onInputTap: (String) -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemGray6))
            
            VStack(spacing: 16) {
                Text("Energy Inputs")
                    .font(.futura(size: 24, weight: .bold))
                    .foregroundColor(themeManager.accentColor)
                
                VStack(spacing: 0) {
                    ForEach(inputs) { input in
                        HStack {
                            Text(input.label)
                                .font(.futura(size: 24, weight: .bold))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("\(input.score)")
                                .font(.futura(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onInputTap(input.id)
                        }
                        
                        if input.id != inputs.last?.id {
                            Divider()
                                .background(Color.gray.opacity(0.2))
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct FlowStepsCardView: View {
    let steps: [FlowStep]
    let priorityNode: String
    let onStepTap: (String) -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemGray6))
            
            VStack(spacing: 16) {
                Text("Flow Steps")
                    .font(.futura(size: 24, weight: .bold))
                    .foregroundColor(themeManager.accentColor)
                
                VStack(spacing: 0) {
                    ForEach(steps) { step in
                        HStack {
                            Text(step.displayLabel)
                                .font(.futura(size: 24, weight: .bold))
                                .foregroundColor(getStepColor(step))
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Text(step.change > 0 ? "+\(step.change)" : "\(step.change)")
                                        .font(.futura(size: 16))
                                        .foregroundColor(.gray)
                                    
                                    Image(systemName: step.change >= 0 ? "arrow.up" : "arrow.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Text("\(step.score)")
                                    .font(.futura(size: 24, weight: .bold))
                                    .foregroundColor(getStepColor(step))
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onStepTap(step.id)
                        }
                        
                        if step.id != steps.last?.id {
                            Divider()
                                .background(Color.gray.opacity(0.2))
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func getStepColor(_ step: FlowStep) -> Color {
        if step.id == priorityNode {
            return themeManager.accentColor
        } else if step.isPriority {
            return themeManager.accentColor.opacity(0.7)
        } else {
            return .gray
        }
    }
}
