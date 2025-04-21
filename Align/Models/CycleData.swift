import Foundation
import SwiftUI

// Node weights according to updated requirements
// Consider moving this to a shared configuration file/struct if used elsewhere (e.g., AnalysisService)
let NODE_WEIGHTS: [String: Double] = [
    // Core Levers (Total weight specified in algorithm affects normalization, not direct summation here)
    "Boost Energy": 0.30, // Composite score weight
    "Repay Debt": 0.25,   // Direct score weight
    "Nurture Home": 0.25, // Direct score weight

    // Energy Inputs (Contribute to Boost Energy composite score)
    "Training": 0.075,
    "Sleep": 0.075,
    "Healthy Food": 0.075,
    "Supplements": 0.075,

    // Secondary Nodes (Direct score weights)
    "Increase Focus": 0.05,
    "Execute Tasks": 0.05,
    "Generate Income": 0.05,
    "Mental Stability": 0.05,
]

struct FlowStep: Identifiable {
    let id: String
    let label: String
    let isPriority: Bool // May need re-evaluation based on single priority node logic
    var score: Int // TODO: Needs update from analysis service
    var change: Int // TODO: Needs update from analysis service

    // Display label mapping remains useful
    var displayLabel: String {
        switch id {
        case "Boost Energy": return "Energy"
        case "Increase Focus": return "Focus"
        case "Execute Tasks": return "Project" // Assuming "Execute Tasks" relates to project work
        case "Generate Income": return "Income"
        case "Repay Debt": return "Finance" // Map Repay Debt to Finance display label
        case "Nurture Home": return "Home"
        case "Mental Stability": return "Mental"
        default: return label
        }
    }
}

struct EnergyInput: Identifiable {
    let id: String
    let label: String
    var score: Int // TODO: Needs update from analysis service
}

// Priority struct now primarily used to format data for the PriorityCardView
struct Priority: Identifiable {
    let id: String // Keep identifiable
    let node: String // The priority node name
    let score: Int // The total display score
    let recommendation: String // The action recommendation
}

@MainActor // Ensure updates happen on the main thread
class CycleDataManager: ObservableObject {
    @Published var totalScore: Int = 0
    @Published var currentPriorityNode: String = "Boost Energy"
    @Published var currentPriorityRecommendation: String = "Loading recommendation..."
    @Published var priorities: [Priority] = []
    @Published var currentPriorityIndex: Int = 0
    @Published var flowSteps: [FlowStep] = []
    @Published var energyInputs: [EnergyInput] = []
    @Published var selectedNode: String? = nil

    private let databaseService: DatabaseService
    private let recommendations: [String: String] = [
        "Boost Energy": "Improve your energy through better routines and recovery.",
        "Repay Debt": "Set aside 30 minutes to review your budget and make a debt payment.",
        "Nurture Home": "Spend quality time with your partner or create a calming space at home.",
        "Default": "Focus on improving this area."
    ]

    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
        print("[CycleDataManager] Initialized.")
        setupInitialState()
        loadLatestData()
    }

    private func setupInitialState() {
        flowSteps = [
            FlowStep(id: "Boost Energy", label: "Boost Energy", isPriority: true, score: 0, change: 0),
            FlowStep(id: "Increase Focus", label: "Increase Focus", isPriority: false, score: 0, change: 0),
            FlowStep(id: "Execute Tasks", label: "Execute Tasks", isPriority: false, score: 0, change: 0),
            FlowStep(id: "Generate Income", label: "Generate Income", isPriority: false, score: 0, change: 0),
            FlowStep(id: "Repay Debt", label: "Repay Debt", isPriority: true, score: 0, change: 0),
            FlowStep(id: "Nurture Home", label: "Nurture Home", isPriority: true, score: 0, change: 0),
            FlowStep(id: "Mental Stability", label: "Mental Stability", isPriority: false, score: 0, change: 0)
        ]
        energyInputs = [
            EnergyInput(id: "Training", label: "Training", score: 0),
            EnergyInput(id: "Sleep", label: "Sleep", score: 0),
            EnergyInput(id: "Healthy Food", label: "Food", score: 0),
            EnergyInput(id: "Supplements", label: "Supplements", score: 0)
        ]
        updatePriorityDisplay()
        print("[CycleDataManager] Initial structure set.")
    }

    func loadLatestData() {
        Task {
            do {
                print("[CycleDataManager] Loading latest score and priority...")
                let (score, priority) = try await databaseService.getLatestDisplayScoreAndPriority()
                await MainActor.run {
                    self.totalScore = score ?? 0
                    self.currentPriorityNode = priority ?? "Boost Energy"
                    updatePriorityDisplay()
                    print("[CycleDataManager] Loaded - Score: \(self.totalScore), Priority: \(self.currentPriorityNode)")
                }
            } catch {
                print("‼️ [CycleDataManager] Error loading latest data: \(error)")
                await MainActor.run {
                    self.totalScore = 0
                    self.currentPriorityNode = "Boost Energy"
                    updatePriorityDisplay()
                }
            }
        }
    }

    private func updatePriorityDisplay() {
        let recommendationText = recommendations[self.currentPriorityNode] ?? recommendations["Default"]!
        let current = Priority(id: self.currentPriorityNode, node: self.currentPriorityNode, score: self.totalScore, recommendation: recommendationText)
        self.priorities = [current]
        self.currentPriorityIndex = 0
        self.currentPriorityRecommendation = recommendationText
        print("[CycleDataManager] Priority updated for node: \(self.currentPriorityNode)")
    }

    func getNodeInfo(for nodeId: String) -> (title: String, description: String, importance: String) {
        let map: [String: (String, String, String)] = [
            "Boost Energy": (
                "Boost Energy",
                "Your energy level affects everything downstream in the cycle. Focus on sleep, nutrition, exercise, and supplements to maintain optimal energy.",
                "Core lever (Composite Score derived from Training, Sleep, Healthy Food, Supplements)."
            ),
            // ... other nodes omitted for brevity
        ]
        return map[nodeId] ?? (nodeId, "Information about this node is not available.", "Weight information not available.")
    }
}

#Preview {
     let previewDbService = try! DatabaseService()
     let cycleManager = CycleDataManager(databaseService: previewDbService)

     return CycleView(presentNodeInfo: { _ in })
          .environmentObject(cycleManager)
          .environmentObject(ThemeManager())
}
