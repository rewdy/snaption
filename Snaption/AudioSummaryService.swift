import Foundation

final class AudioSummaryService {
    func isAvailable() -> Bool {
        false
    }

    func summarize(_ text: String) async throws -> String {
        throw NSError(domain: "AudioSummaryService", code: 1)
    }
}
