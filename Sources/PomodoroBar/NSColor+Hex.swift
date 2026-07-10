import AppKit

/// Converts between NSColor and the "0xAARRGGBB" hex format JankyBorders
/// expects on its command line.
extension NSColor {
    var borderHex: String {
        let color = usingColorSpace(.deviceRGB) ?? self
        let a = Int((color.alphaComponent * 255).rounded())
        let r = Int((color.redComponent * 255).rounded())
        let g = Int((color.greenComponent * 255).rounded())
        let b = Int((color.blueComponent * 255).rounded())
        return String(format: "0x%02x%02x%02x%02x", a, r, g, b)
    }

    convenience init?(borderHex hex: String) {
        var digits = hex
        if digits.hasPrefix("0x") { digits.removeFirst(2) }
        guard digits.count == 8, let value = UInt64(digits, radix: 16) else { return nil }
        let a = CGFloat((value >> 24) & 0xFF) / 255
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(deviceRed: r, green: g, blue: b, alpha: a)
    }
}
