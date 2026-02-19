enum FilenameSortDirection {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }

    var label: String {
        switch self {
        case .ascending:
            return "A->Z"
        case .descending:
            return "Z->A"
        }
    }
}
