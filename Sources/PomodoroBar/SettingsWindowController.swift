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
        let content = NSHostingView(
            rootView: SettingsView(preferences: preferences, borderAvailable: borderAvailable)
        )
        window.contentView = content
        // The form is fixed-width and sizes itself vertically, and the window
        // is not resizable, so take the height from the view rather than a
        // hardcoded rect that every added row silently clips further. Capped
        // at the screen so a tall form can never run off the bottom.
        let fitted = content.fittingSize
        let maxHeight = (window.screen ?? NSScreen.main)?.visibleFrame.height ?? fitted.height
        window.setContentSize(NSSize(width: fitted.width, height: min(fitted.height, maxHeight - 40)))
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
