import SwiftUI

/// The frame every converted Today card is drawn in, on iPhone and iPad alike: the same corner radius,
/// padding, header (icon, title, and a chevron when the card opens a page) and background. What goes
/// inside depends on the card's size; see `ChoresTodayCard` for the pattern.
///
/// The card fills whatever space its grid gives it. `fixedHeight` is for the one place that has no grid
/// (the narrow single-column iPad layout).
struct TodayCardFrame<Content: View>: View {
    static var cornerRadius: CGFloat { 22 }

    @Environment(\.openHubDestination) private var openHubDestination

    let card: DashboardCardId
    var fixedHeight: CGFloat?
    /// What tapping the header does, when it is more than opening the card's page (Snacks opens its tab).
    var onNavigate: (() -> Void)?
    @ViewBuilder var content: () -> Content

    /// How many items the card's lists could not fit, shown as one "+N more" pill in the header.
    @State private var more: TodayCardMore?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
                .overlay(alignment: .trailing) {
                    // Beside the chevron (or at the edge when there is none), above the header's own button.
                    if let more, !dynamicTypeSize.isAccessibilitySize {
                        DashboardMoreChip(count: more.count, action: more.action)
                            .padding(.trailing, card.destination == nil ? 0 : 22)
                    }
                }
            // At the accessibility text sizes the title alone fills the header, so the pill gets its own line.
            if let more, dynamicTypeSize.isAccessibilitySize {
                DashboardMoreChip(count: more.count, action: more.action)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .onPreferenceChange(TodayCardMoreKey.self) { more = $0 }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: fixedHeight)
        .frame(maxHeight: fixedHeight == nil ? .infinity : nil, alignment: .topLeading)
        .background(HubTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var header: some View {
        if let destination = card.destination {
            Button { if let onNavigate { onNavigate() } else { openHubDestination(destination) } } label: {
                headerLabel(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(card.label)
            .accessibilityHint("Open \(card.label)")
        } else {
            headerLabel(showsChevron: false)
        }
    }

    private func headerLabel(showsChevron: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: card.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HubTheme.accentText)
                .accessibilityHidden(true)
            Text(card.compactTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HubTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 28)
        .contentShape(Rectangle())
    }
}

/// The big number or phrase on a Small card, with the line that explains it under it. Every Small card
/// uses this, so they read the same.
struct TodayCardHeadline: View {
    let headline: String
    let caption: String
    /// How many lines the headline may take before it shrinks: one for a number or a time, more for a name.
    var headlineLines = 1
    var headlineFont: Font = .title2.weight(.bold)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headline)
                .font(headlineFont)
                .monospacedDigit()
                .lineLimit(headlineLines)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
            Text(caption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
                .lineLimit(3)
        }
    }
}

/// The one line a Medium or Large card puts above its rows ("2 left · 1 done").
struct TodayCardSummaryLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(HubTheme.muted)
            .lineLimit(1)
    }
}

/// A named group of rows inside a Large card (Today, Coming up).
struct TodayCardSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(HubTheme.muted)
                .accessibilityAddTraits(.isHeader)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A short sentence where a list would be, for a section with nothing in it.
struct TodayCardEmptyNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(HubTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension DashboardCardId {
    /// The card's name as its header shows it, shortened where the full name would not fit a Small card.
    var compactTitle: String {
        switch self {
        case .schedule: "Schedule"
        case .routines: "Routines"
        case .meals: "Food"
        default: label
        }
    }

    /// Cards already drawn with `TodayCardFrame` and a layout for every size. The rest still use their
    /// older panels and compact tiles until they are converted.
    var usesTodayCard: Bool { self != .weather }
}

/// A Small card's body: one button that opens the card's page, so a glance is also a way in. Small never
/// does anything else; actions start at Medium.
/// Set by a card's edit chrome while the Today page is being edited, so a card can leave room for the size button
/// that sits over its bottom-right corner.
private struct DashboardCardIsEditingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var dashboardCardIsEditing: Bool {
        get { self[DashboardCardIsEditingKey.self] }
        set { self[DashboardCardIsEditingKey.self] = newValue }
    }
}

struct TodayCardSmallBody<Content: View>: View {
    @Environment(\.openHubDestination) private var openHubDestination
    @Environment(\.dashboardCardIsEditing) private var isEditing

    let card: DashboardCardId
    /// What tapping does when it should be more than opening the card's page.
    var action: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button {
            if let action {
                action()
            } else if let destination = card.destination {
                openHubDestination(destination)
            }
        } label: {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // While editing, the size button covers the bottom-right corner, where a progress bar or a row
                // of avatars sits; this lifts the content clear of it.
                .padding(.bottom, isEditing && card.allowedSizes.count > 1 ? DashboardMetrics.scaled(26, .subheadline) : 0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open \(card.label)")
    }
}

/// A day as the small marker at the start of a row ("Tue"): a chore coming up, a dinner later in the week.
/// The nearest one can be set in the accent color so it stands out.
struct TodayCardDayChip: View {
    let label: String
    let highlighted: Bool


    var body: some View {
        Text(label)
            .font(.caption2.weight(.heavy))
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(highlighted ? HubTheme.accentText : HubTheme.muted)
            .frame(width: 28, height: 28)
            .background(HubTheme.tile, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}
