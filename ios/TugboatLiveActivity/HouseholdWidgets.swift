import AppIntents
import SwiftUI
import UIKit
import WidgetKit

struct HouseholdWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    var personId: String? = nil
    var noteId: String? = nil
    var dinnerImage: UIImage? = nil
    var accent: WidgetAccentChoice = .automatic
    var trueBlack = false
    /// Taps shown but not yet accepted by the server (no connection when they were made).
    var pendingTapTimes: [Date] = []
    /// A tap that was only just made is on its way to the server, not waiting: it counts as waiting once it has
    /// been unsent for `inFlightSeconds`, which a quick send never reaches.
    static let inFlightSeconds: TimeInterval = 8
    var pendingCount: Int { pendingTapTimes.filter { date.timeIntervalSince($0) >= Self.inFlightSeconds }.count }
}

enum HouseholdWidgetTimeline {
    static func entry(date: Date = .now, personId: String? = nil, noteId: String? = nil, includesImage: Bool = false,
                      accent: WidgetAccentChoice = .automatic, trueBlack: Bool = false) async -> HouseholdWidgetEntry {
        let store = WidgetStore()
        // Taps that were made without a connection: try them again now, briefly, so a widget refreshed once
        // the phone is back online shows the result. With no connection this fails at once and they wait.
        let queue = WidgetPendingQueue()
        // A tap made a moment ago is already being sent by the extension that handled it; waiting for that here
        // would hold the timeline back for seconds, long enough for the entries that show the row's check to
        // be in the past by the time they are returned, so the check would never be seen.
        if let user = store.load()?.userId {
            let stuck = queue.load().contains { $0.userId == user && date.timeIntervalSince($0.tappedAt) >= HouseholdWidgetEntry.inFlightSeconds }
            if stuck { await WidgetSync.flush(store: store, queue: queue, timeout: 5) }
        }
        var snapshot = store.load()
        let originalUser = snapshot?.userId
        let originalHome = snapshot?.householdId
        let originalImage = snapshot?.dinner?.imageURL
        var image: UIImage?
        // Widgets render snapshots, not live AsyncImage views. Fetch and downsample during timeline creation.
        if includesImage, let value = snapshot?.dinner?.imageURL, let url = URL(string: value), url.scheme == "https" {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            if let (data, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 8 * 1024 * 1024,
               let thumbnail = ImageDownsampling.thumbnail(from: data, maxPixelSize: 500) {
                image = UIImage(cgImage: thumbnail)
            }
        }
        // A download must not return an old account's content after sign-out or a household switch.
        snapshot = store.load()
        if snapshot?.userId != originalUser || snapshot?.householdId != originalHome || snapshot?.dinner?.imageURL != originalImage {
            image = nil
        }
        let pending = snapshot.map { snap in queue.load().filter { $0.userId == snap.userId && !$0.isExpired(at: date) }.map(\.tappedAt) } ?? []
        return HouseholdWidgetEntry(date: date, snapshot: snapshot, personId: personId, noteId: noteId, dinnerImage: image,
                                    accent: accent, trueBlack: trueBlack, pendingTapTimes: pending)
    }

    static func timeline(_ entry: HouseholdWidgetEntry) -> Timeline<HouseholdWidgetEntry> {
        // Include event boundaries and household midnight so cached data never looks like today's
        // checklist after the day changes. iOS decides when background reloads actually run.
        var dates = [entry.date]
        if let snapshot = entry.snapshot {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = snapshot.timeZone
            if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: entry.date)) {
                dates.append(midnight)
            }
            for hour in [12, 17] {
                if let boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: entry.date), boundary > entry.date {
                    dates.append(boundary)
                }
            }
            dates += snapshot.events.flatMap { [$0.start, $0.end] }.filter { $0 > entry.date && $0 < entry.date.addingTimeInterval(3600) }
        }
        // A tap still unsent after the in-flight time becomes "Waiting to sync".
        dates += entry.pendingTapTimes.map { $0.addingTimeInterval(HouseholdWidgetEntry.inFlightSeconds) }.filter { $0 > entry.date }
        let entries = Set(dates).sorted().map { date in
            HouseholdWidgetEntry(date: date, snapshot: entry.snapshot, personId: entry.personId, noteId: entry.noteId,
                                 dinnerImage: entry.dinnerImage, accent: entry.accent, trueBlack: entry.trueBlack,
                                 pendingTapTimes: entry.pendingTapTimes)
        }
        return Timeline(entries: entries, policy: .after(entry.date.addingTimeInterval(900)))
    }
}

struct HouseholdSummaryProvider: AppIntentTimelineProvider {
    var includesImage = false
    func placeholder(in context: Context) -> HouseholdWidgetEntry { .init(date: .now, snapshot: .preview) }
    func snapshot(for configuration: WidgetAppearanceConfiguration, in context: Context) async -> HouseholdWidgetEntry {
        if context.isPreview { return placeholder(in: context) }
        return await HouseholdWidgetTimeline.entry(includesImage: includesImage, accent: configuration.accent, trueBlack: configuration.trueBlack)
    }
    func timeline(for configuration: WidgetAppearanceConfiguration, in context: Context) async -> Timeline<HouseholdWidgetEntry> {
        HouseholdWidgetTimeline.timeline(await HouseholdWidgetTimeline.entry(
            includesImage: includesImage, accent: configuration.accent, trueBlack: configuration.trueBlack))
    }
}

struct RoutineWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HouseholdWidgetEntry { .init(date: .now, snapshot: .preview) }
    func snapshot(for configuration: RoutineWidgetConfiguration, in context: Context) async -> HouseholdWidgetEntry {
        if context.isPreview { return placeholder(in: context) }
        return await HouseholdWidgetTimeline.entry(personId: configuration.child?.id, accent: configuration.accent, trueBlack: configuration.trueBlack)
    }
    func timeline(for configuration: RoutineWidgetConfiguration, in context: Context) async -> Timeline<HouseholdWidgetEntry> {
        HouseholdWidgetTimeline.timeline(await HouseholdWidgetTimeline.entry(
            personId: configuration.child?.id, accent: configuration.accent, trueBlack: configuration.trueBlack))
    }
}

struct NoteWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HouseholdWidgetEntry { .init(date: .now, snapshot: .preview) }
    func snapshot(for configuration: NoteWidgetConfiguration, in context: Context) async -> HouseholdWidgetEntry {
        if context.isPreview { return placeholder(in: context) }
        return await HouseholdWidgetTimeline.entry(noteId: configuration.note?.id, accent: configuration.accent, trueBlack: configuration.trueBlack)
    }
    func timeline(for configuration: NoteWidgetConfiguration, in context: Context) async -> Timeline<HouseholdWidgetEntry> {
        HouseholdWidgetTimeline.timeline(await HouseholdWidgetTimeline.entry(
            noteId: configuration.note?.id, accent: configuration.accent, trueBlack: configuration.trueBlack))
    }
}

struct HouseholdSummaryWidget: Widget {
    let kind: HouseholdWidgetKind
    init() { kind = .next }
    init(kind: HouseholdWidgetKind) { self.kind = kind }
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Tugboat.\(kind.rawValue)", intent: WidgetAppearanceConfiguration.self,
                               provider: HouseholdSummaryProvider(includesImage: kind == .dinner || kind == .overview)) { entry in
            HouseholdWidgetView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.title)
        .description(description)
        .supportedFamilies(kind == .overview ? [.systemMedium, .systemLarge] : [.systemSmall, .systemMedium, .systemLarge])
    }
    private var description: String {
        switch kind {
        case .next: "Your next calendar event, timed chore, or routine."
        case .chores: "See today's chores and mark them done."
        case .dinner: "See tonight's meal and open its saved recipe."
        case .sleep: "See who's asleep and end a nap or night sleep."
        case .groceries: "See what's left on your grocery list."
        case .celebrations: "Count down to the next birthday or anniversary."
        case .overview: "A quick look at the day across your household."
        default: "A quick look at your household."
        }
    }
}

struct HouseholdRoutineWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Tugboat.routines", intent: RoutineWidgetConfiguration.self, provider: RoutineWidgetProvider()) { entry in
            HouseholdWidgetView(kind: .routines, entry: entry)
        }
        .configurationDisplayName("Child's Routines")
        .description("Choose a child, see their progress, and check off steps.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct HouseholdNoteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Tugboat.notes", intent: NoteWidgetConfiguration.self, provider: NoteWidgetProvider()) { entry in
            HouseholdWidgetView(kind: .notes, entry: entry)
        }
        .configurationDisplayName("Household Note")
        .description("Choose a note, or keep your pinned note in sight.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct HouseholdWidgetView: View {
    let kind: HouseholdWidgetKind
    let entry: HouseholdWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var rowLimit: Int { large ? 5 : (small ? 1 : 2) }
    private var dark: Bool { colorScheme == .dark }
    /// True black applies in dark mode only; light mode keeps its white background.
    private var surfaceHex: String { dark ? (entry.trueBlack ? "#000000" : "#1C1C1E") : "#FFFFFF" }
    /// The chosen color for text and symbols: the app's theme color unless this widget picked its own,
    /// lightened or deepened where needed to read on the widget's background.
    private var accentShade: RGBColor {
        let hex: String
        if let id = entry.accent.paletteId {
            hex = (dark ? AccentColorTable.dark : AccentColorTable.light)[id] ?? "#5F8153"
        } else {
            hex = (dark ? entry.snapshot?.accentDark : entry.snapshot?.accentLight) ?? "#5F8153"
        }
        return ColorMath.textShade(of: RGBColor(hex: hex), on: RGBColor(hex: surfaceHex), lighten: dark)
    }
    private var accent: Color { widgetColor(accentShade.hex) }
    /// White or near-black, whichever reads better on a button filled with the accent.
    private var onAccent: Color { widgetColor(ColorMath.readableText(on: accentShade).hex) }

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 4 : (large ? 8 : 6)) {
            Label(kind.title, systemImage: kind.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let snapshot = entry.snapshot {
                if kind.destination != "dashboard", !snapshot.enabledDestinations.contains(kind.destination) {
                    empty("This section is turned off.")
                } else if !snapshot.isCurrentDay(at: entry.date), [.next, .routines, .chores, .dinner, .overview].contains(kind) {
                    empty("Refresh for today's information.")
                } else {
                    content(snapshot)
                }
                Spacer(minLength: 0)
                footer(snapshot)
            } else {
                empty("Open Tugboat and sign in.")
            }
        }
        .privacySensitive()
        .widgetURL(WidgetRoute.url(destination: kind.destination, recipeId: kind == .dinner ? entry.snapshot?.dinner?.recipeId : nil))
        .containerBackground(for: .widget) { widgetColor(surfaceHex) }
        .tint(accent)
    }

    @ViewBuilder private func content(_ snapshot: WidgetSnapshot) -> some View {
        switch kind {
        case .next: upcoming(snapshot)
        case .routines: routines(snapshot)
        case .chores: chores(snapshot)
        case .dinner: dinner(snapshot)
        case .sleep: sleep(snapshot)
        case .notes: note(snapshot)
        case .groceries: groceries(snapshot)
        case .celebrations: celebrations(snapshot)
        case .overview: overview(snapshot)
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func headline(_ value: String) -> some View {
        Text(value).font(.system(.title2, design: .rounded).weight(.bold)).lineLimit(2).minimumScaleFactor(0.8)
    }

    private func footer(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 4) {
            if let error = snapshot.actionError {
                Text(error).foregroundStyle(.red).lineLimit(small ? 2 : 1)
            } else if entry.pendingCount > 0 {
                // Shown, but the server hasn't had it yet: it will be sent when there is a connection.
                Label("Waiting to sync", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text(snapshot.updatedAt, style: .time).foregroundStyle(.secondary)
                    .accessibilityLabel("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
            }
            Spacer(minLength: 0)
            Button(intent: HouseholdWidgetRefreshIntent(snapshot: snapshot)) {
                Image(systemName: "arrow.clockwise").frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh household widget")
        }
        .font(.caption2)
    }

    @ViewBuilder private func upcoming(_ snapshot: WidgetSnapshot) -> some View {
        let items = snapshot.upcoming(at: entry.date)
        if items.isEmpty { empty("Nothing coming up.") }
        ForEach(Array(items.prefix(rowLimit))) { item in
            Link(destination: WidgetRoute.url(destination: item.destination)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(small ? .headline : .subheadline.weight(.semibold)).lineLimit(small || large ? 2 : 1)
                    HStack(spacing: 6) {
                        Text(item.detail)
                        if let start = item.start { Text(start, style: .time) }
                    }.font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(.primary)
        }
    }

    @ViewBuilder private func routines(_ snapshot: WidgetSnapshot) -> some View {
        let validPerson = entry.personId == nil || snapshot.people.contains { $0.id == entry.personId && $0.isChild }
        let steps = snapshot.routineSteps(personId: entry.personId, at: entry.date)
        let done = steps.filter(\.completed).count
        if !validPerson {
            empty("Choose a child in Edit Widget.")
        } else if steps.isEmpty {
            empty("No routines on today.")
        } else {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(accent.opacity(0.18), lineWidth: 4)
                    Circle().trim(from: 0, to: CGFloat(done) / CGFloat(steps.count))
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(done)").font(.headline.monospacedDigit())
                }.frame(width: small ? 30 : 38, height: small ? 30 : 38)
                    .accessibilityLabel("\(done) of \(steps.count) routine steps complete")
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.personId.map { snapshot.personName($0) } ?? "Everyone").font(small ? .subheadline.weight(.semibold) : .headline).lineLimit(1)
                    Text("\(done) of \(steps.count) done").font(.caption2).foregroundStyle(.secondary)
                }
            }
            ForEach(Array(steps.filter { !$0.completed }.prefix(large ? 5 : 1))) { step in
                checkoff(step.label, detail: small ? nil : snapshot.personName(step.personId), action: "step", id: step.id, snapshot: snapshot)
            }
            if done == steps.count { Text("All set").font(.subheadline).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private func chores(_ snapshot: WidgetSnapshot) -> some View {
        let remaining = snapshot.chores.filter { !$0.completed }
        if small || large { headline("\(remaining.count) left") }
        if remaining.isEmpty { empty("All set for today.") }
        ForEach(Array(remaining.prefix(rowLimit))) { chore in
            checkoff(chore.title, detail: small ? nil : snapshot.personName(chore.personId), action: "chore", id: chore.id, snapshot: snapshot)
        }
    }

    /// A toggle rather than a plain button: the system flips it to its checked look the instant it is tapped,
    /// without waiting for a redraw, so the tap is seen while the action holds the row on screen. The row is
    /// removed by the redraw that follows the action.
    private func checkoff(_ title: String, detail: String?, action: String, id: String, snapshot: WidgetSnapshot) -> some View {
        Toggle(isOn: false, intent: HouseholdWidgetCheckIntent(action: action, itemId: id, snapshot: snapshot)) {
            Text(title)
        }
        .toggleStyle(WidgetCheckoffToggleStyle(title: title, detail: detail, small: small, large: large, accent: accent))
        .accessibilityLabel("Mark \(title) done")
    }

    @ViewBuilder private func dinner(_ snapshot: WidgetSnapshot) -> some View {
        if let meal = snapshot.dinner {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    headline(meal.title)
                    if !small, kind == .dinner { Text(snapshot.householdName).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                }
                if !small, let image = entry.dinnerImage {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: large ? 100 : 68, height: large ? 100 : 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
                }
            }
        } else { empty("Dinner isn't planned yet.") }
    }

    @ViewBuilder private func sleep(_ snapshot: WidgetSnapshot) -> some View {
        let active = snapshot.sleeps.filter { $0.end == nil }.sorted { $0.start < $1.start }
        let limit = small ? 1 : (large ? 3 : 2)
        if active.isEmpty {
            headline("Everyone awake")
            sleepSummary(snapshot, awakeLimit: small ? 0 : (large ? 5 : 3), showsTotal: true)
        } else {
            ForEach(Array(active.prefix(limit))) { log in
                sleepRow(log, snapshot: snapshot, roomy: active.count == 1)
            }
            // The room left over on a medium widget with one sleeper, and on a large one, shows who is
            // awake and for how long, and how much has been slept today.
            if large || (!small && active.count == 1) {
                sleepSummary(snapshot, awakeLimit: large ? 4 : 2, showsTotal: true)
            }
        }
    }

    /// One sleeper: their name, what kind of sleep and since when, the running timer, and an End button
    /// big enough to hit without looking (at least 44 pt tall, and the full width on a small widget).
    private func sleepRow(_ log: WidgetSnapshot.Sleep, snapshot: WidgetSnapshot, roomy: Bool) -> some View {
        let name = snapshot.personName(log.personId)
        let kind = log.kind == "night" ? "Night sleep" : "Nap"
        let info = VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.headline).lineLimit(1)
            (Text("\(kind) since ") + Text(log.start, style: .time)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(log.start, style: .timer)
                .font(.system(roomy && !small ? .largeTitle : .title2, design: .rounded).weight(.semibold).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        let end = Button(intent: HouseholdWidgetActionIntent(action: "endSleep", itemId: log.id, snapshot: snapshot)) {
            Text(small ? "End Sleep" : "End")
                .font(.headline)
                .foregroundStyle(onAccent)
                .frame(maxWidth: small ? .infinity : 84, minHeight: small ? 34 : 44, maxHeight: roomy && !small ? .infinity : 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("End sleep for \(name)")
        return Group {
            if small {
                VStack(alignment: .leading, spacing: 6) { info; end }
            } else {
                HStack(alignment: .center, spacing: 10) { info; end }
            }
        }
    }

    /// Who is awake and since when (from their last sleep), and the day's total, for the room a sleep
    /// widget otherwise leaves empty.
    @ViewBuilder private func sleepSummary(_ snapshot: WidgetSnapshot, awakeLimit: Int, showsTotal: Bool) -> some View {
        let sleeping = Set(snapshot.sleeps.filter { $0.end == nil }.map(\.personId))
        let awake: [(name: String, since: Date)] = snapshot.people.filter { $0.isChild && !sleeping.contains($0.id) }.compactMap { person in
            guard let last = snapshot.sleeps.filter({ $0.personId == person.id }).compactMap(\.end).max() else { return nil }
            return (person.name, last)
        }.sorted { $0.since < $1.since }
        ForEach(Array(awake.prefix(awakeLimit).enumerated()), id: \.offset) { _, item in
            HStack(spacing: 4) {
                Text("\(item.name) awake").lineLimit(1)
                Spacer(minLength: 4)
                Text(item.since, style: .relative).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }.font(.caption)
        }
        if showsTotal, !small, snapshot.isCurrentDay(at: entry.date) {
            let minutes = snapshot.sleepMinutes(on: entry.date)
            if minutes > 0 {
                Text("\(minutes / 60)h \(minutes % 60)m slept today").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    @ViewBuilder private func note(_ snapshot: WidgetSnapshot) -> some View {
        if let note = snapshot.selectedNote(id: entry.noteId) {
            Text(note.title).font(.headline).lineLimit(large ? 4 : 2)
            if !note.body.isEmpty { Text(note.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(large ? 10 : (small ? 2 : 3)) }
        } else { empty(entry.noteId == nil ? "No household notes yet." : "This note is no longer available.") }
    }

    @ViewBuilder private func groceries(_ snapshot: WidgetSnapshot) -> some View {
        headline("\(snapshot.groceryCount) to buy")
        if snapshot.groceryCount == 0 { empty("Your list is clear.") }
        ForEach(Array(snapshot.groceries.prefix(large ? 7 : 2).enumerated()), id: \.offset) { _, title in
            Text(title).font(.subheadline).lineLimit(1)
        }
    }

    @ViewBuilder private func celebrations(_ snapshot: WidgetSnapshot) -> some View {
        let calendar = calendar(snapshot)
        let upcoming = snapshot.celebrations.filter { localDate($0.date, snapshot: snapshot).map { $0 >= calendar.startOfDay(for: entry.date) } ?? false }
        if upcoming.isEmpty { empty("No upcoming celebrations.") }
        ForEach(Array(upcoming.prefix(large ? 5 : 1))) { celebration in
            if let date = localDate(celebration.date, snapshot: snapshot) {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date), to: date).day ?? 0
                VStack(alignment: .leading, spacing: 3) {
                    Text(celebration.name).font(.headline).lineLimit(1)
                    Text(days == 0 ? "Today" : "\(days) days").font(small ? .title2.weight(.bold) : .subheadline.weight(.semibold))
                    if !small { Text(celebration.isAnniversary ? "\(celebration.years) years" : "Turns \(celebration.years)").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func overview(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.householdName).font(.headline).lineLimit(1)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if let next = snapshot.upcoming(at: entry.date).first {
                        Link(destination: WidgetRoute.url(destination: next.destination)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(next.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                Text(next.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }.foregroundStyle(.primary)
                    } else { empty("Nothing coming up.") }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(snapshot.steps.filter(\.completed).count)/\(snapshot.steps.count) steps", systemImage: "checklist")
                    Label("\(snapshot.chores.filter { !$0.completed }.count) chores left", systemImage: "checkmark.square")
                    Text(snapshot.dinner?.title ?? "Dinner not planned").lineLimit(2)
                }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            }
            if large {
                Divider()
                dinner(snapshot)
            }
            if large, let note = snapshot.selectedNote(id: nil) {
                Divider()
                Text(note.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            }
        }
    }

    private func calendar(_ snapshot: WidgetSnapshot) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone
        return calendar
    }
    private func localDate(_ value: String, snapshot: WidgetSnapshot) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar(snapshot).date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

private func widgetColor(_ hex: String?) -> Color {
    let value = UInt32((hex ?? "#5F8153").replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x5F8153
    return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
}

private extension WidgetSnapshot {
    static var preview: WidgetSnapshot {
        let now = Date.now
        return WidgetSnapshot(userId: "preview", householdId: "preview", householdName: "Our Family",
            timezone: TimeZone.current.identifier, localDate: localDate(now, timezone: .current), updatedAt: now,
            accentLight: "#57764C", accentDark: "#5F8153", enabledDestinations: Array(WidgetRoute.destinations),
            people: [.init(id: "child", name: "Alex", color: "#5F8153", isChild: true)],
            steps: [.init(id: "step", label: "Brush teeth", personId: "child", period: "morning", completed: false)],
            chores: [.init(id: "chore", title: "Water the plants", personId: nil, periodKey: "once", completed: false)],
            events: [.init(id: "event", title: "School pickup", start: now.addingTimeInterval(1800), end: now.addingTimeInterval(3600), allDay: false)],
            dinner: .init(title: "Pasta night"), sleeps: [],
            notes: [.init(id: "note", title: "Picture day tomorrow", body: "Set out a favorite outfit tonight.", pinned: true)],
            groceries: ["Apples", "Milk", "Bread"], groceryCount: 3,
            celebrations: [.init(id: "birthday", name: "Alex", date: localDate(now.addingTimeInterval(86400 * 3), timezone: .current), years: 5, isAnniversary: false)])
    }
}

#Preview("Routines", as: .systemSmall) {
    HouseholdRoutineWidget()
} timeline: {
    HouseholdWidgetEntry(date: .now, snapshot: .preview)
}


/// The look of a check-off row: an empty circle and the words, which turn into a filled check and struck-through
/// words when the system flips the toggle.
struct WidgetCheckoffToggleStyle: ToggleStyle {
    let title: String
    let detail: String?
    let small: Bool
    let large: Bool
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle").font(.title3)
                .foregroundStyle(configuration.isOn ? accent : Color.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: small ? 26 : 30, height: small ? 28 : 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(small ? .caption.weight(.semibold) : .subheadline.weight(.semibold)).lineLimit(large ? 2 : 1)
                    .strikethrough(configuration.isOn)
                    .foregroundStyle(configuration.isOn ? Color.secondary : Color.primary)
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
        }
    }
}
