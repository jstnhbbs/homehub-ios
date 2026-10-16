import Foundation

extension Notification.Name {
    /// The widget finished a write (see `WidgetWriteSignal`). Posted on the main queue.
    static let tugboatWidgetWrote = Notification.Name("tugboat.widgetWrote")
}

/// Turns the widget's system-wide "I wrote something" notification into an ordinary one, while the app is
/// running. (An app that is suspended hears nothing and checks `WidgetWriteSignal.lastWriteAt` when it
/// comes to the front instead.)
final class WidgetWriteObserver {
    init() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
            { _, _, _, _, _ in
                DispatchQueue.main.async { NotificationCenter.default.post(name: .tugboatWidgetWrote, object: nil) }
            },
            WidgetWriteSignal.darwinName as CFString, nil, .deliverImmediately)
    }

    deinit {
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                           Unmanaged.passUnretained(self).toOpaque(), nil, nil)
    }
}
