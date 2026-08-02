import Foundation

/// Calls `onRollover` once whenever the local calendar day changes, so a run
/// left going overnight never bleeds into the new day's goal and the session
/// graphics never show yesterday's numbers.
///
/// A one-shot timer aimed just past the next midnight does the work.
/// `NSCalendarDayChanged` can lag for a background accessory app and a timer
/// is the only signal that fires with the day still counting down, so the
/// timer is primary; the notifications below only add a second opinion.
/// `NSSystemClockDidChange` matters because a manual clock change or a
/// timezone move invalidates an already-scheduled fire date, and a timer that
/// came due while the machine slept fires as soon as the run loop wakes,
/// since its fire date is absolute.
final class DayRolloverMonitor {
    private let calendar: Calendar
    private let now: () -> Date
    private let onRollover: () -> Void
    private var currentDay: Date
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(
        // Autoupdating, so a timezone move changes when midnight lands
        // instead of leaving the monitor on the zone it launched in.
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init,
        onRollover: @escaping () -> Void
    ) {
        self.calendar = calendar
        self.now = now
        self.onRollover = onRollover
        currentDay = calendar.startOfDay(for: now())
        scheduleNextMidnight()

        observers = [Notification.Name.NSCalendarDayChanged, .NSSystemClockDidChange].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.checkForRollover()
            }
        }
    }

    deinit {
        timer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Fires `onRollover` if the calendar day has changed since the last
    /// check, then re-arms the midnight timer. Returns whether it fired.
    @discardableResult
    func checkForRollover() -> Bool {
        defer { scheduleNextMidnight() }
        let today = calendar.startOfDay(for: now())
        // Backwards clock changes land here as a rollover too; resetting is
        // the safe response either way.
        guard today != currentDay else { return false }
        currentDay = today
        onRollover()
        return true
    }

    private func scheduleNextMidnight() {
        timer?.invalidate()
        // nextDate(matching:) rather than adding a day, so DST shifts and the
        // rare locale where midnight itself does not exist still resolve.
        guard let midnight = calendar.nextDate(
            after: now(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }

        // A second past midnight, so the fire can never round back into the
        // day that just ended.
        let timer = Timer(fire: midnight.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            self?.checkForRollover()
        }
        // .common keeps the rollover on schedule while the dropdown is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
