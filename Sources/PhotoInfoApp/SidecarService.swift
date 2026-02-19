import Foundation

struct SidecarService {
    private let iso8601Formatter = ISO8601DateFormatter()
    private let managedKeys: Set<String> = ["photo", "updated_at", "tags", "labels"]

    func readDocument(for photo: PhotoItem) throws -> SidecarDocument {
        guard FileManager.default.fileExists(atPath: photo.sidecarURL.path) else {
            return SidecarDocument(
                frontMatterLines: ["photo: \(photo.filename)"],
                notesMarkdown: "",
                tags: [],
                labels: [],
                hadFrontMatter: false,
                parseWarning: nil
            )
        }

        let raw = try String(contentsOf: photo.sidecarURL, encoding: .utf8)
        return parse(raw: raw, photoFilename: photo.filename)
    }

    func writeDocument(_ document: SidecarDocument, for photo: PhotoItem) throws {
        var lines = removeManagedBlocks(from: document.frontMatterLines)
        lines.append("photo: \(photo.filename)")
        lines.append(contentsOf: renderTagsBlock(document.tags))
        lines.append(contentsOf: renderLabelsBlock(document.labels))
        lines.append("updated_at: \(iso8601Formatter.string(from: Date()))")

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
                tags: [],
                labels: [],
                hadFrontMatter: false,
                parseWarning: nil
            )
        }

        guard let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return SidecarDocument(
                frontMatterLines: ["photo: \(photoFilename)"],
                notesMarkdown: raw,
                tags: [],
                labels: [],
                hadFrontMatter: false,
                parseWarning: "Malformed front matter. Notes were loaded as plain markdown."
            )
        }

        let frontMatterLines = Array(lines[1..<closingIndex])
        let bodyStartIndex = lines.index(after: closingIndex)
        let bodyLines = bodyStartIndex < lines.endIndex ? lines[bodyStartIndex...] : []
        let notesMarkdown = bodyLines.joined(separator: "\n").trimmingPrefix("\n")
        let tags = parseTags(from: frontMatterLines)
        let labels = parseLabels(from: frontMatterLines)

        return SidecarDocument(
            frontMatterLines: frontMatterLines,
            notesMarkdown: notesMarkdown,
            tags: tags,
            labels: labels,
            hadFrontMatter: true,
            parseWarning: nil
        )
    }

    private func removeManagedBlocks(from lines: [String]) -> [String] {
        var result: [String] = []
        var currentTopLevelKey: String?

        for line in lines {
            if let key = topLevelKey(for: line) {
                currentTopLevelKey = key
                if managedKeys.contains(key) {
                    continue
                }
                result.append(line)
                continue
            }

            if let currentTopLevelKey, managedKeys.contains(currentTopLevelKey) {
                continue
            }

            result.append(line)
        }

        while result.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            _ = result.popLast()
        }

        return result
    }

    private func topLevelKey(for line: String) -> String? {
        guard !line.hasPrefix(" "), let separatorIndex = line.firstIndex(of: ":") else {
            return nil
        }
        return String(line[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
    }

    private func parseTags(from lines: [String]) -> [String] {
        guard let block = blockLines(for: "tags", in: lines) else {
            return []
        }

        let header = block[0]
        let inlinePortion = header.replacingOccurrences(of: "tags:", with: "").trimmingCharacters(in: .whitespaces)
        if inlinePortion.hasPrefix("[") && inlinePortion.hasSuffix("]") {
            let inner = inlinePortion.dropFirst().dropLast()
            return inner
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .map(unquote)
                .filter { !$0.isEmpty }
        }

        return block.dropFirst().compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") else {
                return nil
            }
            return unquote(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
        }
    }

    private func parseLabels(from lines: [String]) -> [PointLabel] {
        guard let block = blockLines(for: "labels", in: lines) else {
            return []
        }

        var items: [[String: String]] = []
        var current: [String: String] = [:]

        for line in block.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                if !current.isEmpty {
                    items.append(current)
                    current = [:]
                }
                let payload = String(trimmed.dropFirst(2))
                if let (key, value) = splitKeyValue(payload) {
                    current[key] = value
                }
                continue
            }

            if let (key, value) = splitKeyValue(trimmed) {
                current[key] = value
            }
        }

        if !current.isEmpty {
            items.append(current)
        }

        return items.compactMap { item in
            guard
                let xRaw = item["x"],
                let yRaw = item["y"],
                let x = Double(xRaw),
                let y = Double(yRaw),
                let text = item["text"],
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            let id = item["id"] ?? "lbl-\(UUID().uuidString.prefix(8))"
            return PointLabel(id: id, x: x, y: y, text: unquote(text))
        }
    }

    private func blockLines(for key: String, in lines: [String]) -> [String]? {
        var collected: [String] = []
        var inBlock = false

        for line in lines {
            if let topLevelKey = topLevelKey(for: line) {
                if inBlock {
                    break
                }
                if topLevelKey == key {
                    inBlock = true
                    collected.append(line)
                }
                continue
            }

            if inBlock {
                collected.append(line)
            }
        }

        return collected.isEmpty ? nil : collected
    }

    private func renderTagsBlock(_ tags: [String]) -> [String] {
        let normalized = tags
            .map { unquote($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }

        guard !normalized.isEmpty else {
            return []
        }

        var lines = ["tags:"]
        for tag in normalized {
            lines.append("  - \"\(escapeDoubleQuotes(tag))\"")
        }
        return lines
    }

    private func renderLabelsBlock(_ labels: [PointLabel]) -> [String] {
        guard !labels.isEmpty else {
            return []
        }

        var lines = ["labels:"]
        for label in labels {
            lines.append("  - id: \(label.id)")
            lines.append("    x: \(formatDecimal(label.x))")
            lines.append("    y: \(formatDecimal(label.y))")
            lines.append("    text: \"\(escapeDoubleQuotes(label.text))\"")
        }
        return lines
    }

    private func splitKeyValue(_ line: String) -> (String, String)? {
        guard let separatorIndex = line.firstIndex(of: ":") else {
            return nil
        }

        let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
        let valueStart = line.index(after: separatorIndex)
        let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            return nil
        }
        return (key, value)
    }

    private func unquote(_ value: String) -> String {
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private func escapeDoubleQuotes(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func formatDecimal(_ value: Double) -> String {
        String(format: "%.6f", value)
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
