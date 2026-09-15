import Foundation

struct Routine: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var profileId: String?
    var name: String
    var period: RoutinePeriod
    var days: String
    var sortOrder: Int
    var createdAt: Date?
    var updatedAt: Date?
    var steps: [RoutineStep]?
}

struct RoutineStep: Codable, Identifiable, Sendable {
    let id: String
    let routineId: String
    var label: String
    var sortOrder: Int
}

struct RoutineCompletion: Codable, Sendable {
    let stepId: String
    let localDate: String
    var completedAt: Date
}

struct RoutineStepRow: Codable, Identifiable, Sendable {
    let id: String
    var label: String
    var routineName: String
    var period: RoutinePeriod
    var profileId: String?
    var completed: Bool
}

struct RoutineInput: Codable, Sendable {
    var name: String
    var period: RoutinePeriod
    var profileId: String?
    var days: String
    var steps: [String]
}

struct ToggleRoutineStepRequest: Codable, Sendable {
    var stepId: String
    var localDate: String
}

struct RoutineStepDisplay: Equatable, Sendable {
    var glyph: String
    var label: String
}

struct RoutineGlyphOption: Identifiable, Equatable, Sendable {
    var glyph: String
    var label: String
    var terms: [String]

    var id: String { glyph }
}

enum RoutineGlyphs {
    static let fallbackGlyph = "⭐"

    static let options: [RoutineGlyphOption] = [
        .init(glyph: "🪥", label: "Brush teeth", terms: ["brush", "teeth", "tooth"]),
        .init(glyph: "🚽", label: "Potty", terms: ["potty", "toilet", "bathroom", "pee"]),
        .init(glyph: "🧼", label: "Wash hands", terms: ["wash", "hands", "soap"]),
        .init(glyph: "🛁", label: "Bath", terms: ["bath", "shower"]),
        .init(glyph: "🍼", label: "Diaper", terms: ["diaper", "change", "wipe"]),
        .init(glyph: "👕", label: "Get dressed", terms: ["clothes", "shirt", "pajamas", "dressed"]),
        .init(glyph: "👟", label: "Shoes", terms: ["shoes", "socks"]),
        .init(glyph: "🎒", label: "Backpack", terms: ["backpack", "pack", "school bag"]),
        .init(glyph: "🍽️", label: "Meal", terms: ["eat", "breakfast", "dinner", "lunch"]),
        .init(glyph: "💧", label: "Water", terms: ["water", "drink"]),
        .init(glyph: "🐶", label: "Dog", terms: ["dog", "puppy"]),
        .init(glyph: "🥣", label: "Pet food", terms: ["food", "feed", "kibble"]),
        .init(glyph: "📚", label: "Read", terms: ["read", "book", "homework"]),
        .init(glyph: "🎵", label: "Sing", terms: ["sing", "song", "music", "lullaby"]),
        .init(glyph: "🙏", label: "Pray", terms: ["pray", "prayer", "blessing"]),
        .init(glyph: "🧸", label: "Clean up toys", terms: ["toy", "clean up", "pick up"]),
        .init(glyph: "🛏️", label: "Make bed", terms: ["bed", "sleep"]),
        .init(glyph: "💊", label: "Medicine", terms: ["medicine", "vitamin"]),
        .init(glyph: "🧴", label: "Lotion", terms: ["lotion", "sunscreen"]),
        .init(glyph: "🧦", label: "Laundry", terms: ["laundry", "hamper"]),
        .init(glyph: "🧹", label: "Sweep", terms: ["sweep", "vacuum"]),
        .init(glyph: "🗑️", label: "Trash", terms: ["trash", "garbage"]),
        .init(glyph: fallbackGlyph, label: "Other", terms: [])
    ]

    static func display(for label: String) -> RoutineStepDisplay {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return RoutineStepDisplay(glyph: fallbackGlyph, label: "")
        }

        if let first = trimmed.first, isEmojiGlyph(first) {
            let remaining = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            return RoutineStepDisplay(glyph: String(first), label: remaining.isEmpty ? trimmed : remaining)
        }

        let normalized = trimmed.lowercased()
        let match = options.first { option in
            option.terms.contains { normalized.contains($0) }
        }

        return RoutineStepDisplay(glyph: match?.glyph ?? fallbackGlyph, label: trimmed)
    }

    static func storageValue(glyph: String, label: String) -> String {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLabel.isEmpty else { return "" }

        let inferred = display(for: normalizedLabel)
        if glyph == inferred.glyph {
            return normalizedLabel
        }
        return "\(glyph) \(normalizedLabel)"
    }

    private static func isEmojiGlyph(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation ||
                (scalar.properties.isEmoji && scalar.value > 0x238C)
        }
    }
}
