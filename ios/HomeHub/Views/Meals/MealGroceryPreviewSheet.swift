import SwiftUI

struct MealGroceryPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: MealGroceryPreview
    let onAdd: ([String]) async -> Bool

    @State private var selected: Set<String>
    @State private var isAdding = false

    init(preview: MealGroceryPreview, onAdd: @escaping ([String]) async -> Bool) {
        self.preview = preview
        self.onAdd = onAdd
        _selected = State(initialValue: Set(preview.rows.filter(\.startsSelected).map(\.id)))
    }

    private var chosenTitles: [String] {
        preview.rows.filter { selected.contains($0.id) }.map(\.text)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(preview.rows) { row in
                        Toggle(isOn: binding(for: row)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.text)
                                    .font(.body.weight(.semibold))
                                Text(subtitle(for: row))
                                    .font(.caption)
                                    .foregroundStyle(HubTheme.muted)
                            }
                        }
                    }
                } header: {
                    Text(preview.heading)
                } footer: {
                    Text(footerText)
                }

                if !preview.mealsWithoutRecipe.isEmpty {
                    Section {
                        Text(preview.mealsWithoutRecipe.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(HubTheme.muted)
                    } header: {
                        Text("Not included (no saved recipe)")
                    }
                }
            }
            .navigationTitle("Add to Groceries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isAdding)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAdding ? "Adding" : "Add \(chosenTitles.count)") {
                        Task {
                            isAdding = true
                            let added = await onAdd(chosenTitles)
                            isAdding = false
                            if added { dismiss() }
                        }
                    }
                    .disabled(isAdding || chosenTitles.isEmpty)
                }
            }
        }
    }

    private func binding(for row: MealGroceryRow) -> Binding<Bool> {
        Binding(
            get: { selected.contains(row.id) },
            set: { isOn in
                if isOn {
                    selected.insert(row.id)
                } else {
                    selected.remove(row.id)
                }
            }
        )
    }

    private func subtitle(for row: MealGroceryRow) -> String {
        var parts = [row.sources.joined(separator: ", ")]
        if row.alreadyOnList {
            parts.append("already on your list")
        } else if row.isStaple {
            parts.append("usually on hand")
        }
        return parts.joined(separator: " · ")
    }

    private var footerText: String {
        let destination = preview.usesReminders ? "Apple Reminders" : "the household grocery list"
        return "Items go to \(destination). Amounts are added together only when the unit matches, so check quantities before shopping."
    }
}
