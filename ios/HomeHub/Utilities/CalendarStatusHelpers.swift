import Foundation

enum CalendarStatusHelpers {
    static func syncStatus(
        connections: [CalendarConnection],
        timezone: TimeZone
    ) -> CalendarSyncStatus {
        guard !connections.isEmpty else {
            return CalendarSyncStatus(connected: false, updatedLabel: nil, lastSyncedAt: nil)
        }

        let latest = connections.compactMap(\.lastSyncedAt).max()
        let updatedLabel: String?
        if let latest {
            let formatter = DateFormatter()
            formatter.timeZone = timezone
            formatter.dateFormat = "h:mm a"
            updatedLabel = "Updated \(formatter.string(from: latest))"
        } else {
            updatedLabel = nil
        }

        return CalendarSyncStatus(
            connected: true,
            updatedLabel: updatedLabel,
            lastSyncedAt: latest
        )
    }
}
