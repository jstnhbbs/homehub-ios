import SwiftUI

/// What the header's weather readout opens: the rest of today's reading, and the Apple Weather mark
/// with its data sources link. Apple requires that attribution wherever WeatherKit data is shown,
/// and this is the one place the app shows more than the temperature.
struct WeatherDetailsPanel: View {
    let weather: NativeWeatherSnapshot
    let attribution: WeatherAttributionInfo?
    var refreshError: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summary
                details
                Divider()
                footer
            }
            .padding(18)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 290, alignment: .leading)
        .frame(idealHeight: dynamicTypeSize.isAccessibilitySize ? 500 : 420, maxHeight: 500)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Image(systemName: weather.symbolName)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(HubTheme.accentText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(weather.temperature)°")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(weather.condition)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(spacing: 8) {
            if let high = weather.high, let low = weather.low {
                row("High & Low", "\(high)° / \(low)°")
            }
            row("Feels Like", "\(weather.feelsLike)°")
            if let chance = weather.precipitationChance {
                row("Chance of Rain", "\(chance)%")
            }
            if let humidity = weather.humidity {
                row("Humidity", "\(humidity)%")
            }
            if let wind = weather.windSpeed {
                row("Wind", "\(wind) mph")
            }
            if let uv = weather.uvIndex {
                row("UV Index", "\(uv)")
            }
        }
        .font(.subheadline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout())
        return layout {
            Text(title)
                .foregroundStyle(HubTheme.muted)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 16) }
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Updated \(weather.updatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(HubTheme.muted)

            if let refreshError {
                Text("Showing the last reading. \(refreshError)")
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
            }

            if weather.isSample {
                Text("Sample reading. Weather appears here once WeatherKit is enabled.")
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
            } else if let attribution {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .center))
                layout {
                    // The mark must be shown whole, so it is fitted rather than filled.
                    AsyncImage(url: colorScheme == .dark ? attribution.darkMarkURL : attribution.lightMarkURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit().frame(height: 14)
                        } else {
                            Text(attribution.serviceName)
                                .font(.caption.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityLabel(attribution.serviceName)

                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }

                    Link("Other Data Sources", destination: attribution.legalPageURL)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.accentText)
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
        }
    }
}
