import AppKit
import Vision

struct FaceDetectionResult: Sendable {
    let bounds: [CGRect]
}

actor FaceDetectionService {
    func detectFaces(in image: NSImage) async throws -> FaceDetectionResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return FaceDetectionResult(bounds: [])
        }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let bounds = observations.map { $0.boundingBox }
        return FaceDetectionResult(bounds: bounds)
    }
}
