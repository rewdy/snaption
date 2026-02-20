import AppKit
import Foundation

protocol DisplayMonitoring: AnyObject {
    var hasExternalDisplay: Bool { get }
    func startMonitoring(onChange: @escaping (Bool) -> Void)
    func stopMonitoring()
}

@MainActor
final class DisplayMonitor: DisplayMonitoring {
    private var observer: NSObjectProtocol?
    private var onChange: ((Bool) -> Void)?

    var hasExternalDisplay: Bool {
        NSScreen.screens.count > 1
    }

    func startMonitoring(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        onChange(hasExternalDisplay)

        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }
            onChange(self.hasExternalDisplay)
        }
    }

    func stopMonitoring() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        onChange = nil
    }
}
