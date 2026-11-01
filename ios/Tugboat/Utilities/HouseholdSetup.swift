import Foundation

/// The guided setup a person who has just created a household is offered. Foundation only, checked in
/// `ios/checks/household-setup`.
///
/// It is a checklist, not a tour: the four steps can be done in any order and each can be skipped. What was done
/// is remembered per household on this device (`HouseholdSetupStore`), and only someone who created the household
/// here ever has a state, so people who join one, and everyone who was already using the app, never see it.
enum HouseholdSetupStep: String, CaseIterable, Codable, Identifiable, Sendable {
    case family, routines, chores, food

    var id: String { rawValue }

    /// A title: Title Case.
    var title: String {
        switch self {
        case .family: "Add Your Family"
        case .routines: "Start a Routine"
        case .chores: "Add Some Chores"
        case .food: "Plan Dinner & Groceries"
        }
    }

    /// A sentence: sentence case.
    var detail: String {
        switch self {
        case .family: "Add the other adults and children so things can be given to someone."
        case .routines: "Pick a starter, like Morning or Bedtime, for each child."
        case .chores: "Choose a few common chores, or write your own."
        case .food: "Put tonight's dinner on the plan and the first things on the grocery list."
        }
    }

    var systemImage: String {
        switch self {
        case .family: "person.2.fill"
        case .routines: "checklist"
        case .chores: "checkmark.square.fill"
        case .food: "fork.knife"
        }
    }
}

/// What has been done so far for one household.
struct HouseholdSetupState: Codable, Equatable, Sendable {
    var completed: Set<HouseholdSetupStep> = []
    /// The person closed the "Finish Setting Up" card for good.
    var dismissed = false
    /// The full-screen setup has been shown once on its own. Later it is only opened from Today or Settings.
    var presented = false

    var doneCount: Int { completed.count }
    var totalCount: Int { HouseholdSetupStep.allCases.count }
    var isFinished: Bool { completed.count >= totalCount }

    /// "2 of 4 done"
    var progressText: String { "\(doneCount) of \(totalCount) done" }

    /// Whether Today shows its "Finish Setting Up" card.
    var showsCard: Bool { !dismissed && !isFinished }

    /// Whether setup should open by itself (once).
    var shouldPresentAutomatically: Bool { !presented && !dismissed && !isFinished }

    func isDone(_ step: HouseholdSetupStep) -> Bool { completed.contains(step) }

    /// The first step not done yet, for the card's button.
    var nextStep: HouseholdSetupStep? {
        HouseholdSetupStep.allCases.first { !completed.contains($0) }
    }

    mutating func complete(_ step: HouseholdSetupStep) {
        completed.insert(step)
    }
}

/// Remembers a household's setup on this device. An absent state means setup was never offered.
struct HouseholdSetupStore {
    var defaults: UserDefaults = .standard

    static func key(for householdId: String) -> String { "tugboat.setup.\(householdId)" }

    func load(householdId: String) -> HouseholdSetupState? {
        guard let data = defaults.data(forKey: Self.key(for: householdId)) else { return nil }
        return try? JSONDecoder().decode(HouseholdSetupState.self, from: data)
    }

    func save(_ state: HouseholdSetupState, householdId: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.key(for: householdId))
    }

    /// Called when this device creates a household. Does not overwrite a state that exists.
    func begin(householdId: String) {
        guard load(householdId: householdId) == nil else { return }
        save(HouseholdSetupState(), householdId: householdId)
    }
}

/// A routine that can be added with one tap. Its steps start with the emoji `RoutineGlyphs` knows, as steps
/// the family writes do.
struct RoutineStarter: Identifiable, Equatable, Sendable {
    let name: String
    /// The period as the API's raw value ("morning", "afternoon", "evening").
    let period: String
    let steps: [String]

    var id: String { name }
}

struct ChoreStarter: Identifiable, Equatable, Sendable {
    let title: String
    /// Repeats every day (true) or every week on `weekday` (false).
    let daily: Bool
    /// 0 = Sunday. Only used by a weekly chore.
    let weekday: Int

    var id: String { title }

    /// Shown under the title: "Every day" or "Every Saturday".
    var repeatText: String {
        if daily { return "Every day" }
        return "Every \(Self.weekdayNames[min(max(weekday, 0), 6)])"
    }

    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
}

enum HouseholdSetupStarters {
    static let routines: [RoutineStarter] = [
        RoutineStarter(name: "Morning", period: "morning", steps: ["👕 Get dressed", "🪥 Brush teeth", "🎒 Pack backpack"]),
        RoutineStarter(name: "After School", period: "afternoon", steps: ["🧼 Wash hands", "📚 Homework", "🧸 Clean up toys"]),
        RoutineStarter(name: "Bedtime", period: "evening", steps: ["🛁 Bath", "🪥 Brush teeth", "📚 Read a book"])
    ]

    static let chores: [ChoreStarter] = [
        ChoreStarter(title: "Feed the pet", daily: true, weekday: 0),
        ChoreStarter(title: "Make your bed", daily: true, weekday: 0),
        ChoreStarter(title: "Tidy up the living room", daily: true, weekday: 0),
        ChoreStarter(title: "Take out the trash", daily: false, weekday: 2),
        ChoreStarter(title: "Do the laundry", daily: false, weekday: 6),
        ChoreStarter(title: "Vacuum", daily: false, weekday: 6)
    ]

    static let dinners = ["Tacos", "Spaghetti", "Chicken and rice", "Pizza night"]

    static let groceries = ["Milk", "Eggs", "Bread", "Bananas", "Chicken", "Pasta"]
}

/// The pages the last step points to. Only their one-line descriptions live here.
enum HouseholdSetupTour {
    /// One line per page, by the module's raw value.
    static func blurb(forModule rawValue: String) -> String? {
        switch rawValue {
        case "calendar": "Your phone's calendars, next to the family's day."
        case "sleep": "Naps and nights, with a timer on the Lock Screen."
        case "snacks": "A checklist of snacks the kids can have today."
        case "notes": "A shared board for little reminders."
        case "birthdays": "Birthdays and anniversaries, with countdowns."
        case "recipes": "Your recipes, which can fill the meal plan and the grocery list."
        default: nil
        }
    }
}
