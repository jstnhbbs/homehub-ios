import SwiftUI

/// Swipe a row left to reveal a red Delete button (and an Edit button beside it when `onEdit` is given), for rows that sit in a card rather than in a `List` (a
/// `List` gets `.swipeActions` for free; a row in a `VStack` does not).
///
/// Deleting asks first, like the delete button in the editors does: tapping Delete, or swiping most of the way
/// across, opens a confirmation. The drag is tracked alongside a scroll view's own, and only moves the row once
/// it is clearly horizontal, so scrolling the page past the row still works.
private struct SwipeToDelete: ViewModifier {
    let title: String
    let message: String
    let onTap: (() -> Void)?
    let onEdit: (() -> Void)?
    let isEnabled: Bool
    let cornerRadius: CGFloat
    let onDelete: () -> Void

    /// One button's width; with an Edit button beside Delete the row opens twice as far.
    private var revealWidth: CGFloat { onEdit == nil ? 92 : 168 }
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var confirming = false

    @ViewBuilder func body(content: Content) -> some View {
        if !isEnabled {
            content
        } else {
            swipeable(content)
        }
    }

    private func swipeable(_ content: Content) -> some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                // Rounded buttons set apart from the row, like the system's own swipe actions.
                HStack(spacing: 8) {
                    if let onEdit {
                        Button { close(); onEdit() } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "pencil").font(.body.weight(.semibold))
                                Text("Edit").font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(HubTheme.onAccent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(HubTheme.accent, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHidden(true)
                    }
                    Button { confirming = true } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "trash.fill").font(.body.weight(.semibold))
                            Text("Delete").font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(HubTheme.onFill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
                }
                .padding(.leading, 8)
                // The buttons keep their full size and are uncovered as the row slides, instead of being squeezed
                // narrower while it moves.
                .frame(width: revealWidth)
                .frame(width: -offset, alignment: .trailing)
                .frame(maxHeight: .infinity)
                .clipped()
            }
            content
                .contentShape(Rectangle())
                // The row's own tap lives here, not in a Button inside it: a Button still counts a drag that
                // ends inside it as a tap, so a swipe would also have opened the row. A tap gesture is
                // dropped once the finger has moved. While the Delete button is showing, a tap closes it.
                .onTapGesture {
                    if settledOffset != 0 { close() } else { onTap?() }
                }
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(drag)
        .accessibilityAction(named: "Delete") { confirming = true }
        .accessibilityAction(named: "Edit") { onEdit?() }
        .confirmationDialog(title, isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                close()
                onDelete()
            }
            Button("Cancel", role: .cancel) { close() }
        } message: {
            Text(message)
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Leave a mostly vertical drag to the page's scrolling.
                if !isDragging {
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.6 else { return }
                    isDragging = true
                }
                offset = min(0, max(-(revealWidth * 2.4), settledOffset + value.translation.width))
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                let projected = settledOffset + value.predictedEndTranslation.width
                if offset < -revealWidth * 1.9 || projected < -revealWidth * 2.2 {
                    // A long swipe is a request to delete: ask, with the button still showing.
                    settle(at: -revealWidth)
                    confirming = true
                } else if offset < -revealWidth * 0.5 {
                    settle(at: -revealWidth)
                } else {
                    close()
                }
            }
    }

    /// Where the row rests between drags: closed (0) or showing the button.
    @State private var settledOffset: CGFloat = 0

    private func settle(at value: CGFloat) {
        withAnimation(.spring(duration: 0.25)) { offset = value }
        settledOffset = value
    }

    private func close() { settle(at: 0) }
}

extension View {
    /// Swipe left to delete, with a confirmation. See `SwipeToDelete`.
    /// `onTap` is what tapping the row does; give it here rather than wrapping the row in a Button.
    func swipeToDelete(
        title: String,
        message: String = "This can't be undone.",
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        isEnabled: Bool = true,
        cornerRadius: CGFloat = 18,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(SwipeToDelete(title: title, message: message, onTap: onTap, onEdit: onEdit, isEnabled: isEnabled, cornerRadius: cornerRadius, onDelete: onDelete))
    }
}
