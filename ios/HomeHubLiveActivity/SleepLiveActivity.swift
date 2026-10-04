import ActivityKit
import SwiftUI
import WidgetKit

@main
struct HomeHubLiveActivities: WidgetBundle {
    var body: some Widget {
        SleepLiveActivityWidget()
    }
}

struct SleepLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SleepActivityAttributes.self) { context in
            SleepLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(hex: context.attributes.colorHex).opacity(0.22))
        } dynamicIsland: { context in
            let tint = Color(hex: context.attributes.colorHex)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SleepAvatar(name: context.attributes.childName, color: tint, size: 36)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(tint)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.childName)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Label(
                        "\(stateLabel(context.attributes.kind)) since \(context.state.startedAt.formatted(date: .omitted, time: .shortened))",
                        systemImage: icon(context.attributes.kind)
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: icon(context.attributes.kind))
                    .foregroundStyle(tint)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: icon(context.attributes.kind))
                    .foregroundStyle(tint)
            }
        }
    }
}

private struct SleepLockScreenView: View {
    let attributes: SleepActivityAttributes
    let state: SleepActivityAttributes.ContentState

    var body: some View {
        let tint = Color(hex: attributes.colorHex)
        HStack(spacing: 14) {
            SleepAvatar(name: attributes.childName, color: tint, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.childName)
                    .font(.headline)
                    .lineLimit(1)
                Label(stateLabel(attributes.kind), systemImage: icon(attributes.kind))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                // The system words this out ("25 minutes") while the lock screen is dimmed, so let it
                // shrink rather than wrap.
                Text(state.startedAt, style: .timer)
                    .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("since \(state.startedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct SleepAvatar: View {
    let name: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

private func stateLabel(_ kind: String) -> String {
    kind == "night" ? "In bed" : "Napping"
}

private func icon(_ kind: String) -> String {
    kind == "night" ? "bed.double.fill" : "moon.zzz.fill"
}

private extension Color {
    /// "#rrggbb" profile colors, with the app's sage as the fallback.
    init(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7, let value = Int(hex.dropFirst(), radix: 16) else {
            self = Color(red: 79 / 255, green: 124 / 255, blue: 109 / 255)
            return
        }
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
