import Foundation
import Vision

struct FaceLabelEntry: Codable, Sendable {
    let id: String
    let label: String
    let featurePrint: Data
    let updatedAt: Date
}

actor FaceLabelStore {
    private let storeURL: URL

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    func load() -> [FaceLabelEntry] {
        guard let data = try? Data(contentsOf: storeURL) else {
            return []
        }
        return (try? JSONDecoder().decode([FaceLabelEntry].self, from: data)) ?? []
    }

    func save(_ entries: [FaceLabelEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        try? data.write(to: storeURL, options: [.atomic])
    }

    func append(label: String, featurePrint: Data) async {
        var entries = load()
        let entry = FaceLabelEntry(
            id: "face-label-\(UUID().uuidString.prefix(8))",
            label: label,
            featurePrint: featurePrint,
            updatedAt: Date()
        )
        entries.append(entry)
        save(entries)
    }

    func suggestLabel(for featurePrint: Data, threshold: Float = 0.45) async -> String? {
        let entries = load()
        guard !entries.isEmpty else {
            return nil
        }

        let queryPrint = await MainActor.run { FaceFeaturePrintCodec.decode(featurePrint) }
        guard let queryPrint else {
            return nil
        }

        var bestLabel: String?
        var bestDistance: Float = .greatestFiniteMagnitude

        for entry in entries {
            let candidate = await MainActor.run { FaceFeaturePrintCodec.decode(entry.featurePrint) }
            guard let candidate else {
                continue
            }
            var distance: Float = 0
            try? queryPrint.computeDistance(&distance, to: candidate)
            if distance < bestDistance {
                bestDistance = distance
                bestLabel = entry.label
            }
        }

        guard let bestLabel, bestDistance <= threshold else {
            return nil
        }
        return bestLabel
    }
}
