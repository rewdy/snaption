enum FilenameSortDirection {
    case filenameAscending
    case filenameDescending
    case modifiedAscending
    case modifiedDescending

    mutating func toggle() {
        switch self {
        case .filenameAscending:
            self = .filenameDescending
        case .filenameDescending:
            self = .filenameAscending
        case .modifiedAscending:
            self = .modifiedDescending
        case .modifiedDescending:
            self = .modifiedAscending
        }
    }
}
