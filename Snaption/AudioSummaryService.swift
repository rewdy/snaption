import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

final class AudioSummaryService {
    func isAvailable() -> Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            return model.isAvailable && model.supportsLocale(Locale.current)
        }
        #endif
        return false
    }

    func summarize(_ text: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw NSError(domain: "AudioSummaryService", code: 1)
            }
            let session = LanguageModelSession(model: model)
            let prompt = """
            Summarize the following text in 1-3 concise sentences:

            \(text)
            """
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw NSError(domain: "AudioSummaryService", code: 1)
    }
}
