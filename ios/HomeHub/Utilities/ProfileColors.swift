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

    /// The color an entry gets when nobody has chosen one: picked from the name so it stays the
    /// same. This is `colorForBirthdayName` on the server, so a new entry starts out showing the
    /// color it would have been given.
    static func automatic(forName name: String) -> String {
        let sum = name.unicodeScalars.reduce(0) { total, scalar in
            total + Int(String(scalar).utf16.first ?? 0)
        }
        return options[sum % options.count].value
    }
}
