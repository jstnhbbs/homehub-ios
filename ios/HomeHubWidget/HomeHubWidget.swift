import SwiftUI
import WidgetKit

struct HomeHubWidgetEntry: TimelineEntry {
    let date: Date
    let summary: HomeHubWidgetSummary?
}

struct HomeHubWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeHubWidgetEntry {
        HomeHubWidgetEntry(date: .now, summary: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeHubWidgetEntry) -> Void) {
        let summary = HomeHubWidgetStore.load() ?? .placeholder
        completion(HomeHubWidgetEntry(date: .now, summary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeHubWidgetEntry>) -> Void) {
        let entry = HomeHubWidgetEntry(date: .now, summary: HomeHubWidgetStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct HomeHubTodayWidget: Widget {
    let kind = "HomeHubTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HomeHubWidgetProvider()) { entry in
            HomeHubWidgetView(entry: entry)
                .containerBackground(HomeHubWidgetStyle.background, for: .widget)
        }
        .configurationDisplayName("Beacon Today")
        .description("See routines, chores, dinner, weather, and the next event.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct HomeHubWidgets: WidgetBundle {
    var body: some Widget {
        HomeHubTodayWidget()
    }
}

private struct HomeHubWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomeHubWidgetEntry

    var body: some View {
        if let summary = entry.summary {
            switch family {
            case .systemSmall:
                SmallTodaySummary(summary: summary)
            default:
                MediumTodaySummary(summary: summary)
            }
        } else {
            EmptyWidgetView()
        }
    }
}

private struct SmallTodaySummary: View {
    let summary: HomeHubWidgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(summary: summary, compact: true)

            VStack(alignment: .leading, spacing: 6) {
                MetricRow(icon: "checklist", label: "Routines", value: "\(summary.pendingRoutineCount)")
                MetricRow(icon: "checkmark.circle", label: "Chores", value: "\(summary.pendingChoreCount)")
            }

            Spacer(minLength: 0)

            if let dinner = summary.dinnerTitle {
                Label(dinner, systemImage: "fork.knife")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HomeHubWidgetStyle.ink)
                    .lineLimit(1)
            }
        }
        .padding()
    }
}

private struct MediumTodaySummary: View {
    let summary: HomeHubWidgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(summary: summary, compact: false)

            HStack(alignment: .top, spacing: 10) {
                CountTile(title: "Routines", count: summary.pendingRoutineCount, icon: "checklist")
                CountTile(title: "Chores", count: summary.pendingChoreCount, icon: "checkmark.circle")

                if let temperature = summary.weatherTemperature {
                    WeatherTile(temperature: temperature, condition: summary.weatherCondition)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                DetailPill(
                    icon: "calendar",
                    title: summary.nextEventTime ?? "Next",
                    detail: summary.nextEventTitle ?? "No more events"
                )

                DetailPill(
                    icon: "fork.knife",
                    title: "Dinner",
                    detail: summary.dinnerTitle ?? "Not planned"
                )
            }
        }
        .padding()
    }
}

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundStyle(HomeHubWidgetStyle.accent)

            Text("Open Beacon")
                .font(.headline)
                .foregroundStyle(HomeHubWidgetStyle.ink)

            Text("Your today summary will appear here after the app loads.")
                .font(.caption)
                .foregroundStyle(HomeHubWidgetStyle.muted)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

private struct WidgetHeader: View {
    let summary: HomeHubWidgetSummary
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(HomeHubWidgetStyle.accent)

                Text(initial)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(compact ? "Today" : summary.householdName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HomeHubWidgetStyle.accent)
                    .lineLimit(1)

                Text(summary.localDate)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(HomeHubWidgetStyle.muted)
                    .lineLimit(1)
            }
        }
    }

    private var initial: String {
        summary.householdName.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "H"
    }
}

private struct CountTile: View {
    let title: String
    let count: Int
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(HomeHubWidgetStyle.accent)

            Text("\(count)")
                .font(.title3.weight(.heavy))
                .foregroundStyle(HomeHubWidgetStyle.ink)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(HomeHubWidgetStyle.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WeatherTile: View {
    let temperature: Int
    let condition: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.88, green: 0.55, blue: 0.18))

            Text("\(temperature)°")
                .font(.title3.weight(.heavy))
                .foregroundStyle(HomeHubWidgetStyle.ink)

            Text(condition ?? "Weather")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(HomeHubWidgetStyle.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(HomeHubWidgetStyle.accent)
                .frame(width: 16)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(HomeHubWidgetStyle.ink)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(value)
                .font(.caption.weight(.heavy))
                .foregroundStyle(HomeHubWidgetStyle.ink)
        }
    }
}

private struct DetailPill: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(HomeHubWidgetStyle.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HomeHubWidgetStyle.accent)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HomeHubWidgetStyle.ink)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum HomeHubWidgetStyle {
    static let background = Color(red: 0.89, green: 0.94, blue: 0.91)
    static let accent = Color(red: 0.32, green: 0.52, blue: 0.45)
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.09)
    static let muted = Color(red: 0.48, green: 0.50, blue: 0.52)
}
