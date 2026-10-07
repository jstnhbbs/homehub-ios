import SwiftUI

/// One tappable circle per child for a single snack, filled in once that child has had it.
/// Wraps onto a second line for a large family rather than shrinking the tap targets.
struct SnackChildChips: View {
    static let chipSize: CGFloat = 32
    static let spacing: CGFloat = 6

    let snack: String
    let children: [Profile]
    let records: [SnackEatenRecord]
    /// Called with the child and the state wanted (true: they ate it), so the request can say so.
    let onToggle: (Profile, Bool) async -> Void

    @State private var working: Set<String> = []

    var body: some View {
        TagFlowLayout(spacing: Self.spacing) {
            ForEach(children) { child in
                chip(for: child)
            }
        }
    }

    /// One letter, or two when another child's name starts with the same letter.
    private func initials(for child: Profile) -> String {
        let first = child.name.prefix(1).uppercased()
        let clash = children.contains { $0.id != child.id && $0.name.prefix(1).uppercased() == first }
        return clash ? String(child.name.prefix(2)).capitalized : first
    }

    /// The child's photo, if they have one.
    private func photoURL(for child: Profile) -> URL? {
        guard ProfilePhotoHelpers.hasPhoto(child.avatar) else { return nil }
        return URL(string: child.avatar)
    }

    /// No photo: their color, with their initial until they have had it and a check after.
    private func initialChip(child: Profile, tint: Color, isEaten: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isEaten ? tint : tint.opacity(0.14))
            Circle()
                .stroke(tint, lineWidth: isEaten ? 0 : 1.5)
            if isEaten {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HubTheme.readableText(on: tint))
            } else {
                Text(initials(for: child))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(tint)
            }
        }
    }

    /// Their photo: faded with a thin ring until they have had it, then full color with a solid
    /// ring and a small check badge in their color.
    private func photoChip(url: URL, child: Profile, tint: Color, isEaten: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RemoteImage(url: url, maxPixelSize: Int(Self.chipSize * 3)) {
                initialChip(child: child, tint: tint, isEaten: false)
            }
            .frame(width: Self.chipSize, height: Self.chipSize)
            .clipShape(Circle())
            .opacity(isEaten ? 1 : 0.5)
            .saturation(isEaten ? 1 : 0.6)
            .overlay {
                Circle().strokeBorder(tint, lineWidth: isEaten ? 2.5 : 1.5)
            }
            if isEaten {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(HubTheme.readableText(on: tint))
                    .frame(width: 14, height: 14)
                    .background(tint, in: Circle())
                    .overlay { Circle().strokeBorder(HubTheme.tile, lineWidth: 1.5) }
                    .offset(x: 3, y: 3)
            }
        }
    }

    private func chip(for child: Profile) -> some View {
        let isEaten = SnackHelpers.isEaten(label: snack, profileId: child.id, in: records)
        let tint = HubTheme.profileColor(child.color)
        return Button {
            Task {
                guard !working.contains(child.id) else { return }
                working.insert(child.id)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                await onToggle(child, !isEaten)
                working.remove(child.id)
            }
        } label: {
            Group {
                if let photo = photoURL(for: child) {
                    photoChip(url: photo, child: child, tint: tint, isEaten: isEaten)
                } else {
                    initialChip(child: child, tint: tint, isEaten: isEaten)
                }
            }
            .frame(width: Self.chipSize, height: Self.chipSize)
            .opacity(working.contains(child.id) ? 0.6 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(child.name), \(snack)")
        .accessibilityValue(isEaten ? "Eaten" : "Not eaten")
        .accessibilityAddTraits(.isToggle)
    }
}
