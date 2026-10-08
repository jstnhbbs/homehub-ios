import SwiftUI

/// Makes a control easy to hit without changing how it looks: the tap area grows to at least
/// `side` points each way (Apple's minimum is 44) and the layout stays exactly as it was. A
/// control that is already big enough is left alone. Put it on a button's label so the button's
/// own area includes it.
private struct MinimumTapTarget: ViewModifier {
    let side: CGFloat
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        let horizontal = max(0, (side - size.width) / 2)
        let vertical = max(0, (side - size.height) / 2)
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { size = proxy.size }
                        .onChange(of: proxy.size) { _, new in size = new }
                }
            )
            // Pad out, mark the whole padded area as touchable, then take the padding away again
            // so the neighbours do not move.
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .contentShape(Rectangle())
            .padding(.horizontal, -horizontal)
            .padding(.vertical, -vertical)
    }
}

extension View {
    /// See `MinimumTapTarget`. Use on small icon buttons.
    func minimumTapTarget(_ side: CGFloat = 44) -> some View {
        modifier(MinimumTapTarget(side: side))
    }

    /// VoiceOver for a view that is tapped with `onTapGesture`: it is announced as a button with a
    /// name, instead of as whatever text it happens to contain (or not at all).
    func accessibleButton(_ label: String, hint: String? = nil) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}
