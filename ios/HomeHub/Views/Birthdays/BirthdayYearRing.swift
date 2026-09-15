import SwiftUI

struct BirthdayYearRing: View {
    let items: [BirthdayItem]
    let today: String
    let timezone: TimeZone
    var next: BirthdayItem?
    var size: CGFloat = 320

    private var marks: [BirthdayHelpers.RingMark] {
        BirthdayHelpers.ringMarks(items: items, today: today, size: size)
    }

    var body: some View {
        let year = Int(today.prefix(4)) ?? Calendar.current.component(.year, from: .now)
        let days = BirthdayHelpers.daysInYear(year)
        let todayAngle = BirthdayHelpers.angle(
            forDayOfYear: BirthdayHelpers.dayOfYear(localDate: today),
            daysInYear: days
        )
        let center = size / 2
        let ringRadius = size / 2 - 46
        let todayPoint = BirthdayHelpers.point(angleDegrees: todayAngle, radius: ringRadius, center: center)

        ZStack {
            Circle()
                .stroke(HubTheme.line, lineWidth: 10)
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            Canvas { context, _ in
                for month in 0..<12 {
                    let monthDate = String(format: "%04d-%02d-01", year, month + 1)
                    let angle = BirthdayHelpers.angle(
                        forDayOfYear: BirthdayHelpers.dayOfYear(localDate: monthDate),
                        daysInYear: days
                    )
                    let inner = BirthdayHelpers.point(angleDegrees: angle, radius: ringRadius - 8, center: center)
                    let outer = BirthdayHelpers.point(angleDegrees: angle, radius: ringRadius + 8, center: center)
                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    context.stroke(path, with: .color(HubTheme.muted.opacity(0.55)), lineWidth: 1.5)
                }
            }

            ForEach(0..<12, id: \.self) { month in
                let monthDate = String(format: "%04d-%02d-01", year, month + 1)
                let angle = BirthdayHelpers.angle(
                    forDayOfYear: BirthdayHelpers.dayOfYear(localDate: monthDate),
                    daysInYear: days
                )
                let point = BirthdayHelpers.point(angleDegrees: angle, radius: size / 2 - 12, center: center)
                Text(BirthdayHelpers.monthShortTitle(index: month, timezone: timezone))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .position(x: point.x, y: point.y)
            }

            Circle()
                .fill(HubTheme.sage)
                .frame(width: 8, height: 8)
                .position(todayPoint)

            ForEach(marks) { mark in
                ZStack {
                    if mark.isNext {
                        Circle()
                            .stroke(HubTheme.sage, lineWidth: 3)
                            .frame(width: 34, height: 34)
                    }
                    ProfileAvatarView(name: mark.name, avatar: mark.avatar, color: mark.color, size: 26)
                    if mark.extra > 0 {
                        Text("+\(mark.extra)")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(HubTheme.surface)
                            .clipShape(Capsule())
                            .offset(x: 10, y: 10)
                    }
                }
                .position(x: mark.x, y: mark.y)
                .accessibilityLabel(mark.extra > 0 ? "\(mark.name) and \(mark.extra) more" : mark.name)
            }

            VStack(spacing: 2) {
                if let next {
                    Text(next.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    if next.upcomingAge > 0 {
                        Text("turns \(next.upcomingAge)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                    Text(BirthdayHelpers.countdownLabel(daysUntil: next.daysUntil))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.sage)
                } else {
                    Text("\(items.count)")
                        .font(.title2.weight(.semibold))
                    Text("birthdays")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: size * 0.42)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Year of birthdays")
    }
}
