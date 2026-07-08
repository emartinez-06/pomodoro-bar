import AppKit

/// Dropdown graphic: today's completed sessions as dots, hollow dots for the
/// remainder of the active run, and a seven-day history bar chart below.
final class SessionsView: NSView {
    private static let maxDots = 12
    private static let dotDiameter: CGFloat = 8
    private static let dotSpacing: CGFloat = 5

    private var todayCount = 0
    private var pendingInRun = 0
    private var history: [SessionStore.DayCount] = []

    func update(todayCount: Int, pendingInRun: Int, history: [SessionStore.DayCount]) {
        self.todayCount = todayCount
        self.pendingInRun = pendingInRun
        self.history = history
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor.gray.withAlphaComponent(0.12).setFill()
        background.fill()

        let inset = bounds.insetBy(dx: 10, dy: 8)

        let title = "Today: \(todayCount) session\(todayCount == 1 ? "" : "s")" as NSString
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]
        let titleHeight = title.size(withAttributes: titleAttributes).height
        title.draw(
            at: NSPoint(x: inset.minX, y: inset.maxY - titleHeight),
            withAttributes: titleAttributes
        )

        let dotsTop = inset.maxY - titleHeight - 4
        drawDots(in: inset, top: dotsTop)
        drawChart(in: inset, below: dotsTop - Self.dotDiameter - 8)
    }

    private func drawDots(in inset: NSRect, top: CGFloat) {
        let y = top - Self.dotDiameter
        let filled = min(todayCount, Self.maxDots)
        let hollow = min(pendingInRun, Self.maxDots - filled)
        var x = inset.minX

        for index in 0..<(filled + hollow) {
            let rect = NSRect(x: x, y: y, width: Self.dotDiameter, height: Self.dotDiameter)
            if index < filled {
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: rect).fill()
            } else {
                let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
                path.lineWidth = 1
                NSColor.gray.withAlphaComponent(0.6).setStroke()
                path.stroke()
            }
            x += Self.dotDiameter + Self.dotSpacing
        }

        if todayCount > Self.maxDots {
            let overflow = "+\(todayCount - Self.maxDots)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            overflow.draw(at: NSPoint(x: x + 1, y: y - 1), withAttributes: attributes)
        }
    }

    private func drawChart(in inset: NSRect, below barsMaxY: CGFloat) {
        guard !history.isEmpty else { return }

        let labelHeight: CGFloat = 12
        let barsMinY = inset.minY + labelHeight
        let barsHeight = max(barsMaxY - barsMinY, 8)
        let slot = inset.width / CGFloat(history.count)
        let barWidth = min(18, slot - 8)
        let maxCount = max(history.map(\.count).max() ?? 0, 4)

        let labelFont = NSFont.systemFont(ofSize: 9, weight: .medium)
        for (index, day) in history.enumerated() {
            let centerX = inset.minX + slot * (CGFloat(index) + 0.5)

            let height = day.count == 0
                ? 2
                : max(3, barsHeight * CGFloat(day.count) / CGFloat(maxCount))
            let color = day.count == 0
                ? NSColor.gray.withAlphaComponent(0.25)
                : day.isToday ? NSColor.systemRed : NSColor.systemRed.withAlphaComponent(0.4)
            color.setFill()
            NSBezierPath(
                roundedRect: NSRect(x: centerX - barWidth / 2, y: barsMinY, width: barWidth, height: height),
                xRadius: 2,
                yRadius: 2
            ).fill()

            let label = day.label as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: day.isToday ? NSColor.labelColor : NSColor.secondaryLabelColor,
            ]
            let labelSize = label.size(withAttributes: attributes)
            label.draw(
                at: NSPoint(x: centerX - labelSize.width / 2, y: inset.minY - 1),
                withAttributes: attributes
            )
        }
    }
}
