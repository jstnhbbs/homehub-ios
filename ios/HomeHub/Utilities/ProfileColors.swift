import Foundation

struct ProfileColorOption: Identifiable, Sendable {
    let value: String
    let label: String
    var id: String { value }
}

enum ProfileColors {
    /// The stored values are the original palette's hex colors (the server and the web settings
    /// still know them), shown in the app as the theme colors named here (`HubTheme.profileColor`).
    static let options: [ProfileColorOption] = [
        .init(value: "#d87861", label: "Raspberry"),
        .init(value: "#6689a3", label: "Azure"),
        .init(value: "#4f7c6d", label: "Emerald"),
        .init(value: "#b07aa1", label: "Blossom"),
        .init(value: "#d19b45", label: "Sunflower"),
        .init(value: "#5f8f8b", label: "Lagoon"),
        .init(value: "#8c7ca8", label: "Orchid"),
        .init(value: "#b86f4d", label: "Tangerine"),
        .init(value: "#7f8757", label: "Rosewood"),
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
