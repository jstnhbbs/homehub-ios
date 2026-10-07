import SwiftUI
import UIKit

enum AccentPalette: String, CaseIterable, Identifiable, Sendable {
    // The raw values are what is saved on a device, so they keep the names of the original,
    // earthier palette (sage is now Emerald, rose is Raspberry). `label` is what people see. A
    // device that saved the removed Meadow ("forest") starts on the default.
    case sage
    case ocean
    case clay
    case plum
    case slate
    case rosewood
    case teal
    case indigo
    case rose
    case ochre

    var id: String { rawValue }
    var label: String { AccentColorTable.labels[rawValue] ?? rawValue }

    var accent: Color { Color(uiColor: accentUIColor) }
    var soft: Color { Color(uiColor: softUIColor) }
    /// Text and icons on a fill of this accent: whichever of white and near-black reads better.
    var onAccent: Color { Color(uiColor: onAccentUIColor) }
    /// The color where it is text or a small icon. Where the accent itself is too dim to read at
    /// small sizes this is a lighter (or, in light mode, deeper) shade of it.
    var textColor: Color { Color(uiColor: textUIColor) }
    var swatch: Color { Color(uiColor: UIColor(AccentColorTable.fill(rawValue, dark: true))) }
    var swatchIcon: some View {
        Circle()
            .fill(swatch)
            .frame(width: 14, height: 14)
    }

    private var accentUIColor: UIColor {
        UIColor { [rawValue] traits in
            UIColor(AccentColorTable.fill(rawValue, dark: traits.userInterfaceStyle == .dark))
        }
    }

    private var textUIColor: UIColor {
        UIColor { [rawValue] traits in
            UIColor(AccentColorTable.text(rawValue, dark: traits.userInterfaceStyle == .dark))
        }
    }

    /// A tint of the accent for selected rows and highlights.
    private var softUIColor: UIColor {
        UIColor { [rawValue] traits in
            let dark = traits.userInterfaceStyle == .dark
            return UIColor(AccentColorTable.fill(rawValue, dark: dark)).withAlphaComponent(dark ? 0.22 : 0.14)
        }
    }

    private var onAccentUIColor: UIColor {
        UIColor { [rawValue] traits in
            UIColor(AccentColorTable.onFill(rawValue, dark: traits.userInterfaceStyle == .dark))
        }
    }
}

extension UIColor {
    convenience init(_ color: RGBColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: 1)
    }
}

enum HubTheme {
    static var currentAccent: AccentPalette = .sage

    static var accent: Color { currentAccent.accent }
    static var sage: Color { accent }
    /// The accent where it is text or a small icon (see `AccentPalette.textColor`). Use this, not
    /// `accent`, for any text or icon drawn in the theme color; `accent` is for fills.
    static var accentText: Color { currentAccent.textColor }
    static var selectionBackground: Color { currentAccent.soft }
    static var sageSoft: Color { selectionBackground }

    /// Text and icons on an accent-colored fill: white or near-black, whichever reads better on
    /// that color in the current mode.
    static var onAccent: Color { currentAccent.onAccent }

    /// The same for fills that aren't the accent (the destructive coral, a red banner).
    static let onFill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? darkInk : .white
    })

    /// Near-black with a little blue, softer than pure black on a bright fill.
    static let darkInk = UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)

    /// Warm highlight panels (calendar day, guest badge). Dark: neutral grey, not green/cream.
    static let sunSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1)
            : UIColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1)
    })

    // Light mode keeps the system's colors. Dark mode is a soft charcoal rather than the system's
    // true black: the page is #1C1C1E, cards sit a step lighter at #2C2C2E and the things inside
    // cards a step lighter again at #3A3A3C.
    private static func surface(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static let canvas = surface(light: .systemGroupedBackground, dark: UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1))
    static let surface = surface(light: .systemBackground, dark: UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1))
    static let surfaceStrong = surface(light: .tertiarySystemGroupedBackground, dark: UIColor(red: 0.227, green: 0.227, blue: 0.235, alpha: 1))
    static let tile = surface(light: .secondarySystemGroupedBackground, dark: UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1))
    static let tileQuiet = surface(light: .tertiarySystemGroupedBackground, dark: UIColor(red: 0.227, green: 0.227, blue: 0.235, alpha: 1))
    static let line = Color(.separator)
    static let muted = Color(.secondaryLabel)

    // Text styles rather than fixed point sizes, so everything scales with the
    // reader's Dynamic Type setting. At the default size these render identically
    // to the hardcoded sizes they replaced: .largeTitle is 34pt, .title is 28pt.
    static let pageTitle = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    static let sectionTitle = Font.system(.title, design: .rounded).weight(.semibold)

    /// The colors people can give a profile are stored as the muted hex values of the original
    /// palette (the server and the web settings still know them by those) and shown as the theme
    /// colors here, so a person's dot matches the app. Anything else is shown as it is.
    private static let personColors: [String: String] = [
        "#d87861": "rose",      // Coral shows as Raspberry
        "#6689a3": "ocean",     // Blue shows as Azure
        "#4f7c6d": "sage",      // Sage shows as Emerald
        "#b07aa1": "plum",      // Plum shows as Blossom
        "#d19b45": "ochre",     // Gold shows as Sunflower
        "#5f8f8b": "teal",      // Teal shows as Lagoon
        "#8c7ca8": "indigo",    // Lavender shows as Orchid
        "#b86f4d": "clay",      // Terracotta shows as Tangerine
        "#7f8757": "rosewood",  // Olive shows as Rosewood
    ]

    static func profileColor(_ hex: String?) -> Color {
        guard let hex, hex.hasPrefix("#"), hex.count == 7 else { return accent }
        if let id = personColors[hex.lowercased()] {
            return Color(uiColor: UIColor(AccentColorTable.fill(id, dark: true)))
        }
        let start = hex.index(hex.startIndex, offsetBy: 1)
        let r = Int(hex[start..<hex.index(start, offsetBy: 2)], radix: 16) ?? 79
        let g = Int(hex[hex.index(start, offsetBy: 2)..<hex.index(start, offsetBy: 4)], radix: 16) ?? 124
        let b = Int(hex[hex.index(start, offsetBy: 4)..<hex.index(start, offsetBy: 6)], radix: 16) ?? 109
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// White or near-black, whichever has more contrast with `color`.
    static func readableText(on color: Color) -> Color {
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let text = ColorMath.readableText(on: RGBColor(red: Double(red), green: Double(green), blue: Double(blue)))
        return text == ColorMath.white ? .white : Color(darkInk)
    }
}

private struct OpenHubDestinationKey: EnvironmentKey {
    static let defaultValue: (HubDestination) -> Void = { _ in }
}

extension EnvironmentValues {
    var openHubDestination: (HubDestination) -> Void {
        get { self[OpenHubDestinationKey.self] }
        set { self[OpenHubDestinationKey.self] = newValue }
    }
}

extension View {
    /// Paints the app's page color behind a whole screen. The tab bar and navigation stacks fill
    /// themselves with the system background, which is true black in dark mode, so every screen
    /// that sits directly in one asks for the page color itself.
    func hubPageBackground() -> some View {
        background(HubTheme.canvas.ignoresSafeArea())
    }
}

struct HubCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(HubTheme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(HubTheme.line, lineWidth: 1)
            )
    }
}

struct CardTitleView: View {
    let systemImage: String
    let title: String
    var action: (() -> Void)?

    @ViewBuilder
    var body: some View {
        if let action {
            Button(action: action) {
                titleRow(showsArrow: true)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(title)
            .accessibilityHint("Open \(title)")
        } else {
            titleRow(showsArrow: false)
        }
    }

    private func titleRow(showsArrow: Bool) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(HubTheme.accentText)
            Spacer()
            if showsArrow {
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(HubTheme.tileQuiet)
                    .clipShape(Circle())
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }
}

struct CheckItemView: View {
    let label: String
    var detail: String?
    var color: String?
    @Binding var isChecked: Bool
    var removeWhenChecked = false
    var onToggle: () async -> Void

    @State private var isHidden = false
    @State private var isWorking = false

    var body: some View {
        if !isHidden {
            Button {
                Task {
                    isWorking = true
                    await onToggle()
                    isChecked.toggle()
                    isWorking = false
                    if removeWhenChecked, isChecked {
                        withAnimation { isHidden = true }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isChecked ? HubTheme.accentText : HubTheme.muted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isChecked ? HubTheme.muted : .primary)
                            .strikethrough(isChecked, color: HubTheme.muted)
                        if let detail {
                            Text(detail)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(HubTheme.profileColor(color))
                        }
                    }
                    Spacer()
                    if isWorking {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isChecked ? HubTheme.tileQuiet : HubTheme.tile)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
    }
}

/// Ambient temperature readout for the app headers. Weather is the only dashboard
/// card with no destination and no quick action, so it reads better as chrome than
/// as a tile. Renders nothing at all when there's nothing useful to say.
struct WeatherHeaderReadout: View {
    @EnvironmentObject private var appState: AppState

    private var service: NativeWeatherService { appState.nativeWeather }

    var body: some View {
        Group {
            if let weather = service.snapshot {
                // Shed the high/low stack as space tightens instead of truncating.
                ViewThatFits(in: .horizontal) {
                    readout(weather, showsRange: true)
                    readout(weather, showsRange: false)
                }
            } else if service.accessStatus == .notDetermined {
                // The weather card used to be the only place to grant location, so the
                // readout doubles as the prompt. Denied/unavailable render nothing and
                // recovery lives in Settings, where a denied permission belongs.
                Button {
                    Task { await appState.requestNativeWeatherAccessAndRefresh() }
                } label: {
                    Label("Weather", systemImage: "location.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show local weather")
                .accessibilityHint("Asks for location access.")
            }
        }
        .task { await service.activateIfAuthorized() }
    }

    /// Glyph and a large temperature, with the day's high over its low beside them. The condition
    /// ("Partly Cloudy") is left out because the glyph already says it; VoiceOver still hears it.
    private func readout(_ weather: NativeWeatherSnapshot, showsRange: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: weather.symbolName)
                .font(.title.weight(.semibold))
                .foregroundStyle(HubTheme.accentText)

            Text("\(weather.temperature)°")
                .font(.system(.title, design: .rounded).weight(.bold))
                .monospacedDigit()

            if showsRange, let high = weather.high, let low = weather.low {
                VStack(alignment: .leading, spacing: 1) {
                    Text("H:\(high)°")
                    Text("L:\(low)°")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
                .monospacedDigit()
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(for: weather))
    }

    private func label(for weather: NativeWeatherSnapshot) -> String {
        var parts = ["\(weather.temperature) degrees", weather.condition]
        if let high = weather.high, let low = weather.low {
            parts.append("High \(high), low \(low)")
        }
        return parts.joined(separator: ", ")
    }
}

struct LiveClockView: View {
    let timezone: TimeZone

    var body: some View {
        // TimelineView schedules its own updates and suspends them while the view is
        // off screen, so there's no Timer to retain or invalidate. `.everyMinute`
        // fires on the minute boundary, which matches the short time style shown here.
        TimelineView(.everyMinute) { context in
            Text(DateHelpers.timeString(context.date, timezone: timezone))
                .font(HubTheme.pageTitle)
                .monospacedDigit()
        }
    }
}

struct ProfileAvatarView: View {
    let name: String
    var avatar: String?
    var color: String = "#4f7c6d"
    var size: CGFloat = 44

    var body: some View {
        Group {
            if ProfilePhotoHelpers.hasPhoto(avatar), let avatar, let url = URL(string: avatar) {
                RemoteImage(url: url, maxPixelSize: max(96, Int(size * 3))) {
                    initialsView
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(HubTheme.readableText(on: HubTheme.profileColor(color)))
            .frame(width: size, height: size)
            .background(HubTheme.profileColor(color))
    }
}

enum HouseholdNameHelpers {
    private static let ignoredHouseholdWords: Set<String> = [
        "the", "family", "household", "house", "home", "fam",
    ]

    static func initial(name: String?, ownerName: String?) -> String {
        householdSurname(from: name)
            ?? surname(from: ownerName)
            ?? "H"
    }

    static func householdSurname(from name: String?) -> String? {
        guard let name else { return nil }
        let parts = name
            .split { $0.isWhitespace || $0 == "/" }
            .map(String.init)
            .filter { !$0.isEmpty }
            .filter { !ignoredHouseholdWords.contains($0.lowercased()) }

        guard let last = parts.last, let initial = last.first else { return nil }
        return String(initial).uppercased()
    }

    static func surname(from name: String?) -> String? {
        guard let name else { return nil }
        let parts = name.split { $0.isWhitespace }.map(String.init).filter { !$0.isEmpty }
        guard let last = parts.last, let initial = last.first else { return nil }
        return String(initial).uppercased()
    }
}

struct HouseholdMarkView: View {
    let name: String
    var photo: String?
    var ownerName: String?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if ProfilePhotoHelpers.hasPhoto(photo), let photo, let url = URL(string: photo) {
                RemoteImage(url: url, maxPixelSize: max(96, Int(size * 3))) {
                    initialView
                }
            } else {
                initialView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        .accessibilityLabel("\(name) household")
    }

    private var initialView: some View {
        Text(HouseholdNameHelpers.initial(name: name, ownerName: ownerName))
            .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(HubTheme.onAccent)
            .frame(width: size, height: size)
            .background(HubTheme.sage)
    }
}

struct EmptyStateView: View {
    let text: String
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HubTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 96)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(HubTheme.line)
                )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

enum HubButtonSize {
    case regular
    case small
    case mini

    var font: Font {
        switch self {
        case .regular: .subheadline.weight(.bold)
        case .small: .caption.weight(.bold)
        case .mini: .caption2.weight(.bold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular: 18
        case .small: 14
        case .mini: 10
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .regular: 10
        case .small: 8
        case .mini: 5
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .regular: 48
        case .small: 36
        case .mini: 28
        }
    }
}

enum HubButtonEmphasis {
    case primary
    case secondary
    case secondaryDestructive
    case danger
}

struct HubButtonStyle: ButtonStyle {
    var emphasis: HubButtonEmphasis = .primary
    var size: HubButtonSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(foregroundColor)
            // The regular button's minimum height is its whole height (48pt), padding included, which is
            // about what Apple's own buttons are; the padding used to be added on top, making it 68pt.
            // A label that grows with the text size still pushes the button taller. Small and mini keep
            // the sizes they have always had.
            .frame(minHeight: size == .regular ? nil : size.minHeight)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size == .regular ? size.minHeight : nil)
            .background(backgroundColor)
            .overlay {
                if showsBorder {
                    Capsule().stroke(HubTheme.line, lineWidth: 1)
                }
            }
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var showsBorder: Bool {
        switch emphasis {
        case .secondary, .secondaryDestructive: true
        case .primary, .danger: false
        }
    }

    private var backgroundColor: Color {
        switch emphasis {
        case .primary: HubTheme.sage
        case .secondary, .secondaryDestructive: HubTheme.surfaceStrong
        case .danger: HubTheme.coral
        }
    }

    private var foregroundColor: Color {
        switch emphasis {
        case .primary: HubTheme.onAccent
        case .danger: HubTheme.onFill
        case .secondary: .primary
        case .secondaryDestructive: HubTheme.coral
        }
    }
}

extension HubTheme {
    static let coral = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.48, blue: 0.40, alpha: 1)
            : UIColor(red: 0.93, green: 0.33, blue: 0.25, alpha: 1)
    })
}

struct RoutineCelebrationBurst: View {
    var tint: Color
    var compact = false
    @State private var burst = false

    private var sparkles: [(String, CGFloat, CGFloat, Double)] {
        let scale: CGFloat = compact ? 0.52 : 1
        return [
            ("⭐", -94 * scale, -48 * scale, 0.0),
            ("✨", 0 * scale, -70 * scale, 0.06),
            ("🎉", 93 * scale, -42 * scale, 0.12),
            ("✨", -67 * scale, 58 * scale, 0.18),
            ("⭐", 77 * scale, 54 * scale, 0.24),
        ]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(burst ? 0 : 0.28))
                .frame(width: compact ? 36 : 64, height: compact ? 36 : 64)
                .scaleEffect(burst ? 2.4 : 0.12)

            ForEach(Array(sparkles.enumerated()), id: \.offset) { _, sparkle in
                Text(sparkle.0)
                    .font(compact ? .body : .title2)
                    .offset(x: burst ? sparkle.1 : 0, y: burst ? sparkle.2 : 0)
                    .scaleEffect(burst ? 1.1 : 0.25)
                    .opacity(burst ? 0 : 1)
                    .rotationEffect(.degrees(burst ? 26 : 0))
                    .animation(.easeOut(duration: 0.78).delay(sparkle.3), value: burst)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onAppear {
            burst = false
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.76)) {
                    burst = true
                }
            }
        }
    }
}
