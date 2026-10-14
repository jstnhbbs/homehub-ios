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

struct RoutineWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Routines"
    static let description = IntentDescription("Choose a child, or show everyone's routines.")
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
}

/// Run in the app process so the extension never needs access to the sign-in Keychain.
struct HouseholdWidgetActionIntent: LiveActivityIntent {
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
        #if HOMEHUB_WIDGET_EXTENSION
        try requireAppExecution()
        #else
        try await WidgetActionRunner.perform(action: action, itemId: itemId, userId: userId,
                                            householdId: householdId, localDate: localDate)
        #endif
        return .result()
    }

    private func requireAppExecution() throws { throw WidgetActionFailure.openApp }
}

enum WidgetActionFailure: LocalizedError {
    case openApp, stale, failed
    var errorDescription: String? {
        switch self {
        case .openApp: "Open Tugboat and sign in to update this widget."
        case .stale: "This widget has changed. Refresh it before trying again."
        case .failed: "Couldn't update. Check your connection and try again."
        }
    }
}
