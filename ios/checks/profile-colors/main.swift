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

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall profile color checks passed")
