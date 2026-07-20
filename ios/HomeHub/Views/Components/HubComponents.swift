import SwiftUI
import UIKit

enum HubTheme {
    /// Brand accent — sage green in light mode, slightly brighter in dark for contrast.
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.44, green: 0.68, blue: 0.60, alpha: 1)
            : UIColor(red: 0.31, green: 0.49, blue: 0.43, alpha: 1)
    })

    static let sage = accent

    /// Selected nav rows, chips, etc. Light: soft sage tint. Dark: neutral grey fill.
    static let selectionBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.tertiarySystemFill
            : UIColor(red: 0.88, green: 0.93, blue: 0.90, alpha: 1)
    })

    static let sageSoft = selectionBackground

    /// Warm highlight panels (calendar day, guest badge). Dark: neutral grey, not green/cream.
    static let sunSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.secondarySystemGroupedBackground
            : UIColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1)
    })

    static let canvas = Color(.systemGroupedBackground)
    static let surface = Color(.systemBackground)
    static let tile = Color(.secondarySystemGroupedBackground)
    static let tileQuiet = Color(.tertiarySystemGroupedBackground)
    static let line = Color(.separator)
    static let muted = Color(.secondaryLabel)

    static func profileColor(_ hex: String?) -> Color {
        guard let hex, hex.hasPrefix("#"), hex.count == 7 else { return sage }
        let start = hex.index(hex.startIndex, offsetBy: 1)
        let r = Int(hex[start..<hex.index(start, offsetBy: 2)], radix: 16) ?? 79
        let g = Int(hex[hex.index(start, offsetBy: 2)..<hex.index(start, offsetBy: 4)], radix: 16) ?? 124
        let b = Int(hex[hex.index(start, offsetBy: 4)..<hex.index(start, offsetBy: 6)], radix: 16) ?? 109
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

struct HubCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(HubTheme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(HubTheme.line, lineWidth: 1)
            )
    }
}

struct CardTitleView: View {
    let systemImage: String
    let title: String
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(HubTheme.sage)
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(HubTheme.tileQuiet)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CheckItemView: View {
    let label: String
    var detail: String?
    var color: String?
    @Binding var isChecked: Bool
    var removeWhenChecked = false
    var onToggle: () async -> Void

    @State private var isHidden = false
    @State private var isWorking = false

    var body: some View {
        if !isHidden {
            Button {
                Task {
                    isWorking = true
                    await onToggle()
                    isChecked.toggle()
                    isWorking = false
                    if removeWhenChecked, isChecked {
                        withAnimation { isHidden = true }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isChecked ? HubTheme.sage : HubTheme.muted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let detail {
                            Text(detail)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(HubTheme.profileColor(color))
                        }
                    }
                    Spacer()
                    if isWorking {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(HubTheme.tileQuiet)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
    }
}

struct LiveClockView: View {
    let timezone: TimeZone
    @State private var now = Date.now

    private var timeText: String {
        DateHelpers.timeString(now, timezone: timezone)
    }

    var body: some View {
        Text(timeText)
            .font(.system(size: 34, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                    now = .now
                }
            }
    }
}

struct ProfileAvatarView: View {
    let name: String
    var avatar: String?
    var color: String = "#4f7c6d"
    var size: CGFloat = 44

    var body: some View {
        Group {
            if ProfilePhotoHelpers.hasPhoto(avatar), let avatar, let url = URL(string: avatar) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(HubTheme.profileColor(color))
    }
}

struct EmptyStateView: View {
    let text: String
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HubTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 96)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(HubTheme.line)
                )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
