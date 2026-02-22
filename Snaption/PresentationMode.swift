import AppKit
import Foundation

protocol PresentationWindowControlling: AnyObject {
    func showWindow(on displayID: CGDirectDisplayID?)
    func moveWindow(to displayID: CGDirectDisplayID?)
    func updatePhoto(url: URL?)
    func hideWindow()
}

@MainActor
final class PresentationWindowController: PresentationWindowControlling {
    private var window: NSWindow?
    private let imageView = NSImageView()
    private var previousPresentationOptions: NSApplication.PresentationOptions?

    func showWindow(on displayID: CGDirectDisplayID?) {
        ensureWindow()
        beginSystemPresentationIfNeeded()
        moveWindow(to: displayID)
        window?.orderFrontRegardless()
    }

    func updatePhoto(url: URL?) {
        guard window != nil else {
            return
        }

        if let url {
            imageView.image = NSImage(contentsOf: url)
        } else {
            imageView.image = nil
        }
    }

    func hideWindow() {
        window?.orderOut(nil)
        endSystemPresentationIfNeeded()
    }

    func moveWindow(to displayID: CGDirectDisplayID?) {
        guard let window else {
            return
        }

        let targetScreen: NSScreen? = {
            if let displayID, let screen = screenForDisplayID(displayID) {
                return screen
            }
            return NSScreen.screens.dropFirst().first
        }()

        guard let targetScreen else {
            return
        }

        window.setFrame(targetScreen.frame, display: true)
    }

    private func ensureWindow() {
        if window != nil {
            return
        }

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenDisallowsTiling]
        window.ignoresMouseEvents = true

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.animates = false
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor

        let containerView = NSView(frame: .zero)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        containerView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        window.contentView = containerView
        self.window = window
    }

    private func beginSystemPresentationIfNeeded() {
        guard previousPresentationOptions == nil else {
            return
        }
        previousPresentationOptions = NSApplication.shared.presentationOptions
        NSApplication.shared.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableSessionTermination,
            .disableHideApplication
        ]
    }

    private func endSystemPresentationIfNeeded() {
        guard let previousPresentationOptions else {
            return
        }
        NSApplication.shared.presentationOptions = previousPresentationOptions
        self.previousPresentationOptions = nil
    }

    private func screenForDisplayID(_ displayID: CGDirectDisplayID) -> NSScreen? {
        for screen in NSScreen.screens {
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               screenNumber.uint32Value == displayID {
                return screen
            }
        }
        return nil
    }
}
