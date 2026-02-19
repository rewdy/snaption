import Foundation

struct SearchEntry {
    let combinedLowercasedText: String

    func matches(_ query: String) -> Bool {
        combinedLowercasedText.contains(query)
    }

    static func from(notes: String, tags: [String], labels: [PointLabel]) -> SearchEntry {
        let labelText = labels.map(\.text).joined(separator: " ")
        let tagText = tags.joined(separator: " ")
        let text = "\(notes) \(tagText) \(labelText)".lowercased()
        return SearchEntry(combinedLowercasedText: text)
    }
}
