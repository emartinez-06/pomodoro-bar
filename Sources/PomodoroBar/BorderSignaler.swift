import AppKit

/// Outlines the focused window in green during work intervals by running
/// JankyBorders as an owned child process: spawned when focus time starts,
/// terminated when it ends. Nothing runs and nothing is drawn outside of
/// work intervals, and everything is a silent no-op when borders is not
/// installed.
final class BorderSignaler {
    private static let searchPaths = [
        "/opt/homebrew/bin/borders",
        "/usr/local/bin/borders",
    ]
    private static let style = [
        "active_color=0xffa6e3a1",
        "inactive_color=0x00000000",
        "width=6.0",
        "hidpi=on",
    ]

    private let binaryPath: String?
    private var process: Process?

    var isAvailable: Bool { binaryPath != nil }

    init() {
        binaryPath = Self.searchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
        // If a previous PomodoroBar crashed mid-session, its borders child was
        // orphaned and would show a stale focus border forever; reap it here.
        // PomodoroBar owns the borders process, so no separately managed
        // JankyBorders service should be running alongside it.
        if isAvailable {
            reapStrayProcess()
        }
    }

    func show() {
        guard let binaryPath, process == nil else { return }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: binaryPath)
        child.arguments = Self.style
        child.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.process = nil }
        }
        do {
            try child.run()
            process = child
        } catch {
            NSLog("BorderSignaler: failed to launch borders: \(error)")
        }
    }

    func hide() {
        process?.terminate()
        process = nil
    }

    private func reapStrayProcess() {
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-x", "borders"]
        try? pkill.run()
        pkill.waitUntilExit()
    }
}
