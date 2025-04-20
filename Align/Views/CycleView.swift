import SwiftUI

struct CycleView: View {
    @StateObject private var cycleData = CycleDataManager()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showScoreInfo = false
    @State private var showNodeInfo = false
    @State private var nodeInfoData: (title: String, description: String, importance: String) = ("", "", "")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) { // Consistent spacing between cards
                // Priority Card
                PriorityCardView(
                    priority: cycleData.priorities[cycleData.currentPriorityIndex],
                    isHighestPriority: cycleData.currentPriorityIndex == 0, // Keep for background color logic
                    currentPriorityIndex: cycleData.currentPriorityIndex, // Pass index
                    prioritiesCount: cycleData.priorities.count, // Pass count
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
            .padding() // Keep existing padding
            .padding(.bottom, 30) // Add extra padding at the bottom
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
    let isHighestPriority: Bool // To control background color
    let currentPriorityIndex: Int // Index of the currently shown priority
    let prioritiesCount: Int // Total number of priorities for dots
    let onPrevious: () -> Void
    let onNext: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    // Remove internal cycleData instance
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighestPriority ? themeManager.accentColor : Color(UIColor.systemGray6))
            
            VStack(spacing: 8) {
                // Removed "HIGHEST PRIORITY" text block
                
                HStack(spacing: 0) { // Use spacing 0 for precise control with Spacers
                    // Left Chevron Button
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                            .frame(width: 40, height: 40) // Give button a frame for consistent tap area
                            .contentShape(Rectangle())
                    }
                    .padding(.leading, 8) // Padding from card edge
                    
                    Spacer() // Pushes text to center
                    
                    // Text Content VStack
                    VStack(spacing: 8) {
                        Text(priority.node)
                            .font(.futura(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : .primary)
                        
                        Text(priority.recommendation)
                            .font(.futura(size: 18))
                            .multilineTextAlignment(.center)
                            .foregroundColor(isHighestPriority ? .black.opacity(0.8) : .gray)
                            .lineLimit(2) // Limit lines to prevent excessive height changes
                    }
                    .frame(maxWidth: .infinity) // Allow text to take available space
                    
                    Spacer() // Pushes text to center
                    
                    // Right Chevron Button
                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                            .frame(width: 40, height: 40) // Give button a frame
                            .contentShape(Rectangle())
                    }
                    .padding(.trailing, 8) // Padding from card edge
                }
                .frame(height: 100) // Give HStack a fixed height if needed to prevent layout jumps further

                // Priority indicators
                HStack(spacing: 6) {
                    // Use prioritiesCount passed from parent view
                    ForEach(0..<prioritiesCount, id: \.self) { index in
                        // Check if this dot represents the currently displayed priority
                        let isActive = index == currentPriorityIndex
                        // Use Capsule for active dot, Circle for inactive
                        Group {
                            if isActive {
                                Capsule()
                                    .frame(width: 16, height: 6) // Elongated shape for active
                            } else {
                                Circle()
                                    .frame(width: 6, height: 6) // Standard circle for inactive
                            }
                        }
                        .foregroundColor(
                            isActive
                            ? (isHighestPriority ? .black : themeManager.accentColor) // Active color
                            : (isHighestPriority ? .black.opacity(0.3) : Color.gray.opacity(0.3)) // Inactive color
                        )
                        .animation(.easeInOut(duration: 0.2), value: isActive) // Animate shape/color change
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        // Removed fixed height to allow natural spacing based on content
    }
    // Removed internal cycleData instance
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
                
                // Removed info button
            }
            .padding()
        }
        // Removed fixed height to allow natural spacing based on content
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
        // Explicitly color Finance/Repay Debt with accent color
        if step.id == "Repay Debt" {
            return themeManager.accentColor
        }
        // Color the node currently shown in the priority card
        if step.id == priorityNode {
            return themeManager.accentColor
        }
        // Dim other priority nodes
        else if step.isPriority {
            return themeManager.accentColor.opacity(0.7)
        }
        // Default color for non-priority nodes
        else {
            return .gray
        }
    }
}