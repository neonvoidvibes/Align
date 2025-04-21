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
    let node: String // The priority node name (e.g., "Boost Energy")
    let score: Int // The total display score (associated with the priority card)
    let recommendation: String // The action recommendation for the priority node
}

@MainActor // Ensure updates happen on the main thread
class CycleDataManager: ObservableObject {
    // Published properties reflecting the current state fetched from DB
    @Published var totalScore: Int = 0
    @Published var currentPriorityNode: String = "Boost Energy" // Default priority until loaded
    @Published var currentPriorityRecommendation: String = "Loading recommendation..."

    // Published array derived from the single priority node for the card view
    @Published var priorities: [Priority] = [] // This will hold only the single current priority
    @Published var currentPriorityIndex: Int = 0 // Always 0 as there's only one priority shown

    // Internal structure for display, scores need real data hookup
    @Published var flowSteps: [FlowStep] = [] // Keep for structure, score needs update from analysis
    @Published var energyInputs: [EnergyInput] = [] // Keep for structure, score needs update from analysis

    @Published var selectedNode: String? = nil // For NodeInfoView interaction

    // Dependency
    private let databaseService: DatabaseService

    // Predefined recommendations mapped to node IDs
    private let recommendations: [String: String] = [
        "Boost Energy": "Improve your energy through better routines and recovery.",
        "Repay Debt": "Set aside 30 minutes to review your budget and make a debt payment.",
        "Nurture Home": "Spend quality time with your partner or create a calming space at home.",
        // Add other nodes if they can become priorities, though algorithm implies only these 3
        "Default": "Focus on improving this area."
    ]


    // Remove default value to prevent MainActor isolation error
    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
        print("[CycleDataManager] Initialized.")
        setupInitialState() // Set up default structure
        loadLatestData() // Load real data on init
    }

    // Sets up the initial structure of flowSteps and energyInputs with default values
    private func setupInitialState() {
         // Initialize flowSteps and energyInputs with default structure but zero scores
         // These scores will need to be updated based on fetched analysis results eventually
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
         updatePriorityDisplay() // Initialize priority display with defaults
         print("[CycleDataManager] Initial structure set.")
    }

    // Fetches the latest score and priority node from the database
    func loadLatestData() {
        Task {
            do {
                print("[CycleDataManager] Loading latest score and priority...")
                let (score, priority) = try await databaseService.getLatestDisplayScoreAndPriority()
                await MainActor.run {
                    self.totalScore = score ?? 0 // Default to 0 if nil
                    self.currentPriorityNode = priority ?? "Boost Energy" // Default if nil
                     // Update display elements based on new priority
                     updatePriorityDisplay()
                     // TODO: Update individual flowStep/energyInput scores
                     // This requires fetching detailed score breakdown (e.g., from Scores or RawValues table)
                     // Example: Fetch normalized scores for each category and apply to flowSteps/energyInputs
                    print("[CycleDataManager] Loaded - Score: \(self.totalScore), Priority: \(self.currentPriorityNode)")
                }
            } catch {
                print("‼️ [CycleDataManager] Error loading latest data: \(error)")
                // Keep defaults on error
                 await MainActor.run {
                      self.totalScore = 0
                      self.currentPriorityNode = "Boost Energy"
                      updatePriorityDisplay()
                 }
            }
        }
    }

    // Updates the `priorities` array (which only holds the current priority)
    // This array is used by the PriorityCardView.
    private func updatePriorityDisplay() {
          let recommendationText = recommendations[self.currentPriorityNode] ?? recommendations["Default"]!

          let currentPriorityStruct = Priority(
               id: self.currentPriorityNode, // Use node ID as identifier
               node: self.currentPriorityNode,
               score: self.totalScore, // Show the total score on the priority card
               recommendation: recommendationText
          )
          self.priorities = [currentPriorityStruct] // Only show the current one
          self.currentPriorityIndex = 0 // Always index 0
          self.currentPriorityRecommendation = recommendationText // Update separate recommendation property if needed elsewhere
          print("[CycleDataManager] Priority display updated for node: \(self.currentPriorityNode)")
     }


    // Provides detailed information for a specific node ID (used by NodeInfoView)
    func getNodeInfo(for nodeId: String) -> (title: String, description: String, importance: String) {
        // TODO: Update importance strings to reflect actual calculation method if different from weights
        let nodeInfoMap: [String: (title: String, description: String, importance: String)] = [
            "Boost Energy": (
                title: "Boost Energy",
                description: "Your energy level affects everything downstream in the cycle. Focus on sleep, nutrition, exercise, and supplements to maintain optimal energy.",
                importance: "Core lever (Composite Score derived from Training, Sleep, Healthy Food, Supplements)." // Clarified composite nature
            ),
            "Increase Focus": (
                title: "Increase Focus",
                description: "Your ability to concentrate and direct attention effectively. Better focus leads to more productive work sessions.",
                importance: "Secondary node. Contributes \(String(format: "%.0f%%", (NODE_WEIGHTS["Increase Focus"] ?? 0.0) * 100)) to total score."
            ),
            "Execute Tasks": (
                title: "Execute Tasks",
                description: "Completing app development and consulting work. This directly generates your income.",
                 importance: "Secondary node. Contributes \(String(format: "%.0f%%", (NODE_WEIGHTS["Execute Tasks"] ?? 0.0) * 100)) to total score."
            ),
            "Generate Income": (
                title: "Generate Income",
                description: "The financial results of your work. This feeds directly into debt repayment and cash reserves.",
                 importance: "Secondary node. Contributes \(String(format: "%.0f%%", (NODE_WEIGHTS["Generate Income"] ?? 0.0) * 100)) to total score."
            ),
             "Repay Debt": ( // Changed ID from Stabilize Finances
                 title: "Repay Debt", // Changed Title
                 description: "Reducing financial obligations and building cash reserves. This reduces stress and improves future options.",
                  importance: "Core lever. Contributes \(String(format: "%.0f%%", (NODE_WEIGHTS["Repay Debt"] ?? 0.0) * 100)) to total score." // Corrected weight/label
             ),
            "Nurture Home": (
                title: "Nurture Home",
                description: "Creating a calm living environment and maintaining healthy relationships. This directly impacts mental stability.",
                 importance: "Core lever. Contributes \(String(format: "%.0f%%", (NODE_WEIGHTS["Nurture Home"] ?? 0.0) * 100)) to total score."
            ),
            "Mental Stability": (
                title: "Mental Stability",
                description: "Your overall psychological wellbeing. This feeds back into energy levels, completing the cycle.",
                 importance: "Secondary node. Contributes \(String(format: "%.0f%%", (NODE_WEIGHTS["Mental Stability"] ?? 0.0) * 100)) to total score."
            ),
            // Energy Inputs - Explain their contribution to Boost Energy
            "Training": (
                title: "Training",
                description: "Physical exercise that builds strength, endurance, and overall fitness.",
                 importance: "Energy input. Contributes to Boost Energy composite score (Weighted \(String(format: "%.1f%%", (NODE_WEIGHTS["Training"] ?? 0.0) * 100))).",
            ),
            "Sleep": (
                title: "Sleep",
                description: "Quality and quantity of rest, critical for recovery and cognitive function.",
                 importance: "Energy input. Contributes to Boost Energy composite score (Weighted \(String(format: "%.1f%%", (NODE_WEIGHTS["Sleep"] ?? 0.0) * 100))).",
            ),
            "Healthy Food": (
                title: "Healthy Food",
                description: "Nutritious diet that provides essential nutrients for optimal functioning.",
                 importance: "Energy input. Contributes to Boost Energy composite score (Weighted \(String(format: "%.1f%%", (NODE_WEIGHTS["Healthy Food"] ?? 0.0) * 100))).",
            ),
            "Supplements": (
                title: "Supplements",
                description: "Additional nutritional support to address specific deficiencies or needs.",
                 importance: "Energy input. Contributes to Boost Energy composite score (Weighted \(String(format: "%.1f%%", (NODE_WEIGHTS["Supplements"] ?? 0.0) * 100))).",
            )
        ]

        return nodeInfoMap[nodeId] ?? (
            title: nodeId,
            description: "Information about this node is not available.",
            importance: "Weight information not available."
        )
    }

    // Removed next/previous priority as we now only show the single current priority
    /*
    func nextPriority() {
        // Logic removed
    }

    func previousPriority() {
        // Logic removed
    }
    */
}

// Add preview provider if needed
 #Preview {
      // Create mock services for preview
      // DatabaseService init is @MainActor, ensure preview runs in a MainActor context implicitly or explicitly if needed.
      // SwiftUI Previews generally run on the main thread.
      let previewDbService = DatabaseService()
      let cycleManager = CycleDataManager(databaseService: previewDbService) // Pass explicitly

      // Example View using the manager
      // CycleView itself now uses environmentObject for cycleData
      return CycleView(presentNodeInfo: { _ in })
           .environmentObject(cycleManager) // Provide the manager to the environment
           .environmentObject(ThemeManager()) // Provide ThemeManager for preview
           .padding()
           .background(Color(UIColor.systemGray6))
 }
