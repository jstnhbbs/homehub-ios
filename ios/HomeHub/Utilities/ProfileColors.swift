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
        .init(value: "#4f7c6d", label: "Moss"),
        .init(value: "#b07aa1", label: "Blossom"),
        .init(value: "#d19b45", label: "Sunflower"),
        .init(value: "#5f8f8b", label: "Seafoam"),
        .init(value: "#8c7ca8", label: "Amethyst"),
        .init(value: "#b86f4d", label: "Tangerine"),
        .init(value: "#7f8757", label: "Rosewood"),
    ]

    /// The color a guest's profile starts with (the server gives it out, `GUEST_PROFILE_COLOR`): a quiet grey,
    /// shown as Slate, since a guest mostly looks and logs and shouldn't use up one of the family's colors.
    /// It is not in `options` on purpose: `automatic(forName:)` and `firstUnused` work by position in that
    /// list, so adding to it would change colors people already have.
    static let guestGrey = ProfileColorOption(value: "#8e939b", label: "Slate")

    /// What the color picker offers: the nine family colors, then the guest grey.
    static let choices: [ProfileColorOption] = options + [guestGrey]

    /// The color an entry gets when nobody has chosen one: picked from the name so it stays the
    /// same. This is `colorForBirthdayName` on the server, so a new entry starts out showing the
    /// color it would have been given.
    static func automatic(forName name: String) -> String {
        let sum = name.unicodeScalars.reduce(0) { total, scalar in
            total + Int(String(scalar).utf16.first ?? 0)
        }
        return options[sum % options.count].value
    }

    /// The color a new profile should start with: the first in the palette that nobody has, so two people added
    /// in a row don't come out the same. Once all nine are taken, the one used least (the first of those in
    /// palette order). The server applies the same rule to profiles it creates (`pickProfileColor`).
    static func firstUnused(taken: [String]) -> String {
        var counts: [String: Int] = [:]
        for color in taken { counts[color.lowercased(), default: 0] += 1 }
        var best = options[0].value
        var bestCount = Int.max
        for option in options {
            let count = counts[option.value.lowercased(), default: 0]
            if count == 0 { return option.value }
            if count < bestCount { best = option.value; bestCount = count }
        }
        return best
    }
}
