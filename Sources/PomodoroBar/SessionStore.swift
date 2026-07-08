import Foundation

/// Persists completed session counts per calendar day, plus the two user
/// preferences, in UserDefaults. Days older than the retention window are
/// pruned on every write.
final class SessionStore {
    struct DayCount {
        let label: String
        let count: Int
        let isToday: Bool
    }

    private static let sessionsKey = "sessionsByDay"
    private static let dailyGoalKey = "dailyGoal"
    private static let focusBorderKey = "focusBorderEnabled"
    private static let retentionDays = 30
    private static let defaultDailyGoal = 10

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var dailyGoal: Int {
        get {
            let stored = defaults.integer(forKey: Self.dailyGoalKey)
            return stored == 0 ? Self.defaultDailyGoal : min(max(stored, 1), 12)
        }
        set { defaults.set(newValue, forKey: Self.dailyGoalKey) }
    }

    var focusBorderEnabled: Bool {
        get { defaults.object(forKey: Self.focusBorderKey) == nil || defaults.bool(forKey: Self.focusBorderKey) }
        set { defaults.set(newValue, forKey: Self.focusBorderKey) }
    }

    func recordSession(on date: Date = Date()) {
        var counts = sessionsByDay()
        counts[dayKey(for: date), default: 0] += 1
        prune(&counts, now: date)
        defaults.set(counts, forKey: Self.sessionsKey)
    }

    func todayCount(now: Date = Date()) -> Int {
        sessionsByDay()[dayKey(for: now)] ?? 0
    }

    /// Counts for the last seven days, oldest first, ending today.
    func lastSevenDays(endingOn now: Date = Date()) -> [DayCount] {
        let counts = sessionsByDay()
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let weekdayIndex = calendar.component(.weekday, from: day) - 1
            return DayCount(
                label: calendar.veryShortWeekdaySymbols[weekdayIndex],
                count: counts[dayKey(for: day)] ?? 0,
                isToday: offset == 0
            )
        }
    }

    private func sessionsByDay() -> [String: Int] {
        defaults.dictionary(forKey: Self.sessionsKey) as? [String: Int] ?? [:]
    }

    private func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private func prune(_ counts: inout [String: Int], now: Date) {
        guard let cutoffDate = calendar.date(byAdding: .day, value: -Self.retentionDays, to: now) else { return }
        let cutoff = dayKey(for: cutoffDate)
        // yyyy-MM-dd keys sort lexicographically in date order.
        counts = counts.filter { $0.key >= cutoff }
    }
}
