import Foundation
import SwiftUI
import Combine // Added for @MainActor and potentially future publishers

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
    var score: Int // Updated from analysis service via CycleDataManager
    var change: Int // Updated from analysis service via CycleDataManager

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
    var score: Int // Updated from analysis service via CycleDataManager
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
                print("[CycleDataManager] Loading latest score, priority, and category scores...")
                // Fetch score, priority, and category scores together
                // Remove await as getLatest... is synchronous and both classes are @MainActor
                let (score, priority, categoryScores) = try databaseService.getLatestDisplayScoreAndPriority()
                let displayScore = score ?? 0
                let currentPriority = priority ?? "Boost Energy"

                // No need to fetch category scores separately anymore
                print("[CycleDataManager] Received \(categoryScores.count) category scores from DB.")

                // --- Fetch Previous Day's Scores for Change Calculation ---
                // Determine the date for which scores were fetched
                // We need the date associated with the fetched scores to find the *previous* day's scores
                // Let's modify getLatest... again slightly to return the date reliably
                // For now, assume categoryScores relate to 'today' conceptually if latestDate was nil (edge case)
                // This part needs refinement based on how getLatest... determines the date implicitly
                let calendar = Calendar.current
                // Ideally, get 'latestDate' from the DB query result directly
                // As a temporary measure, let's assume the scores are for the current day if no date was explicitly returned
                // This assumption might be wrong if analysis runs late.
                let dateForScores = Date() // Placeholder - Needs date from DB
                var previousCategoryScores: [String: Double] = [:]
                if let previousDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for:dateForScores)) {
                    previousCategoryScores = (try? await databaseService.fetchCategoryScores(for: previousDate)) ?? [:]
                    let prevDateString = previousDate.formatted(date: .abbreviated, time: .omitted)
                    print("[CycleDataManager] Fetched \(previousCategoryScores.count) category scores for previous date \(prevDateString)")
                } else {
                     print("[CycleDataManager] Could not calculate previous date.")
                     previousCategoryScores = [:]
                }
                // --- End Fetch Previous Day's Scores ---


                await MainActor.run {
                    self.totalScore = displayScore
                    self.currentPriorityNode = currentPriority
                    updatePriorityDisplay() // Update priority card based on node and total score

                    // Update individual step/input scores based on categoryScores and previousCategoryScores
                    updateFlowStepsAndInputs(currentScores: categoryScores, previousScores: previousCategoryScores)

                    print("[CycleDataManager] Loaded - Score: \(self.totalScore), Priority: \(self.currentPriorityNode)")
                }
            } catch {
                print("‼️ [CycleDataManager] Error loading latest data: \(error)")
                await MainActor.run {
                    // Reset to defaults on error
                    self.totalScore = 0
                    self.currentPriorityNode = "Boost Energy"
                    updatePriorityDisplay()
                    // Reset scores with empty dictionaries
                    updateFlowStepsAndInputs(currentScores: [:], previousScores: [:])
                }
            }
        }
    }


    private func updatePriorityDisplay() {
        let recommendationText = recommendations[self.currentPriorityNode] ?? recommendations["Default"]!
        // Use self.totalScore directly here
        let current = Priority(id: self.currentPriorityNode, node: self.currentPriorityNode, score: self.totalScore, recommendation: recommendationText)
        self.priorities = [current]
        self.currentPriorityIndex = 0
        self.currentPriorityRecommendation = recommendationText
        print("[CycleDataManager] Priority updated for node: \(self.currentPriorityNode)")
    }

    func getNodeInfo(for nodeId: String) -> (title: String, description: String, importance: String) {
        // Node descriptions including weight/type information
        // TODO: Expand descriptions for all nodes
        let nodeInfoMap: [String: (String, String, String)] = [
             "Boost Energy": (
                 "Boost Energy",
                 "This score reflects your overall energy level, derived from Training, Sleep, Healthy Food, and Supplements. High energy fuels focus and execution.",
                 "Core Lever (Composite Score, Weight: 30%)"
             ),
             "Increase Focus": (
                 "Increase Focus",
                 "Measures your ability to concentrate and avoid distractions. Influenced by energy levels and mental clarity.",
                 "Secondary Node (Direct Score, Weight: 5%)"
             ),
             "Execute Tasks": (
                 "Execute Tasks",
                 "Represents progress on planned tasks and projects. Directly impacted by focus and energy.",
                 "Secondary Node (Direct Score, Weight: 5%)"
             ),
             "Generate Income": (
                 "Generate Income",
                 "Tracks progress towards income goals through work or other activities.",
                 "Secondary Node (Direct Score, Weight: 5%)"
             ),
             "Repay Debt": (
                 "Repay Debt",
                 "Monitors efforts towards reducing financial debt and improving financial stability.",
                 "Core Lever (Direct Score, Weight: 25%)"
             ),
             "Nurture Home": (
                 "Nurture Home",
                 "Reflects time and effort invested in home life and key relationships.",
                 "Core Lever (Direct Score, Weight: 25%)"
             ),
             "Mental Stability": (
                 "Mental Stability",
                 "Indicates emotional balance and resilience. Influenced by all other cycle nodes.",
                 "Secondary Node (Direct Score, Weight: 5%)"
             ),
             // Energy Inputs - Explain their contribution
             "Training": (
                 "Training",
                 "Score based on physical activity duration and consistency. Contributes to Boost Energy.",
                 "Energy Input (Weight towards Energy: 7.5%)"
             ),
             "Sleep": (
                 "Sleep",
                 "Score based on sleep duration and quality. Contributes to Boost Energy.",
                 "Energy Input (Weight towards Energy: 7.5%)"
             ),
             "Healthy Food": (
                 "Healthy Food",
                 "Score reflecting nutritious food choices. Contributes to Boost Energy.",
                 "Energy Input (Weight towards Energy: 7.5%)"
             ),
             "Supplements": (
                 "Supplements",
                 "Score based on consistent intake of planned supplements. Contributes to Boost Energy.",
                 "Energy Input (Weight towards Energy: 7.5%)"
             )
         ]
         return nodeInfoMap[nodeId] ?? (nodeId, "Information about this node is not available.", "Weight information not available.")
    }

    // Helper function to update FlowStep and EnergyInput scores, now including previous scores
    private func updateFlowStepsAndInputs(currentScores: [String: Double], previousScores: [String: Double]) {
        // Update FlowSteps
        // Correct loop: Iterate directly over indices
        for i in flowSteps.indices {
            let stepId = flowSteps[i].id
            let currentNormalizedScore = currentScores[stepId] ?? 0.0
            let previousNormalizedScore = previousScores[stepId] ?? 0.0

            // Convert normalized scores (0-1) to display scores (0-100)
            let currentDisplayScore = Int(round(currentNormalizedScore * 100))
            let previousDisplayScore = Int(round(previousNormalizedScore * 100))

            flowSteps[i].score = currentDisplayScore
            flowSteps[i].change = currentDisplayScore - previousDisplayScore // Calculate change

            print("  [CycleDataUpdate] Updated FlowStep '\(stepId)' score to \(flowSteps[i].score), change: \(flowSteps[i].change)")

        }

        // Update EnergyInputs
        // Correct loop: Iterate directly over indices
        for i in energyInputs.indices {
            let inputId = energyInputs[i].id
            if let normalizedScore = currentScores[inputId] {
                // Convert normalized score (0-1) to display score (0-100)
                energyInputs[i].score = Int(round(normalizedScore * 100))
                print("  [CycleDataUpdate] Updated EnergyInput '\(inputId)' score to \(energyInputs[i].score)")
            } else {
                energyInputs[i].score = 0 // Default to 0 if not found
                print("  [CycleDataUpdate] Category score not found for EnergyInput '\(inputId)', setting score to 0")
            }
        }
        print("[CycleDataManager] Finished updating FlowStep and EnergyInput scores.")
    }
}

// Preview remains the same, using mock/initial data
#Preview {
     let previewDbService = try! DatabaseService()
     let cycleManager = CycleDataManager(databaseService: previewDbService)

     return CycleView(presentNodeInfo: { _ in })
          .environmentObject(cycleManager)
          .environmentObject(ThemeManager())
 }  
