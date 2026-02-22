import Combine

@MainActor
final class AppUIState: ObservableObject {
    @Published var isAirPlayPickerPresented = false
}
