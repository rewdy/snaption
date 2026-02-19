import AppKit
import Foundation

protocol ProjectService {
    func selectProjectFolder() throws -> URL?
}

struct DefaultProjectService: ProjectService {
    func selectProjectFolder() throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Photo Project Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        return panel.runModal() == .OK ? panel.url : nil
    }
}
