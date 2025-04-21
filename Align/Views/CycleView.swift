import SwiftUI

struct CycleView: View {
    // Use EnvironmentObject to get the CycleDataManager provided by ContentView/AlignApp
    @EnvironmentObject private var cycleData: CycleDataManager
    @EnvironmentObject private var themeManager: ThemeManager

    // Closure provided by ContentView to handle presentation
    let presentNodeInfo: (String) -> Void

    var body: some View {
        // Simplified: Just the ScrollView containing the cards
        ScrollView {
            VStack(spacing: 16) { // Consistent spacing between cards
                // Priority Card (Uses data from cycleData.priorities, which holds the single current priority)
                PriorityCardView(
                     priority: cycleData.priorities.first ?? Priority(id: "loading", node: "Loading...", score: 0, recommendation: "..."), // Safely access the first (only) priority
                     isHighestPriority: true, // Always highest as it's the only one
                     showNavigation: false // Disable prev/next buttons
                 )

                // Total Loop Score (Uses data from cycleData.totalScore)
                TotalScoreView(
                    score: cycleData.totalScore,
                    onInfoTap: {
                        // Action removed - ScoreInfoView not implemented with new modal style yet
                    }
                )

                // Energy Inputs Card (Uses data from cycleData.energyInputs)
                // Note: Scores in energyInputs need to be updated from analysis results
                EnergyInputsCardView(
                    inputs: cycleData.energyInputs,
                    onInputTap: { inputId in
                        // Call the closure passed from ContentView
                        presentNodeInfo(inputId)
                    }
                )

                // Flow Steps Card (Uses data from cycleData.flowSteps)
                // Note: Scores/Changes in flowSteps need to be updated from analysis results
                FlowStepsCardView(
                    steps: cycleData.flowSteps,
                    // Use the directly published priority node name
                    priorityNode: cycleData.currentPriorityNode,
                    onStepTap: { stepId in
                        // Call the closure passed from ContentView
                        presentNodeInfo(stepId)
                    }
                )
            }
            .padding() // Keep existing padding
            .padding(.bottom, 30) // Add extra padding at the bottom
        }
        .onAppear {
            // Reload data when the view appears to ensure it's up-to-date
            cycleData.loadLatestData()
        }
        // No ZStack, animation, or disabled modifiers needed here anymore
    }
}

// MARK: - Subviews (PriorityCardView, TotalScoreView, etc.)

struct PriorityCardView: View {
     let priority: Priority // Accepts the single Priority object
    let isHighestPriority: Bool // To control background color
     let showNavigation: Bool // Flag to control nav elements
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighestPriority ? themeManager.accentColor : Color(UIColor.systemGray6))

            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 0) {
                     // Conditionally show Previous button
                     if showNavigation {
                          Button(action: { /* Action removed */ }) {
                              Image(systemName: "chevron.left")
                                  .font(.system(size: 24, weight: .bold))
                                  .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                                  .frame(width: 40, height: 40)
                                  .contentShape(Rectangle())
                          }
                          .padding(.leading, 8)
                          .offset(y: 5)
                     } else {
                          // Add placeholder for spacing if button hidden
                          Spacer().frame(width: 40, height: 40).padding(.leading, 8)
                     }

                    Spacer()

                    VStack(spacing: 8) {
                        Text(priority.node) // Display node name from priority object
                            .font(.futura(size: 24, weight: .bold))
                            .foregroundColor(isHighestPriority ? .black : .primary)

                        Text(priority.recommendation) // Display recommendation from priority object
                            .font(.futura(size: 18))
                            .multilineTextAlignment(.center)
                            .foregroundColor(isHighestPriority ? .black.opacity(0.8) : .gray)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer()

                    // Conditionally show Next button
                    if showNavigation {
                         Button(action: { /* Action removed */ }) {
                             Image(systemName: "chevron.right")
                                 .font(.system(size: 24, weight: .bold))
                                 .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                                 .frame(width: 40, height: 40)
                                 .contentShape(Rectangle())
                         }
                         .padding(.trailing, 8)
                         .offset(y: 5)
                     } else {
                          // Add placeholder for spacing if button hidden
                          Spacer().frame(width: 40, height: 40).padding(.trailing, 8)
                     }
                }

                 // Conditionally show pagination dots (currently shows only 1 if navigation enabled)
                 if showNavigation {
                      HStack(spacing: 6) {
                           // Replace with actual logic if multiple priorities are ever shown again
                          ForEach(0..<1, id: \.self) { index in // Show only 1 dot for now
                               let isActive = true // Always active as it's the only one
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
                 } // End if showNavigation
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

                            // TODO: Update this Text view when real scores are available
                            Text("\(input.score)") // Currently shows 0 from initialState
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
                                // TODO: Update change display when real data is available
                                HStack(spacing: 4) {
                                    Text(step.change > 0 ? "+\(step.change)" : "\(step.change)")
                                        .font(.futura(size: 16))
                                        .foregroundColor(.gray)

                                    Image(systemName: step.change >= 0 ? "arrow.up" : "arrow.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                // TODO: Update score display when real data is available
                                Text("\(step.score)") // Currently shows 0 from initialState
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

    // Color logic remains, uses priorityNode passed from CycleDataManager
    private func getStepColor(_ step: FlowStep) -> Color {
        if step.id == "Repay Debt" || step.id == "Boost Energy" || step.id == "Nurture Home" {
            return themeManager.accentColor
        }
        if step.id == priorityNode {
            return themeManager.accentColor
        }
        else if step.isPriority { // This might be redundant now?
            return themeManager.accentColor.opacity(0.7)
        }
        else {
            return .gray
        }
    }
}

// Preview Provider needs adjustment
 #Preview {
      // Create mock services for preview
      let previewDbService = DatabaseService()
      // Provide the DB service to CycleDataManager
      let cycleManager = CycleDataManager(databaseService: previewDbService)

      // Simulate loading some data for preview if desired
       // Task { try? await Task.sleep(nanoseconds: 100_000_000); cycleManager.loadLatestData() }

      return CycleView(presentNodeInfo: { nodeId in print("Preview tapped node: \(nodeId)") })
           .environmentObject(cycleManager) // Provide CycleDataManager
           .environmentObject(ThemeManager()) // Provide ThemeManager
           .padding()
           .background(Color(UIColor.systemGray6))
 }
