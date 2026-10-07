import Foundation

/// A color as red, green and blue from 0 to 1. Foundation only, so the color rules below can be
/// checked from the command line (`ios/checks/accent-colors`).
struct RGBColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// "#rrggbb" (the # is optional). Anything unreadable is black.
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255
        )
    }

    var hex: String {
        func part(_ value: Double) -> String {
            let byte = Int((min(max(value, 0), 1) * 255).rounded())
            return String(format: "%02x", byte)
        }
        return "#" + part(red) + part(green) + part(blue)
    }
}

enum ColorMath {
    /// Relative luminance as WCAG defines it.
    static func luminance(_ color: RGBColor) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    /// Contrast ratio from 1 to 21, the same either way round.
    static func contrast(_ first: RGBColor, _ second: RGBColor) -> Double {
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    static func hsl(_ color: RGBColor) -> (hue: Double, saturation: Double, lightness: Double) {
        let maximum = max(color.red, color.green, color.blue)
        let minimum = min(color.red, color.green, color.blue)
        let lightness = (maximum + minimum) / 2
        let delta = maximum - minimum
        guard delta > 0 else { return (0, 0, lightness) }
        let saturation = delta / (1 - abs(2 * lightness - 1))
        var hue: Double
        switch maximum {
        case color.red: hue = (color.green - color.blue) / delta
        case color.green: hue = (color.blue - color.red) / delta + 2
        default: hue = (color.red - color.green) / delta + 4
        }
        hue = (hue * 60).truncatingRemainder(dividingBy: 360)
        return (hue < 0 ? hue + 360 : hue, saturation, lightness)
    }

    static func color(hue: Double, saturation: Double, lightness: Double) -> RGBColor {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let h = hue / 60
        let x = chroma * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double)
        switch h {
        case ..<1: (r, g, b) = (chroma, x, 0)
        case ..<2: (r, g, b) = (x, chroma, 0)
        case ..<3: (r, g, b) = (0, chroma, x)
        case ..<4: (r, g, b) = (0, x, chroma)
        case ..<5: (r, g, b) = (x, 0, chroma)
        default: (r, g, b) = (chroma, 0, x)
        }
        let m = lightness - chroma / 2
        return RGBColor(red: r + m, green: g + m, blue: b + m)
    }

    /// The color to use for text and icons on `surface`: `color` itself when it already reads at
    /// `minimum` to 1, otherwise the same hue and saturation moved lighter (`lighten`) or darker
    /// until it does. A color that can't get there moves as far as it can.
    static func textShade(of color: RGBColor, on surface: RGBColor, minimum: Double = 4.5, lighten: Bool) -> RGBColor {
        guard contrast(color, surface) < minimum else { return color }
        let base = hsl(color)
        var lightness = base.lightness
        var shade = color
        while contrast(shade, surface) < minimum {
            lightness += lighten ? 0.01 : -0.01
            guard lightness > 0.02, lightness < 0.98 else { break }
            shade = self.color(hue: base.hue, saturation: base.saturation, lightness: lightness)
        }
        return shade
    }

    /// Near-black, softer than pure black on a bright fill.
    static let ink = RGBColor(red: 0.07, green: 0.08, blue: 0.10)
    static let white = RGBColor(red: 1, green: 1, blue: 1)

    /// White or near-black, whichever has more contrast with `fill`.
    static func readableText(on fill: RGBColor) -> RGBColor {
        contrast(white, fill) >= contrast(fill, ink) ? white : ink
    }
}

/// The ten theme colors. The keys are what is saved on a device, so they stay as they were when
/// the palette was earthier (sage is now Emerald, rose is Raspberry, and so on).
enum AccentColorTable {
    static let ids = ["sage", "ocean", "clay", "plum", "slate", "rosewood", "teal", "indigo", "rose", "ochre"]

    static let labels: [String: String] = [
        "sage": "Emerald", "ocean": "Azure", "clay": "Tangerine", "plum": "Blossom", "slate": "Slate",
        "rosewood": "Rosewood", "teal": "Lagoon", "indigo": "Orchid", "rose": "Raspberry", "ochre": "Sunflower",
    ]

    /// In dark mode. Each is at least 3 to 1 as text on a dark card, and the app lightens the shade
    /// it uses for small text where that is under 4.5 (`textShade`).
    static let dark: [String: String] = [
        "sage": "#2bb675", "ocean": "#56a2dc", "clay": "#f2852c", "plum": "#e656a8", "slate": "#6c7684",
        "rosewood": "#b05e6b", "teal": "#4d9d98", "indigo": "#9564ce", "rose": "#f22c4a", "ochre": "#f2c02c",
    ]

    /// In light mode: deeper where that was needed for 3.5 to 1 against white. Yellow stays as it
    /// is (it cannot get there without turning brown) and carries dark text.
    static let light: [String: String] = [
        "sage": "#229c63", "ocean": "#2b8ed9", "clay": "#d96608", "plum": "#e64ca4", "slate": "#6c7684",
        "rosewood": "#b05e6b", "teal": "#47948f", "indigo": "#9564ce", "rose": "#f22c4a", "ochre": "#f2c02c",
    ]

    /// The surfaces text sits on: the dark card, and a white one.
    static let darkSurface = RGBColor(hex: "#2c2c2e")
    static let lightSurface = RGBColor(hex: "#ffffff")

    static func fill(_ id: String, dark isDark: Bool) -> RGBColor {
        RGBColor(hex: (isDark ? dark : light)[id] ?? "#2bb675")
    }

    /// The shade to use where the color is text or an icon.
    static func text(_ id: String, dark isDark: Bool) -> RGBColor {
        ColorMath.textShade(
            of: fill(id, dark: isDark),
            on: isDark ? darkSurface : lightSurface,
            lighten: isDark
        )
    }

    /// Text and icons on a fill of the color.
    static func onFill(_ id: String, dark isDark: Bool) -> RGBColor {
        ColorMath.readableText(on: fill(id, dark: isDark))
    }
}
