import SwiftUI
import UIKit

enum AccentPalette: String, CaseIterable, Identifiable, Sendable {
    // The raw values are what is saved on a device, so they keep the names of the original,
    // earthier palette (sage is now Moss, rose is Raspberry). `label` is what people see. A
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

    /// Dark mode uses pure black pages instead of charcoal when this is on (Settings > Appearance >
    /// True Black), for OLED screens. Every surface moves down one step, so cards stay lighter than
    /// the page. Saved on the device by `AppState.usesTrueBlack`.
    static var usesTrueBlack = false
    static var backgroundStyle: HubBackgroundStyle = .theme

    // Light mode keeps the system's colors. Dark mode is a soft charcoal rather than the system's
    // true black: the page is #1C1C1E, cards sit a step lighter at #2C2C2E and the things inside
    // cards a step lighter again at #3A3A3C. With True Black on, the page is #000000, cards are
    // #1C1C1E and the things inside them #2C2C2E (the system's own dark steps).
    //
    // Each surface is two colors, one per setting, and the one in use is picked when a view reads
    // it. (A single color that looked up the setting itself would be resolved once and kept, so
    // flipping the switch would leave every screen as it was.)
    private static func surface(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    private static func grey(_ value: CGFloat, _ blue: CGFloat? = nil) -> UIColor {
        UIColor(red: value, green: value, blue: blue ?? value, alpha: 1)
    }

    private static let charcoalPage = grey(0.110, 0.118)    // #1C1C1E
    private static let charcoalCard = grey(0.173, 0.180)    // #2C2C2E
    private static let charcoalInner = grey(0.227, 0.235)   // #3A3A3C
    private static let blackPage = grey(0)                   // #000000
    private static let blackCard = grey(0.110, 0.118)        // #1C1C1E
    private static let blackInner = grey(0.173, 0.180)       // #2C2C2E

    private static let canvasCharcoal = surface(light: .systemGroupedBackground, dark: charcoalPage)
    private static let canvasBlack = surface(light: .systemGroupedBackground, dark: blackPage)
    private static let surfaceCharcoal = surface(light: .systemBackground, dark: charcoalPage)
    private static let surfaceBlack = surface(light: .systemBackground, dark: blackPage)
    private static let strongCharcoal = surface(light: .tertiarySystemGroupedBackground, dark: charcoalInner)
    private static let strongBlack = surface(light: .tertiarySystemGroupedBackground, dark: blackInner)
    private static let tileCharcoal = surface(light: .secondarySystemGroupedBackground, dark: charcoalCard)
    private static let tileBlack = surface(light: .secondarySystemGroupedBackground, dark: blackCard)

    static var canvas: Color { usesTrueBlack ? canvasBlack : canvasCharcoal }
    static var surface: Color { usesTrueBlack ? surfaceBlack : surfaceCharcoal }
    static var surfaceStrong: Color { usesTrueBlack ? strongBlack : strongCharcoal }
    static var tile: Color { usesTrueBlack ? tileBlack : tileCharcoal }
    static var tileQuiet: Color { surfaceStrong }
    static let line = Color(.separator)
    static let muted = Color(.secondaryLabel)

    // Text styles rather than fixed point sizes, so everything scales with the
    // reader's Dynamic Type setting. At the default size these render identically
    // to the hardcoded sizes they replaced: .largeTitle is 34pt, .title is 28pt.
    static let pageTitle = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    static let sectionTitle = Font.system(.title, design: .rounded).weight(.semibold)

    /// The colors people can give a profile are stored as the muted hex values of the original
    /// palette (the server and the web settings still know them by those) and shown as the theme
    /// colors here, so a person's dot matches the app (`AccentColorTable.personColorIds`). Anything else is
    /// shown as it is. This is the fill color; for text use `profileText`.
    static func profileColor(_ hex: String?) -> Color {
        guard let hex, let fill = AccentColorTable.personFill(hex) else { return accent }
        return Color(uiColor: UIColor(fill))
    }

    /// A person's color where it is text or a small icon: the color itself where it reads at 4.5 to 1,
    /// otherwise a lighter (dark mode) or deeper (light mode) shade of it (`AccentColorTable.personText`).
    /// Use this, not `profileColor`, for any text drawn in a person's color; `profileColor` is for fills.
    /// A chip that sits on a tint of the same color passes that tint's strength as `onTint`.
    static func profileText(_ hex: String?, onTint: Double = 0) -> Color {
        guard let hex, AccentColorTable.personFill(hex) != nil else { return accentText }
        return Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(AccentColorTable.personText(hex, dark: isDark, onTint: onTint) ?? AccentColorTable.text("sage", dark: isDark))
        })
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
        background(HubBackdrop(base: HubTheme.canvas).ignoresSafeArea())
    }

    /// The page color for screens that sit on the app's white surface rather than the grouped canvas.
    func hubSurfaceBackground() -> some View {
        background(HubBackdrop(base: HubTheme.surface).ignoresSafeArea())
    }

    /// A card in glass: real Liquid Glass on iOS 26 and later, a frosted material with a bright rim before that.
    func hubGlass(cornerRadius: CGFloat) -> some View {
        modifier(HubGlassCard(cornerRadius: cornerRadius))
    }
}

/// The phone's top safe area (status bar and Dynamic Island), read from the window, for pages that scroll under it.
enum HubScreen {
    private static var insets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero
    }
    static var topInset: CGFloat { insets.top }
    /// The room the floating tab bar takes at the bottom: the home indicator's inset and the bar itself.
    static var tabBarClearance: CGFloat { insets.bottom + 52 }
}

/// A soft frosted fade over the status bar, so content that scrolls up under it stays out of the clock's way.
struct HubTopFade: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
            .frame(height: HubScreen.topInset + 14)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Lets a phone page's scroll view fill the screen and inset its own content for the bars, so content scrolls
    /// under the status bar and the tab bar instead of stopping at a clip line.
    func hubFullBleed() -> some View {
        ignoresSafeArea(.container, edges: [.top, .bottom])
            .overlay(alignment: .top) { HubTopFade().ignoresSafeArea(edges: .top) }
    }
}

/// A frosted row background for grouped lists that sit on the page's own background.
struct HubGlassRow: View {
    var body: some View { Rectangle().fill(HubTheme.tile.opacity(0.62)).background(.ultraThinMaterial) }
}

/// How the page background looks, chosen in Settings > Appearance and saved on this device.
enum HubBackgroundStyle: String, CaseIterable, Identifiable {
    /// A soft glow of the theme color behind the top of each page.
    case theme
    /// A faint grey glow, which never clashes with the colors people and routines are given.
    case neutral
    /// Just the page color.
    case off

    var id: String { rawValue }
    var label: String {
        switch self {
        case .theme: "Theme Color"
        case .neutral: "Neutral"
        case .off: "Off"
        }
    }
}

/// Which glow a page asks for. Pages made of people's colors (routines, chores, snacks, sleep) ask for a neutral one,
/// because a green wash behind rose and blue tiles turns them muddy.
enum HubWash { case theme, neutral }

private struct HubWashKey: EnvironmentKey { static let defaultValue: HubWash = .theme }
private struct HubBackdropProvidedKey: EnvironmentKey { static let defaultValue = false }
private struct HubSolidBackdropKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var hubWash: HubWash {
        get { self[HubWashKey.self] }
        set { self[HubWashKey.self] = newValue }
    }
    /// True inside the iPad's hub, which paints one page color and glow behind the whole screen; pages inside it must not
    /// paint another, or each shows as a box with its own gradient.
    /// Inside a navigation stack on the iPad's hub, which paints its own system black behind its pages: they paint the
    /// plain page color (no glow, the hub already draws that) so the stack does not show as a black box.
    var hubSolidBackdrop: Bool {
        get { self[HubSolidBackdropKey.self] }
        set { self[HubSolidBackdropKey.self] = newValue }
    }
    var hubBackdropProvided: Bool {
        get { self[HubBackdropProvidedKey.self] }
        set { self[HubBackdropProvidedKey.self] = newValue }
    }
}

/// The page color with a soft wash at the top, so glass cards have something to refract.
struct HubBackdrop: View {
    let base: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hubWash) private var wash
    @Environment(\.hubBackdropProvided) private var provided
    @Environment(\.hubSolidBackdrop) private var solid

    private var washColor: Color {
        switch (HubTheme.backgroundStyle, wash) {
        case (.neutral, _), (.theme, .neutral): Color.gray
        default: HubTheme.accent
        }
    }

    var body: some View {
        let dark = colorScheme == .dark
        if provided {
            if solid { base } else { Color.clear }
        } else {
        ZStack {
            base
            if HubTheme.backgroundStyle != .off {
                LinearGradient(
                    stops: [
                        .init(color: washColor.opacity(dark ? (wash == .neutral || HubTheme.backgroundStyle == .neutral ? 0.17 : 0.38) : 0.20), location: 0),
                        .init(color: washColor.opacity(dark ? (wash == .neutral || HubTheme.backgroundStyle == .neutral ? 0.06 : 0.16) : 0.07), location: 0.38),
                        .init(color: .clear, location: 0.8),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        }
    }
}

private struct HubGlassCard: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, *) {
            // In dark mode a solid base sits under the glass, so what is behind a card (the page's wash, a person's
            // color) cannot shift the card's own colors.
            content
                .background(colorScheme == .dark ? HubTheme.tile.opacity(0.7) : Color.clear, in: shape)
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(colorScheme == .dark ? 0.28 : 0.75), .white.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
                )
        }
    }
}

/// Lines a grouped list's cards up with the page's own side margin. A grouped list adds a margin of
/// its own, which stacks on the page's (16pt on iPhone, 24pt on iPad) and left its cards narrower
/// than every other page's. The list is widened over the page's padding and given the same margin
/// back, so the cards keep their rounded corners and sit exactly where other pages' cards do.
private struct ListAlignedWithPage: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ViewBuilder
    func body(content: Content) -> some View {
        if horizontalSizeClass == .compact {
            // A phone page no longer pads its scroll view, so a grouped list's own margin is already right.
            content
        } else {
            content
                .contentMargins(.horizontal, 24, for: .scrollContent)
                .padding(.horizontal, -24)
        }
    }
}

extension View {
    func listAlignedWithPage() -> some View {
        modifier(ListAlignedWithPage())
    }
}

struct HubCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .hubGlass(cornerRadius: 24)
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
    /// The row can't be ticked yet (a chore waiting for its day). Only the circle is dimmed; the words
    /// keep their full contrast, which is why this is not `.disabled` (that fades the whole label).
    var isUnavailable = false
    var onToggle: () async -> Void

    @State private var isHidden = false
    @State private var isWorking = false

    var body: some View {
        if !isHidden {
            // Not a Button: a Button counts a swipe that ends inside it as a tap, and this row is swiped (edit and
            // delete). A tap gesture is dropped once the finger has moved.
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? HubTheme.accentText : HubTheme.muted)
                    .opacity(isUnavailable ? 0.4 : 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isChecked ? HubTheme.muted : .primary)
                        .strikethrough(isChecked, color: HubTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HubTheme.profileText(color))
                            // The words ("Every month · on the 24th") are information; at the large text
                            // sizes they wrap to the lines they need instead of ending in "…".
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if isWorking {
                    ProgressView()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .hubGlass(cornerRadius: 18)
            .opacity(isChecked ? 0.7 : 1)
            .contentShape(Rectangle())
            .opacity(isWorking ? 0.6 : 1)
            .onTapGesture {
                guard !isWorking else { return }
                guard !isUnavailable else { return }
                Task {
                    isWorking = true
                    await onToggle()
                    isChecked.toggle()
                    isWorking = false
                    if removeWhenChecked, isChecked {
                        withAnimation { isHidden = true }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { Task { guard !isWorking, !isUnavailable else { return }; isWorking = true; await onToggle(); isChecked.toggle(); isWorking = false } }
            .accessibilityValue(isChecked ? "Done" : "Not done")
            .accessibilityAddTraits(.isToggle)
            .accessibilityHint(isUnavailable ? "Not due until its day" : "")
        }
    }
}

/// Ambient temperature readout for the app headers. Weather is the only dashboard
/// card with no destination and no quick action, so it reads better as chrome than
/// as a tile. Renders nothing at all when there's nothing useful to say.
struct WeatherHeaderReadout: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ObservedWeatherReadout(service: appState.nativeWeather)
    }
}

private struct ObservedWeatherReadout: View {
    @ObservedObject var service: NativeWeatherService
    @State private var showsDetails = false

    var body: some View {
        Group {
            if let weather = service.snapshot {
                // Tapping opens the rest of the reading and the Apple Weather attribution, which
                // Apple requires wherever WeatherKit data is shown.
                Button {
                    showsDetails = true
                } label: {
                    // Shed the high/low stack as space tightens instead of truncating.
                    ViewThatFits(in: .horizontal) {
                        readout(weather, showsRange: true)
                        readout(weather, showsRange: false)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows today's weather details.")
                .popover(isPresented: $showsDetails) {
                    WeatherDetailsPanel(weather: weather, attribution: service.attribution, refreshError: service.errorMessage)
                        .presentationCompactAdaptation(.popover)
                }
            } else if service.accessStatus == .notDetermined {
                // The weather card used to be the only place to grant location, so the
                // readout doubles as the prompt. Denied/unavailable render nothing and
                // recovery lives in Settings, where a denied permission belongs.
                Button {
                    Task { await service.requestAccessAndRefresh() }
                } label: {
                    Label("Weather", systemImage: "location.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
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
                .accessibilityAddTraits(.isHeader)
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
    /// The buttons that edit the Today page (the pencil, Done and a card's size button): near-black in light mode
    /// and near-white in dark mode, whatever the theme color is, so they stand out from the cards and never blend
    /// into a theme of the same color. The text and icon on them is `editChromeText`.
    static let editChrome = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
            : UIColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1)
    })
    static let editChromeText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1)
            : .white
    })

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
