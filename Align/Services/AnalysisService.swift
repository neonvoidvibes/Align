import Foundation

// Actor to handle analysis generation safely in the background
actor AnalysisService {
    private let databaseService: DatabaseService
    private let llmService: LLMService

    // Constants from PRD/Algorithm
    private let decayFactor: Double = 0.9
    private let windowDays: Int = 7
    private let nodeTargets: [String: Double] = [
        "Training": 30.0,          // minutes
        "Sleep": 7.0 * 60.0,       // minutes (converted from hours)
        "HealthyFood": 3.0,        // meals/count
        "Supplements": 4.0,        // intakes/count
        "IncreaseFocus": 1.0,      // rating (assuming 0-1)
        "ExecuteTasks": 1.0,       // Planned tasks per day (assuming 1 for now, could be configurable)
        "GenerateIncome": 100.0,   // Daily income target (example, needs configuration)
        "MentalStability": 1.0,    // rating (assuming 0-1)
        "Repay Debt": 50.0,        // Daily debt repayment target (example, needs configuration)
        "Nurture Home": 60.0       // Daily partner time target (example, needs configuration)
    ]
    // Use NODE_WEIGHTS defined in CycleData.swift (consider moving to a shared config)
    private let nodeWeights = NODE_WEIGHTS

    init(databaseService: DatabaseService, llmService: LLMService) {
        self.databaseService = databaseService
        self.llmService = llmService
        print("[AnalysisService] Initialized.")
    }

    // Main function to trigger analysis for a specific message
    func generateAnalysis(for messageId: UUID) async {
        print("➡️ [AnalysisService] Starting analysis for message ID: \(messageId)")
        do {
            // 1. Fetch the message content
            guard let message = try await databaseService.fetchChatMessage(withId: messageId) else {
                print("‼️ [AnalysisService] Could not fetch message \(messageId). Aborting analysis.")
                return
            }
             // Only analyze user messages for now
             guard message.role == .user else {
                  print("[AnalysisService] Skipping analysis for non-user message \(messageId).")
                  // Mark as processed anyway? Or ignore? Let's mark as processed to avoid re-checking.
                  try await databaseService.markChatMessageProcessed(messageId)
                  return
             }

            // 2. Extract Quantitative Values using LLM
            print("[AnalysisService] Extracting values from message: '\(message.content.prefix(50))...'")
            let extractedValues = await extractValuesFromMessage(messageContent: message.content)
            print("[AnalysisService] Extracted values: \(extractedValues)")

            // 3. Get today's date (start of day)
             let calendar = Calendar.current
             let today = calendar.startOfDay(for: message.timestamp) // Use message timestamp for the relevant day

            // 4. Fetch previous day's raw values
            print("[AnalysisService] Fetching previous day's raw values...")
            let previousDay = calendar.date(byAdding: .day, value: -1, to: today)!
            let previousRawValues = try await databaseService.fetchRawValues(for: previousDay)
            print("[AnalysisService] Previous day values: \(previousRawValues)")

            // 5. Calculate & Store Today's Raw Values (with decay)
            var todayRawValues: [String: Double] = [:]
             for category in nodeWeights.keys { // Iterate through all defined categories
                 if let extractedValue = extractedValues[category] {
                     todayRawValues[category] = extractedValue
                     print("   [RawValue Calc] Category '\(category)': Using extracted value \(extractedValue)")
                 } else {
                     // Apply decay if value not extracted
                     let previousValue = previousRawValues[category] ?? 0.0 // Default to 0 if no previous value
                     let decayedValue = previousValue * decayFactor
                     todayRawValues[category] = decayedValue
                      print("   [RawValue Calc] Category '\(category)': Applying decay. Previous: \(previousValue), Decayed: \(decayedValue)")
                 }
             }
            try await databaseService.saveRawValues(values: todayRawValues, for: today)
            print("✅ [AnalysisService] Saved today's raw values: \(todayRawValues)")

            // 6. Calculate Scores based on 7-day window
            print("[AnalysisService] Calculating scores based on 7-day window ending \(today.formatted(date: .abbreviated, time: .omitted))...") // Use .abbreviated
            let (displayScore, energyScore, financeScore, homeScore) = await calculateScores(for: today)
            print("[AnalysisService] Calculated Scores - Display: \(displayScore), E: \(energyScore), F: \(financeScore), H: \(homeScore)")

            // 7. Determine Priority Node
            let priorityNode = determinePriorityNode(energyScore: energyScore, financeScore: financeScore, homeScore: homeScore)
            print("[AnalysisService] Determined Priority Node: \(priorityNode)")

            // 8. Save Scores and Priority
            try await databaseService.saveScores(
                date: today,
                displayScore: displayScore,
                energyScore: energyScore,
                financeScore: financeScore,
                homeScore: homeScore
            )
            try await databaseService.savePriorityNode(date: today, node: priorityNode)
            print("✅ [AnalysisService] Saved scores and priority node.")

            // 9. Mark Message as Processed
            try await databaseService.markChatMessageProcessed(messageId)
            print("✅ [AnalysisService] Marked message \(messageId) as processed.")

        } catch {
            print("‼️ [AnalysisService] Error during analysis for message \(messageId): \(error)")
            // Optionally re-throw or handle specific errors
        }
        print("🏁 [AnalysisService] Finished analysis for message ID: \(messageId)")
    }

    // Helper to call LLM for value extraction
    private func extractValuesFromMessage(messageContent: String) async -> [String: Double] {
        do {
            let extractedData: [String: Double] = try await llmService.generateAnalysisData(messageContent: messageContent)
            return extractedData
        } catch {
            print("‼️ [AnalysisService] Failed to extract values via LLM: \(error)")
            return [:] // Return empty dictionary on error
        }
    }

    // Helper to calculate scores
    private func calculateScores(for date: Date) async -> (displayScore: Int, energyScore: Double, financeScore: Double, homeScore: Double) {
        var categoryScores: [String: Double] = [:]
        let calendar = Calendar.current

        do {
            // Fetch last W days of raw values for all categories
            print("[AnalysisService-ScoreCalc] Fetching raw values for the last \(windowDays) days...")
            let dateRange = (0..<windowDays).compactMap { i in
                calendar.date(byAdding: .day, value: -i, to: date)
            }
            let historicalRawValues = try await databaseService.fetchRawValues(forDates: dateRange)
            print("[AnalysisService-ScoreCalc] Fetched \(historicalRawValues.count) days of raw values.")

             // Calculate average and normalized score for each category
             for category in nodeWeights.keys {
                 // Removed unused sum and count variables
                 var valuesForAvg: [Double] = []

                 // Iterate through the dates in the window
                 for day in dateRange {
                     if let dayValues = historicalRawValues[day], let value = dayValues[category] {
                         valuesForAvg.append(value)
                     } else {
                         // Handle missing day/category value (e.g., assume 0 or apply decay retroactively?)
                         // Simplest: Treat missing as 0 for average calculation if within window
                         // More complex: Could try to apply decay from the *last known* value before this day.
                         // For now, treat missing day's data as 0 for simplicity, matching algorithm step 3b if no mention implies decay.
                         // Fetching previous values guarantees *some* value exists due to decay logic in step 5.
                         // If a day is missing entirely, assume 0.
                         valuesForAvg.append(0.0)
                     }
                 }

                 if !valuesForAvg.isEmpty {
                      let avgValue = valuesForAvg.reduce(0, +) / Double(valuesForAvg.count)
                      let target = nodeTargets[category] ?? 1.0 // Default target to 1 to avoid division by zero
                      let normalizedScore = min(avgValue / target, 1.0) // Normalize and cap at 1.0
                      categoryScores[category] = normalizedScore
                      print("   [ScoreCalc] Category '\(category)': Avg=\(avgValue), Target=\(target), NormScore=\(normalizedScore)")
                 } else {
                     categoryScores[category] = 0.0 // Default score if no data
                     print("   [ScoreCalc] Category '\(category)': No raw values found in window. Score=0.0")
                 }
             }


            // Calculate Total Score
            var totalScore: Double = 0
            for (category, weight) in nodeWeights {
                 // Ensure we handle categories that might be in weights but not in scores (shouldn't happen with current logic)
                 let score = categoryScores[category] ?? 0.0
                 totalScore += score * weight
            }
            let displayScore = Int(round(totalScore * 100))
            print("[AnalysisService-ScoreCalc] Raw Total Score: \(totalScore), Display Score: \(displayScore)")


            // Calculate Composite Core Scores
             // Energy: Mean of the four energy inputs
             let energyInputs = ["Training", "Sleep", "HealthyFood", "Supplements"]
             let energySum = energyInputs.reduce(0.0) { $0 + (categoryScores[$1] ?? 0.0) }
             let energyScore = energyInputs.isEmpty ? 0.0 : energySum / Double(energyInputs.count)

            // Finance: Direct score
             let financeScore = categoryScores["Repay Debt"] ?? 0.0 // Use "Repay Debt" as key

            // Home: Direct score
             let homeScore = categoryScores["Nurture Home"] ?? 0.0

            return (displayScore, energyScore, financeScore, homeScore)

        } catch {
            print("‼️ [AnalysisService] Error calculating scores: \(error)")
            return (0, 0, 0, 0) // Return default scores on error
        }
    }

    // Helper to determine priority node
    private func determinePriorityNode(energyScore: Double, financeScore: Double, homeScore: Double) -> String {
         let scores = [
             ("Boost Energy", energyScore),
             ("Repay Debt", financeScore),
             ("Nurture Home", homeScore)
         ]

        // Find the node with the minimum score. Handle ties by prioritizing (e.g., Energy > Finance > Home) or choosing arbitrarily.
        let minScore = scores.min(by: { $0.1 < $1.1 })?.1 ?? 0.0
        let lowestNodes = scores.filter { $0.1 == minScore }

        // Simple tie-breaking: return the first one found (default order Energy, Finance, Home)
        return lowestNodes.first?.0 ?? "Boost Energy" // Default to Energy if all else fails
    }
}