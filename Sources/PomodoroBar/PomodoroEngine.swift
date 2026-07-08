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
    var isPaused = false

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
    }

    mutating func reset() {
        phase = .idle
        remaining = 0
        isPaused = false
    }

    /// Advances the countdown by one second and performs at most one
    /// phase transition, returned so the caller can react to it.
    mutating func tick() -> Transition? {
        guard phase != .idle, !isPaused else { return nil }
        remaining -= 1
        guard remaining <= 0 else { return nil }

        switch phase {
        case .idle:
            return nil
        case .work(let round):
            if round >= totalRounds {
                phase = .idle
                remaining = 0
                return .workToIdle
            }
            if round % config.longBreakEvery == 0 {
                phase = .longBreak(after: round)
                remaining = config.longBreakDuration
                return .workToLongBreak
            }
            phase = .shortBreak(after: round)
            remaining = config.shortBreakDuration
            return .workToShortBreak
        case .shortBreak(let after), .longBreak(let after):
            phase = .work(round: after + 1)
            remaining = config.workDuration
            return .breakToWork
        }
    }
}
