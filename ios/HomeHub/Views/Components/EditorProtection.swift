import SwiftUI

struct EditorCancelButton: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: EditorSession

    var body: some View {
        Button("Cancel") {
            if session.requestDismissal() { dismiss() }
        }
        .disabled(session.isBusy)
    }
}

private struct EditorProtection: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: EditorSession

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(session.preventsInteractiveDismissal)
            .confirmationDialog("Discard Changes?", isPresented: $session.confirmDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) {
                    if !session.isBusy { dismiss() }
                }
            }
    }
}

extension View {
    func editorProtection(_ session: EditorSession) -> some View {
        modifier(EditorProtection(session: session))
    }
}
