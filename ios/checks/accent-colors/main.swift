import Foundation

var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    if ok { print("ok   \(label)") } else { failures += 1; print("FAIL \(label) \(detail())") }
}
func fmt(_ value: Double) -> String { String(format: "%.2f", value) }

// The maths
check("white on black is 21 to 1", abs(ColorMath.contrast(RGBColor(hex: "#ffffff"), RGBColor(hex: "#000000")) - 21) < 0.01)
check("contrast is the same either way round", ColorMath.contrast(RGBColor(hex: "#2bb675"), RGBColor(hex: "#2c2c2e")) == ColorMath.contrast(RGBColor(hex: "#2c2c2e"), RGBColor(hex: "#2bb675")))
check("hex round trips", RGBColor(hex: "#B05E6B").hex == "#b05e6b")
check("hsl round trips", ColorMath.color(hue: ColorMath.hsl(RGBColor(hex: "#56a2dc")).hue, saturation: ColorMath.hsl(RGBColor(hex: "#56a2dc")).saturation, lightness: ColorMath.hsl(RGBColor(hex: "#56a2dc")).lightness).hex == "#56a2dc")
check("white text on a dark fill", ColorMath.readableText(on: RGBColor(hex: "#4c596b")) == ColorMath.white)
check("dark text on a bright fill", ColorMath.readableText(on: RGBColor(hex: "#f2c02c")) == ColorMath.ink)

// The ten colors
check("there are ten, each with a name and both modes", AccentColorTable.ids.count == 10 && AccentColorTable.ids.allSatisfy { AccentColorTable.labels[$0] != nil && AccentColorTable.dark[$0] != nil && AccentColorTable.light[$0] != nil })
check("the names people see", AccentColorTable.ids.map { AccentColorTable.labels[$0]! }.joined(separator: ",") == "Emerald,Azure,Tangerine,Blossom,Slate,Rosewood,Lagoon,Orchid,Raspberry,Sunflower")

for id in AccentColorTable.ids {
    let name = AccentColorTable.labels[id]!
    let darkFill = AccentColorTable.fill(id, dark: true)
    let lightFill = AccentColorTable.fill(id, dark: false)
    // The chosen colors are at least 3 to 1 as large text on the dark card, with no help.
    let raw = ColorMath.contrast(darkFill, AccentColorTable.darkSurface)
    check("\(name): the dark color is at least 3 to 1 on the dark card", raw >= 3.0, "got \(fmt(raw))")
    // Small text uses a lightened shade where needed, and reaches 4.5 to 1 in dark mode.
    let darkText = AccentColorTable.text(id, dark: true)
    let darkRatio = ColorMath.contrast(darkText, AccentColorTable.darkSurface)
    check("\(name): text on dark reaches 4.5 to 1", darkRatio >= 4.5, "got \(fmt(darkRatio))")
    // And in light mode on white.
    let lightText = AccentColorTable.text(id, dark: false)
    let lightRatio = ColorMath.contrast(lightText, AccentColorTable.lightSurface)
    check("\(name): text on light reaches 4.5 to 1", lightRatio >= 4.5, "got \(fmt(lightRatio))")
    // The shade of text keeps the color's hue.
    let a = ColorMath.hsl(darkFill).hue, b = ColorMath.hsl(darkText).hue
    check("\(name): the text shade keeps the hue", min(abs(a - b), 360 - abs(a - b)) < 4 || ColorMath.hsl(darkFill).saturation < 0.2, "\(fmt(a)) vs \(fmt(b))")
    // Text on a button fill is readable in both modes.
    for isDark in [true, false] {
        let fill = AccentColorTable.fill(id, dark: isDark)
        let text = AccentColorTable.onFill(id, dark: isDark)
        let r = ColorMath.contrast(text, fill)
        check("\(name): button text in \(isDark ? "dark" : "light") mode is at least 4 to 1", r >= 4.0, "got \(fmt(r))")
    }
    // A light-mode fill is deep enough to show as a graphic on white (3 to 1), except yellow.
    if id != "ochre" {
        let g = ColorMath.contrast(lightFill, AccentColorTable.lightSurface)
        check("\(name): the light color is at least 3 to 1 on white", g >= 3.0, "got \(fmt(g))")
    }
}

// The values the user chose
check("Azure is #56a2dc", AccentColorTable.dark["ocean"] == "#56a2dc")
check("Emerald is #2bb675", AccentColorTable.dark["sage"] == "#2bb675")
check("Rosewood is #b05e6b and Slate #6c7684", AccentColorTable.dark["rosewood"] == "#b05e6b" && AccentColorTable.dark["slate"] == "#6c7684")
check("a color that already reads is left alone", AccentColorTable.text("clay", dark: true) == AccentColorTable.fill("clay", dark: true))
check("Rosewood text on dark is lightened", AccentColorTable.text("rosewood", dark: true) != AccentColorTable.fill("rosewood", dark: true))

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall accent color checks passed")
