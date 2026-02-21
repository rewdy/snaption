import AVFoundation

final class AudioRecordingService: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?

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
}
