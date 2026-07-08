import AppKit

/// Outlines the focused window in green during work intervals via JankyBorders.
/// The caller keeps a borders server owned by this app warm (fully transparent
/// when not focused) for the span it passes enabled=true, typically an active
/// run; phase transitions then flip the color through client updates that land
/// in milliseconds instead of paying a fresh launch. The server is terminated
/// when enabled turns false and on quit, and everything is a silent no-op when
/// borders is not installed.
final class BorderSignaler {
    private static let searchPaths = [
        "/opt/homebrew/bin/borders",
        "/usr/local/bin/borders",
    ]
    private static let focusColor = "active_color=0xffa6e3a1"
    private static let clearColor = "active_color=0x00000000"
    private static let baseStyle = [
        "inactive_color=0x00000000",
        "width=6.0",
        "hidpi=on",
    ]

    private let binaryPath: String?
    private var server: Process?
    private var appliedColor: String?

    var isAvailable: Bool { binaryPath != nil }

    init() {
        binaryPath = Self.searchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
        // If a previous PomodoroBar crashed, its borders child was orphaned and
        // would draw forever; reap it here. PomodoroBar owns the borders
        // process, so no separately managed JankyBorders service should run
        // alongside it.
        if isAvailable {
            reapStrayProcess()
        }
    }

    /// Reconciles the borders process with the desired state. Called on every
    /// render; cheap unless the color actually changes.
    func apply(enabled: Bool, focused: Bool) {
        guard isAvailable else { return }
        guard enabled else {
            shutdown()
            return
        }

        let color = focused ? Self.focusColor : Self.clearColor
        if let server, server.isRunning {
            guard color != appliedColor else { return }
            runClient(arguments: [color])
            appliedColor = color
        } else {
            // Spawn the server directly with the desired color; a client call
            // this early could race the server's mach port registration and
            // accidentally become a second server.
            spawnServer(color: color)
        }
    }

    func shutdown() {
        server?.terminate()
        server = nil
        appliedColor = nil
    }

    private func spawnServer(color: String) {
        guard let binaryPath else { return }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: binaryPath)
        child.arguments = [color] + Self.baseStyle
        child.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.server = nil
                self?.appliedColor = nil
            }
        }
        do {
            try child.run()
            server = child
            appliedColor = color
        } catch {
            NSLog("BorderSignaler: failed to launch borders: \(error)")
        }
    }

    private func runClient(arguments: [String]) {
        guard let binaryPath else { return }
        let client = Process()
        client.executableURL = URL(fileURLWithPath: binaryPath)
        client.arguments = arguments
        do {
            try client.run()
            client.waitUntilExit()
        } catch {
            NSLog("BorderSignaler: failed to send borders update: \(error)")
        }
    }

    private func reapStrayProcess() {
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-x", "borders"]
        try? pkill.run()
        pkill.waitUntilExit()
    }
}
