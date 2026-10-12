import SwiftUI
import UIKit

// Rearranging the Today cards on the page itself, the way icons are rearranged on a Home Screen:
// press and hold a card (or tap the pencil), the cards get a dashed outline, drag one to move it, tap its size
// button to make it Small, Medium or Large, tap the minus to take it off, and tap Done.
//
// The grid layouts in DashboardView report where each card sits to `DashboardFrameStore`, so a drag
// can tell which card the finger is over without every card measuring itself. The rules for what a
// move does are in `TodayLayoutEditing` (checked in ios/checks/today-editing).

/// Where each card sits in the grid, in the grid's own coordinates. The layouts write it every time
/// they place the cards; the drag reads it. It is a plain class, not published state, so a layout pass
/// doesn't ask the screen to redraw.
final class DashboardFrameStore {
    var frames: [DashboardCardId: CGRect] = [:]
}

/// The grid's own view, so a finger can be measured directly in the grid's space (never through window
/// coordinates, which are rotated differently from a view's own on a landscape iPad), and the scroll view
/// that holds it, so the page can scroll when a card is dragged to the top or bottom edge.
@MainActor
final class DashboardGridProbeReference {
    fileprivate(set) weak var view: UIView?

    var scrollView: UIScrollView? {
        var current = view?.superview
        while let candidate = current {
            if let scroll = candidate as? UIScrollView { return scroll }
            current = candidate.superview
        }
        return nil
    }
}

/// A view with no size placed behind the grid, so `DashboardGridProbeReference` has something in the
/// grid's space to measure from. It also owns the press-and-hold that starts editing (see `Coordinator`).
struct DashboardGridProbe: UIViewRepresentable {
    let reference: DashboardGridProbeReference
    /// Whether the page is being edited (the press-and-hold only starts editing when it is not) and what to
    /// do when the hold succeeds.
    var isEditing = false
    var onPressAndHold: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        context.coordinator.probe = view
        reference.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        reference.view = view
        context.coordinator.isEditing = isEditing
        context.coordinator.onPressAndHold = onPressAndHold
        // The scroll view may not have been above the probe yet when it joined the window.
        context.coordinator.attach()
    }

    /// Starts editing when a card is pressed and held. It is a UIKit recognizer on the page's scroll view,
    /// not a SwiftUI gesture on each card, so that when the hold succeeds the touch is **cancelled** for
    /// the card under the finger: with a SwiftUI long press running alongside the card's own buttons, lifting the
    /// finger afterwards still tapped the card, which opened its page just after editing started.
    /// Moving before the hold is over fails the recognizer, so the page still scrolls.
    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        fileprivate weak var probe: UIView?
        var isEditing = false
        var onPressAndHold: () -> Void = {}
        private weak var attachedTo: UIScrollView?
        private let recognizer = UILongPressGestureRecognizer()

        override init() {
            super.init()
            recognizer.addTarget(self, action: #selector(handle(_:)))
            recognizer.minimumPressDuration = 0.6
            recognizer.allowableMovement = 10
            recognizer.cancelsTouchesInView = true
            recognizer.delegate = self
        }

        /// Called when the probe joins a window, when the scroll view above it exists.
        fileprivate func attach() {
            guard let scroll = findScrollView(), scroll !== attachedTo else { return }
            attachedTo?.removeGestureRecognizer(recognizer)
            scroll.addGestureRecognizer(recognizer)
            attachedTo = scroll
        }

        fileprivate func detach() {
            attachedTo?.removeGestureRecognizer(recognizer)
            attachedTo = nil
        }

        private func findScrollView() -> UIScrollView? {
            var current = probe?.superview
            while let candidate = current {
                if let scroll = candidate as? UIScrollView { return scroll }
                current = candidate.superview
            }
            return nil
        }

        @objc private func handle(_ recognizer: UILongPressGestureRecognizer) {
            if recognizer.state == .began { onPressAndHold() }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard !isEditing, let probe else { return false }
            // Only a press on the grid of cards (not the greeting or the banner above it).
            return probe.bounds.contains(gestureRecognizer.location(in: probe))
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    final class ProbeView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { coordinator?.detach() } else { coordinator?.attach() }
        }
    }
}

/// Where the dragged card is drawn, in the grid's coordinates. It lives in its own small object, not in
/// `DashboardEditState`, because it changes on every movement of the finger: anything that watches
/// `DashboardEditState` (the whole dashboard) would be rebuilt dozens of times a second, which is what made
/// dragging feel slow. Only the cards' edit wrappers watch this one, and hand the position to the grid as a
/// layout value, so a movement re-places the cards without rebuilding any of them.
final class DashboardDragModel: ObservableObject {
    @Published var origin: CGPoint?
}

/// The grid layouts read this to draw a dragged card where the finger has it instead of in its cell.
struct DashboardDragOriginKey: LayoutValueKey {
    static let defaultValue: CGPoint? = nil
}

@MainActor
final class DashboardEditState: ObservableObject {
    @Published var isEditing = false
    /// The order the cards are shown in while one is being dragged. Nil when nothing is being dragged.
    @Published var previewOrder: [DashboardCardId]?
    @Published var draggingCard: DashboardCardId?

    let frames = DashboardFrameStore()
    let drag = DashboardDragModel()
    let probe = DashboardGridProbeReference()

    private var grabOffset = CGSize.zero
    /// Where the finger is in the grid's space, and how far the page had scrolled when it was there.
    private var fingerInGrid: CGPoint?
    private var offsetAtFinger: CGFloat = 0
    private var lastSwap = Date.distantPast
    private var autoscrollTimer: Timer?
    private var currentOrder: [DashboardCardId] = []

    func enter() {
        guard !isEditing else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.snappy(duration: 0.2)) { isEditing = true }
    }

    func exit() {
        cancelDrag()
        withAnimation(.snappy(duration: 0.2)) { isEditing = false }
    }

    /// Called for every movement of a finger that is dragging `card`. `order` is the order the cards
    /// are in when the drag starts.
    func dragChanged(_ card: DashboardCardId, locationInGrid point: CGPoint, order: [DashboardCardId]) {
        if draggingCard != card {
            draggingCard = card
            let frame = frames.frames[card] ?? CGRect(origin: point, size: .zero)
            grabOffset = CGSize(width: point.x - frame.minX, height: point.y - frame.minY)
            previewOrder = order
            currentOrder = order
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            autoscrollArmed = false
            zoneEnteredAt = nil
            zoneEdge = 0
            lastSwapPoint = nil
            startAutoscroll()
        }
        fingerInGrid = point
        offsetAtFinger = probe.scrollView?.contentOffset.y ?? 0
        drag.origin = CGPoint(x: point.x - grabOffset.width, y: point.y - grabOffset.height)
        swapIfOverAnotherCard(card, at: point)
    }

    /// The order the drag ended on, or nil if nothing was moved. The dragged card settles into its
    /// place; the caller saves the order and then calls `finishCommit`.
    func dragEnded() -> [DashboardCardId]? {
        guard draggingCard != nil else { return nil }
        stopAutoscroll()
        let final = previewOrder
        withAnimation(.snappy(duration: 0.2)) {
            draggingCard = nil
            drag.origin = nil
        }
        fingerInGrid = nil
        return final
    }

    func finishCommit() {
        previewOrder = nil
    }

    private func cancelDrag() {
        stopAutoscroll()
        draggingCard = nil
        drag.origin = nil
        previewOrder = nil
        fingerInGrid = nil
    }

    /// How far the finger must travel after a swap before another is allowed.
    private static let swapTravel: CGFloat = 30
    private var lastSwapPoint: CGPoint?

    private func swapIfOverAnotherCard(_ card: DashboardCardId, at point: CGPoint) {
        // After a swap the cards are still sliding into place; wait for them so a card that has
        // just moved under the finger doesn't swap straight back.
        guard Date().timeIntervalSince(lastSwap) > 0.22 else { return }
        // A finger inside the dragged card's own landing spot has nothing to swap with.
        if let own = frames.frames[card], own.contains(point) { return }
        // A swap reshuffles the layout, which can leave a finger that has not moved over a different
        // card, and that would swap again, and again: the other cards bounced back and forth under a
        // held card. So the next swap needs the finger to have moved on.
        if let last = lastSwapPoint, hypot(point.x - last.x, point.y - last.y) < Self.swapTravel { return }
        for (other, frame) in frames.frames where other != card {
            guard frame.insetBy(dx: 8, dy: 8).contains(point) else { continue }
            let next = TodayLayoutEditing.moving(card, ontoPositionOf: other, in: currentOrder)
            guard next != currentOrder else { return }
            lastSwap = Date()
            lastSwapPoint = point
            currentOrder = next
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.2)) { previewOrder = next }
            return
        }
    }

    // MARK: Scrolling while dragging

    private func startAutoscroll() {
        stopAutoscroll()
        autoscrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.autoscrollTick() }
        }
    }

    private func stopAutoscroll() {
        autoscrollTimer?.invalidate()
        autoscrollTimer = nil
    }

    /// How long a finger must rest in an edge zone before the page starts to scroll, and how far in from
    /// the edge the zone reaches. Edge scrolling that starts at once, in a wide zone, ran away on an iPad in
    /// landscape (a short page, so most cards sit inside the zone): picking a card up near the top or bottom
    /// sent the page flying in the opposite direction to the drag.
    private static let autoscrollDwell: TimeInterval = 0.35
    private static let autoscrollEdge: CGFloat = 56
    private static let autoscrollMaxStep: CGFloat = 9

    private var zoneEnteredAt: Date?
    private var zoneEdge = 0
    /// False until the finger has been clear of both edge zones once, so a card lifted from inside a zone
    /// does not scroll until it has been moved out and back in.
    private var autoscrollArmed = false

    private func autoscrollTick() {
        guard let card = draggingCard, let fingerAtLastMove = fingerInGrid,
              let scroll = probe.scrollView, let gridView = probe.view else { return }
        // The page may have scrolled since the finger last moved, so where the finger is in the grid has
        // changed by that much (it has not moved on the glass).
        let point = CGPoint(x: fingerAtLastMove.x, y: fingerAtLastMove.y + (scroll.contentOffset.y - offsetAtFinger))
        // Where it is within the visible part of the page, from its top edge.
        let viewportY = gridView.convert(point, to: scroll).y - scroll.contentOffset.y
        let height = scroll.bounds.height
        let edge = Self.autoscrollEdge
        let minY = -scroll.adjustedContentInset.top
        let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)

        var direction = 0
        var depth: CGFloat = 0
        if viewportY < edge {
            direction = -1
            depth = edge - viewportY
        } else if viewportY > height - edge {
            direction = 1
            depth = viewportY - (height - edge)
        }

        if direction == 0 {
            autoscrollArmed = true
            zoneEnteredAt = nil
        } else if zoneEdge != direction {
            zoneEdge = direction
            zoneEnteredAt = Date()
        } else if zoneEnteredAt == nil {
            zoneEnteredAt = Date()
        }

        // Only scroll when there is somewhere to scroll to, the finger has settled in the zone, and it got
        // there by being dragged (see `autoscrollArmed`).
        if direction != 0, autoscrollArmed, maxY > minY,
           let entered = zoneEnteredAt, Date().timeIntervalSince(entered) >= Self.autoscrollDwell {
            let step = min(Self.autoscrollMaxStep, depth / 10 + 1.5)
            let y = min(max(scroll.contentOffset.y + CGFloat(direction) * step, minY), maxY)
            if y != scroll.contentOffset.y {
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: y), animated: false)
            }
        }
        // The page moved under a finger that did not, so the card has to follow the finger again.
        let moved = CGPoint(x: fingerAtLastMove.x, y: fingerAtLastMove.y + (scroll.contentOffset.y - offsetAtFinger))
        drag.origin = CGPoint(x: moved.x - grabOffset.width, y: moved.y - grabOffset.height)
        swapIfOverAnotherCard(card, at: moved)
    }
}


/// A transparent view that turns a press-and-hold into a drag: `onChanged` is called with the finger's
/// position in the grid's own coordinates when the hold succeeds and on every movement after it, `onEnded`
/// when the finger lifts or the system cancels the touch.
struct DashboardDragSurface: UIViewRepresentable {
    let space: DashboardGridProbeReference
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let recognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        recognizer.minimumPressDuration = 0.35
        // A little movement while holding is fine; more than this means the person is scrolling.
        recognizer.allowableMovement = 8
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.space = space
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    final class Coordinator: NSObject {
        var space: DashboardGridProbeReference?
        var onChanged: (CGPoint) -> Void = { _ in }
        var onEnded: () -> Void = {}

        @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                // In the grid's own space; the card's own view is the fallback before the grid is on screen.
                let gridView = MainActor.assumeIsolated { space?.view }
                onChanged(recognizer.location(in: gridView ?? recognizer.view))
            case .ended, .cancelled, .failed:
                onEnded()
            default:
                break
            }
        }
    }
}


/// Passes the dragged card's position to the grid as a layout value. It is the only thing that watches
/// `DashboardDragModel`, and its body is tiny, so a movement of the finger costs almost nothing.
private struct DashboardDragOriginReporter: ViewModifier {
    @ObservedObject var drag: DashboardDragModel
    let isDragging: Bool

    func body(content: Content) -> some View {
        content.layoutValue(key: DashboardDragOriginKey.self, value: isDragging ? drag.origin : nil)
    }
}

extension DashboardCardSize {
    /// A small picture of the shape the size takes, for the resize menu.
    var menuSymbol: String {
        switch self {
        case .small: "square"
        case .medium: "rectangle"
        case .large: "square.grid.2x2"
        }
    }
}

// MARK: - Card chrome while editing

/// What a card gets while the page is being edited: a dashed outline, its own buttons stop working, a minus
/// takes it off, a size button changes its size, and a press-and-drag moves it.
private struct DashboardEditChrome: ViewModifier {
    let card: DashboardCardId
    let size: DashboardCardSize
    let cornerRadius: CGFloat
    let isDragging: Bool
    let dragSpace: DashboardGridProbeReference
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void
    let onSetSize: (DashboardCardSize) -> Void
    let onRemove: () -> Void
    let onMove: (Int) -> Void

    private var canResize: Bool { card.allowedSizes.count > 1 }

    private var outline: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                HubTheme.accentText.opacity(isDragging ? 0.9 : 0.35),
                style: StrokeStyle(lineWidth: isDragging ? 2 : 1.5, dash: isDragging ? [] : [6, 5])
            )
            .allowsHitTesting(false)
    }

    /// The surface that takes the touch. It is a UIKit long-press recognizer, not a SwiftUI gesture,
    /// because UIKit already knows how to share a touch with the scroll view: moving before the hold is
    /// over scrolls the page, holding still lifts the card.
    private var dragSurface: some View {
        DashboardDragSurface(space: dragSpace, onChanged: onDragChanged, onEnded: onDragEnded)
    }

    /// A menu of the sizes this card offers, the current one checked, so any size is two taps whichever
    /// size the card is now.
    @ViewBuilder
    private var resizeButton: some View {
        if canResize {
            Menu {
                Picker("Size", selection: Binding(get: { size }, set: { onSetSize($0) })) {
                    ForEach(card.allowedSizes) { option in
                        Label(option.label, systemImage: option.menuSymbol).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(size.label)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .heavy))
                        .accessibilityHidden(true)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.onAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HubTheme.accent, in: Capsule())
                .minimumTapTarget()
            }
            .padding(8)
            .accessibilityLabel("Resize \(card.label)")
            .accessibilityValue(size.label)
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "minus")
                .font(.caption.weight(.heavy))
                .foregroundStyle(HubTheme.onFill)
                .frame(width: 26, height: 26)
                .background(HubTheme.coral, in: Circle())
                .overlay(Circle().stroke(HubTheme.canvas, lineWidth: 2))
                .minimumTapTarget()
        }
        .buttonStyle(.plain)
        .offset(x: -8, y: -8)
        .accessibilityLabel("Remove \(card.label)")
    }

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(false)
            .overlay { outline }
            .overlay { dragSurface }
            .overlay(alignment: .bottomTrailing) { resizeButton }
            .overlay(alignment: .topLeading) { removeButton }
            .scaleEffect(isDragging ? 1.04 : 1)
            .shadow(color: .black.opacity(isDragging ? 0.28 : 0), radius: isDragging ? 14 : 0, y: isDragging ? 8 : 0)
            .animation(.snappy(duration: 0.15), value: isDragging)
            .zIndex(isDragging ? 10 : 0)
        .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(card.label) card")
            .accessibilityValue(size.label)
            .accessibilityHint("Press and hold, then drag to move it.")
            .accessibilityAction(named: Text("Move earlier")) { onMove(-1) }
            .accessibilityAction(named: Text("Move later")) { onMove(1) }
            .accessibilityActions {
                ForEach(card.allowedSizes.filter { $0 != size }) { option in
                    Button("Make \(option.label)") { onSetSize(option) }
                }
            }
            .accessibilityAction(named: Text("Remove from Today"), onRemove)
    }
}

extension View {
    /// Wraps a Today card in the edit-mode controls when `isEditing`. See `DashboardEditChrome`.
    @ViewBuilder
    func dashboardEditable(
        card: DashboardCardId,
        size: DashboardCardSize,
        cornerRadius: CGFloat,
        isEditing: Bool,
        isDragging: Bool,
        drag: DashboardDragModel,
        dragSpace: DashboardGridProbeReference,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping () -> Void,
        onSetSize: @escaping (DashboardCardSize) -> Void,
        onRemove: @escaping () -> Void,
        onMove: @escaping (Int) -> Void
    ) -> some View {
        if isEditing {
            modifier(DashboardEditChrome(
                card: card,
                size: size,
                cornerRadius: cornerRadius,
                isDragging: isDragging,
                dragSpace: dragSpace,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded,
                onSetSize: onSetSize,
                onRemove: onRemove,
                onMove: onMove
            ))
            .modifier(DashboardDragOriginReporter(drag: drag, isDragging: isDragging))
        } else {
            // Press-and-hold to start editing is the grid probe's (`DashboardGridProbe`).
            self
        }
    }
}

// MARK: - Buttons and the tray of removed cards

/// The pencil that starts editing, which becomes Done while editing.
struct DashboardEditButton: View {
    let isEditing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isEditing {
                Label("Done", systemImage: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(HubTheme.onAccent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(HubTheme.accent, in: Capsule())
            } else {
                Image(systemName: "pencil")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.accentText)
                    .frame(width: 48, height: 48)
                    .background(HubTheme.tile, in: Circle())
                    .overlay(Circle().stroke(HubTheme.line, lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .accessibilityLabel(isEditing ? "Done Editing Today" : "Edit Today")
        .accessibilityHint(isEditing ? "" : "Rearrange, resize, add or remove cards.")
    }
}

/// The cards that are turned off, as buttons that bring them back.
struct DashboardAddCardsTray: View {
    let cards: [DashboardCardId]
    let onAdd: (DashboardCardId) -> Void

    var body: some View {
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Cards")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HubTheme.muted)
                    .accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cards) { card in
                            Button { onAdd(card) } label: {
                                Label(card.label, systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(HubTheme.accentText)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .background(HubTheme.tile, in: Capsule())
                                    .overlay(Capsule().stroke(HubTheme.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(card.label)")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
