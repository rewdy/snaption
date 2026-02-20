import Foundation

struct SearchEntry: Sendable {
    let combinedLowercasedText: String

    nonisolated func matches(_ query: String) -> Bool {
        combinedLowercasedText.contains(query)
    }

    nonisolated static func from(notes: String, tags: [String], labels: [PointLabel]) -> SearchEntry {
        let labelText = labels.map(\.text).joined(separator: " ")
        let tagText = tags.joined(separator: " ")
        let text = "\(notes) \(tagText) \(labelText)".lowercased()
        return SearchEntry(combinedLowercasedText: text)
    }
}
