import SwiftUI

struct CycleView: View {
    // Use EnvironmentObject if provided by ContentView, or StateObject if managed here
    // Assuming EnvironmentObject based on new ContentView structure
    @EnvironmentObject private var cycleData: CycleDataManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Closure provided by ContentView to handle presentation
    let presentNodeInfo: (String) -> Void
    
    var body: some View {
        // Simplified: Just the ScrollView containing the cards
        ScrollView {
            VStack(spacing: 16) { // Consistent spacing between cards
                // Priority Card
                PriorityCardView(
                    priority: cycleData.priorities[cycleData.currentPriorityIndex],
                    isHighestPriority: cycleData.currentPriorityIndex == 0,
                    currentPriorityIndex: cycleData.currentPriorityIndex,
                    prioritiesCount: cycleData.priorities.count,
                    onPrevious: cycleData.previousPriority,
                    onNext: cycleData.nextPriority
                )
                
                // Total Loop Score
                TotalScoreView(
                    score: cycleData.totalScore,
                    onInfoTap: {
                        // Action removed - ScoreInfoView not implemented with new modal style yet
                    }
                )
                
                // Energy Inputs Card
                EnergyInputsCardView(
                    inputs: cycleData.energyInputs,
                    onInputTap: { inputId in
                        // Call the closure passed from ContentView
                        presentNodeInfo(inputId)
                    }
                )
                
                // Flow Steps Card
                FlowStepsCardView(
                    steps: cycleData.flowSteps,
                    priorityNode: cycleData.priorities[cycleData.currentPriorityIndex].node,
                    onStepTap: { stepId in
                        // Call the closure passed from ContentView
                        presentNodeInfo(stepId)
                    }
                )
            }
            .padding() // Keep existing padding
            .padding(.bottom, 30) // Add extra padding at the bottom
        }
        // No ZStack, animation, or disabled modifiers needed here anymore
    }
}

// MARK: - Subviews (PriorityCardView, TotalScoreView, etc.) - Keep these structs as they were

struct PriorityCardView: View {
    let priority: Priority
    let isHighestPriority: Bool // To control background color
    let currentPriorityIndex: Int // Index of the currently shown priority
    let prioritiesCount: Int // Total number of priorities for dots
    let onPrevious: () -> Void
    let onNext: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighestPriority ? themeManager.accentColor : Color(UIColor.systemGray6))
            
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 0) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .padding(.leading, 8)
                    .offset(y: 5)
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text(priority.node)
                            .font(.futura(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : .primary)
                        
                        Text(priority.recommendation)
                            .font(.futura(size: 18))
                            .multilineTextAlignment(.center)
                            .foregroundColor(isHighestPriority ? .black.opacity(0.8) : .gray)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .padding(.trailing, 8)
                    .offset(y: 5)
                }

                HStack(spacing: 6) {
                    ForEach(0..<prioritiesCount, id: \.self) { index in
                        let isActive = index == currentPriorityIndex
                        Group {
                            if isActive {
                                Capsule()
                                    .frame(width: 16, height: 6)
                            } else {
                                Circle()
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .foregroundColor(
                            isActive
                            ? (isHighestPriority ? .black : themeManager.accentColor)
                            : (isHighestPriority ? .black.opacity(0.3) : Color.gray.opacity(0.3))
                        )
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
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
            }
            .padding()
        }
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
                                    .foregroundColor(getStepColor(step) == .gray ? .primary : getStepColor(step))
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onStepTap(step.id)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func getStepColor(_ step: FlowStep) -> Color {
        if step.id == "Repay Debt" || step.id == "Boost Energy" || step.id == "Nurture Home" {
            return themeManager.accentColor
        }
        if step.id == priorityNode {
            return themeManager.accentColor
        }
        else if step.isPriority {
            return themeManager.accentColor.opacity(0.7)
        }
        else {
            return .gray
        }
    }
}