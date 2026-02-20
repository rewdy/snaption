import AppKit
import Foundation

protocol PresentationWindowControlling: AnyObject {
    func showWindow()
    func updatePhoto(url: URL?)
    func hideWindow()
}

@MainActor
final class PresentationWindowController: PresentationWindowControlling {
    private var window: NSWindow?
    private let imageView = NSImageView()

    func showWindow() {
        ensureWindow()
        moveWindowToFirstExternalDisplay()
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
        window.level = .normal
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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

    private func moveWindowToFirstExternalDisplay() {
        guard
            let window,
            let screen = NSScreen.screens.dropFirst().first
        else {
            return
        }

        window.setFrame(screen.frame, display: true)
    }
}
