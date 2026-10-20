import SwiftUI
import WidgetKit

// Lock Screen widgets: an inline line above the clock, small circles and wider rectangles in the row below it.
// They read the same saved snapshot the Home Screen widgets do and never call the server. They are single color
// (iOS tints them from the wallpaper), so they carry no accent choice, and a tap opens the matching page.

private struct LockProvider: TimelineProvider {
    func placeholder(in context: Context) -> HouseholdWidgetEntry { .init(date: .now, snapshot: .preview) }
    func getSnapshot(in context: Context, completion: @escaping (HouseholdWidgetEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(await HouseholdWidgetTimeline.entry()) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HouseholdWidgetEntry>) -> Void) {
        Task { completion(HouseholdWidgetTimeline.timeline(await HouseholdWidgetTimeline.entry())) }
    }
}

private let lockFamilies: [WidgetFamily] = [.accessoryInline, .accessoryCircular, .accessoryRectangular]

private enum LockKind: String {
    case today, sleep, evening, groceries
    var title: String {
        switch self {
        case .today: "Today at a Glance"
        case .sleep: "Sleep"
        case .evening: "Evening"
        case .groceries: "Groceries"
        }
    }
    var summary: String {
        switch self {
        case .today: "Chores left, routine progress and what's next."
        case .sleep: "Live nap and night timers, and how long everyone has been awake."
        case .evening: "Tonight's dinner and the next birthday."
        case .groceries: "How many groceries are left to buy."
        }
    }
    var destination: String {
        switch self {
        case .today: "dashboard"
        case .sleep: "sleep"
        case .evening: "meals"
        case .groceries: "groceries"
        }
    }
}

private func lockConfiguration(_ kind: LockKind) -> some WidgetConfiguration {
    StaticConfiguration(kind: "Tugboat.lock.\(kind.rawValue)", provider: LockProvider()) { entry in
        LockView(kind: kind, entry: entry)
    }
    .configurationDisplayName(kind.title)
    .description(kind.summary)
    .supportedFamilies(lockFamilies)
}

struct LockTodayWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.today) }
}
struct LockSleepWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.sleep) }
}
struct LockEveningWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.evening) }
}
struct LockGroceriesWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.groceries) }
}

/// One child's routine progress, chosen in Edit Widget.
struct LockRoutineWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Tugboat.lock.routine", intent: RoutineWidgetConfiguration.self, provider: RoutineWidgetProvider()) { entry in
            LockRoutineView(entry: entry)
        }
        .configurationDisplayName("Child's Routine")
        .description("A child's routine progress and their next step.")
        .supportedFamilies(lockFamilies)
    }
}

// MARK: - Shared pieces

private struct LockCalendar {
    let snapshot: WidgetSnapshot
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone
        return calendar
    }
    func date(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
    /// The next celebration on or after today, and how many days away it is.
    func nextCelebration(at now: Date) -> (WidgetSnapshot.Celebration, Int)? {
        let today = calendar.startOfDay(for: now)
        return snapshot.celebrations.compactMap { item -> (WidgetSnapshot.Celebration, Int)? in
            guard let day = date(item.date), day >= today else { return nil }
            return (item, calendar.dateComponents([.day], from: today, to: day).day ?? 0)
        }.min { $0.1 < $1.1 }
    }
}

private func routineCounts(_ snapshot: WidgetSnapshot, personId: String?, at date: Date) -> (done: Int, total: Int) {
    let steps = snapshot.routineSteps(personId: personId, at: date)
    return (steps.filter(\.completed).count, steps.count)
}

private func sleepingNow(_ snapshot: WidgetSnapshot) -> [WidgetSnapshot.Sleep] {
    snapshot.sleeps.filter { $0.end == nil }.sorted { $0.start < $1.start }
}

/// Children who are awake and since when (from their last sleep), longest awake first.
private func awakeChildren(_ snapshot: WidgetSnapshot) -> [(name: String, since: Date)] {
    let sleeping = Set(sleepingNow(snapshot).map(\.personId))
    return snapshot.people.filter { $0.isChild && !sleeping.contains($0.id) }.compactMap { person in
        guard let last = snapshot.sleeps.filter({ $0.personId == person.id }).compactMap(\.end).max() else { return nil }
        return (person.name, last)
    }.sorted { $0.since < $1.since }
}

private struct LockMessage: View {
    let text: String
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryInline: Text(text)
        case .accessoryCircular: Image(systemName: "tray").widgetAccentable()
        default: Text(text).font(.caption)
        }
    }
}

// MARK: - Today, Sleep, Evening, Groceries

private struct LockView: View {
    let kind: LockKind
    let entry: HouseholdWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.isCurrentDay(at: entry.date) || kind == .sleep {
                switch kind {
                case .today: today(snapshot)
                case .sleep: sleep(snapshot)
                case .evening: evening(snapshot)
                case .groceries: groceries(snapshot)
                }
            } else {
                LockMessage(text: entry.snapshot == nil ? "Open Tugboat" : "Refresh Tugboat")
            }
        }
        .privacySensitive()
        .widgetURL(WidgetRoute.url(destination: kind.destination))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    // Today: chores left, routine progress, what's next.
    @ViewBuilder private func today(_ snapshot: WidgetSnapshot) -> some View {
        let left = snapshot.chores.filter { !$0.completed }.count
        switch family {
        case .accessoryInline:
            Label(left == 0 ? "Chores done" : "\(left) chore\(left == 1 ? "" : "s") left", systemImage: "checkmark.square")
        case .accessoryCircular:
            let counts = routineCounts(snapshot, personId: nil, at: entry.date)
            Gauge(value: Double(counts.done), in: 0...Double(max(counts.total, 1))) {
                Image(systemName: "checklist")
            } currentValueLabel: {
                Text("\(counts.done)/\(counts.total)").font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        default:
            if let next = snapshot.upcoming(at: entry.date).first {
                VStack(alignment: .leading, spacing: 1) {
                    if let start = next.start {
                        (Text(next.detail == "Now" ? "Now · " : "Up next · ") + Text(start, style: .time)).font(.caption.weight(.semibold))
                    } else {
                        Text("Up next").font(.caption.weight(.semibold))
                    }
                    Text(next.title).font(.headline).lineLimit(1)
                    Text("\(left) chore\(left == 1 ? "" : "s") left").font(.caption).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nothing coming up").font(.headline).lineLimit(1)
                    Text("\(left) chore\(left == 1 ? "" : "s") left").font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // Sleep: timers for whoever is asleep, otherwise how long everyone has been awake.
    @ViewBuilder private func sleep(_ snapshot: WidgetSnapshot) -> some View {
        let sleeping = sleepingNow(snapshot)
        let awake = awakeChildren(snapshot)
        switch family {
        case .accessoryInline:
            if let first = sleeping.first {
                Label {
                    Text("\(snapshot.personName(first.personId)) asleep ") + Text(first.start, style: .timer)
                } icon: { Image(systemName: "moon.zzz") }
            } else if let longest = awake.first {
                Label {
                    Text("\(longest.name) awake ") + Text(longest.since, style: .relative)
                } icon: { Image(systemName: "sun.max") }
            } else {
                Label("Everyone's awake", systemImage: "sun.max")
            }
        case .accessoryCircular:
            if let first = sleeping.first {
                VStack(spacing: 1) {
                    Image(systemName: "moon.zzz.fill").font(.caption)
                    Text(first.start, style: .timer)
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.6).lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 4)
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "sun.max.fill").font(.caption)
                    if let longest = awake.first {
                        Text(longest.since, style: .timer)
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                            .minimumScaleFactor(0.6).lineLimit(1)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 4)
            }
        default:
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(sleeping.prefix(2)), id: \.id) { log in
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill").font(.caption2)
                        Text(snapshot.personName(log.personId)).font(.headline).lineLimit(1)
                        Spacer(minLength: 2)
                        Text(log.start, style: .timer).font(.subheadline.monospacedDigit()).lineLimit(1)
                    }
                }
                if sleeping.count < 2 {
                    ForEach(Array(awake.prefix(2 - sleeping.count).enumerated()), id: \.offset) { _, child in
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max").font(.caption2)
                            Text("\(child.name) awake").font(sleeping.isEmpty ? .headline : .caption).lineLimit(1)
                            Spacer(minLength: 2)
                            Text(child.since, style: .relative).font(.caption).lineLimit(1)
                        }
                    }
                    if sleeping.isEmpty && awake.isEmpty { Text("Everyone's awake").font(.headline) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Evening: tonight's dinner and the next birthday.
    @ViewBuilder private func evening(_ snapshot: WidgetSnapshot) -> some View {
        let next = LockCalendar(snapshot: snapshot).nextCelebration(at: entry.date)
        switch family {
        case .accessoryInline:
            Label(snapshot.dinner.map { "Dinner: \($0.title)" } ?? "Dinner isn't planned", systemImage: "fork.knife")
        case .accessoryCircular:
            if let next {
                VStack(spacing: 0) {
                    Image(systemName: "gift").font(.caption)
                    Text(next.1 == 0 ? "Today" : "\(next.1)").font(.system(size: 17, weight: .semibold, design: .rounded))
                    if next.1 != 0 { Text(next.1 == 1 ? "day" : "days").font(.system(size: 9)) }
                }
            } else {
                Image(systemName: "gift").widgetAccentable()
            }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("Tonight").font(.caption.weight(.semibold))
                Text(snapshot.dinner?.title ?? "Dinner isn't planned").font(.headline).lineLimit(1)
                if let next {
                    Text("\(next.0.name) · \(next.1 == 0 ? "today" : "\(next.1) day\(next.1 == 1 ? "" : "s")")")
                        .font(.caption).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Groceries: how many are left.
    @ViewBuilder private func groceries(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .accessoryInline:
            Label(snapshot.groceryCount == 0 ? "Groceries: all set" : "\(snapshot.groceryCount) to buy", systemImage: "basket")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "basket").font(.caption)
                Text("\(snapshot.groceryCount)").font(.system(size: 20, weight: .semibold, design: .rounded))
            }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.groceryCount == 0 ? "Groceries: all set" : "\(snapshot.groceryCount) to buy").font(.headline)
                ForEach(Array(snapshot.groceries.prefix(2).enumerated()), id: \.offset) { _, title in
                    Text(title).font(.caption).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - One child's routine

private struct LockRoutineView: View {
    let entry: HouseholdWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.isCurrentDay(at: entry.date) {
                if let id = entry.personId, !snapshot.people.contains(where: { $0.id == id && $0.isChild }) {
                    LockMessage(text: "Choose a child")
                } else {
                    content(snapshot)
                }
            } else {
                LockMessage(text: entry.snapshot == nil ? "Open Tugboat" : "Refresh Tugboat")
            }
        }
        .privacySensitive()
        .widgetURL(WidgetRoute.url(destination: "routines"))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    @ViewBuilder private func content(_ snapshot: WidgetSnapshot) -> some View {
        let counts = routineCounts(snapshot, personId: entry.personId, at: entry.date)
        let name = entry.personId.map { snapshot.personName($0) } ?? "Everyone"
        let next = snapshot.routineSteps(personId: entry.personId, at: entry.date).first { !$0.completed }
        switch family {
        case .accessoryInline:
            Label(counts.total == 0 ? "\(name): no routine today" : "\(name): \(counts.done) of \(counts.total) steps", systemImage: "checklist")
        case .accessoryCircular:
            Gauge(value: Double(counts.done), in: 0...Double(max(counts.total, 1))) {
                Image(systemName: "checklist")
            } currentValueLabel: {
                Text(String(name.prefix(1))).font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        default:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name).font(.headline).lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(counts.done) of \(counts.total)").font(.caption)
                }
                ProgressView(value: Double(counts.done), total: Double(max(counts.total, 1)))
                Text(next.map { "Next: \($0.label)" } ?? (counts.total == 0 ? "No routine today" : "All done")).font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
