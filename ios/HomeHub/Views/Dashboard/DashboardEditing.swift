import SwiftUI
import UIKit

// Rearranging the Today cards on the page itself, the way icons are rearranged on a Home Screen:
// press and hold a card (or tap the pencil), the cards wiggle, drag one to move it, tap its size
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

/// Lets the drag turn a finger position on the screen into a position in the grid, and find the
/// scroll view so it can scroll when a card is dragged to the top or bottom edge.
final class DashboardGridProbeReference {
    fileprivate(set) weak var view: UIView?

    /// The grid's top-left corner in window coordinates. Moves as the page scrolls.
    var windowOrigin: CGPoint {
        view?.convert(CGPoint.zero, to: nil) ?? .zero
    }

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
/// grid's space to measure from.
struct DashboardGridProbe: UIViewRepresentable {
    let reference: DashboardGridProbeReference

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        reference.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        reference.view = view
    }
}

@MainActor
final class DashboardEditState: ObservableObject {
    @Published var isEditing = false
    /// The order the cards are shown in while one is being dragged. Nil when nothing is being dragged.
    @Published var previewOrder: [DashboardCardId]?
    @Published var draggingCard: DashboardCardId?
    /// Where the dragged card's top-left corner is drawn, in the grid's coordinates.
    @Published var draggedOrigin: CGPoint?

    let frames = DashboardFrameStore()
    let probe = DashboardGridProbeReference()

    private var grabOffset = CGSize.zero
    private var fingerInWindow: CGPoint?
    private var lastSwap = Date.distantPast
    private var autoscrollTimer: Timer?
    private var currentOrder: [DashboardCardId] = []

    func enter() {
        guard !isEditing else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.snappy(duration: 0.25)) { isEditing = true }
    }

    func exit() {
        cancelDrag()
        withAnimation(.snappy(duration: 0.25)) { isEditing = false }
    }

    /// Called for every movement of a finger that is dragging `card`. `order` is the order the cards
    /// are in when the drag starts.
    func dragChanged(_ card: DashboardCardId, locationInWindow: CGPoint, order: [DashboardCardId]) {
        let origin = probe.windowOrigin
        let point = CGPoint(x: locationInWindow.x - origin.x, y: locationInWindow.y - origin.y)
        if draggingCard != card {
            draggingCard = card
            let frame = frames.frames[card] ?? CGRect(origin: point, size: .zero)
            grabOffset = CGSize(width: point.x - frame.minX, height: point.y - frame.minY)
            previewOrder = order
            currentOrder = order
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            startAutoscroll()
        }
        fingerInWindow = locationInWindow
        draggedOrigin = CGPoint(x: point.x - grabOffset.width, y: point.y - grabOffset.height)
        swapIfOverAnotherCard(card, at: point)
    }

    /// The order the drag ended on, or nil if nothing was moved. The dragged card settles into its
    /// place; the caller saves the order and then calls `finishCommit`.
    func dragEnded() -> [DashboardCardId]? {
        stopAutoscroll()
        let final = previewOrder
        withAnimation(.snappy(duration: 0.25)) {
            draggingCard = nil
            draggedOrigin = nil
        }
        fingerInWindow = nil
        return final
    }

    func finishCommit() {
        previewOrder = nil
    }

    private func cancelDrag() {
        stopAutoscroll()
        draggingCard = nil
        draggedOrigin = nil
        previewOrder = nil
        fingerInWindow = nil
    }

    private func swapIfOverAnotherCard(_ card: DashboardCardId, at point: CGPoint) {
        // After a swap the cards are still sliding into place; wait for them so a card that has
        // just moved under the finger doesn't swap straight back.
        guard Date().timeIntervalSince(lastSwap) > 0.3 else { return }
        for (other, frame) in frames.frames where other != card {
            guard frame.insetBy(dx: 8, dy: 8).contains(point) else { continue }
            let next = TodayLayoutEditing.moving(card, ontoPositionOf: other, in: currentOrder)
            guard next != currentOrder else { return }
            lastSwap = Date()
            currentOrder = next
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.28)) { previewOrder = next }
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

    private func autoscrollTick() {
        guard let card = draggingCard, let finger = fingerInWindow, let scroll = probe.scrollView else { return }
        let visible = scroll.convert(scroll.bounds, to: nil)
        let edge: CGFloat = 80
        var delta: CGFloat = 0
        if finger.y < visible.minY + edge {
            delta = -min(14, (visible.minY + edge - finger.y) / 6 + 2)
        } else if finger.y > visible.maxY - edge {
            delta = min(14, (finger.y - (visible.maxY - edge)) / 6 + 2)
        }
        if delta != 0 {
            let minY = -scroll.adjustedContentInset.top
            let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let y = min(max(scroll.contentOffset.y + delta, minY), maxY)
            if y != scroll.contentOffset.y {
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: y), animated: false)
            }
        }
        // The page moved under a finger that did not, so the card has to follow the finger again.
        let origin = probe.windowOrigin
        let point = CGPoint(x: finger.x - origin.x, y: finger.y - origin.y)
        draggedOrigin = CGPoint(x: point.x - grabOffset.width, y: point.y - grabOffset.height)
        swapIfOverAnotherCard(card, at: point)
    }
}

// MARK: - Card chrome while editing

/// What a card gets while the page is being edited: it wiggles, its own buttons stop working, a minus
/// takes it off, a size button changes its size, and a press-and-drag moves it.
private struct DashboardEditChrome: ViewModifier {
    let card: DashboardCardId
    let size: DashboardCardSize
    let cornerRadius: CGFloat
    let wiggleSeed: Int
    let isDragging: Bool
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void
    let onResize: () -> Void
    let onRemove: () -> Void
    let onMove: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggle = false

    private var canResize: Bool { card.allowedSizes.count > 1 }

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(false)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(HubTheme.accentText.opacity(isDragging ? 0.9 : 0.35), style: StrokeStyle(lineWidth: isDragging ? 2 : 1.5, dash: isDragging ? [] : [6, 5]))
                    .allowsHitTesting(false)
            }
            .overlay {
                // The surface that takes the touch: press and hold briefly, then drag. A plain drag
                // still scrolls the page.
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .gesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                            .onChanged { value in
                                if case .second(true, let drag?) = value {
                                    onDragChanged(drag.location)
                                }
                            }
                            .onEnded { _ in onDragEnded() }
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                if canResize {
                    Button(action: onResize) {
                        HStack(spacing: 5) {
                            Text(size.label)
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .accessibilityHidden(true)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(HubTheme.accent, in: Capsule())
                        .minimumTapTarget()
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("Resize \(card.label)")
                    .accessibilityValue(size.label)
                }
            }
            .overlay(alignment: .topLeading) {
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
            .rotationEffect(.degrees(isDragging || reduceMotion ? 0 : (wiggle ? 1.0 : -1.0)))
            .scaleEffect(isDragging ? 1.04 : 1)
            .shadow(color: .black.opacity(isDragging ? 0.28 : 0), radius: isDragging ? 14 : 0, y: isDragging ? 8 : 0)
            .zIndex(isDragging ? 10 : 0)
            .animation(.snappy(duration: 0.2), value: isDragging)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.13 + Double(wiggleSeed % 4) * 0.012).repeatForever(autoreverses: true), value: wiggle)
            .onAppear {
                // Cards start at opposite ends of the wiggle so they never move in step.
                wiggle = wiggleSeed.isMultiple(of: 2)
                DispatchQueue.main.async { wiggle.toggle() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(card.label) card")
            .accessibilityValue(size.label)
            .accessibilityHint("Press and hold, then drag to move it.")
            .accessibilityAction(named: Text("Move earlier")) { onMove(-1) }
            .accessibilityAction(named: Text("Move later")) { onMove(1) }
            .accessibilityAction(named: Text("Change size")) { if canResize { onResize() } }
            .accessibilityAction(named: Text("Remove from Today"), onRemove)
    }
}

extension View {
    /// Wraps a Today card in the wiggle-mode controls when `isEditing`, and otherwise lets a long press
    /// start editing. See `DashboardEditChrome`.
    @ViewBuilder
    func dashboardEditable(
        card: DashboardCardId,
        size: DashboardCardSize,
        cornerRadius: CGFloat,
        wiggleSeed: Int,
        isEditing: Bool,
        isDragging: Bool,
        onBeginEditing: @escaping () -> Void,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping () -> Void,
        onResize: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onMove: @escaping (Int) -> Void
    ) -> some View {
        if isEditing {
            modifier(DashboardEditChrome(
                card: card,
                size: size,
                cornerRadius: cornerRadius,
                wiggleSeed: wiggleSeed,
                isDragging: isDragging,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded,
                onResize: onResize,
                onRemove: onRemove,
                onMove: onMove
            ))
        } else {
            simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6).onEnded { _ in onBeginEditing() }
            )
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
