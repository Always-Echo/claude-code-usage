import AppKit
import SwiftUI

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let dataService = UsageDataService()
    private var mouseMonitor: Any?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "Claude Usage")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem.isVisible = true

        let contentView = UsagePopoverView(dataService: dataService)
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.behavior = .applicationDefined
        popover.delegate = self
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            dataService.refreshIfNeeded()
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
            startMouseMonitor()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopMouseMonitor()
    }

    private func startMouseMonitor() {
        stopMouseMonitor()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown else { return }
            guard let window = self.popover.contentViewController?.view.window else { return }
            let mouseLocation = NSEvent.mouseLocation
            let windowFrame = window.frame
            if !windowFrame.contains(mouseLocation) {
                Task { @MainActor in
                    self.closePopover()
                }
            }
        }
    }

    private func stopMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
}

extension StatusBarController: NSPopoverDelegate {
    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            self.stopMouseMonitor()
        }
    }
}
