import AppKit
import SwiftUI

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let dataService = UsageDataService()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "Claude Usage")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let contentView = UsagePopoverView(dataService: dataService)
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.behavior = .transient
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            Task { @MainActor in
                self.dataService.refreshIfNeeded()
            }
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
