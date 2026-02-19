import Foundation

struct SidecarDocument {
    var frontMatterLines: [String]
    var notesMarkdown: String
    var hadFrontMatter: Bool
    var parseWarning: String?
}

enum NotesSaveState {
    case clean
    case dirty
    case saving
    case error(String)

    var label: String {
        switch self {
        case .clean:
            return "Saved"
        case .dirty:
            return "Unsaved changes"
        case .saving:
            return "Saving..."
        case let .error(message):
            return "Save failed: \(message)"
        }
    }
}
