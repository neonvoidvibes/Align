import SwiftUI

struct CycleView: View {
    @EnvironmentObject private var cycleData: CycleDataManager
    @EnvironmentObject private var themeManager: ThemeManager

    let presentNodeInfo: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PriorityCardView(
                    priority: cycleData.priorities.first ?? Priority(id: "loading", node: "Loading...", score: 0, recommendation: "..."),
                    isHighestPriority: true,
                    showNavigation: false
                )

                TotalScoreView(
                    score: cycleData.totalScore,
                    onInfoTap: { }
                )

                EnergyInputsCardView(
                    inputs: cycleData.energyInputs,
                    onInputTap: { inputId in
                        presentNodeInfo(inputId)
                    }
                )

                FlowStepsCardView(
                    steps: cycleData.flowSteps,
                    priorityNode: cycleData.currentPriorityNode,
                    onStepTap: { stepId in
                        presentNodeInfo(stepId)
                    }
                )
            }
            .padding()
            .padding(.bottom, 30)
        }
        .onAppear {
            cycleData.loadLatestData()
        }
    }
}

struct PriorityCardView: View {
    let priority: Priority
    let isHighestPriority: Bool
    let showNavigation: Bool
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighestPriority ? themeManager.accentColor : Color(UIColor.systemGray6))

            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    if showNavigation {
                        Button(action: { }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                        }
                        .padding(.leading, 8)
                        .offset(y: 5)
                    } else {
                        Spacer().frame(width: 40, height: 40).padding(.leading, 8)
                    }

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

                    if showNavigation {
                        Button(action: { }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                        }
                        .padding(.trailing, 8)
                        .offset(y: 5)
                    } else {
                        Spacer().frame(width: 40, height: 40).padding(.trailing, 8)
                    }
                }

                if showNavigation {
                    HStack(spacing: 6) {
                        ForEach(0..<1, id: \.self) { _ in
                            Capsule()
                                .frame(width: 16, height: 6)
                                .foregroundColor(isHighestPriority ? .black : themeManager.accentColor)
                                .animation(.easeInOut(duration: 0.2), value: true)
                        }
                    }
                    .padding(.top, 8)
                }
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
        if step.isPriority {
            return themeManager.accentColor.opacity(0.7)
        }
        return .gray
    }
}

#Preview {
    let previewDbService = try! DatabaseService()
    let cycleManager = CycleDataManager(databaseService: previewDbService)

    return CycleView(presentNodeInfo: { _ in })
        .environmentObject(cycleManager)
        .environmentObject(ThemeManager())
}
