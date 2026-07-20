import Foundation

struct ProfileColorOption: Identifiable, Sendable {
    let value: String
    let label: String
    var id: String { value }
}

enum ProfileColors {
    static let options: [ProfileColorOption] = [
        .init(value: "#d87861", label: "Coral"),
        .init(value: "#6689a3", label: "Blue"),
        .init(value: "#4f7c6d", label: "Sage"),
        .init(value: "#b07aa1", label: "Plum"),
        .init(value: "#d19b45", label: "Gold"),
        .init(value: "#5f8f8b", label: "Teal"),
        .init(value: "#8c7ca8", label: "Lavender"),
        .init(value: "#b86f4d", label: "Terracotta"),
        .init(value: "#7f8757", label: "Olive"),
    ]

    static func isProfileColor(_ value: String) -> Bool {
        options.contains { $0.value == value }
    }
}
