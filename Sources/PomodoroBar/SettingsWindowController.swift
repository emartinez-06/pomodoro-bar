import AppKit
import SwiftUI

/// Owns the single Settings window instance; repeated show() calls bring the
/// existing window forward instead of creating duplicates.
final class SettingsWindowController: NSWindowController {
    convenience init(preferences: Preferences, borderAvailable: Bool) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PomodoroBar Settings"
        window.contentView = NSHostingView(
            rootView: SettingsView(preferences: preferences, borderAvailable: borderAvailable)
        )
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
