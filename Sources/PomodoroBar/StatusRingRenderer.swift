import AppKit

enum StatusRingRenderer {
    /// Renders the menu bar ring: a faint full-circle track with a colored
    /// arc that fills clockwise from 12 o'clock as the interval elapses.
    static func image(progress: Double, color: NSColor?, dimmed: Bool) -> NSImage {
        let side: CGFloat = 16
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let lineWidth: CGFloat = 2.5
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = (min(rect.width, rect.height) - lineWidth) / 2 - 0.5

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            NSColor.gray.withAlphaComponent(0.35).setStroke()
            track.stroke()

            if let color, progress > 0 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - 360 * min(progress, 1),
                    clockwise: true
                )
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                (dimmed ? color.withAlphaComponent(0.4) : color).setStroke()
                arc.stroke()
            }
            return true
        }
    }
}
