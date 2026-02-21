import AppKit
import SwiftUI

struct FacesGalleryView: View {
    let storeURL: URL

    @State private var faces: [FaceTile] = []

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Faces")
                .font(.headline)

            if faces.isEmpty {
                ContentUnavailableView(
                    "No faces indexed",
                    systemImage: "person.crop.square",
                    description: Text("Enable Face Features to build the face index.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(faces) { face in
                            FaceTileView(tile: face)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
        .task {
            await loadFaces()
        }
    }

    private func loadFaces() async {
        let store = FaceIndexStore(storeURL: storeURL)
        let entries = await store.load()
        var tiles: [FaceTile] = []
        tiles.reserveCapacity(entries.values.reduce(0) { $0 + $1.faces.count })

        for entry in entries.values {
            let url = URL(fileURLWithPath: entry.photoPath)
            for face in entry.faces {
                tiles.append(
                    FaceTile(id: UUID(), imageURL: url, normalizedRect: face.bounds)
                )
            }
        }

        faces = tiles
    }
}

private struct FaceTile: Identifiable {
    let id: UUID
    let imageURL: URL
    let normalizedRect: CGRect
}

private struct FaceTileView: View {
    let tile: FaceTile

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))

            if let image = croppedImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "person.crop.square")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .clipped()
    }

    private func croppedImage() -> NSImage? {
        guard let image = NSImage(contentsOf: tile.imageURL) else {
            return nil
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let rect = CGRect(
            x: tile.normalizedRect.minX * width,
            y: (1 - tile.normalizedRect.maxY) * height,
            width: tile.normalizedRect.width * width,
            height: tile.normalizedRect.height * height
        )
        guard let cropped = cgImage.cropping(to: rect) else {
            return nil
        }
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
    }
}
