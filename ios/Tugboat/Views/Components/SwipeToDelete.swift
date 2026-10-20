import SwiftUI

/// One button revealed by swiping a row.
struct SwipeButton: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    var tint: Color = .red
    var foreground: Color = HubTheme.onFill
    /// Asked before the action runs, as in "Delete this sleep?"; nil runs it at once.
    var confirmation: Confirmation?
    let action: () -> Void

    struct Confirmation {
        let title: String
        var message: String = "This can't be undone."
        var confirmLabel: String = "Delete"
    }

    /// The same button with another label and icon ("Clear" for a meal rather than "Delete").
    func titled(_ title: String, systemImage: String) -> SwipeButton {
        var copy = SwipeButton(title: title, systemImage: systemImage, tint: tint, foreground: foreground, confirmation: confirmation, action: action)
        copy.confirmation = confirmation
        return copy
    }

    static func edit(_ action: @escaping () -> Void) -> SwipeButton {
        SwipeButton(title: "Edit", systemImage: "pencil", tint: HubTheme.accent, foreground: HubTheme.onAccent, action: action)
    }

    static func delete(confirmation: Confirmation? = nil, _ action: @escaping () -> Void) -> SwipeButton {
        SwipeButton(title: "Delete", systemImage: "trash.fill", confirmation: confirmation, action: action)
    }
}

/// Only one row is open at a time: opening another closes the one that was open.
final class SwipeCoordinator: ObservableObject {
    static let shared = SwipeCoordinator()
    @Published var openID: UUID?
}

/// Swipe a row to reveal rounded buttons, for rows in a card (a `VStack` row has no `.swipeActions`) and in lists
/// alike, so every swipe in the app looks and moves the same way.
///
/// The buttons keep their size and fade in (and grow a little) as the row slides, instead of being squeezed. A
/// swipe most of the way across the trailing side runs its last button (the delete), asking first when that
/// button has a confirmation. The drag is tracked alongside a scroll view's own, and only moves the row once it is
/// clearly horizontal, so scrolling the page past the row still works.
private struct RowSwipe: ViewModifier {
    let trailing: [SwipeButton]
    let leading: [SwipeButton]
    let onTap: (() -> Void)?
    let isEnabled: Bool
    let cornerRadius: CGFloat

    @State private var offset: CGFloat = 0
    @State private var settledOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var pending: SwipeButton?
    @State private var rowID = UUID()
    @ObservedObject private var coordinator = SwipeCoordinator.shared

    private let buttonWidth: CGFloat = 76
    private let gap: CGFloat = 8

    private func revealWidth(_ buttons: [SwipeButton]) -> CGFloat {
        guard !buttons.isEmpty else { return 0 }
        return gap + CGFloat(buttons.count) * buttonWidth + CGFloat(buttons.count - 1) * gap
    }
    private var trailingReveal: CGFloat { revealWidth(trailing) }
    private var leadingReveal: CGFloat { revealWidth(leading) }
    /// How far a row has to be dragged to stay open when let go. The same for every row: it used to be half of the
    /// buttons' width, so a row with one button opened on half the drag a row with two did and felt more sensitive.
    private let openDistance: CGFloat = 56
    /// How far across a swipe has to go to count as asking for the last button outright: well past the buttons, so a
    /// comfortable swipe to reach them never does it by accident.
    private var fullSwipe: CGFloat { max(trailingReveal * 1.6, 190) }

    @ViewBuilder func body(content: Content) -> some View {
        if !isEnabled || (trailing.isEmpty && leading.isEmpty) {
            content
        } else {
            swipeable(content)
        }
    }

    private func swipeable(_ content: Content) -> some View {
        ZStack {
            if offset < 0 { buttonsView(trailing, reveal: trailingReveal, shown: -offset, edge: .trailing) }
            if offset > 0 { buttonsView(leading, reveal: leadingReveal, shown: offset, edge: .leading) }
            content
                .contentShape(Rectangle())
                // The row's own tap lives here, not in a Button inside it: a Button still counts a drag that
                // ends inside it as a tap, so a swipe would also have opened the row. A tap gesture is
                // dropped once the finger has moved. While buttons are showing, a tap closes them.
                .onTapGesture {
                    if settledOffset != 0 { close() } else { onTap?() }
                }
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(drag)
        .onChange(of: coordinator.openID) { _, openID in
            if openID != rowID, settledOffset != 0 { close() }
        }
        .modifier(SwipeAccessibility(buttons: trailing + leading, run: run))
        .confirmationDialog(
            pending?.confirmation?.title ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            if let button = pending, let confirmation = button.confirmation {
                Button(confirmation.confirmLabel, role: .destructive) {
                    close()
                    button.action()
                }
            }
            Button("Cancel", role: .cancel) { close() }
        } message: {
            Text(pending?.confirmation?.message ?? "")
        }
    }

    private func buttonsView(_ buttons: [SwipeButton], reveal: CGFloat, shown: CGFloat, edge: Alignment) -> some View {
        HStack(spacing: gap) {
            ForEach(buttons) { button in
                Button { run(button) } label: {
                    VStack(spacing: 2) {
                        Image(systemName: button.systemImage).font(.body.weight(.semibold))
                        Text(button.title).font(.caption2.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(button.foreground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(button.tint, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
        .padding(edge == .trailing ? .leading : .trailing, gap)
        // The buttons keep their full size and are uncovered as the row slides, instead of being squeezed
        // narrower while it moves; they fade in and grow a little on the way.
        .frame(width: reveal)
        .opacity(min(1, Double(shown / (reveal * 0.6))))
        .scaleEffect(0.9 + 0.1 * min(1, shown / reveal), anchor: edge == .trailing ? .trailing : .leading)
        .frame(width: shown, alignment: edge == .trailing ? .trailing : .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge)
        .clipped()
    }

    private func run(_ button: SwipeButton) {
        if button.confirmation != nil {
            pending = button
        } else {
            close()
            button.action()
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
                let proposed = settledOffset + value.translation.width
                offset = min(leadingReveal * 1.4, max(-(fullSwipe + 30), proposed))
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                if !trailing.isEmpty, offset < -fullSwipe, let primary = trailing.last {
                    // A long swipe is a request for the last button (the delete): ask when it has to, with the buttons
                    // still showing, otherwise just do it.
                    if primary.confirmation != nil {
                        settle(at: -trailingReveal)
                        pending = primary
                    } else {
                        close()
                        primary.action()
                    }
                } else if offset < -openDistance, !trailing.isEmpty {
                    settle(at: -trailingReveal)
                } else if offset > openDistance, !leading.isEmpty {
                    settle(at: leadingReveal)
                } else {
                    close()
                }
            }
    }

    private func settle(at value: CGFloat) {
        withAnimation(.spring(duration: 0.25)) { offset = value }
        settledOffset = value
        if value != 0 {
            coordinator.openID = rowID
        } else if coordinator.openID == rowID {
            coordinator.openID = nil
        }
    }

    private func close() { settle(at: 0) }
}

/// VoiceOver gets each button as an action on the row.
private struct SwipeAccessibility: ViewModifier {
    let buttons: [SwipeButton]
    let run: (SwipeButton) -> Void

    func body(content: Content) -> some View {
        buttons.reduce(AnyView(content)) { view, button in
            AnyView(view.accessibilityAction(named: Text(button.title)) { run(button) })
        }
    }
}

extension View {
    /// Swipe a row to reveal buttons. `trailing` is shown by swiping left (the last one is the delete, which a long
    /// swipe runs), `leading` by swiping right. See `RowSwipe`.
    /// `onTap` is what tapping the row does; give it here rather than wrapping the row in a Button.
    func rowSwipe(
        trailing: [SwipeButton] = [],
        leading: [SwipeButton] = [],
        onTap: (() -> Void)? = nil,
        isEnabled: Bool = true,
        cornerRadius: CGFloat = 18
    ) -> some View {
        modifier(RowSwipe(trailing: trailing, leading: leading, onTap: onTap, isEnabled: isEnabled, cornerRadius: cornerRadius))
    }

    /// Swipe left to delete (and edit, when `onEdit` is given), with a confirmation before the delete.
    func swipeToDelete(
        title: String,
        message: String = "This can't be undone.",
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        isEnabled: Bool = true,
        cornerRadius: CGFloat = 18,
        onDelete: @escaping () -> Void
    ) -> some View {
        var buttons: [SwipeButton] = []
        if let onEdit { buttons.append(.edit(onEdit)) }
        buttons.append(.delete(confirmation: .init(title: title, message: message), onDelete))
        return rowSwipe(trailing: buttons, onTap: onTap, isEnabled: isEnabled, cornerRadius: cornerRadius)
    }
}
