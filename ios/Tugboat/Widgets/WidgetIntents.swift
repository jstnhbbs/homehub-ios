import AppIntents
import Foundation

struct WidgetChildEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Child"
    static let defaultQuery = WidgetChildQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct WidgetChildQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetChildEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [WidgetChildEntity] {
        (WidgetStore().load()?.people ?? []).filter(\.isChild).map { .init(id: $0.id, name: $0.name) }
    }
}

/// The color a widget draws its accents in: the app's theme color, or one of the ten by name. The
/// raw values are the saved theme ids (`AccentColorTable`), so the table gives the colors.
enum WidgetAccentChoice: String, AppEnum {
    case automatic, sage, ocean, clay, plum, slate, rosewood, teal, indigo, rose, ochre

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Accent Color"
    // Each color has a filled circle in `WidgetSwatches.xcassets`, so the menu shows what the name looks like.
    static let caseDisplayRepresentations: [WidgetAccentChoice: DisplayRepresentation] = [
        .automatic: DisplayRepresentation(title: "Same as App", image: .init(systemName: "circle.lefthalf.filled")),
        .sage: DisplayRepresentation(title: "Moss", image: .init(named: "WidgetAccentSage", isTemplate: false)),
        .ocean: DisplayRepresentation(title: "Azure", image: .init(named: "WidgetAccentOcean", isTemplate: false)),
        .clay: DisplayRepresentation(title: "Tangerine", image: .init(named: "WidgetAccentClay", isTemplate: false)),
        .plum: DisplayRepresentation(title: "Blossom", image: .init(named: "WidgetAccentPlum", isTemplate: false)),
        .slate: DisplayRepresentation(title: "Slate", image: .init(named: "WidgetAccentSlate", isTemplate: false)),
        .rosewood: DisplayRepresentation(title: "Rosewood", image: .init(named: "WidgetAccentRosewood", isTemplate: false)),
        .teal: DisplayRepresentation(title: "Seafoam", image: .init(named: "WidgetAccentTeal", isTemplate: false)),
        .indigo: DisplayRepresentation(title: "Amethyst", image: .init(named: "WidgetAccentIndigo", isTemplate: false)),
        .rose: DisplayRepresentation(title: "Raspberry", image: .init(named: "WidgetAccentRose", isTemplate: false)),
        .ochre: DisplayRepresentation(title: "Sunflower", image: .init(named: "WidgetAccentOchre", isTemplate: false)),
    ]

    /// The theme id this choice stands for; nil follows the app.
    var paletteId: String? { self == .automatic ? nil : rawValue }
}

/// The two appearance choices every widget offers in Edit Widget.
struct WidgetAppearanceConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Appearance"
    static let description = IntentDescription("Choose the widget's accent color and a true black background.")
    @Parameter(title: "Accent Color", default: .automatic) var accent: WidgetAccentChoice
    @Parameter(title: "True Black", description: "Use a black background in dark mode.", default: false) var trueBlack: Bool
}

struct RoutineWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Routines"
    static let description = IntentDescription("Choose a child, or show everyone's routines.")
    @Parameter(title: "Child") var child: WidgetChildEntity?
    @Parameter(title: "Accent Color", default: .automatic) var accent: WidgetAccentChoice
    @Parameter(title: "True Black", description: "Use a black background in dark mode.", default: false) var trueBlack: Bool
}

/// Lock Screen widgets use the system's appearance, so only the child is configurable.
struct LockChildConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Child"
    static let description = IntentDescription("Choose a child, or show everyone.")
    @Parameter(title: "Child") var child: WidgetChildEntity?
}

struct WidgetNoteEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    static let defaultQuery = WidgetNoteQuery()
    var id: String
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct WidgetNoteQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetNoteEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [WidgetNoteEntity] {
        (WidgetStore().load()?.notes ?? []).map { .init(id: $0.id, title: $0.title) }
    }
}

struct NoteWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Household Note"
    static let description = IntentDescription("Choose a note, or automatically show a pinned note.")
    @Parameter(title: "Note") var note: WidgetNoteEntity?
    @Parameter(title: "Accent Color", default: .automatic) var accent: WidgetAccentChoice
    @Parameter(title: "True Black", description: "Use a black background in dark mode.", default: false) var trueBlack: Bool
}

/// A check-off or End Sleep tapped in a widget. It runs in the widget's own process, which is what lets
/// the widget redraw the moment the tap finishes: an intent that runs in the app (a Live Activity
/// intent) made iOS wait about three seconds before redrawing the widget that was tapped. The
/// extension shows the change from the saved snapshot first and sends the write behind it
/// (`WidgetWriter`), using the sign-in it shares with the app through the Keychain.
struct HouseholdWidgetActionIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Household Widget"
    static let openAppWhenRun = false
    static let isDiscoverable = false
    @Parameter(title: "Action") var action: String
    @Parameter(title: "Item") var itemId: String
    @Parameter(title: "User") var userId: String
    @Parameter(title: "Household") var householdId: String
    @Parameter(title: "Day") var localDate: String

    init() {}
    init(action: String, itemId: String, snapshot: WidgetSnapshot) {
        self.action = action
        self.itemId = itemId
        self.userId = snapshot.userId
        self.householdId = snapshot.householdId
        self.localDate = snapshot.localDate
    }
    func perform() async throws -> some IntentResult {
        #if TUGBOAT_WIDGET_EXTENSION
        try await WidgetWriter.perform(action: action, itemId: itemId, userId: userId,
                                       householdId: householdId, localDate: localDate)
        #else
        try WidgetActionFailure.refuse()
        #endif
        return .result()
    }
}

/// The check circle of a chore or routine step. A `SetValueIntent` so the widget's toggle shows its checked look
/// the moment it is tapped; the action then holds for a moment (the row stays, checked) before it returns and
/// the redraw takes the row off the list.
struct HouseholdWidgetCheckIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Check Off"
    static let openAppWhenRun = false
    static let isDiscoverable = false
    @Parameter(title: "Done") var value: Bool
    @Parameter(title: "Action") var action: String
    @Parameter(title: "Item") var itemId: String
    @Parameter(title: "User") var userId: String
    @Parameter(title: "Household") var householdId: String
    @Parameter(title: "Day") var localDate: String

    init() {}
    init(action: String, itemId: String, snapshot: WidgetSnapshot) {
        self.value = true
        self.action = action
        self.itemId = itemId
        self.userId = snapshot.userId
        self.householdId = snapshot.householdId
        self.localDate = snapshot.localDate
    }
    func perform() async throws -> some IntentResult {
        #if TUGBOAT_WIDGET_EXTENSION
        try await WidgetWriter.perform(action: action, itemId: itemId, userId: userId,
                                       householdId: householdId, localDate: localDate, holdSeconds: 1.6)
        #else
        try WidgetActionFailure.refuse()
        #endif
        return .result()
    }
}

/// The refresh button. It rebuilds the whole snapshot (server data, calendar, reminders), which only the
/// app can do, so it runs in the app process.
struct HouseholdWidgetRefreshIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Refresh Household Widget"
    static let openAppWhenRun = false
    static let isDiscoverable = false
    @Parameter(title: "User") var userId: String
    @Parameter(title: "Household") var householdId: String
    @Parameter(title: "Day") var localDate: String

    init() {}
    init(snapshot: WidgetSnapshot) {
        self.userId = snapshot.userId
        self.householdId = snapshot.householdId
        self.localDate = snapshot.localDate
    }
    func perform() async throws -> some IntentResult {
        #if TUGBOAT_WIDGET_EXTENSION
        try WidgetActionFailure.refuse()
        #else
        try await WidgetActionRunner.perform(action: "refresh", itemId: "", userId: userId,
                                            householdId: householdId, localDate: localDate)
        #endif
        return .result()
    }
}

/// The End button on a nap's Live Activity. It runs in the app's process, which can end the activity itself, and
/// sends the write through the same waiting list as a widget tap (`NapEndRunner`).
struct EndNapActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Nap"
    static let openAppWhenRun = false
    static let isDiscoverable = false
    @Parameter(title: "Sleep") var sleepId: String

    init() {}
    init(sleepId: String) { self.sleepId = sleepId }
    func perform() async throws -> some IntentResult {
        #if TUGBOAT_WIDGET_EXTENSION
        try WidgetActionFailure.refuse()
        #else
        await NapEndRunner.perform(sleepId: sleepId)
        #endif
        return .result()
    }
}

enum WidgetActionFailure: LocalizedError {
    case openApp, stale, failed

    /// Where an intent must not run (the extension's copy of an app-only action, or the app's copy of a
    /// widget-only one) this is called instead of a bare `throw`, so the `return .result()` after the
    /// `#if` is not reported as unreachable.
    static func refuse() throws { throw WidgetActionFailure.openApp }

    var errorDescription: String? {
        switch self {
        case .openApp: "Open Tugboat and sign in to update this widget."
        case .stale: "This widget has changed. Refresh it before trying again."
        case .failed: "Couldn't update. Check your connection and try again."
        }
    }
}
