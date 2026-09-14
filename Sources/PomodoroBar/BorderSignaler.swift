import AppKit

/// Outlines the focused window via JankyBorders: green during work, warm
/// during rest, transparent otherwise. The caller keeps a borders server
/// owned by this app warm for the span it passes enabled=true, typically an
/// active run; phase transitions then flip the color (or flash it) through
/// client updates that land in milliseconds instead of paying a fresh
/// launch. The server is terminated when enabled turns false and on quit,
/// and everything is a silent no-op when borders is not available.
final class BorderSignaler {
    /// The three steady-state looks the border can be in. Callers pick one
    /// per render(); flash() pulses through .focus or .rest before a caller
    /// would otherwise settle on .clear at a cycle boundary.
    enum ColorState {
        case clear
        case focus
        case rest
    }

    /// `make install`/`make dist` place a `borders` binary built from
    /// third_party/janky-borders next to the PomodoroBar executable, so the
    /// app always has a known, bundled copy and never depends on the user
    /// separately installing JankyBorders. The Homebrew paths remain as a
    /// fallback for `swift run`/`swift build` dev flows that skip the
    /// Makefile and so never produce that bundled binary.
    private static var searchPaths: [String] {
        var paths: [String] = []
        if let bundled = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("borders")
            .path {
            paths.append(bundled)
        }
        paths.append(contentsOf: [
            "/opt/homebrew/bin/borders",
            "/usr/local/bin/borders",
        ])
        return paths
    }
    private static let clearColor = "active_color=0x00000000"
    private static let baseStyle = [
        "inactive_color=0x00000000",
        "width=8.0",
        "hidpi=on",
    ]
    private static let flashPulseCount = 3
    private static let flashPulseInterval: TimeInterval = 0.15

    private let preferences: Preferences
    private let binaryPath: String?
    private var server: Process?
    private var appliedColor: String?
    private var flashTimer: Timer?

    var isAvailable: Bool { binaryPath != nil }

    init(preferences: Preferences) {
        self.preferences = preferences
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
    func apply(enabled: Bool, colorState: ColorState) {
        guard isAvailable else { return }
        guard enabled else {
            shutdown()
            return
        }
        // A flash owns the client calls for its duration; let it finish
        // rather than racing it with a steady-state color.
        guard flashTimer == nil else { return }

        let color = color(for: colorState)
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

    /// Pulses the border between `colorState` and transparent a few times to
    /// mark a phase boundary (a work or rest interval ending), then leaves it
    /// transparent. Whatever the caller's next apply() asks for settles a
    /// moment later: .clear when the run parks at the boundary waiting to be
    /// continued, or the incoming phase's color when auto-advance carried it
    /// straight on - this just makes the boundary itself visible first.
    func flash(_ colorState: ColorState) {
        guard isAvailable, let server, server.isRunning else { return }
        flashTimer?.invalidate()

        let color = color(for: colorState)
        var step = 0
        let totalSteps = Self.flashPulseCount * 2
        let timer = Timer(timeInterval: Self.flashPulseInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let target = step.isMultiple(of: 2) ? color : Self.clearColor
            self.runClient(arguments: [target])
            self.appliedColor = target
            step += 1
            if step >= totalSteps {
                timer.invalidate()
                self.flashTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        flashTimer = timer
        timer.fire()
    }

    func shutdown() {
        flashTimer?.invalidate()
        flashTimer = nil
        server?.terminate()
        server = nil
        appliedColor = nil
    }

    private func color(for state: ColorState) -> String {
        switch state {
        case .clear: return Self.clearColor
        case .focus: return "active_color=\(preferences.focusColorHex)"
        case .rest: return "active_color=\(preferences.restColorHex)"
        }
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

        // The client hands its message to the server over IPC and normally
        // exits within milliseconds. Waiting for it synchronously (via
        // waitUntilExit) would block the app's main run loop - and with it
        // the status item menu and the global hotkey - if the server ever
        // wedges. So wait asynchronously via terminationHandler instead, with
        // a timeout that kills both the client and the wedged server, so the
        // next apply() respawns a fresh one rather than hanging forever.
        let timeout = DispatchWorkItem { [weak self] in
            guard client.isRunning else { return }
            client.terminate()
            NSLog("BorderSignaler: borders client timed out; restarting server")
            self?.server?.terminate()
            self?.server = nil
            self?.appliedColor = nil
        }
        client.terminationHandler = { _ in timeout.cancel() }

        do {
            try client.run()
        } catch {
            NSLog("BorderSignaler: failed to send borders update: \(error)")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: timeout)
    }

    private func reapStrayProcess() {
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-x", "borders"]
        try? pkill.run()
        pkill.waitUntilExit()
    }
}
