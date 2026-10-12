import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

// The color an entry gets from its name must be the one the server gives it (colorForBirthdayName in
// src/lib/family-birthdays.ts), or a new entry would start out one color and change on first save.
// The expected values below came from running that function.
let fromServer: [(String, String)] = [
    ("Grandma Eve", "#6689a3"),
    ("Riley", "#d19b45"),
    ("Alex & Sam", "#4f7c6d"),
    ("", "#d87861"),
    ("José", "#4f7c6d"),
    ("Zoë", "#d19b45"),
    ("Mom & Dad", "#b86f4d"),
    ("😀 Party", "#d87861"),
    ("Aunt Jo", "#d19b45"),
]
for (name, expected) in fromServer {
    check("automatic color for \"\(name)\"", ProfileColors.automatic(forName: name), expected)
}

check("the palette has the nine colors the server allows", String(ProfileColors.options.count), "9")
check("the same name always gets the same color", ProfileColors.automatic(forName: "Riley"), ProfileColors.automatic(forName: "Riley"))

// MARK: a new profile's color

let palette = ProfileColors.options.map(\.value)
check("nobody has one: the first color", ProfileColors.firstUnused(taken: []), palette[0])
check("taken colors are skipped", ProfileColors.firstUnused(taken: [palette[0]]), palette[1])
check("a gap is filled", ProfileColors.firstUnused(taken: [palette[1], palette[2]]), palette[0])
check("case is ignored", ProfileColors.firstUnused(taken: [palette[0].uppercased()]), palette[1])
check("a color outside the palette changes nothing", ProfileColors.firstUnused(taken: ["#123456"]), palette[0])
check("all taken: the first", ProfileColors.firstUnused(taken: palette), palette[0])
check("all taken, one doubled: the next", ProfileColors.firstUnused(taken: palette + [palette[0]]), palette[1])
check("repeats are spread out", ProfileColors.firstUnused(taken: palette + Array(palette.prefix(8))), palette[8])

// MARK: the guest grey

// Must be the server's GUEST_PROFILE_COLOR (src/lib/profile-colors.ts).
check("the guest grey is the server's", ProfileColors.guestGrey.value, "#8e939b")
check("the picker offers the nine and then the grey", String(ProfileColors.choices.count), "10")
check("the grey is last in the picker", ProfileColors.choices.last?.value ?? "", ProfileColors.guestGrey.value)
check("the grey is not one of the nine", String(palette.contains(ProfileColors.guestGrey.value)), "false")
check("the grey is not handed to a new profile", ProfileColors.firstUnused(taken: palette), palette[0])
check("a taken grey changes nothing for a new profile", ProfileColors.firstUnused(taken: [ProfileColors.guestGrey.value]), palette[0])

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall profile color checks passed")
