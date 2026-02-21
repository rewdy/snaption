import AVKit
import SwiftUI

struct AirPlayRoutePickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.isRoutePickerButtonBordered = true
        return view
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
