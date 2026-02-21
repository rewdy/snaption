import AppKit
import AVFoundation
import Combine
import SwiftUI

struct ViewerView: View {
    @ObservedObject var appState: AppState
    @State private var image: NSImage?
    @State private var newTagText = ""
    @State private var pendingLabel: PendingLabelDraft?
    @State private var editRequest: LabelEditRequest?
    @State private var faceObservations: [FaceObservation] = []
    @State private var recordings: [RecordingItem] = []
    @StateObject private var audioPlayer = AudioPlayerController()
    private let faceDetectionService = FaceDetectionService()

    private var sidecarURL: URL? {
        appState.selectedPhoto?.sidecarURL
    }

    private var sidecarExists: Bool {
        guard let sidecarURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: sidecarURL.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.selectedPhoto != nil {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                            PhotoCanvasView(
                                image: image,
                                labels: appState.labels,
                                pendingLabel: $pendingLabel,
                                isLabelsHidden: appState.areLabelsHidden,
                                editRequest: $editRequest,
                                faceObservations: faceObservations,
                                isFaceFeaturesEnabled: appState.faceFeaturesEnabled,
                                onPlaceLabel: { normalizedPoint, anchorPoint in
                                    let draftID = UUID()
                                    let featurePrint = featurePrintForPoint(normalizedPoint)
                                    pendingLabel = PendingLabelDraft(
                                        id: draftID,
                                        labelID: nil,
                                        normalizedPoint: normalizedPoint,
                                    anchorPoint: anchorPoint,
                                    text: "",
                                    featurePrint: featurePrint
                                )
                                    if let featurePrint {
                                        Task {
                                            let suggestion = await appState.suggestLabel(for: featurePrint)
                                            await MainActor.run {
                                                guard let pending = pendingLabel, pending.id == draftID else {
                                                    return
                                                }
                                                if let suggestion, !suggestion.isEmpty {
                                                    pendingLabel = PendingLabelDraft(
                                                        id: pending.id,
                                                        labelID: pending.labelID,
                                                        normalizedPoint: pending.normalizedPoint,
                                                        anchorPoint: pending.anchorPoint,
                                                        text: suggestion,
                                                        featurePrint: pending.featurePrint
                                                    )
                                                }
                                            }
                                        }
                                    }
                            },
                            onSelectLabel: { label, anchorPoint in
                                let featurePrint = featurePrintForPoint(CGPoint(x: label.x, y: label.y))
                                pendingLabel = PendingLabelDraft(
                                    id: UUID(),
                                    labelID: label.id,
                                    normalizedPoint: CGPoint(x: label.x, y: label.y),
                                    anchorPoint: anchorPoint,
                                    text: label.text,
                                    featurePrint: featurePrint
                                )
                            },
                            onSaveLabel: { draft, text in
                                handleSaveLabel(draft: draft, text: text)
                            },
                            onCancelLabel: {
                                    pendingLabel = nil
                                }
                            )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                            Text("\(appState.labels.count) labels")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

                        Text("Recordings")
                            .font(.headline)

                        if recordings.isEmpty {
                            Text("No recordings yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(recordings) { recording in
                                        HStack(spacing: 8) {
                                            Text(recording.modifiedAt, style: .date)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(recording.modifiedAt, style: .time)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(recording.url.lastPathComponent)
                                                .lineLimit(1)
                                                .help(recording.url.lastPathComponent)
                                            Spacer()
                                            Button {
                                                audioPlayer.togglePlayback(for: recording.url)
                                            } label: {
                                                ZStack {
                                                    AudioProgressRing(
                                                        progress: audioPlayer.progress(for: recording.url),
                                                        isActive: audioPlayer.isPlaying(recording.url)
                                                    )
                                                    Image(systemName: audioPlayer.isPlaying(recording.url) ? "pause.fill" : "play.fill")
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .clipShape(Circle())
                                            Button {
                                                openRecordingInFinder(recording.url)
                                            } label: {
                                                ZStack {
                                                    AudioProgressRing(progress: 1, isActive: false)
                                                        .hidden()
                                                    Image(systemName: "folder")
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .clipShape(Circle())
                                            .help("Show Recording in Finder")
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                            .frame(maxHeight: 140)
                        }

                        Divider()

                        HStack {
                            Text("Labels")
                                .font(.headline)
                            Spacer()
                            Toggle(isOn: $appState.areLabelsHidden) {
                                Text("Hide")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .toggleStyle(.switch)
                        }

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
                                            if !appState.areLabelsHidden {
                                                Button("Edit") {
                                                    editRequest = LabelEditRequest(labelID: label.id)
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                                Button("Remove") {
                                                    appState.removeLabel(id: label.id)
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            }
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                            .frame(maxHeight: 170)
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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ControlGroup {
                    Button {
                        appState.goToPreviousPhoto()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("Back")
                    .disabled(!appState.canGoToPreviousPhoto)
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    Button {
                        appState.goToNextPhoto()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .help("Next")
                    .disabled(!appState.canGoToNextPhoto)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
                
                Menu {
                    Button("Show Data File in Finder") {
                        openSidecarInFinder()
                    }
                    .disabled(!sidecarExists)
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .focusable()
        .onMoveCommand(perform: handleMoveCommand)
        .task(id: appState.selectedPhotoID) {
            guard let selectedPhoto = appState.selectedPhoto else {
                image = nil
                newTagText = ""
                pendingLabel = nil
                faceObservations = []
                return
            }

            image = NSImage(contentsOf: selectedPhoto.imageURL)
            recordings = loadRecordings(for: selectedPhoto)
            audioPlayer.stop()
        }
        .task(id: FaceDetectionKey(
            photoID: appState.selectedPhotoID,
            isEnabled: appState.faceFeaturesEnabled,
            areLabelsHidden: appState.areLabelsHidden
        )) {
            guard appState.faceFeaturesEnabled, !appState.areLabelsHidden else {
                faceObservations = []
                return
            }
            guard let image else {
                faceObservations = []
                return
            }
            do {
                faceObservations = try await faceDetectionService.detectFaces(in: image, includeFeaturePrints: true)
            } catch {
                faceObservations = []
            }
        }
        .onChange(of: appState.areLabelsHidden) { _, isHidden in
            if isHidden {
                pendingLabel = nil
                faceObservations = []
            }
        }
    }

    private func addTag() {
        appState.addTag(newTagText)
        newTagText = ""
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .left:
            appState.goToPreviousPhoto()
        case .right:
            appState.goToNextPhoto()
        default:
            break
        }
    }

    private func handleSaveLabel(draft: PendingLabelDraft, text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        appState.recordFaceLabelIfNeeded(labelText: trimmedText, featurePrint: draft.featurePrint)

        if let labelID = draft.labelID {
            appState.updateLabel(id: labelID, text: trimmedText)
        } else {
            appState.addLabel(
                x: draft.normalizedPoint.x,
                y: draft.normalizedPoint.y,
                text: trimmedText
            )
        }

        self.pendingLabel = nil
    }

    private func openSidecarInFinder() {
        guard let sidecarURL, sidecarExists else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([sidecarURL])
    }

    private func openRecordingInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func featurePrintForPoint(_ normalizedPoint: CGPoint) -> Data? {
        guard appState.faceFeaturesEnabled else {
            return nil
        }
        let visionPoint = CGPoint(x: normalizedPoint.x, y: 1 - normalizedPoint.y)
        for observation in faceObservations {
            if observation.bounds.contains(visionPoint) {
                return observation.featurePrint
            }
        }
        return nil
    }

    private func loadRecordings(for photo: PhotoItem) -> [RecordingItem] {
        let directory = photo.imageURL.deletingLastPathComponent()
        let baseName = photo.imageURL.deletingPathExtension().lastPathComponent
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension.lowercased() == "m4a" }
            .filter { $0.lastPathComponent.hasPrefix("\(baseName)-") }
            .compactMap { url in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                guard let modifiedAt = values?.contentModificationDate else {
                    return nil
                }
                return RecordingItem(url: url, modifiedAt: modifiedAt)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }
}

private struct BubbleContent: View {
    let title: String
    let coordinates: CGPoint
    let initialText: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @State private var text: String

    init(
        title: String,
        coordinates: CGPoint,
        initialText: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.coordinates = coordinates
        self.initialText = initialText
        self.onSave = onSave
        self.onCancel = onCancel
        self._text = State(initialValue: initialText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text("Coordinates: \(coordinates.x, specifier: "%.3f"), \(coordinates.y, specifier: "%.3f")")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Label text", text: $text)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                Button("Save") {
                    onSave(text)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08))
        )
        .shadow(radius: 8, y: 4)
    }
}

private struct PhotoCanvasView: View {
    let image: NSImage?
    let labels: [PointLabel]
    @Binding var pendingLabel: PendingLabelDraft?
    let isLabelsHidden: Bool
    @Binding var editRequest: LabelEditRequest?
    let faceObservations: [FaceObservation]
    let isFaceFeaturesEnabled: Bool
    let onPlaceLabel: (CGPoint, CGPoint) -> Void
    let onSelectLabel: (PointLabel, CGPoint) -> Void
    let onSaveLabel: (PendingLabelDraft, String) -> Void
    let onCancelLabel: () -> Void
    @State private var labelSizes: [String: CGSize] = [:]

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

                if isFaceFeaturesEnabled && !isLabelsHidden {
                    ForEach(Array(faceObservations.enumerated()), id: \.offset) { _, observation in
                        let rect = faceRect(from: observation.bounds, in: drawRect)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.yellow.opacity(0.9), lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard pendingLabel == nil, !isLabelsHidden else {
                                    return
                                }
                                guard drawRect.contains(value.location), drawRect.width > 0, drawRect.height > 0 else {
                                    return
                                }

                                let normalizedX = (value.location.x - drawRect.minX) / drawRect.width
                                let normalizedY = (value.location.y - drawRect.minY) / drawRect.height
                                onPlaceLabel(CGPoint(x: normalizedX, y: normalizedY), value.location)
                            }
                    )

                if !isLabelsHidden {
                    ForEach(labels) { label in
                        let point = CGPoint(
                            x: drawRect.minX + label.x * drawRect.width,
                            y: drawRect.minY + label.y * drawRect.height
                        )

                        let dotSize: CGFloat = 10
                        let hitSize: CGFloat = 16
                        let isEditing = pendingLabel?.labelID == label.id
                        let dotColor: Color = isEditing ? Color(red: 0.0, green: 0.5686, blue: 1.0) : Color(red: 0.7608, green: 0.5098, blue: 0.9647)
                        let labelSize = labelSizes[label.id] ?? CGSize(width: 80, height: 24)
                        let labelPoint = positionedLabelPoint(
                            from: point,
                            labelSize: labelSize,
                            canvasSize: canvasSize
                        )

                        Circle()
                            .fill(dotColor)
                            .frame(width: dotSize, height: dotSize)
                            .position(x: point.x, y: point.y)

                        Button(action: {
                            onSelectLabel(label, point)
                        }) {
                            Color.clear
                                .frame(width: hitSize, height: hitSize)
                        }
                        .buttonStyle(.plain)
                        .position(x: point.x, y: point.y)

                        Button {
                            onSelectLabel(label, point)
                        } label: {
                            Text(label.text)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.65))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.white.opacity(0.3), radius: 2, x: 0, y: 1)
                                .padding(6)
                                .contentShape(Rectangle())
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear
                                            .preference(
                                                key: LabelSizePreferenceKey.self,
                                                value: [label.id: proxy.size]
                                            )
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .position(x: labelPoint.x, y: labelPoint.y)
                    }
                }

                if let pendingLabel, pendingLabel.isNew {
                    let pendingPoint = CGPoint(
                        x: drawRect.minX + pendingLabel.normalizedPoint.x * drawRect.width,
                        y: drawRect.minY + pendingLabel.normalizedPoint.y * drawRect.height
                    )
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .position(x: pendingPoint.x, y: pendingPoint.y)
                }

                if let pendingLabel {
                    let bubbleSize = CGSize(width: 300, height: 150)
                    let bubblePoint = positionedBubblePoint(
                        from: pendingLabel.anchorPoint,
                        bubbleSize: bubbleSize,
                        canvasSize: canvasSize
                    )

                    BubbleContent(
                        title: pendingLabel.isNew ? "Add Label" : "Edit Label",
                        coordinates: pendingLabel.normalizedPoint,
                        initialText: pendingLabel.text,
                        onSave: { text in
                            onSaveLabel(pendingLabel, text)
                        },
                        onCancel: {
                            onCancelLabel()
                        }
                    )
                    .frame(width: bubbleSize.width, height: bubbleSize.height)
                    .position(x: bubblePoint.x, y: bubblePoint.y)
                }

            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onPreferenceChange(LabelSizePreferenceKey.self) { sizes in
                if !sizes.isEmpty {
                    labelSizes.merge(sizes) { _, new in new }
                }
            }
            .onChange(of: editRequest?.id) { _, _ in
                guard pendingLabel == nil, !isLabelsHidden, let request = editRequest else {
                    return
                }
                guard let label = labels.first(where: { $0.id == request.labelID }) else {
                    editRequest = nil
                    return
                }
                guard drawRect.width > 0, drawRect.height > 0 else {
                    editRequest = nil
                    return
                }

                let anchorPoint = CGPoint(
                    x: drawRect.minX + label.x * drawRect.width,
                    y: drawRect.minY + label.y * drawRect.height
                )
                pendingLabel = PendingLabelDraft(
                    id: UUID(),
                    labelID: label.id,
                    normalizedPoint: CGPoint(x: label.x, y: label.y),
                    anchorPoint: anchorPoint,
                    text: label.text,
                    featurePrint: featurePrintForNormalizedPoint(CGPoint(x: label.x, y: label.y))
                )
                editRequest = nil
            }
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

    private func positionedBubblePoint(
        from anchorPoint: CGPoint,
        bubbleSize: CGSize,
        canvasSize: CGSize
    ) -> CGPoint {
        let margin: CGFloat = 12
        let halfWidth = bubbleSize.width / 2
        let halfHeight = bubbleSize.height / 2
        let preferredBelowY = anchorPoint.y + margin + halfHeight
        let preferredAboveY = anchorPoint.y - margin - halfHeight
        let canFitBelow = (anchorPoint.y + margin + bubbleSize.height) <= canvasSize.height

        let rawX = anchorPoint.x
        let rawY = canFitBelow ? preferredBelowY : preferredAboveY

        let clampedX = min(max(rawX, halfWidth), canvasSize.width - halfWidth)
        let clampedY = min(max(rawY, halfHeight), canvasSize.height - halfHeight)
        return CGPoint(x: clampedX, y: clampedY)
    }

    private func positionedLabelPoint(
        from anchorPoint: CGPoint,
        labelSize: CGSize,
        canvasSize: CGSize
    ) -> CGPoint {
        let margin: CGFloat = 6
        let halfWidth = labelSize.width / 2
        let halfHeight = labelSize.height / 2
        let preferredBelowY = anchorPoint.y + margin + halfHeight
        let preferredAboveY = anchorPoint.y - margin - halfHeight
        let canFitBelow = (anchorPoint.y + margin + labelSize.height) <= canvasSize.height

        let rawX = anchorPoint.x
        let rawY = canFitBelow ? preferredBelowY : preferredAboveY

        let clampedX = min(max(rawX, halfWidth), canvasSize.width - halfWidth)
        let clampedY = min(max(rawY, halfHeight), canvasSize.height - halfHeight)
        return CGPoint(x: clampedX, y: clampedY)
    }

    private func faceRect(from normalizedRect: CGRect, in drawRect: CGRect) -> CGRect {
        let x = drawRect.minX + normalizedRect.minX * drawRect.width
        let y = drawRect.minY + (1 - normalizedRect.maxY) * drawRect.height
        let width = normalizedRect.width * drawRect.width
        let height = normalizedRect.height * drawRect.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func featurePrintForNormalizedPoint(_ normalizedPoint: CGPoint) -> Data? {
        let visionPoint = CGPoint(x: normalizedPoint.x, y: 1 - normalizedPoint.y)
        for observation in faceObservations {
            if observation.bounds.contains(visionPoint) {
                return observation.featurePrint
            }
        }
        return nil
    }
}

private struct PendingLabelDraft: Identifiable {
    let id: UUID
    let labelID: String?
    let normalizedPoint: CGPoint
    let anchorPoint: CGPoint
    var text: String
    let featurePrint: Data?

    var isNew: Bool {
        labelID == nil
    }
}

private struct LabelEditRequest: Identifiable {
    let id: UUID = UUID()
    let labelID: String
}

private struct LabelSizePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGSize] = [:]

    static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct FaceDetectionKey: Equatable {
    let photoID: String?
    let isEnabled: Bool
    let areLabelsHidden: Bool
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

private struct RecordingItem: Identifiable {
    let id: String
    let url: URL
    let modifiedAt: Date

    init(url: URL, modifiedAt: Date) {
        self.url = url
        self.modifiedAt = modifiedAt
        self.id = url.path
    }
}

private final class AudioPlayerController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    let objectWillChange = PassthroughSubject<Void, Never>()
    private(set) var currentURL: URL?
    private(set) var isPlaying = false
    private(set) var isPaused = false
    private(set) var progress: Double = 0
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    func isPlaying(_ url: URL) -> Bool {
        isPlaying && currentURL == url
    }

    func togglePlayback(for url: URL) {
        if isPlaying(url) {
            pause()
        } else if isPaused, currentURL == url {
            resume()
        } else {
            play(url)
        }
    }

    func progress(for url: URL) -> Double {
        guard currentURL == url else {
            return 0
        }
        return progress
    }

    func play(_ url: URL) {
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            self.player = player
            player.delegate = self
            player.play()
            currentURL = url
            isPlaying = true
            isPaused = false
            progress = 0
            startProgressTimer()
            objectWillChange.send()
        } catch {
            stop()
        }
    }

    func pause() {
        guard isPlaying else {
            return
        }
        player?.pause()
        isPlaying = false
        isPaused = true
        stopProgressTimer()
        objectWillChange.send()
    }

    func resume() {
        guard let player, isPaused else {
            return
        }
        player.play()
        isPlaying = true
        isPaused = false
        startProgressTimer()
        objectWillChange.send()
    }

    func stop() {
        player?.stop()
        player = nil
        currentURL = nil
        isPlaying = false
        isPaused = false
        progress = 0
        stopProgressTimer()
        objectWillChange.send()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player else {
                return
            }
            guard player.duration > 0 else {
                return
            }
            let value = player.currentTime / player.duration
            progress = min(max(value, 0), 1)
            objectWillChange.send()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

private struct AudioProgressRing: View {
    let progress: Double
    let isActive: Bool

    var body: some View {
        Circle()
            .trim(from: 0, to: max(0.02, progress))
            .stroke(
                isActive ? Color.accentColor : Color.secondary.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 18, height: 18)
    }
}
