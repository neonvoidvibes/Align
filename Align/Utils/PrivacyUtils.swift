import Foundation
import NaturalLanguage

// Basic PII Filtering Utility
// Focuses on common types like names and places. Can be expanded.
@available(iOS 12.0, *) // NLTagger requires iOS 12+
func filterPII(text: String) -> String {
    // If the input text is very long, consider processing in chunks or returning early
    // to avoid performance issues with NLTagger on large inputs.
    guard !text.isEmpty, text.count < 5000 else { // Add a reasonable character limit
        // print("[PII Filter] Text too long or empty, skipping filtering.")
        return text
    }

    var filteredText = text
    let tagger = NLTagger(tagSchemes: [.nameType]) // Focus on nameType first
    tagger.string = text

    // Define tags to filter
    let tagsToFilter: [NLTag] = [.personalName, .placeName, .organizationName]
    // Define corresponding placeholders
    let placeholders: [NLTag: String] = [
        .personalName: "[NAME]",
        .placeName: "[PLACE]",
        .organizationName: "[ORG]"
    ]

    // Enumerate tags - process replacements from end to start to avoid range issues
    let rangesToReplace = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType)
        .compactMap { tag, tokenRange -> (NLTag, Range<String.Index>)? in
            guard let tag = tag, tagsToFilter.contains(tag) else { return nil }
            // Basic check: Avoid replacing very short potential matches if desired
            // if text.distance(from: tokenRange.lowerBound, to: tokenRange.upperBound) < 3 { return nil }
            return (tag, tokenRange)
        }
        .sorted { $0.1.lowerBound > $1.1.lowerBound } // Sort ranges descending by start index

    for (tag, range) in rangesToReplace {
        if let placeholder = placeholders[tag] {
            // Clamp the range to ensure it's valid within the current state of filteredText
            // range.clamped(to:) returns a NON-OPTIONAL range.
            let validRange = range.clamped(to: filteredText.startIndex..<filteredText.endIndex)

            // Perform the replacement using the valid, clamped range
            filteredText.replaceSubrange(validRange, with: placeholder)
        }
    }

    // Optional: Add more filtering logic here (e.g., regex for emails, phone numbers) if needed

    return filteredText
}