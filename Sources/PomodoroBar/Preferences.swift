import AppKit
import Combine

/// User-configurable settings, persisted in UserDefaults. `@Published`
/// properties give the SwiftUI settings view live updates for free; other
/// consumers (BorderSignaler, AppDelegate) read the current value directly
/// on each use rather than observing, since they're already called on every
/// tick of an active run.
final class Preferences: ObservableObject {
    static let defaultFocusColorHex = "0xffa6e3a1"
    static let defaultRestColorHex = "0xfffab387"

    private static let dailyGoalKey = "dailyGoal"
    private static let focusBorderKey = "focusBorderEnabled"
    private static let workMinutesKey = "workMinutes"
    private static let breakMinutesKey = "breakMinutes"
    private static let longBreakMinutesKey = "longBreakMinutes"
    private static let roundsBeforeLongBreakKey = "roundsBeforeLongBreak"
    private static let autoAdvanceKey = "autoAdvanceEnabled"
    private static let soundsEnabledKey = "soundsEnabled"
    private static let focusColorKey = "focusColorHex"
    private static let restColorKey = "restColorHex"

    private let defaults: UserDefaults

    @Published var dailyGoal: Int {
        didSet { defaults.set(dailyGoal, forKey: Self.dailyGoalKey) }
    }
    @Published var focusBorderEnabled: Bool {
        didSet { defaults.set(focusBorderEnabled, forKey: Self.focusBorderKey) }
    }
    @Published var workMinutes: Int {
        didSet { defaults.set(workMinutes, forKey: Self.workMinutesKey) }
    }
    @Published var breakMinutes: Int {
        didSet { defaults.set(breakMinutes, forKey: Self.breakMinutesKey) }
    }
    @Published var longBreakMinutes: Int {
        didSet { defaults.set(longBreakMinutes, forKey: Self.longBreakMinutesKey) }
    }
    @Published var roundsBeforeLongBreak: Int {
        didSet { defaults.set(roundsBeforeLongBreak, forKey: Self.roundsBeforeLongBreakKey) }
    }
    @Published var autoAdvanceEnabled: Bool {
        didSet { defaults.set(autoAdvanceEnabled, forKey: Self.autoAdvanceKey) }
    }
    @Published var soundsEnabled: Bool {
        didSet { defaults.set(soundsEnabled, forKey: Self.soundsEnabledKey) }
    }
    @Published var focusColorHex: String {
        didSet { defaults.set(focusColorHex, forKey: Self.focusColorKey) }
    }
    @Published var restColorHex: String {
        didSet { defaults.set(restColorHex, forKey: Self.restColorKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedGoal = defaults.integer(forKey: Self.dailyGoalKey)
        dailyGoal = storedGoal == 0 ? 10 : min(max(storedGoal, 1), 12)

        focusBorderEnabled = defaults.object(forKey: Self.focusBorderKey) == nil
            || defaults.bool(forKey: Self.focusBorderKey)

        let storedWork = defaults.integer(forKey: Self.workMinutesKey)
        workMinutes = storedWork == 0 ? 25 : min(max(storedWork, 1), 120)

        let storedBreak = defaults.integer(forKey: Self.breakMinutesKey)
        breakMinutes = storedBreak == 0 ? 5 : min(max(storedBreak, 1), 60)

        let storedLongBreak = defaults.integer(forKey: Self.longBreakMinutesKey)
        longBreakMinutes = storedLongBreak == 0 ? 15 : min(max(storedLongBreak, 1), 60)

        let storedRounds = defaults.integer(forKey: Self.roundsBeforeLongBreakKey)
        roundsBeforeLongBreak = storedRounds == 0 ? 4 : min(max(storedRounds, 2), 12)

        autoAdvanceEnabled = defaults.object(forKey: Self.autoAdvanceKey) == nil
            || defaults.bool(forKey: Self.autoAdvanceKey)

        soundsEnabled = defaults.object(forKey: Self.soundsEnabledKey) == nil
            || defaults.bool(forKey: Self.soundsEnabledKey)

        focusColorHex = defaults.string(forKey: Self.focusColorKey) ?? Self.defaultFocusColorHex
        restColorHex = defaults.string(forKey: Self.restColorKey) ?? Self.defaultRestColorHex
    }

    func restoreDefaults() {
        dailyGoal = 10
        focusBorderEnabled = true
        workMinutes = 25
        breakMinutes = 5
        longBreakMinutes = 15
        roundsBeforeLongBreak = 4
        autoAdvanceEnabled = true
        soundsEnabled = true
        focusColorHex = Self.defaultFocusColorHex
        restColorHex = Self.defaultRestColorHex
    }

    var engineConfig: PomodoroEngine.Config {
        PomodoroEngine.Config(
            workDuration: workMinutes * 60,
            shortBreakDuration: breakMinutes * 60,
            longBreakDuration: longBreakMinutes * 60,
            longBreakEvery: roundsBeforeLongBreak
        )
    }
}
