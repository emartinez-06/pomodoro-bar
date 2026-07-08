import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var engine = PomodoroEngine()
    private let store = SessionStore()
    private let border = BorderSignaler()

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var currentSound: NSSound?
    private var hotKey: GlobalHotKey?

    private let sessionsView = SessionsView(frame: NSRect(x: 0, y: 0, width: 240, height: 104))
    private let statusInfoItem = NSMenuItem()
    private let startPauseItem = NSMenuItem()
    private let resetItem = NSMenuItem()
    private let dailyGoalItem = NSMenuItem()
    private let focusBorderItem = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        }
        statusItem.menu = buildMenu()
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_A, modifiers: cmdKey | shiftKey) { [weak self] in
            self?.startPause()
        }
        if hotKey == nil {
            NSLog("GlobalHotKey: Shift+Cmd+A registration failed; running without a hotkey")
        }
        render()
    }

    func applicationWillTerminate(_ notification: Notification) {
        border.shutdown()
    }

    func menuWillOpen(_ menu: NSMenu) {
        render()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let sessionsItem = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 264, height: 112))
        sessionsView.frame = NSRect(x: 12, y: 4, width: 240, height: 104)
        container.addSubview(sessionsView)
        sessionsItem.view = container
        menu.addItem(sessionsItem)

        statusInfoItem.isEnabled = false
        menu.addItem(statusInfoItem)

        menu.addItem(.separator())

        startPauseItem.target = self
        startPauseItem.action = #selector(startPause)
        startPauseItem.keyEquivalent = "a"
        startPauseItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(startPauseItem)

        resetItem.title = "Reset"
        resetItem.target = self
        resetItem.action = #selector(resetRun)
        menu.addItem(resetItem)

        menu.addItem(.separator())

        dailyGoalItem.title = "Daily Goal"
        let goalMenu = NSMenu()
        goalMenu.autoenablesItems = false
        for count in 1...12 {
            let item = NSMenuItem(title: "\(count)", action: #selector(selectDailyGoal(_:)), keyEquivalent: "")
            item.target = self
            item.tag = count
            goalMenu.addItem(item)
        }
        dailyGoalItem.submenu = goalMenu
        menu.addItem(dailyGoalItem)

        focusBorderItem.title = "Green Focus Border"
        focusBorderItem.target = self
        focusBorderItem.action = #selector(toggleFocusBorder)
        focusBorderItem.isEnabled = border.isAvailable
        focusBorderItem.toolTip = border.isAvailable
            ? "Outline the focused window with JankyBorders during work intervals"
            : "Install JankyBorders (brew install felixkratz/formulae/borders) to enable"
        menu.addItem(focusBorderItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit PomodoroBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    // MARK: - Actions

    @objc private func startPause() {
        switch engine.phase {
        case .idle:
            // A run covers exactly the sessions still needed to reach the
            // daily goal, so completing a run means completing the day.
            engine.start(rounds: max(store.dailyGoal - store.todayCount(), 1))
            startTimer()
        default:
            if engine.isPaused {
                engine.isPaused = false
                startTimer()
            } else {
                engine.isPaused = true
                stopTimer()
            }
        }
        render()
    }

    @objc private func resetRun() {
        engine.reset()
        stopTimer()
        render()
    }

    @objc private func selectDailyGoal(_ sender: NSMenuItem) {
        store.dailyGoal = sender.tag
        render()
    }

    @objc private func toggleFocusBorder() {
        store.focusBorderEnabled.toggle()
        render()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps the countdown running while the dropdown menu is open.
        RunLoop.main.add(ticker, forMode: .common)
        timer = ticker
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        switch engine.tick() {
        case .workToShortBreak, .workToLongBreak:
            store.recordSession()
            play("Glass")
        case .workToIdle:
            store.recordSession()
            play("Hero")
            stopTimer()
        case .breakToWork:
            play("Ping")
        case nil:
            break
        }
        render()
    }

    private func play(_ name: String) {
        currentSound?.stop()
        currentSound = NSSound(named: name)
        currentSound?.play()
    }

    // MARK: - Rendering

    private func render() {
        if let button = statusItem.button {
            button.image = StatusRingRenderer.image(
                progress: engine.progress,
                color: ringColor,
                dimmed: engine.isPaused
            )
            button.title = engine.phase == .idle ? "" : " " + formattedRemaining
            button.toolTip = "PomodoroBar: \(statusText)"
        }

        statusInfoItem.title = statusText
        switch engine.phase {
        case .idle:
            startPauseItem.title = "Start"
        default:
            startPauseItem.title = engine.isPaused ? "Resume" : "Pause"
        }
        resetItem.isEnabled = engine.phase != .idle
        if let submenu = dailyGoalItem.submenu {
            for item in submenu.items {
                item.state = item.tag == store.dailyGoal ? .on : .off
            }
        }
        focusBorderItem.state = store.focusBorderEnabled && border.isAvailable ? .on : .off

        let todayCount = store.todayCount()
        sessionsView.update(
            todayCount: todayCount,
            pendingToGoal: max(store.dailyGoal - todayCount, 0),
            history: store.lastSevenDays()
        )

        updateBorder()
    }

    private func updateBorder() {
        let inFocusedWork: Bool
        if case .work = engine.phase, !engine.isPaused {
            inFocusedWork = true
        } else {
            inFocusedWork = false
        }
        // The warm server is scoped to active runs: zero resource cost while
        // idle, instant color flips for every transition within a run.
        border.apply(
            enabled: store.focusBorderEnabled && engine.phase != .idle,
            focused: inFocusedWork
        )
    }

    private var ringColor: NSColor? {
        switch engine.phase {
        case .idle:
            return nil
        case .work:
            return .systemRed
        case .shortBreak, .longBreak:
            return .systemGreen
        }
    }

    private var formattedRemaining: String {
        String(format: "%02d:%02d", engine.remaining / 60, engine.remaining % 60)
    }

    private var statusText: String {
        let base: String
        switch engine.phase {
        case .idle:
            base = "Idle"
        case .work:
            base = "Work, session \(store.todayCount() + 1) of \(store.dailyGoal) today"
        case .shortBreak:
            base = "Short break"
        case .longBreak:
            base = "Long break"
        }
        return engine.phase != .idle && engine.isPaused ? "Paused: \(base)" : base
    }
}
