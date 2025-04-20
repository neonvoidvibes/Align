import SwiftUI

struct CycleView: View {
    @StateObject private var cycleData = CycleDataManager()
    @EnvironmentObject private var themeManager: ThemeManager
    // Reintroduce state variables for NodeInfo modal
    @State private var showNodeInfo = false
    @State private var selectedNodeId: String? = nil
    
    var body: some View {
        // Wrap content in ZStack for modal layering
        ZStack {
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
                            // Action removed - ScoreInfoView not implemented with new modal style yet
                        }
                    )
                    
                    // Energy Inputs Card
                    EnergyInputsCardView(
                        inputs: cycleData.energyInputs,
                        onInputTap: { inputId in
                            // Trigger modal presentation
                            selectedNodeId = inputId
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showNodeInfo = true
                            }
                        }
                    )
                    
                    // Flow Steps Card
                    FlowStepsCardView(
                        steps: cycleData.flowSteps,
                        priorityNode: cycleData.priorities[cycleData.currentPriorityIndex].node,
                        onStepTap: { stepId in
                            // Trigger modal presentation
                            selectedNodeId = stepId
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showNodeInfo = true
                            }
                        }
                    )
                }
                .padding() // Keep existing padding
                .padding(.bottom, 30) // Add extra padding at the bottom
            }
            // Disable scrollview interaction when modal is shown
            .disabled(showNodeInfo)

            // Layer for background effects when modal is shown
            if showNodeInfo {
                Rectangle()
                    .fill(.clear)
                    .background(.thinMaterial) // Consistent blur
                    .overlay(Color.black.opacity(0.4)) // Consistent dim
                    .ignoresSafeArea()
                    .transition(.opacity)
                    // Allow tapping background to dismiss modal
                    .onTapGesture {
                         withAnimation(.easeInOut(duration: 0.3)) {
                            showNodeInfo = false
                         }
                    }
            }

            // Layer for NodeInfoView modal content
            if showNodeInfo, let nodeId = selectedNodeId {
                let nodeInfo = cycleData.getNodeInfo(for: nodeId)
                NodeInfoView(
                    isPresented: $showNodeInfo, // Pass binding
                    title: nodeInfo.title,
                    description: nodeInfo.description,
                    importance: nodeInfo.importance
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95))) // Example transition
                .zIndex(2) // Ensure modal is on top of effect layer
            }
        }
        // Apply animation to the ZStack container for transitions
        .animation(.easeInOut(duration: 0.3), value: showNodeInfo)
    }
}

// MARK: - Subviews (PriorityCardView, TotalScoreView, etc.)

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
                // Removed "HIGHEST PRIORITY" text block
                
                // Set alignment to .center for vertical centering of chevrons/text
                HStack(alignment: .center, spacing: 0) {
                    // Left Chevron Button
                    Button(action: onPrevious) {
                        // Revert to simple Image inside Button
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                            .frame(width: 40, height: 40) // Keep fixed frame for consistent size
                            .contentShape(Rectangle())
                    }
                    // Remove maxHeight frame, rely on HStack alignment
                    .padding(.leading, 8) // Padding from card edge
                    .offset(y: 5) // Nudge chevron down slightly
                    
                    Spacer() // Pushes text to center
                    
                    // Text Content VStack
                    VStack(spacing: 8) {
                        // Removed "Priority: " prefix
                        Text(priority.node)
                            .font(.futura(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : .primary)
                        
                        Text(priority.recommendation)
                            .font(.futura(size: 18))
                            .multilineTextAlignment(.center)
                            .foregroundColor(isHighestPriority ? .black.opacity(0.8) : .gray)
                            .lineLimit(3) // Increase line limit to 3
                    }
                    .frame(maxWidth: .infinity) // Allow text to take available space
                    
                    Spacer() // Pushes text to center
                    
                    // Right Chevron Button
                    Button(action: onNext) {
                        // Revert to simple Image inside Button
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                            .frame(width: 40, height: 40) // Keep fixed frame for consistent size
                            .contentShape(Rectangle())
                    }
                    // Remove maxHeight frame, rely on HStack alignment
                    .padding(.trailing, 8) // Padding from card edge
                    .offset(y: 5) // Nudge chevron down slightly
                }
                // Removed fixed height to allow natural vertical sizing

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
                        
                        // Removed Divider block
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
                                    // Use primary color for gray steps, accent for accent steps
                                    .foregroundColor(getStepColor(step) == .gray ? .primary : getStepColor(step))
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onStepTap(step.id)
                        }
                        
                        // Removed Divider block
                    }
                }
            }
            .padding()
        }
    }
    
    private func getStepColor(_ step: FlowStep) -> Color {
        // Explicitly color core levers Energy, Finance, Home with accent color
        if step.id == "Repay Debt" || step.id == "Boost Energy" || step.id == "Nurture Home" {
            return themeManager.accentColor
        }
        // Color the node currently shown in the priority card (if different from above)
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
