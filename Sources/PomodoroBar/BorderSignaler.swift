import AppKit

/// Outlines the focused window via JankyBorders: green during work, warm
/// during rest, transparent otherwise. The caller keeps a borders server
/// owned by this app warm for the span it passes enabled=true, typically an
/// active run; phase transitions then flip the color (or flash it) through
/// client updates that land in milliseconds instead of paying a fresh
/// launch. The server is terminated when enabled turns false and on quit,
/// and everything is a silent no-op when borders is not installed.
final class BorderSignaler {
    /// The three steady-state looks the border can be in. Callers pick one
    /// per render(); flash() pulses through .focus or .rest before a caller
    /// would otherwise settle on .clear at a cycle boundary.
    enum ColorState {
        case clear
        case focus
        case rest
    }

    private static let searchPaths = [
        "/opt/homebrew/bin/borders",
        "/usr/local/bin/borders",
    ]
    private static let focusColor = "active_color=0xffa6e3a1"
    private static let restColor = "active_color=0xfffab387"
    private static let clearColor = "active_color=0x00000000"
    private static let baseStyle = [
        "inactive_color=0x00000000",
        "width=8.0",
        "hidpi=on",
    ]
    private static let flashPulseCount = 3
    private static let flashPulseInterval: TimeInterval = 0.15

    private let binaryPath: String?
    private var server: Process?
    private var appliedColor: String?
    private var flashTimer: Timer?

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
    func apply(enabled: Bool, colorState: ColorState) {
        guard isAvailable else { return }
        guard enabled else {
            shutdown()
            return
        }
        // A flash owns the client calls for its duration; let it finish
        // rather than racing it with a steady-state color.
        guard flashTimer == nil else { return }

        let color = Self.color(for: colorState)
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
    /// transparent. The run is paused awaiting the user's advance keypress at
    /// that point, so the caller's next apply() will naturally settle on
    /// .clear too - this just makes the boundary itself visible.
    func flash(_ colorState: ColorState) {
        guard isAvailable, let server, server.isRunning else { return }
        flashTimer?.invalidate()

        let color = Self.color(for: colorState)
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

    private static func color(for state: ColorState) -> String {
        switch state {
        case .clear: return clearColor
        case .focus: return focusColor
        case .rest: return restColor
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
