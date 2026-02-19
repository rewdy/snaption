import Foundation
import XCTest
@testable import PhotoInfoApp

final class SidecarServiceTests: XCTestCase {
    func testReadMissingSidecarReturnsDefaults() throws {
        let (tempDir, photo) = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = SidecarService()
        let document = try service.readDocument(for: photo)

        XCTAssertEqual(document.notesMarkdown, "")
        XCTAssertTrue(document.tags.isEmpty)
        XCTAssertTrue(document.labels.isEmpty)
        XCTAssertTrue(document.frontMatterLines.contains(where: { $0.contains("photo:") }))
    }

    func testWriteThenReadRoundtripIncludesTagsAndLabels() throws {
        let (tempDir, photo) = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = SidecarService()
        let input = SidecarDocument(
            frontMatterLines: ["custom_key: custom_value"],
            notesMarkdown: "Family reunion notes",
            tags: ["reunion", "1985"],
            labels: [PointLabel(id: "lbl-1", x: 0.25, y: 0.4, text: "Dad")],
            hadFrontMatter: true,
            parseWarning: nil
        )

        try service.writeDocument(input, for: photo)
        let output = try service.readDocument(for: photo)

        XCTAssertTrue(output.notesMarkdown.contains("Family reunion notes"))
        XCTAssertEqual(output.tags.count, 2)
        XCTAssertEqual(output.labels.count, 1)
        XCTAssertEqual(output.labels.first?.text, "Dad")
        XCTAssertTrue(output.frontMatterLines.contains(where: { $0 == "custom_key: custom_value" }))
    }

    func testMalformedFrontMatterFallsBackToNotesBody() throws {
        let (tempDir, photo) = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let malformed = """
        ---
        tags:
          - one
        notes without closing delimiter
        """
        try malformed.write(to: photo.sidecarURL, atomically: true, encoding: .utf8)

        let service = SidecarService()
        let document = try service.readDocument(for: photo)

        XCTAssertNotNil(document.parseWarning)
        XCTAssertTrue(document.notesMarkdown.contains("notes without closing delimiter"))
    }

    func testUnknownFrontMatterKeyIsPreservedOnWrite() throws {
        let (tempDir, photo) = try makePhotoFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let initial = """
        ---
        mystery_key: mystery_value
        tags:
          - legacy
        ---

        hello
        """
        try initial.write(to: photo.sidecarURL, atomically: true, encoding: .utf8)

        let service = SidecarService()
        var document = try service.readDocument(for: photo)
        document.notesMarkdown = "updated body"
        try service.writeDocument(document, for: photo)

        let updatedRaw = try String(contentsOf: photo.sidecarURL, encoding: .utf8)
        XCTAssertTrue(updatedRaw.contains("mystery_key: mystery_value"))
    }

    private func makePhotoFixture() throws -> (URL, PhotoItem) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let imageURL = tempDir.appendingPathComponent("IMG_0001.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: imageURL)

        let item = PhotoItem(
            imageURL: imageURL,
            sidecarURL: tempDir.appendingPathComponent("IMG_0001.md"),
            filename: "IMG_0001.jpg",
            relativePath: "IMG_0001.jpg"
        )
        return (tempDir, item)
    }
}
