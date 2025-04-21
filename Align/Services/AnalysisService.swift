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

            // 2. Fetch the *latest* recorded raw values and their date for context & decay calculation
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: message.timestamp) // Use message timestamp for the relevant day
            // Call original function name
            let latestData = try? await databaseService.fetchLatestRawValuesAndDate()
            let latestValues = latestData?.values ?? [:]
            let latestDate = latestData?.date

            // Format the date safely into a separate string variable first
            let latestDateString = latestDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"
            print("[AnalysisService] Latest values (from \(latestDateString)) for context: \(latestValues)")

            // 3. Extract/Infer Quantitative Values using LLM with the *latest* context
            print("[AnalysisService] Extracting/inferring values from message: '\(message.content.prefix(50))...'")
            let inferredValues = await extractValuesFromMessage(messageContent: message.content, previousValues: latestValues) // Pass latest values
            print("[AnalysisService] Inferred values: \(inferredValues)")

            // 4. Calculate days missed since last data entry (if any)
            var daysMissed = 0
            if let lastDate = latestDate {
                // Ensure 'today' is actually after 'lastDate' before calculating difference
                if today > lastDate {
                     // Calculate the difference only if today is after lastDate
                     daysMissed = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0
                 } else if today < lastDate {
                    // This shouldn't happen if message timestamps are chronological, but handle defensively
                    // Format dates into strings first
                    let todayString = today.formatted(date: .abbreviated, time: .omitted)
                    let lastDateString = lastDate.formatted(date: .abbreviated, time: .omitted)
                    print("⚠️ [AnalysisService] Current message date (\(todayString)) is before last recorded raw value date (\(lastDateString)). Assuming 0 days missed for decay.")
                    daysMissed = 0
                }
                // If today == lastDate, daysMissed remains 0, which is correct.
            } else {
                // No previous data, so effectively infinite days missed, but decay starts from 0 anyway.
                daysMissed = 0 // Or could use a large number, but 0 works with pow(factor, 0) = 1
            }
            print("[AnalysisService] Days missed since last data: \(daysMissed)")


            // 5. Calculate & Store Today's Raw Values (using inferred values + decay over missed days)
            var todayRawValues: [String: Double] = [:]
            for category in nodeWeights.keys { // Iterate through all defined categories
                if let inferredValue = inferredValues[category] {
                    // Use the value inferred by the LLM
                    todayRawValues[category] = inferredValue
                    print("   [RawValue Calc] Category '\(category)': Using inferred value \(inferredValue)")
                } else {
                    // Apply decay over potentially multiple days if LLM didn't infer a value
                    let previousValue = latestValues[category] ?? 0.0 // Start from the last *recorded* value
                    // Apply decay factor for each missed day. pow(decay, 0) = 1, so it works for 0 days missed.
                    let decayMultiplier = pow(decayFactor, Double(max(0, daysMissed))) // Ensure exponent is non-negative
                    let decayedValue = previousValue * decayMultiplier
                    todayRawValues[category] = decayedValue
                    print("   [RawValue Calc] Category '\(category)': Applying decay (\(daysMissed) days). Last Recorded: \(previousValue), Multiplier: \(decayMultiplier.formatted(.number.precision(.significantDigits(3)))), Today's Decayed: \(decayedValue)")
                }
            }
            // Add await back as saveRawValues is on MainActor DB service
            try await databaseService.saveRawValues(values: todayRawValues, for: today)
            print("✅ [AnalysisService] Saved today's raw values: \(todayRawValues)")

            // 6. Calculate Scores based on 7-day window
            // 6. Calculate Scores based on 7-day window, passing today's values directly
            let todayScoreString = today.formatted(date: .abbreviated, time: .omitted)
            print("[AnalysisService] Calculating scores based on 7-day window ending \(todayScoreString)...") // Use .abbreviated
            // Pass todayRawValues to calculateScores
            let (displayScore, energyScore, financeScore, homeScore) = await calculateScores(for: today, todayValues: todayRawValues)
            print("[AnalysisService] Calculated Scores - Display: \(displayScore), E: \(energyScore), F: \(financeScore), H: \(homeScore)")

            // 7. Determine Priority Node
            let priorityNode = determinePriorityNode(energyScore: energyScore, financeScore: financeScore, homeScore: homeScore)
            print("[AnalysisService] Determined Priority Node: \(priorityNode)")

            // 8. Save Scores and Priority
            // Explicitly run on MainActor since DatabaseService is @MainActor isolated
            try await MainActor.run {
                try databaseService.saveScores(
                    date: today,
                    displayScore: displayScore,
                    energyScore: energyScore,
                financeScore: financeScore,
                homeScore: homeScore
                )
            }
            // Explicitly run on MainActor since DatabaseService is @MainActor isolated
            try await MainActor.run {
                try databaseService.savePriorityNode(date: today, node: priorityNode)
            }
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

    // Helper to call LLM for value extraction/inference
    private func extractValuesFromMessage(messageContent: String, previousValues: [String: Double]?) async -> [String: Double] {
        do {
            // Pass previous values to the LLM service
            let inferredData: [String: Double] = try await llmService.generateAnalysisData(
                messageContent: messageContent,
                previousDayValues: previousValues
            )
            return inferredData
        } catch {
            print("‼️ [AnalysisService] Failed to infer values via LLM: \(error)")
            return [:] // Return empty dictionary on error
        }
    }

    // Helper to calculate scores, now accepting today's values explicitly
    private func calculateScores(for date: Date, todayValues: [String: Double]) async -> (displayScore: Int, energyScore: Double, financeScore: Double, homeScore: Double) {
        var categoryScores: [String: Double] = [:]
        let calendar = Calendar.current
        let daysToFetch = windowDays - 1 // Fetch only the days *before* today

        do {
            // Fetch raw values for the days *before* the target date
            // Fix date formatting
            print("[AnalysisService-ScoreCalc] Fetching raw values for the \(daysToFetch) days before \(date.formatted(date: .abbreviated, time: .omitted))...")
            // Create range from 1 to daysToFetch (e.g., 1 to 6 for a 7-day window)
            let dateRange = (1...daysToFetch).compactMap { i in
                calendar.date(byAdding: .day, value: -i, to: date) // Days BEFORE date
            }

            var combinedRawValues: [Date: [String: Double]] = [:]
            if !dateRange.isEmpty {
                 // Add await back as fetchRawValues(forDates:) is on MainActor DB service
                 let historicalData = try await databaseService.fetchRawValues(forDates: dateRange)
                 print("[AnalysisService-ScoreCalc] Fetched \(historicalData.count) historical days.")
                 combinedRawValues = historicalData // Start with historical data
            } else {
                 print("[AnalysisService-ScoreCalc] No historical days to fetch (windowDays <= 1?).")
            }

             // Explicitly add today's values to the combined dictionary
             combinedRawValues[date] = todayValues
             print("[AnalysisService-ScoreCalc] Included today's values. Total days for calc: \(combinedRawValues.count)")

             // --- Calculate average and normalized score using combinedRawValues ---
             let fullDateRangeForAvg = (0..<windowDays).compactMap { i in // Generate the full date range again for averaging
                calendar.date(byAdding: .day, value: -i, to: date)
             }

             for category in nodeWeights.keys {
                  // Declare valuesForAvg ONCE inside the category loop
                 var valuesForAvg: [Double] = []

                 // Iterate through the full window range for averaging
                 for day in fullDateRangeForAvg {
                     // Look up value in the *combined* dictionary
                     if let dayValues = combinedRawValues[day], let value = dayValues[category] {
                         valuesForAvg.append(value)
                     } else {
                         // If data for a day in the window is missing (even after combining), treat as 0
                         valuesForAvg.append(0.0)
                     }
                 }
                 // REMOVED the duplicate declaration of valuesForAvg here

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