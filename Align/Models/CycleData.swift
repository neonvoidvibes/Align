import Foundation
import SwiftUI

// Node weights according to updated requirements
let NODE_WEIGHTS: [String: Double] = [
    // Core Levers (75% total)
    "Boost Energy": 0.15, // Reduced from 0.25 to make room for Energy Inputs
    "Repay Debt": 0.25,
    "Nurture Home": 0.25,
    // Energy Inputs (30% total, 7.5% each)
    "Training": 0.075,
    "Sleep": 0.075,
    "Healthy Food": 0.075,
    "Supplements": 0.075,
    // Secondary Nodes (20% total)
    "Increase Focus": 0.05,
    "Execute Tasks": 0.05,
    "Generate Income": 0.05,
    "Mental Stability": 0.05,
]

struct FlowStep: Identifiable {
    let id: String
    let label: String
    let isPriority: Bool
    var score: Int
    var change: Int
    
    var displayLabel: String {
        switch id {
        case "Boost Energy": return "Energy"
        case "Increase Focus": return "Focus"
        case "Execute Tasks": return "Project"
        case "Generate Income": return "Income"
        case "Repay Debt": return "Finance"
        case "Nurture Home": return "Home"
        case "Mental Stability": return "Mental"
        default: return label
        }
    }
}

struct EnergyInput: Identifiable {
    let id: String
    let label: String
    var score: Int
}

struct Priority: Identifiable {
    let id: String
    let node: String
    let score: Int
    let recommendation: String
}

class CycleDataManager: ObservableObject {
    @Published var totalScore: Int = 0
    @Published var flowSteps: [FlowStep] = []
    @Published var energyInputs: [EnergyInput] = []
    @Published var priorities: [Priority] = []
    @Published var currentPriorityIndex: Int = 0
    @Published var selectedNode: String? = nil
    
    init() {
        loadMockData()
        calculateTotalScore()
    }
    
    private func loadMockData() {
        // Mock node scores (0-100)
        let mockNodeScores: [String: Int] = [
            "Boost Energy": 65,
            "Increase Focus": 70,
            "Execute Tasks": 80,
            "Generate Income": 75,
            "Repay Debt": 40,
            "Nurture Home": 60,
            "Mental Stability": 55,
            "Training": 50,
            "Sleep": 60,
            "Healthy Food": 70,
            "Supplements": 40,
        ]
        
        // Generate random changes (-10 to +10)
        let generateRandomChange = { () -> Int in
            return Int.random(in: -10...10)
        }
        
        // Create flow steps
        flowSteps = [
            FlowStep(id: "Boost Energy", label: "Boost Energy", isPriority: true, score: mockNodeScores["Boost Energy"] ?? 65, change: -7),
            FlowStep(id: "Increase Focus", label: "Increase Focus", isPriority: false, score: mockNodeScores["Increase Focus"] ?? 70, change: 3),
            FlowStep(id: "Execute Tasks", label: "Execute Tasks", isPriority: false, score: mockNodeScores["Execute Tasks"] ?? 80, change: 6),
            FlowStep(id: "Generate Income", label: "Generate Income", isPriority: false, score: mockNodeScores["Generate Income"] ?? 75, change: 3),
            FlowStep(id: "Repay Debt", label: "Repay Debt", isPriority: true, score: mockNodeScores["Repay Debt"] ?? 40, change: 3),
            FlowStep(id: "Nurture Home", label: "Nurture Home", isPriority: true, score: mockNodeScores["Nurture Home"] ?? 60, change: 4),
            FlowStep(id: "Mental Stability", label: "Mental Stability", isPriority: false, score: mockNodeScores["Mental Stability"] ?? 55, change: 7)
        ]
        
        // Create energy inputs
        energyInputs = [
            EnergyInput(id: "Training", label: "Training", score: mockNodeScores["Training"] ?? 50),
            EnergyInput(id: "Sleep", label: "Sleep", score: mockNodeScores["Sleep"] ?? 60),
            EnergyInput(id: "Healthy Food", label: "Food", score: mockNodeScores["Healthy Food"] ?? 70),
            EnergyInput(id: "Supplements", label: "Supplements", score: mockNodeScores["Supplements"] ?? 40)
        ]
        
        // Create priorities
        let recommendations: [String: String] = [
            "Boost Energy": "Focus on improving your overall energy management through better routines and recovery.",
            "Repay Debt": "Set aside 30 minutes to review your budget and make a debt payment.",
            "Nurture Home": "Spend quality time with your partner or create a calming space at home.",
            "Training": "Schedule 3-4 short but intense workout sessions this week.",
            "Sleep": "Establish a consistent sleep schedule and aim for 7-8 hours of quality sleep.",
            "Healthy Food": "Prepare nutrient-dense meals and reduce processed food consumption.",
            "Supplements": "Consider adding key supplements like vitamin D, magnesium, and omega-3s to your routine."
        ]
        
        // Create priorities based on core levers and energy inputs
        let coreLevers = [
            (node: "Boost Energy", score: mockNodeScores["Boost Energy"] ?? 65),
            (node: "Repay Debt", score: mockNodeScores["Repay Debt"] ?? 40),
            (node: "Nurture Home", score: mockNodeScores["Nurture Home"] ?? 60),
            (node: "Training", score: mockNodeScores["Training"] ?? 50),
            (node: "Sleep", score: mockNodeScores["Sleep"] ?? 60),
            (node: "Healthy Food", score: mockNodeScores["Healthy Food"] ?? 70),
            (node: "Supplements", score: mockNodeScores["Supplements"] ?? 40)
        ]
        
        // Sort by score (ascending) to prioritize the lowest scores
        let sortedLevers = coreLevers.sorted { $0.score < $1.score }
        
        // Create priority objects
        priorities = sortedLevers.enumerated().map { index, lever in
            Priority(
                id: UUID().uuidString,
                node: lever.node,
                score: lever.score,
                recommendation: recommendations[lever.node] ?? "Focus on improving this area."
            )
        }
    }
    
    func calculateTotalScore() {
        var score = 0.0
        
        // Calculate score from flow steps
        for step in flowSteps {
            if let weight = NODE_WEIGHTS[step.id] {
                score += Double(step.score) * weight
            }
        }
        
        // Calculate score from energy inputs
        for input in energyInputs {
            if let weight = NODE_WEIGHTS[input.id] {
                score += Double(input.score) * weight
            }
        }
        
        // Ensure the score is between 0-100
        totalScore = min(100, Int(round(score)))
    }
    
    func getNodeInfo(for nodeId: String) -> (title: String, description: String, importance: String) {
        let nodeInfoMap: [String: (title: String, description: String, importance: String)] = [
            "Boost Energy": (
                title: "Boost Energy",
                description: "Your energy level affects everything downstream in the cycle. Focus on sleep, nutrition, exercise, and supplements to maintain optimal energy.",
                importance: "Core lever with 15% weight in your total score."
            ),
            "Increase Focus": (
                title: "Increase Focus",
                description: "Your ability to concentrate and direct attention effectively. Better focus leads to more productive work sessions.",
                importance: "Secondary node with 5% weight in your total score."
            ),
            "Execute Tasks": (
                title: "Execute Tasks",
                description: "Completing app development and consulting work. This directly generates your income.",
                importance: "Secondary node with 5% weight in your total score."
            ),
            "Generate Income": (
                title: "Generate Income",
                description: "The financial results of your work. This feeds directly into debt repayment and cash reserves.",
                importance: "Secondary node with 5% weight in your total score."
            ),
            "Repay Debt": (
                title: "Repay Debt",
                description: "Reducing financial obligations and building cash reserves. This reduces stress and improves future options.",
                importance: "Core lever with 25% weight in your total score."
            ),
            "Nurture Home": (
                title: "Nurture Home",
                description: "Creating a calm living environment and maintaining healthy relationships. This directly impacts mental stability.",
                importance: "Core lever with 25% weight in your total score."
            ),
            "Mental Stability": (
                title: "Mental Stability",
                description: "Your overall psychological wellbeing. This feeds back into energy levels, completing the cycle.",
                importance: "Secondary node with 5% weight in your total score."
            ),
            "Training": (
                title: "Training",
                description: "Physical exercise that builds strength, endurance, and overall fitness.",
                importance: "Energy input with 7.5% weight in your total score."
            ),
            "Sleep": (
                title: "Sleep",
                description: "Quality and quantity of rest, critical for recovery and cognitive function.",
                importance: "Energy input with 7.5% weight in your total score."
            ),
            "Healthy Food": (
                title: "Healthy Food",
                description: "Nutritious diet that provides essential nutrients for optimal functioning.",
                importance: "Energy input with 7.5% weight in your total score."
            ),
            "Supplements": (
                title: "Supplements",
                description: "Additional nutritional support to address specific deficiencies or needs.",
                importance: "Energy input with 7.5% weight in your total score."
            )
        ]
        
        return nodeInfoMap[nodeId] ?? (
            title: nodeId,
            description: "Information about this node is not available.",
            importance: "Weight information not available."
        )
    }
    
    func nextPriority() {
        currentPriorityIndex = (currentPriorityIndex + 1) % priorities.count
    }
    
    func previousPriority() {
        currentPriorityIndex = (currentPriorityIndex - 1 + priorities.count) % priorities.count
    }
}
