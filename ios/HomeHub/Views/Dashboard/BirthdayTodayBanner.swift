import SwiftUI

/// A celebratory banner for each birthday that falls today, with a short confetti burst the
/// first time it is seen that day.
struct BirthdayTodayBanners: View {
    let items: [BirthdayItem]
    let localDate: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showConfetti = false

    private var shown: [BirthdayItem] {
        Array(items.prefix(3))
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(shown) { item in
                BirthdayBanner(item: item)
            }
            if items.count > shown.count {
                Text("+\(items.count - shown.count) more today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
        .overlay(alignment: .top) {
            if showConfetti {
                ConfettiBurst()
                    .frame(height: 320)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onAppear(perform: celebrate)
        .onChange(of: items.map(\.id)) { _, _ in celebrate() }
    }

    /// Confetti plays once per person per day, and never when Reduce Motion is on.
    private func celebrate() {
        let fresh = items.filter { !BirthdayToday.hasCelebrated(id: $0.id, localDate: localDate) }
        guard !fresh.isEmpty else { return }
        for item in fresh {
            BirthdayToday.markCelebrated(id: item.id, localDate: localDate)
        }
        guard !reduceMotion else { return }
        showConfetti = true
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            showConfetti = false
        }
    }
}

private struct BirthdayBanner: View {
    let item: BirthdayItem

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    private var tint: Color {
        HubTheme.profileColor(item.color)
    }

    var body: some View {
        HStack(spacing: 14) {
            ProfileAvatarView(name: item.name, avatar: item.avatar, color: item.color, size: 54)
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 3))
                .shadow(color: tint.opacity(0.35), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(BirthdayToday.headline(name: item.name, kind: item.kind))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let age = BirthdayToday.ageLine(item.upcomingAge, kind: item.kind) {
                    Text(age)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "party.popper.fill")
                .font(.title)
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: bounce)
        }
        .padding(16)
        // The tile underneath keeps text readable in light and dark mode; the tint sits on top.
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.22), tint.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(HubTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.orange.opacity(0.55), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .onAppear {
            if !reduceMotion { bounce.toggle() }
        }
    }
}

/// A few seconds of falling confetti. Deterministic pieces, so it looks the same every time.
struct ConfettiBurst: View {
    var duration: TimeInterval = 3.5

    @State private var start = Date()

    private static let colors: [Color] = [.orange, .pink, .yellow, .mint, .blue, .purple, .red]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed < duration else { return }
                let fade = min(1, (duration - elapsed) / 0.8)

                for index in 0..<70 {
                    var random = SeededGenerator(seed: UInt64(index + 1) &* 2_654_435_761)
                    let startX = Double.random(in: 0...1, using: &random) * size.width
                    let delay = Double.random(in: 0...0.9, using: &random)
                    let speed = Double.random(in: 130...260, using: &random)
                    let sway = Double.random(in: 10...36, using: &random)
                    let phase = Double.random(in: 0...(2 * .pi), using: &random)
                    let spin = Double.random(in: -6...6, using: &random)
                    let pieceWidth = Double.random(in: 6...10, using: &random)
                    let color = Self.colors[Int.random(in: 0..<Self.colors.count, using: &random)]

                    let local = elapsed - delay
                    guard local > 0 else { continue }
                    let x = startX + sin(local * 3 + phase) * sway
                    let y = -12 + local * speed

                    var piece = context
                    piece.opacity = fade
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(local * spin))
                    piece.fill(
                        Path(CGRect(x: -pieceWidth / 2, y: -pieceWidth / 4, width: pieceWidth, height: pieceWidth / 2)),
                        with: .color(color)
                    )
                }
            }
        }
        .onAppear { start = Date() }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
