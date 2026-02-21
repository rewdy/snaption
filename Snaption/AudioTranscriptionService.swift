import Foundation
import Speech

final class AudioTranscriptionService {
    func isAvailable() -> Bool {
        guard let recognizer = SFSpeechRecognizer() else {
            return false
        }
        return recognizer.isAvailable
    }

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func transcribeAudio(at url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer() else {
            throw NSError(domain: "AudioTranscriptionService", code: 1)
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else {
                    return
                }
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
}
