import SwiftUI
import WidgetKit

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

private struct LockChildProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HouseholdWidgetEntry { .init(date: .now, snapshot: .preview) }
    func snapshot(for configuration: LockChildConfiguration, in context: Context) async -> HouseholdWidgetEntry {
        if context.isPreview { return placeholder(in: context) }
        return await HouseholdWidgetTimeline.entry(personId: configuration.child?.id)
    }
    func timeline(for configuration: LockChildConfiguration, in context: Context) async -> Timeline<HouseholdWidgetEntry> {
        HouseholdWidgetTimeline.timeline(await HouseholdWidgetTimeline.entry(personId: configuration.child?.id))
    }
}

private let lockFamilies: [WidgetFamily] = [.accessoryInline, .accessoryCircular, .accessoryRectangular]

private func lockConfiguration(_ kind: LockWidgetKind) -> some WidgetConfiguration {
    StaticConfiguration(kind: "Tugboat.lock.\(kind.rawValue)", provider: LockProvider()) { entry in
        LockView(kind: kind, entry: entry)
    }
    .configurationDisplayName(kind.title)
    .description(description(for: kind))
    .supportedFamilies(lockFamilies)
}

private func description(for kind: LockWidgetKind) -> String {
    switch kind {
    case .today: "Your next event, timed chore, or routine."
    case .sleep: "A child's sleep timer or time awake."
    case .evening: "Tonight's dinner, with a link to its saved recipe."
    case .groceries: "How many groceries are left to buy."
    case .celebrations: "The next birthday or anniversary and days to go."
    case .chores: "Today's remaining chores and completion progress."
    }
}

struct LockTodayWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.today) }
}
struct LockEveningWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.evening) }
}
struct LockGroceriesWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.groceries) }
}
struct LockCelebrationsWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.celebrations) }
}
struct LockChoresWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.chores) }
}

struct LockSleepWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Tugboat.lock.sleep", intent: LockChildConfiguration.self, provider: LockChildProvider()) { entry in
            LockView(kind: .sleep, entry: entry)
        }
        .configurationDisplayName("Sleep")
        .description(description(for: .sleep))
        .supportedFamilies(lockFamilies)
    }
}

struct LockRoutineWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Tugboat.lock.routine", intent: LockChildConfiguration.self, provider: LockChildProvider()) { entry in
            LockRoutineView(entry: entry)
        }
        .configurationDisplayName("Child's Routine")
        .description("A child's routine progress and their next step.")
        .supportedFamilies(lockFamilies)
    }
}

private struct LockMessage: View {
    let text: String
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            switch family {
            case .accessoryInline: Text(text)
            case .accessoryCircular: Image(systemName: "tray").widgetAccentable()
            default: Text(text).font(.caption)
            }
        }
        .accessibilityLabel(text)
    }
}

private struct LockView: View {
    let kind: LockWidgetKind
    let entry: HouseholdWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if !kind.isEnabled(in: snapshot) {
                    LockMessage(text: "This section is turned off.")
                } else if kind.requiresCurrentDay && !snapshot.isCurrentDay(at: entry.date) {
                    LockMessage(text: "Refresh Tugboat")
                } else if kind == .sleep && !LockWidgetContent.validChild(entry.personId, in: snapshot) {
                    LockMessage(text: "Choose a child")
                } else {
                    switch kind {
                    case .today: comingUp(snapshot)
                    case .sleep: sleep(snapshot)
                    case .evening: dinner(snapshot)
                    case .groceries: groceries(snapshot)
                    case .celebrations: celebrations(snapshot)
                    case .chores: chores(snapshot)
                    }
                }
            } else {
                LockMessage(text: "Open Tugboat")
            }
        }
        .privacySensitive()
        .widgetURL(kind.url(in: entry.snapshot, at: entry.date))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    @ViewBuilder private func comingUp(_ snapshot: WidgetSnapshot) -> some View {
        if let next = snapshot.upcoming(at: entry.date).first {
            let status = LockWidgetContent.status(for: next)
            let symbol = next.destination == "calendar" ? "calendar" : (next.destination == "chores" ? "checkmark.square" : "checklist")
            switch family {
            case .accessoryInline:
                Label {
                    if let start = next.start {
                        Text("\(status): \(next.title) ") + Text(start, style: .time)
                    } else { Text("\(status): \(next.title)") }
                } icon: { Image(systemName: symbol) }
            case .accessoryCircular:
                VStack(spacing: 1) {
                    Image(systemName: symbol).font(.caption)
                    if status != "Coming Up" || next.start == nil {
                        Text(status == "Coming Up" ? "Next" : status).font(.caption2.weight(.semibold))
                    }
                    if let start = next.start {
                        Text(start, style: .time).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    } else {
                        Text(next.title).font(.caption2).lineLimit(1)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(status), \(next.title)\(next.start.map { ", " + $0.formatted(date: .omitted, time: .shortened) } ?? "")")
            default:
                VStack(alignment: .leading, spacing: 1) {
                    Text(status).font(.caption.weight(.semibold))
                    Text(next.title).font(.headline).lineLimit(1)
                    if let start = next.start { Text(start, style: .time).font(.caption) }
                    else { Text(next.detail).font(.caption).lineLimit(1) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            LockMessage(text: "Nothing coming up")
        }
    }

    @ViewBuilder private func chores(_ snapshot: WidgetSnapshot) -> some View {
        let total = snapshot.chores.count
        let done = snapshot.chores.filter(\.completed).count
        let left = total - done
        switch family {
        case .accessoryInline:
            Label(total == 0 ? "No chores today" : (left == 0 ? "Chores done" : "\(left) chore\(left == 1 ? "" : "s") left"), systemImage: "checkmark.square")
        case .accessoryCircular:
            if total == 0 { LockMessage(text: "No chores today") }
            else {
                Gauge(value: Double(done), in: 0...Double(total)) {
                    Image(systemName: "checkmark.square")
                } currentValueLabel: {
                    Text("\(left)").font(.headline)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .accessibilityLabel("Chores, \(left) remaining, \(done) of \(total) completed")
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(total == 0 ? "No chores today" : (left == 0 ? "Chores Done" : "\(left) Chore\(left == 1 ? "" : "s") Left")).font(.headline).lineLimit(1)
                if total > 0 {
                    ProgressView(value: Double(done), total: Double(total))
                    Text(snapshot.chores.first { !$0.completed }?.title ?? "All done").font(.caption).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func sleep(_ snapshot: WidgetSnapshot) -> some View {
        let sleeping = LockWidgetContent.sleeping(in: snapshot, childId: entry.personId)
        let awake = LockWidgetContent.awake(in: snapshot, childId: entry.personId, at: entry.date)
        let fallback = entry.personId.map { "\(snapshot.personName($0)) awake" } ?? "Everyone's awake"
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
            } else { Label(fallback, systemImage: "sun.max") }
        case .accessoryCircular:
            if let first = sleeping.first {
                sleepCircle(name: snapshot.personName(first.personId), since: first.start, asleep: true)
            } else if let longest = awake.first {
                sleepCircle(name: longest.name, since: longest.since, asleep: false)
            } else {
                Image(systemName: "sun.max.fill").accessibilityLabel(fallback)
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(sleeping.prefix(2)), id: \.id) { log in
                    sleepRow(name: snapshot.personName(log.personId), since: log.start, asleep: true)
                }
                ForEach(Array(awake.prefix(max(0, 2 - sleeping.count))), id: \.id) { child in
                    sleepRow(name: child.name, since: child.since, asleep: false)
                }
                if sleeping.isEmpty && awake.isEmpty { Text(fallback).font(.headline).lineLimit(2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sleepCircle(name: String, since: Date, asleep: Bool) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: asleep ? "moon.zzz.fill" : "sun.max.fill")
                Text(String(name.prefix(1)).uppercased())
            }
            .font(.caption.weight(.semibold))
            Text(since, style: .timer).font(.caption2.monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.7).multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(asleep ? "asleep" : "awake") since \(since.formatted(date: .omitted, time: .shortened))")
    }

    private func sleepRow(name: String, since: Date, asleep: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: asleep ? "moon.zzz.fill" : "sun.max").font(.caption2)
            Text(name).font(.caption.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 2)
            Text(since, style: .timer).font(.caption.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(asleep ? "asleep" : "awake") since \(since.formatted(date: .omitted, time: .shortened))")
    }

    @ViewBuilder private func dinner(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .accessoryInline:
            Label(snapshot.dinner.map { "Dinner: \($0.title)" } ?? "Dinner isn't planned", systemImage: "fork.knife")
        case .accessoryCircular:
            Image(systemName: "fork.knife").widgetAccentable()
                .accessibilityLabel(snapshot.dinner.map { "Dinner: \($0.title)" } ?? "Dinner isn't planned")
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("Tonight's Dinner").font(.caption.weight(.semibold))
                Text(snapshot.dinner?.title ?? "Dinner isn't planned").font(.headline).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func celebrations(_ snapshot: WidgetSnapshot) -> some View {
        if let next = LockWidgetContent.nextCelebration(in: snapshot, at: entry.date) {
            let countdown = next.days == 0 ? "Today" : (next.days == 1 ? "Tomorrow" : "\(next.days) days")
            let symbol = next.item.isAnniversary ? "heart" : "gift"
            switch family {
            case .accessoryInline:
                Label("\(next.item.name): \(countdown)", systemImage: symbol)
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: symbol).font(.caption)
                    Text(next.days == 0 ? "Today" : "\(next.days)").font(.headline)
                    if next.days > 0 { Text(next.days == 1 ? "day" : "days").font(.caption2) }
                }
                .accessibilityLabel("\(next.item.name), \(next.item.isAnniversary ? "anniversary" : "birthday"), \(countdown)")
            default:
                VStack(alignment: .leading, spacing: 1) {
                    Text(next.item.isAnniversary ? "Anniversary" : "Birthday").font(.caption.weight(.semibold))
                    Text(next.item.name).font(.headline).lineLimit(1)
                    Text(countdown).font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else { LockMessage(text: "No upcoming celebrations") }
    }

    @ViewBuilder private func groceries(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .accessoryInline:
            Label(snapshot.groceryCount == 0 ? "Groceries: all set" : "\(snapshot.groceryCount) to buy", systemImage: "basket")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "basket").font(.caption)
                Text("\(snapshot.groceryCount)").font(.title3.weight(.semibold))
            }
            .accessibilityLabel("Groceries, \(snapshot.groceryCount) left to buy")
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.groceryCount == 0 ? "Groceries: all set" : "\(snapshot.groceryCount) to buy").font(.headline).lineLimit(1)
                ForEach(Array(snapshot.groceries.prefix(2).enumerated()), id: \.offset) { _, title in
                    Text(title).font(.caption).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LockRoutineView: View {
    let entry: HouseholdWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if !snapshot.enabledDestinations.contains("routines") { LockMessage(text: "This section is turned off.") }
                else if !snapshot.isCurrentDay(at: entry.date) { LockMessage(text: "Refresh Tugboat") }
                else if !LockWidgetContent.validChild(entry.personId, in: snapshot) { LockMessage(text: "Choose a child") }
                else { content(snapshot) }
            } else { LockMessage(text: "Open Tugboat") }
        }
        .privacySensitive()
        .widgetURL(WidgetRoute.url(destination: "routines"))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    @ViewBuilder private func content(_ snapshot: WidgetSnapshot) -> some View {
        let steps = snapshot.routineSteps(personId: entry.personId, at: entry.date)
        let done = steps.filter(\.completed).count
        let name = entry.personId.map { snapshot.personName($0) } ?? "Everyone"
        let next = steps.first { !$0.completed }
        switch family {
        case .accessoryInline:
            Label(steps.isEmpty ? "\(name): no routine today" : "\(name): \(done) of \(steps.count) steps", systemImage: "checklist")
        case .accessoryCircular:
            if steps.isEmpty { LockMessage(text: "\(name): no routine today") }
            else {
                Gauge(value: Double(done), in: 0...Double(steps.count)) {
                    Image(systemName: "checklist")
                } currentValueLabel: {
                    Text(String(name.prefix(1)).uppercased()).font(.headline)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .accessibilityLabel("\(name), \(done) of \(steps.count) routine steps completed")
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name).font(.headline).lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(done) of \(steps.count)").font(.caption)
                }
                if !steps.isEmpty { ProgressView(value: Double(done), total: Double(steps.count)) }
                Text(next.map { "Next: \($0.label)" } ?? (steps.isEmpty ? "No routine today" : "All done")).font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Coming Up", as: .accessoryRectangular) {
    LockTodayWidget()
} timeline: {
    HouseholdWidgetEntry(date: .now, snapshot: .preview)
}

#Preview("Child's Routine", as: .accessoryCircular) {
    LockRoutineWidget()
} timeline: {
    HouseholdWidgetEntry(date: .now, snapshot: .preview, personId: "child")
}
