import SwiftUI

/// What the header's weather readout opens: the rest of today's reading, and the Apple Weather mark
/// with its data sources link. Apple requires that attribution wherever WeatherKit data is shown,
/// and this is the one place the app shows more than the temperature.
struct WeatherDetailsPanel: View {
    let weather: NativeWeatherSnapshot
    let attribution: WeatherAttributionInfo?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summary
            details
            Divider()
            footer
        }
        .padding(18)
        .frame(width: 290, alignment: .leading)
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
        HStack {
            Text(title)
                .foregroundStyle(HubTheme.muted)
            Spacer(minLength: 16)
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

            if weather.isSample {
                Text("Sample reading. Weather appears here once WeatherKit is enabled.")
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
            } else if let attribution {
                HStack(alignment: .center) {
                    // The mark must be shown whole, so it is fitted rather than filled.
                    AsyncImage(url: colorScheme == .dark ? attribution.darkMarkURL : attribution.lightMarkURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text(attribution.serviceName)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(height: 14)
                    .accessibilityLabel(attribution.serviceName)

                    Spacer(minLength: 8)

                    Link("Other Data Sources", destination: attribution.legalPageURL)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.accentText)
                }
            }
        }
    }
}
