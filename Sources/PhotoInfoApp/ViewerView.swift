import AppKit
import SwiftUI

struct ViewerView: View {
    @ObservedObject var appState: AppState
    @State private var image: NSImage?
    @State private var newTagText = ""
    @State private var isPlacingLabel = false
    @State private var pendingLabelPoint: CGPoint?
    @State private var newLabelText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button("Back to Library") {
                    appState.navigateToLibrary()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("b", modifiers: [.command])

                Button("Previous") {
                    appState.goToPreviousPhoto()
                }
                .buttonStyle(.bordered)
                .disabled(!appState.canGoToPreviousPhoto)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Next") {
                    appState.goToNextPhoto()
                }
                .buttonStyle(.bordered)
                .disabled(!appState.canGoToNextPhoto)
                .keyboardShortcut(.rightArrow, modifiers: [])

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(saveStateColor)
                        .frame(width: 8, height: 8)
                    Text(appState.notesSaveState.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
            }

            if let selectedPhoto = appState.selectedPhoto {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedPhoto.filename)
                            .font(.title2)
                            .bold()

                        Text(selectedPhoto.relativePath)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        PhotoCanvasView(
                            image: image,
                            labels: appState.labels,
                            isPlacingLabel: isPlacingLabel
                        ) { normalizedPoint in
                            guard isPlacingLabel else {
                                return
                            }
                            pendingLabelPoint = normalizedPoint
                            newLabelText = ""
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Annotations")
                                .font(.headline)
                            Spacer()
                            Text("\(appState.labels.count) labels")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(isPlacingLabel ? "Cancel Label" : "Add Label") {
                                isPlacingLabel.toggle()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if isPlacingLabel {
                            Text("Label mode is active. Click the photo to place a point.")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }

                        Text("Notes")
                            .font(.headline)

                        TextEditor(text: Binding(
                            get: { appState.notesText },
                            set: { appState.updateNotesDraft($0) }
                        ))
                        .font(.body.monospaced())
                        .frame(minWidth: 300, idealWidth: 360)
                        .padding(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        )

                        if let notesStatusMessage = appState.notesStatusMessage {
                            Text(notesStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        Text("Tags")
                            .font(.headline)

                        HStack(spacing: 8) {
                            TextField("Add tag", text: $newTagText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(addTag)

                            Button("Add", action: addTag)
                            .buttonStyle(.bordered)
                        }

                        FlowLayout(items: appState.tags) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button {
                                    appState.removeTag(tag)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        Divider()

                        Text("Labels")
                            .font(.headline)

                        if appState.labels.isEmpty {
                            Text("No labels yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(appState.labels) { label in
                                        HStack(spacing: 8) {
                                            Text(label.text)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("(\(label.x, specifier: "%.3f"), \(label.y, specifier: "%.3f"))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Button("Remove") {
                                                appState.removeLabel(id: label.id)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                            .frame(maxHeight: 170)
                        }
                    }
                    .frame(width: 360)
                }
            } else {
                ContentUnavailableView(
                    "No photo selected",
                    systemImage: "photo",
                    description: Text("Select a photo from the library.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: appState.selectedPhotoID) {
            guard let selectedPhoto = appState.selectedPhoto else {
                image = nil
                newTagText = ""
                isPlacingLabel = false
                pendingLabelPoint = nil
                return
            }

            image = NSImage(contentsOf: selectedPhoto.imageURL)
        }
        .sheet(item: Binding(
            get: {
                pendingLabelPoint.map { PendingLabelPoint(x: $0.x, y: $0.y) }
            },
            set: { newValue in
                pendingLabelPoint = newValue.map { CGPoint(x: $0.x, y: $0.y) }
            }
        )) { pendingPoint in
            VStack(alignment: .leading, spacing: 12) {
                Text("Add Label")
                    .font(.headline)
                Text("Coordinates: \(pendingPoint.x, specifier: "%.3f"), \(pendingPoint.y, specifier: "%.3f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Label text", text: $newLabelText)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        pendingLabelPoint = nil
                    }
                    Button("Add") {
                        appState.addLabel(x: pendingPoint.x, y: pendingPoint.y, text: newLabelText)
                        pendingLabelPoint = nil
                        isPlacingLabel = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newLabelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 380)
        }
    }

    private var saveStateColor: Color {
        switch appState.notesSaveState {
        case .clean:
            return .secondary
        case .dirty:
            return .orange
        case .saving:
            return .secondary
        case .error:
            return .red
        }
    }

    private func addTag() {
        appState.addTag(newTagText)
        newTagText = ""
    }
}

private struct PhotoCanvasView: View {
    let image: NSImage?
    let labels: [PointLabel]
    let isPlacingLabel: Bool
    let onPlaceLabel: (CGPoint) -> Void

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size
            let imageSize = image?.size ?? .init(width: 1, height: 1)
            let drawRect = fittedRect(for: imageSize, in: canvasSize)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.12))

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: canvasSize.width, height: canvasSize.height)
                } else {
                    ProgressView("Loading image...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                ForEach(labels) { label in
                    let point = CGPoint(
                        x: drawRect.minX + label.x * drawRect.width,
                        y: drawRect.minY + label.y * drawRect.height
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                        Text(label.text)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.65))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .position(x: point.x, y: point.y)
                }

                if isPlacingLabel {
                    Rectangle()
                        .fill(Color.blue.opacity(0.08))
                        .overlay(
                            Text("Click image to place label")
                                .font(.caption)
                                .padding(6)
                                .background(Color.blue.opacity(0.9))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .padding(10),
                            alignment: .topLeading
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard isPlacingLabel else {
                            return
                        }

                        guard drawRect.contains(value.location), drawRect.width > 0, drawRect.height > 0 else {
                            return
                        }

                        let normalizedX = (value.location.x - drawRect.minX) / drawRect.width
                        let normalizedY = (value.location.y - drawRect.minY) / drawRect.height
                        onPlaceLabel(CGPoint(x: normalizedX, y: normalizedY))
                    }
            )
        }
    }

    private func fittedRect(for imageSize: CGSize, in canvasSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, canvasSize.width > 0, canvasSize.height > 0 else {
            return .zero
        }

        let imageRatio = imageSize.width / imageSize.height
        let canvasRatio = canvasSize.width / canvasSize.height

        if imageRatio > canvasRatio {
            let width = canvasSize.width
            let height = width / imageRatio
            let y = (canvasSize.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        }

        let height = canvasSize.height
        let width = height * imageRatio
        let x = (canvasSize.width - width) / 2
        return CGRect(x: x, y: 0, width: width, height: height)
    }
}

private struct PendingLabelPoint: Identifiable {
    let x: Double
    let y: Double

    var id: String {
        "\(x)-\(y)"
    }
}

private struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if items.isEmpty {
                Text("No tags yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}
