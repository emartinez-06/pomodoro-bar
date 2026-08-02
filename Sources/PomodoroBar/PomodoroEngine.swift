import Foundation

/// Pure Pomodoro state machine with no AppKit or clock dependencies.
/// Time advances only through tick(), one call per elapsed second, so the
/// countdown pauses whenever ticks stop (explicit pause or system sleep).
struct PomodoroEngine {
    enum Phase: Equatable {
        case idle
        case work(round: Int)
        case shortBreak(after: Int)
        case longBreak(after: Int)
    }

    /// Emitted by tick() when an interval finishes, so the app can count
    /// sessions and play the matching sound.
    enum Transition: Equatable {
        case workToShortBreak
        case workToLongBreak
        case workToIdle
        case breakToWork
    }

    struct Config {
        var workDuration = 25 * 60
        var shortBreakDuration = 5 * 60
        var longBreakDuration = 15 * 60
        var longBreakEvery = 4
    }

    let config: Config
    private(set) var phase: Phase = .idle
    private(set) var remaining = 0
    private(set) var totalRounds = 4
    /// Set by tick() when an interval finishes and a cycle (work<->break)
    /// would come next; cleared by advance(). The engine holds here rather
    /// than auto-continuing, so the next phase only starts on an explicit
    /// user action (the Shift+Cmd+A keybind). Never observable while
    /// autoAdvance is on, since tick() clears it in the same call.
    private(set) var pendingTransition: Transition?
    var isPaused = false
    /// When true, tick() moves straight into the next phase at a cycle
    /// boundary instead of holding for advance(), so a whole run needs a
    /// single Start and stops on its own at the end. Read live from
    /// preferences by the caller, so toggling it mid-run takes effect at the
    /// very next boundary.
    var autoAdvance = false

    init(config: Config = Config()) {
        self.config = config
    }

    /// Fraction of the current interval already elapsed, 0 when idle.
    var progress: Double {
        let duration = phaseDuration
        guard duration > 0 else { return 0 }
        return Double(duration - remaining) / Double(duration)
    }

    /// Pomodoros not yet completed in the active run, including the one in progress.
    var pendingRounds: Int {
        switch phase {
        case .idle:
            return 0
        case .work(let round):
            return totalRounds - round + 1
        case .shortBreak(let after), .longBreak(let after):
            return totalRounds - after
        }
    }

    private var phaseDuration: Int {
        switch phase {
        case .idle:
            return 0
        case .work:
            return config.workDuration
        case .shortBreak:
            return config.shortBreakDuration
        case .longBreak:
            return config.longBreakDuration
        }
    }

    mutating func start(rounds: Int) {
        totalRounds = max(1, rounds)
        phase = .work(round: 1)
        remaining = config.workDuration
        isPaused = false
        pendingTransition = nil
    }

    mutating func reset() {
        phase = .idle
        remaining = 0
        isPaused = false
        pendingTransition = nil
    }

    /// Advances the countdown by one second. When an interval finishes, the
    /// run either ends (work -> idle, applied immediately, nothing to start
    /// next) or a cycle boundary is reached (work <-> break), handled by
    /// hold(). Either way the transition is returned so the caller can react
    /// (sound, session count, border flash).
    mutating func tick() -> Transition? {
        guard phase != .idle, !isPaused, pendingTransition == nil else { return nil }
        remaining -= 1
        guard remaining <= 0 else { return nil }
        remaining = 0

        switch phase {
        case .idle:
            return nil
        case .work(let round):
            if round >= totalRounds {
                phase = .idle
                return .workToIdle
            }
            return hold(round % config.longBreakEvery == 0 ? .workToLongBreak : .workToShortBreak)
        case .shortBreak, .longBreak:
            return hold(.breakToWork)
        }
    }

    /// Records the cycle boundary the run just reached. By default the engine
    /// pauses there rather than continuing on its own, and the next phase
    /// only starts when the caller calls advance(); with autoAdvance on it
    /// moves into that phase right away.
    private mutating func hold(_ transition: Transition) -> Transition {
        pendingTransition = transition
        isPaused = true
        if autoAdvance {
            advance()
        }
        return transition
    }

    /// Moves into the phase held by pendingTransition, resuming the
    /// countdown. A no-op if nothing is pending.
    mutating func advance() {
        guard let transition = pendingTransition else { return }
        pendingTransition = nil
        isPaused = false

        switch (transition, phase) {
        case (.workToShortBreak, .work(let round)):
            phase = .shortBreak(after: round)
            remaining = config.shortBreakDuration
        case (.workToLongBreak, .work(let round)):
            phase = .longBreak(after: round)
            remaining = config.longBreakDuration
        case (.breakToWork, .shortBreak(let after)), (.breakToWork, .longBreak(let after)):
            phase = .work(round: after + 1)
            remaining = config.workDuration
        default:
            break
        }
    }
}
