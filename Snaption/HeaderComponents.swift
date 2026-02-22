import SwiftUI

struct EndSlideshowToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button("End slideshow", action: action)
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.76, green: 0.51, blue: 0.96))
            .foregroundStyle(.white)
    }
}

struct FaceFeaturesMenuContent: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if appState.faceFeaturesEnabled {
            Button("Disable Face Features") {
                appState.requestDisableFaceFeatures()
            }
        } else {
            Button("Enable Face Features") {
                appState.enableFaceFeatures()
            }
        }
    }
}

struct PresentationDestinationMenuContent: View {
    @ObservedObject var appState: AppState
    @ObservedObject var uiState: AppUIState

    var body: some View {
        if appState.availablePresentationDisplays.isEmpty {
            Text("No displays found")
        } else {
            ForEach(appState.availablePresentationDisplays) { display in
                Button {
                    appState.selectPresentationDisplay(display.id)
                } label: {
                    if display.id == appState.presentationDisplayID {
                        Label(display.name, systemImage: "checkmark")
                    } else {
                        Text(display.name)
                    }
                }
            }
        }

        Divider()

        Button("AirPlay Devices...") {
            uiState.isAirPlayPickerPresented = true
        }
    }
}

struct PresentationMenuLabel: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.stack")
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
