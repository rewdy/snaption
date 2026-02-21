@preconcurrency import AVFoundation

final class AudioRecordingService: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private let silenceThreshold: Float = 0.02
    private let minSilenceSeconds: Double = 0.8

    func startRecording(to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.delegate = self
        recorder?.record()
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
    }

    func trimSilence(at url: URL) async -> URL {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let sampleRate = format.sampleRate
            let minSilenceFrames = AVAudioFrameCount(sampleRate * minSilenceSeconds)
            let totalFrames = AVAudioFrameCount(file.length)

            guard totalFrames > 0 else {
                return url
            }

            var segments: [(start: AVAudioFramePosition, end: AVAudioFramePosition)] = []
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!

            var currentFrame: AVAudioFramePosition = 0
            var segmentStart: AVAudioFramePosition?
            var silenceStart: AVAudioFramePosition?

            while currentFrame < file.length {
                let remaining = AVAudioFrameCount(file.length - currentFrame)
                let framesToRead = min(buffer.frameCapacity, remaining)
                try file.read(into: buffer, frameCount: framesToRead)

                let isSilent = isBufferSilent(buffer, threshold: silenceThreshold)

                if isSilent {
                    if segmentStart != nil {
                        if silenceStart == nil {
                            silenceStart = currentFrame
                        }
                        if let silenceStartValue = silenceStart, (currentFrame - silenceStartValue) >= AVAudioFramePosition(minSilenceFrames) {
                            segments.append((start: segmentStart ?? 0, end: silenceStartValue))
                            segmentStart = nil
                            silenceStart = nil
                        }
                    }
                } else {
                    if segmentStart == nil {
                        segmentStart = currentFrame
                    }
                    silenceStart = nil
                }

                currentFrame += AVAudioFramePosition(framesToRead)
            }

            if let segmentStart {
                segments.append((start: segmentStart, end: file.length))
            }

            if segments.isEmpty {
                return url
            }

            let isSingleFullSegment = segments.count == 1 && segments[0].start == 0 && segments[0].end == file.length
            if isSingleFullSegment {
                return url
            }

            let tempURL = url.deletingPathExtension().appendingPathExtension("trimmed.m4a")
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }

            let outputFile = try AVAudioFile(forWriting: tempURL, settings: file.fileFormat.settings)
            let writeBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!

            for segment in segments where segment.end > segment.start {
                file.framePosition = segment.start
                var framesLeft = AVAudioFrameCount(segment.end - segment.start)

                while framesLeft > 0 {
                    let framesToRead = min(writeBuffer.frameCapacity, framesLeft)
                    try file.read(into: writeBuffer, frameCount: framesToRead)
                    try outputFile.write(from: writeBuffer)
                    framesLeft -= framesToRead
                }
            }

            _ = try? FileManager.default.replaceItemAt(url, withItemAt: tempURL, backupItemName: nil, options: .usingNewMetadataOnly)
            return url
        } catch {
            return url
        }
    }
}

private func isBufferSilent(_ buffer: AVAudioPCMBuffer, threshold: Float) -> Bool {
    guard let channelData = buffer.floatChannelData else {
        return true
    }
    let frameCount = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)

    for channel in 0..<channelCount {
        let samples = channelData[channel]
        for frame in 0..<frameCount {
            if abs(samples[frame]) > threshold {
                return false
            }
        }
    }
    return true
}
