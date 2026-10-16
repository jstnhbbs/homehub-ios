import Foundation
import Network

/// Calls `onReconnect` each time the phone goes from no usable connection to having one, while the app is
/// running. (The widget can't do this itself: it is only run when someone taps it or iOS refreshes it.)
final class WidgetNetworkWatcher: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "tugboat.widget.network")
    private var wasSatisfied: Bool?

    init(onReconnect: @escaping @Sendable () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            let reconnected = satisfied && self.wasSatisfied == false
            self.wasSatisfied = satisfied
            if reconnected { onReconnect() }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
