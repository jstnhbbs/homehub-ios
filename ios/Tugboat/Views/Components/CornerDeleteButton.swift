import SwiftUI

/// The delete button for an editor sheet: a red trash button in the bottom-right corner, well
/// away from Save so the two can't be tapped by mistake, that asks before it does anything.
/// It stays put behind the keyboard instead of riding up over the form.
private struct CornerDeleteButton: ViewModifier {
    let accessibilityLabel: String
    let confirmTitle: String
    let confirmButton: String
    let message: String?
    let isDisabled: Bool
    let insets: EdgeInsets
    let action: () async -> Void

    @State private var confirming = false

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            Button {
                confirming = true
            } label: {
                Image(systemName: "trash")
                    .frame(width: 20)
            }
            .buttonStyle(HubButtonStyle(emphasis: .danger))
            .accessibilityLabel(accessibilityLabel)
            .disabled(isDisabled)
            .padding(insets)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .confirmationDialog(confirmTitle, isPresented: $confirming, titleVisibility: .visible) {
                Button(confirmButton, role: .destructive) {
                    Task { await action() }
                }
            } message: {
                if let message {
                    Text(message)
                }
            }
        }
    }
}

extension View {
    /// Adds the corner trash button to an editor, when `isShown`. `insets` is the gap from the
    /// corner; a sheet with its own bottom bar can pass less so the button lines up with it.
    @ViewBuilder
    func cornerDeleteButton(
        isShown: Bool = true,
        accessibilityLabel: String,
        confirmTitle: String,
        confirmButton: String,
        message: String? = nil,
        isDisabled: Bool = false,
        insets: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        action: @escaping () async -> Void
    ) -> some View {
        if isShown {
            modifier(CornerDeleteButton(
                accessibilityLabel: accessibilityLabel,
                confirmTitle: confirmTitle,
                confirmButton: confirmButton,
                message: message,
                isDisabled: isDisabled,
                insets: insets,
                action: action
            ))
        } else {
            self
        }
    }
}
