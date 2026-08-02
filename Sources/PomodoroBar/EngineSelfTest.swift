import Foundation

/// In-binary test suite for the pure timing logic - the engine state machine
/// and the day-rollover monitor - run via `PomodoroBar --selftest`.
/// The Command Line Tools toolchain ships no test framework, so the binary
/// carries its own checks; `make test` runs them and fails on any regression.
enum EngineSelfTest {
    private static var failures = 0

    static func run() -> Never {
        startBeginsFirstWorkRound()
        tickCountsDownWithoutTransition()
        workEndsInShortBreak()
        breakEndsInNextWorkRound()
        fourthWorkRoundEndsInLongBreak()
        finalWorkRoundEndsRun()
        finalRoundSkipsLongBreakEvenOnMultipleOfFour()
        singleRoundRunEndsImmediately()
        pauseStopsCountdown()
        resetReturnsToIdle()
        progressAdvances()
        pendingRoundsDuringBreak()
        tickHoldsAtBoundaryUntilAdvance()
        advanceIsNoOpWithoutPendingTransition()
        autoAdvanceCrossesBoundaryWithoutHolding()
        autoAdvanceRunsAWholeDayFromOneStart()
        autoAdvanceStillEndsRunAtFinalRound()
        rolloverFiresOnceWhenTheDayChanges()
        rolloverIgnoresTimeChangesWithinTheSameDay()

        if failures > 0 {
            print("FAILED: \(failures) assertion(s)")
            exit(1)
        }
        print("OK: all engine self-tests passed")
        exit(0)
    }

    private static func expect(
        _ condition: Bool,
        _ message: String,
        function: String = #function,
        line: Int = #line
    ) {
        if !condition {
            failures += 1
            print("FAIL \(function):\(line): \(message)")
        }
    }

    private static func startedEngine(rounds: Int) -> PomodoroEngine {
        var engine = PomodoroEngine()
        engine.start(rounds: rounds)
        return engine
    }

    /// Ticks until the current phase finishes and returns its transition.
    /// Mirrors the real app with auto-advance off: a work<->break boundary
    /// holds in pendingTransition until advance() is called (standing in for
    /// the user's Shift+Cmd+A keypress), so this drives that too, leaving the
    /// engine already moved into the next phase for the caller to inspect.
    private static func finishPhase(_ engine: inout PomodoroEngine) -> PomodoroEngine.Transition? {
        guard let transition = tickToBoundary(&engine) else { return nil }
        engine.advance()
        return transition
    }

    /// Ticks until the current phase finishes, leaving the engine exactly
    /// where tick() put it - held at the boundary, or already in the next
    /// phase when autoAdvance is on.
    private static func tickToBoundary(_ engine: inout PomodoroEngine) -> PomodoroEngine.Transition? {
        for _ in 0..<(engine.remaining + 1) {
            if let transition = engine.tick() {
                return transition
            }
        }
        return nil
    }

    private static func startBeginsFirstWorkRound() {
        let engine = startedEngine(rounds: 4)
        expect(engine.phase == .work(round: 1), "phase is first work round")
        expect(engine.remaining == 25 * 60, "work lasts 25 minutes")
        expect(engine.pendingRounds == 4, "all rounds pending")
    }

    private static func tickCountsDownWithoutTransition() {
        var engine = startedEngine(rounds: 4)
        expect(engine.tick() == nil, "mid-phase tick has no transition")
        expect(engine.remaining == 25 * 60 - 1, "tick removes one second")
        expect(engine.phase == .work(round: 1), "phase unchanged mid-countdown")
    }

    private static func workEndsInShortBreak() {
        var engine = startedEngine(rounds: 4)
        expect(finishPhase(&engine) == .workToShortBreak, "work 1 transitions to short break")
        expect(engine.phase == .shortBreak(after: 1), "short break after round 1")
        expect(engine.remaining == 5 * 60, "short break lasts 5 minutes")
    }

    private static func breakEndsInNextWorkRound() {
        var engine = startedEngine(rounds: 4)
        _ = finishPhase(&engine)
        expect(finishPhase(&engine) == .breakToWork, "break transitions back to work")
        expect(engine.phase == .work(round: 2), "round advances after break")
        expect(engine.remaining == 25 * 60, "next work round is full length")
    }

    private static func fourthWorkRoundEndsInLongBreak() {
        var engine = startedEngine(rounds: 6)
        for _ in 0..<6 {
            _ = finishPhase(&engine)
        }
        expect(engine.phase == .work(round: 4), "reached fourth work round")
        expect(finishPhase(&engine) == .workToLongBreak, "fourth round earns long break")
        expect(engine.phase == .longBreak(after: 4), "long break after round 4")
        expect(engine.remaining == 15 * 60, "long break lasts 15 minutes")
    }

    private static func finalWorkRoundEndsRun() {
        var engine = startedEngine(rounds: 2)
        _ = finishPhase(&engine)
        _ = finishPhase(&engine)
        expect(finishPhase(&engine) == .workToIdle, "final work round ends the run")
        expect(engine.phase == .idle, "engine idle after run")
        expect(engine.pendingRounds == 0, "no rounds pending when idle")
    }

    private static func finalRoundSkipsLongBreakEvenOnMultipleOfFour() {
        var engine = startedEngine(rounds: 4)
        for _ in 0..<6 {
            _ = finishPhase(&engine)
        }
        expect(engine.phase == .work(round: 4), "reached final work round")
        expect(finishPhase(&engine) == .workToIdle, "run ends instead of long break")
        expect(engine.phase == .idle, "engine idle after run")
    }

    private static func singleRoundRunEndsImmediately() {
        var engine = startedEngine(rounds: 1)
        expect(finishPhase(&engine) == .workToIdle, "single round run has no break")
        expect(engine.phase == .idle, "engine idle after single round")
    }

    private static func pauseStopsCountdown() {
        var engine = startedEngine(rounds: 4)
        engine.isPaused = true
        expect(engine.tick() == nil, "paused tick has no transition")
        expect(engine.remaining == 25 * 60, "paused tick does not count down")
        engine.isPaused = false
        expect(engine.tick() == nil, "resumed tick has no transition")
        expect(engine.remaining == 25 * 60 - 1, "resumed tick counts down")
    }

    private static func resetReturnsToIdle() {
        var engine = startedEngine(rounds: 4)
        _ = engine.tick()
        engine.reset()
        expect(engine.phase == .idle, "reset returns to idle")
        expect(engine.remaining == 0, "reset clears remaining time")
        expect(engine.progress == 0, "reset clears progress")
    }

    private static func progressAdvances() {
        var engine = startedEngine(rounds: 4)
        expect(engine.progress == 0, "progress starts at zero")
        for _ in 0..<(25 * 60 / 2) {
            _ = engine.tick()
        }
        expect(abs(engine.progress - 0.5) < 0.001, "progress reaches half at midpoint")
    }

    private static func pendingRoundsDuringBreak() {
        var engine = startedEngine(rounds: 4)
        _ = finishPhase(&engine)
        expect(engine.pendingRounds == 3, "three rounds pending during first break")
    }

    private static func tickHoldsAtBoundaryUntilAdvance() {
        var engine = startedEngine(rounds: 4)
        _ = tickToBoundary(&engine)
        expect(engine.phase == .work(round: 1), "phase holds at work until advance")
        expect(engine.pendingTransition == .workToShortBreak, "pending transition recorded")
        expect(engine.isPaused, "engine pauses awaiting advance")
        expect(engine.tick() == nil, "tick is a no-op while a transition is pending")

        engine.advance()
        expect(engine.phase == .shortBreak(after: 1), "advance moves into the pending phase")
        expect(!engine.isPaused, "advance resumes the countdown")
        expect(engine.pendingTransition == nil, "advance clears the pending transition")
    }

    private static func advanceIsNoOpWithoutPendingTransition() {
        var engine = startedEngine(rounds: 4)
        engine.advance()
        expect(engine.phase == .work(round: 1), "advance without a pending transition changes nothing")
        expect(engine.remaining == 25 * 60, "remaining is untouched")
    }

    private static func autoAdvanceCrossesBoundaryWithoutHolding() {
        var engine = startedEngine(rounds: 4)
        engine.autoAdvance = true
        expect(tickToBoundary(&engine) == .workToShortBreak, "boundary still reports its transition")
        expect(engine.phase == .shortBreak(after: 1), "auto-advance moves straight into the break")
        expect(engine.remaining == 5 * 60, "next phase starts at full length")
        expect(engine.pendingTransition == nil, "nothing is left pending")
        expect(!engine.isPaused, "countdown keeps running")
        expect(engine.tick() == nil, "the next tick counts the break down")
        expect(engine.remaining == 5 * 60 - 1, "break lost a second")
    }

    /// The point of the feature: one Start at the top of the day, one stop at
    /// the end, no keypress at any boundary in between.
    private static func autoAdvanceRunsAWholeDayFromOneStart() {
        var engine = startedEngine(rounds: 3)
        engine.autoAdvance = true
        let expected: [PomodoroEngine.Transition] = [
            .workToShortBreak, .breakToWork, .workToShortBreak, .breakToWork, .workToIdle,
        ]
        for transition in expected {
            expect(tickToBoundary(&engine) == transition, "run reaches \(transition) unattended")
        }
        expect(engine.phase == .idle, "run stops itself once the goal is met")
    }

    private static func autoAdvanceStillEndsRunAtFinalRound() {
        var engine = startedEngine(rounds: 1)
        engine.autoAdvance = true
        expect(tickToBoundary(&engine) == .workToIdle, "final round ends the run rather than continuing")
        expect(engine.phase == .idle, "engine idle after the last round")
        expect(engine.tick() == nil, "idle engine does not restart itself")
    }

    // MARK: - Day rollover

    private static func rolloverFiresOnceWhenTheDayChanges() {
        var now = date("2026-08-02 23:59:30")
        var rollovers = 0
        let monitor = DayRolloverMonitor(now: { now }) { rollovers += 1 }

        expect(!monitor.checkForRollover(), "no rollover before midnight")
        now = date("2026-08-03 00:00:01")
        expect(monitor.checkForRollover(), "rollover once the day changes")
        expect(rollovers == 1, "callback fired exactly once")
        expect(!monitor.checkForRollover(), "the same new day does not fire again")
        expect(rollovers == 1, "callback still fired exactly once")
    }

    private static func rolloverIgnoresTimeChangesWithinTheSameDay() {
        var now = date("2026-08-02 08:00:00")
        var rollovers = 0
        let monitor = DayRolloverMonitor(now: { now }) { rollovers += 1 }

        now = date("2026-08-02 23:59:59")
        expect(!monitor.checkForRollover(), "a jump within the day is not a rollover")
        expect(rollovers == 0, "callback never fired")
    }

    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = formatter.date(from: string) else {
            fatalError("EngineSelfTest: unparseable date \(string)")
        }
        return date
    }
}
