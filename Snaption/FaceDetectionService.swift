import AppKit
import Vision

struct FaceObservation: Sendable {
    let bounds: CGRect
    let featurePrint: Data?
}

actor FaceDetectionService {
    func detectFaces(in image: NSImage, includeFeaturePrints: Bool) async throws -> [FaceObservation] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([faceRequest])

        let faces = faceRequest.results ?? []
        guard includeFeaturePrints, !faces.isEmpty else {
            return faces.map { FaceObservation(bounds: $0.boundingBox, featurePrint: nil) }
        }

        var observations: [FaceObservation] = []
        observations.reserveCapacity(faces.count)

        for face in faces {
            let printRequest = VNGenerateImageFeaturePrintRequest()
            printRequest.regionOfInterest = face.boundingBox
            try handler.perform([printRequest])
            let print = printRequest.results?.first as? VNFeaturePrintObservation
            let printData = await MainActor.run { print.flatMap { FaceFeaturePrintCodec.encode($0) } }
            observations.append(FaceObservation(bounds: face.boundingBox, featurePrint: printData))
        }

        return observations
    }
}
