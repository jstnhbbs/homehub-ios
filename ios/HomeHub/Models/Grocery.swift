import Foundation

struct GroceryItem: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String?
    var title: String
    var quantity: String?
    var category: String
    var checked: Bool
    var checkedAt: Date?
    var sortOrder: Int
    var createdAt: Date?
    var updatedAt: Date?
}

struct GroceryItemInput: Codable, Sendable {
    var title: String
    var category: String?
}

struct ToggleGroceryItemRequest: Codable, Sendable {
    var checked: Bool
}

enum NativeRemindersAccessStatus: String, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    var settingsLabel: String {
        switch self {
        case .authorized: "Full Access"
        case .notDetermined: "Not Enabled"
        case .denied, .restricted: "Off"
        }
    }
}

struct ReminderListOption: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var color: String
}
