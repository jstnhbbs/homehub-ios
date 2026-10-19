import SwiftUI

// The pictures on the welcome tour pages. Each is built from the app's own pieces (`TodayCardFrame`,
// `DashboardRow`, the profile colors, the theme palette) with sample data, so it matches the real app in every
// theme, in dark mode and at every text size.

/// Sample people, in the colors the app gives new profiles.
private enum SamplePerson {
    static let maya = (name: "Maya", color: "#d87861")
    static let leo = (name: "Leo", color: "#d19b45")
    static let nova = (name: "Nova", color: "#5f8f8b")
}

// MARK: Today

/// A small Today page: the header with the weather, then four of the cards.
struct WelcomeTodayArt: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Friday, October 16")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                    Text("Today")
                        .font(HubTheme.pageTitle)
                }
                Spacer()
                Label("72°", systemImage: "cloud.sun.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.accentText)
            }
            HStack(spacing: 8) {
                card(.routines, "2 of 5", "Next: Brush teeth")
                card(.chores, "3 left", "Next: Feed the dog")
            }
            HStack(spacing: 8) {
                card(.meals, "Tacos", "Dinner tonight")
                card(.snacks, "1 of 3", "eaten by everyone")
            }
        }
        // A picture, not a control: a swipe on it is a swipe to the next page.
        .allowsHitTesting(false)
    }

    private func card(_ id: DashboardCardId, _ headline: String, _ caption: String) -> some View {
        TodayCardFrame(card: id, fixedHeight: 128) {
            VStack(alignment: .leading, spacing: 6) {
                TodayCardHeadline(headline: headline, caption: caption)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: Together

/// A routine card and a snack tile that tick off when tapped, as they do in the app.
struct WelcomeTogetherArt: View {
    private struct Step: Identifiable {
        let id: String
        let title: String
        let person: (name: String, color: String)
    }

    private let steps = [
        Step(id: "brush", title: "Brush teeth", person: SamplePerson.maya),
        Step(id: "feed", title: "Feed the dog", person: SamplePerson.leo),
        Step(id: "table", title: "Set the table", person: SamplePerson.nova),
    ]
    private let children = [SamplePerson.maya, SamplePerson.leo, SamplePerson.nova]

    @State private var done: Set<String> = ["feed"]
    @State private var ate: Set<String> = ["Maya"]

    var body: some View {
        VStack(spacing: 10) {
            TodayCardFrame(card: .chores, fixedHeight: 286) {
                VStack(alignment: .leading, spacing: 8) {
                    TodayCardSummaryLine(text: "\(steps.count - done.count) left · \(done.count) done")
                    ForEach(steps) { step in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if done.contains(step.id) { done.remove(step.id) } else { done.insert(step.id) }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            DashboardRow(
                                title: step.title,
                                subtitle: step.person.name,
                                subtitlePersonColor: HubTheme.profileColor(step.person.color),
                                isDone: done.contains(step.id)
                            ) {
                                DashboardCheckMarker(isChecked: done.contains(step.id))
                            } trailing: {
                                EmptyView()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Apple slices")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: SnackChipSizing.regularSpacing) {
                    ForEach(children, id: \.name) { child in
                        chip(child)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HubTheme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("Try tapping")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
        }
    }

    private func chip(_ child: (name: String, color: String)) -> some View {
        let tint = HubTheme.profileColor(child.color)
        let eaten = ate.contains(child.name)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if eaten { ate.remove(child.name) } else { ate.insert(child.name) }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack {
                Circle().fill(eaten ? tint : tint.opacity(0.14))
                Circle().stroke(tint.opacity(0.5), lineWidth: eaten ? 0 : 1.5)
                if eaten {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(HubTheme.readableText(on: tint))
                } else {
                    Text(String(child.name.prefix(1)))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(HubTheme.profileText(child.color, onTint: 0.14))
                }
            }
            .frame(width: SnackChipSizing.regularSize, height: SnackChipSizing.regularSize)
            .minimumTapTarget()
        }
        .buttonStyle(.plain)
    }
}

// MARK: Lock Screen

/// A Lock Screen with a nap's Live Activity on it: the child, a timer that really counts, and End Nap.
struct WelcomeLockScreenArt: View {
    @State private var start = Date().addingTimeInterval(-42 * 60 - 15)
    private let tint = HubTheme.profileColor(SamplePerson.leo.color)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.20, green: 0.22, blue: 0.32), Color(red: 0.55, green: 0.38, blue: 0.30)],
                    startPoint: .top, endPoint: .bottom
                ))
            VStack(spacing: 4) {
                Text("Friday, October 16")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("1:57")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 12)
                activity
            }
            .padding(.top, 22)
            .padding([.horizontal, .bottom], 14)
        }
        .frame(height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .allowsHitTesting(false)
    }

    private var activity: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text(String(SamplePerson.leo.name.prefix(1)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(SamplePerson.leo.name)
                        .font(.headline)
                    Label("Napping", systemImage: "moon.zzz.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(start, style: .timer)
                        .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                        // The readable shade, as on the card in the app: raw yellow is faint on a light card.
                        .foregroundStyle(HubTheme.profileText(SamplePerson.leo.color))
                    Text("since 1:15 PM")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text("End Nap")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HubTheme.readableText(on: tint))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(tint, in: Capsule())
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .foregroundStyle(.primary)
        .environment(\.colorScheme, .light)
    }
}

// MARK: Widgets and themes

/// Two Home Screen widgets that tick off when tapped, and the ten theme colors, which recolor them.
struct WelcomeWidgetsArt: View {
    @State private var palette: AccentPalette = .sage
    @State private var done: Set<String> = []

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                choresWidget
                sleepWidget
            }
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(AccentPalette.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { palette = option }
                        } label: {
                            Circle()
                                .fill(option.swatch)
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if option == palette {
                                        Circle().strokeBorder(Color.primary.opacity(0.85), lineWidth: 2.5).padding(-4)
                                    }
                                }
                                .minimumTapTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.label)
                        .accessibilityAddTraits(option == palette ? .isSelected : [])
                    }
                }
                Text("Pick a color")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
    }

    private var choresWidget: some View {
        widget {
            Label("Chores", systemImage: "checkmark.square")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textColor)
            ForEach(["Feed the dog", "Take out bins"], id: \.self) { title in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if done.contains(title) { done.remove(title) } else { done.insert(title) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: done.contains(title) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(done.contains(title) ? palette.swatch : HubTheme.muted)
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .strikethrough(done.contains(title))
                            .foregroundStyle(done.contains(title) ? HubTheme.muted : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .minimumTapTarget()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sleepWidget: some View {
        widget {
            Label("Sleep", systemImage: "moon.zzz.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textColor)
            Text(SamplePerson.leo.name)
                .font(.headline)
            Text("42m")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(palette.textColor)
            Spacer(minLength: 0)
            Text("End")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HubTheme.readableText(on: palette.swatch))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(palette.swatch, in: Capsule())
        }
        .allowsHitTesting(false)
    }

    private func widget<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 168, maxHeight: 168, alignment: .topLeading)
        .background(HubTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(HubTheme.line, lineWidth: 1))
    }
}

// MARK: Start

/// The app icon, large.
struct WelcomeStartArt: View {
    var body: some View {
        Image("AppIconSagePreview")
            .resizable()
            .scaledToFit()
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}
