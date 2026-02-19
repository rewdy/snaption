import Foundation

struct SidecarService {
    private let iso8601Formatter = ISO8601DateFormatter()

    func readDocument(for photo: PhotoItem) throws -> SidecarDocument {
        guard FileManager.default.fileExists(atPath: photo.sidecarURL.path) else {
            return SidecarDocument(
                frontMatterLines: ["photo: \(photo.filename)"],
                notesMarkdown: "",
                hadFrontMatter: false,
                parseWarning: nil
            )
        }

        let raw = try String(contentsOf: photo.sidecarURL, encoding: .utf8)
        return parse(raw: raw, photoFilename: photo.filename)
    }

    func writeDocument(_ document: SidecarDocument, for photo: PhotoItem) throws {
        var lines = document.frontMatterLines
        upsertScalar(key: "photo", value: photo.filename, in: &lines)
        upsertScalar(key: "updated_at", value: iso8601Formatter.string(from: Date()), in: &lines)

        let frontMatter = lines.joined(separator: "\n")
        let body = document.notesMarkdown
        let output = "---\n\(frontMatter)\n---\n\n\(body)"

        let directoryURL = photo.sidecarURL.deletingLastPathComponent()
        let temporaryURL = directoryURL.appendingPathComponent(".\(photo.sidecarURL.lastPathComponent).tmp")

        try output.write(to: temporaryURL, atomically: true, encoding: .utf8)
        if FileManager.default.fileExists(atPath: photo.sidecarURL.path) {
            _ = try FileManager.default.replaceItemAt(photo.sidecarURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: photo.sidecarURL)
        }
    }

    private func parse(raw: String, photoFilename: String) -> SidecarDocument {
        let lines = raw.components(separatedBy: .newlines)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return SidecarDocument(
                frontMatterLines: ["photo: \(photoFilename)"],
                notesMarkdown: raw,
                hadFrontMatter: false,
                parseWarning: nil
            )
        }

        guard let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return SidecarDocument(
                frontMatterLines: ["photo: \(photoFilename)"],
                notesMarkdown: raw,
                hadFrontMatter: false,
                parseWarning: "Malformed front matter. Notes were loaded as plain markdown."
            )
        }

        let frontMatterLines = Array(lines[1..<closingIndex])
        let bodyStartIndex = lines.index(after: closingIndex)
        let bodyLines = bodyStartIndex < lines.endIndex ? lines[bodyStartIndex...] : []
        let notesMarkdown = bodyLines.joined(separator: "\n").trimmingPrefix("\n")

        return SidecarDocument(
            frontMatterLines: frontMatterLines,
            notesMarkdown: notesMarkdown,
            hadFrontMatter: true,
            parseWarning: nil
        )
    }

    private func upsertScalar(key: String, value: String, in lines: inout [String]) {
        let prefix = "\(key):"
        if let lineIndex = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix(prefix) && !line.hasPrefix(" ")
        }) {
            lines[lineIndex] = "\(key): \(value)"
            return
        }

        lines.append("\(key): \(value)")
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return String(dropFirst(prefix.count))
    }
}
