import SwiftUI

/// One line of the ingredient or method list while it is being edited. A heading is a line the recipe stores
/// as "## Heading" (see `RecipeLines`); here it is a flag so the person never types the marker.
struct EditableRecipeLine: Identifiable, Equatable {
    let id: UUID
    var text: String
    var isHeading: Bool

    init(id: UUID = UUID(), text: String = "", isHeading: Bool = false) {
        self.id = id
        self.text = text
        self.isHeading = isHeading
    }

    static func lines(from stored: [String]) -> [EditableRecipeLine] {
        stored.compactMap { line in
            if RecipeLines.isHeading(line) {
                let text = RecipeLines.headingText(line)
                return text.isEmpty ? nil : EditableRecipeLine(text: text, isHeading: true)
            }
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : EditableRecipeLine(text: text)
        }
    }

    /// The lines as the recipe stores them: blanks dropped, one line each, headings marked.
    static func stored(_ lines: [EditableRecipeLine]) -> [String] {
        lines.compactMap { line in
            let flattened = line.text
                .split(whereSeparator: \.isNewline)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !flattened.isEmpty else { return nil }
            return line.isHeading ? RecipeLines.headingPrefix + flattened : flattened
        }
    }
}

/// An ingredient line with its amount in the accent color ("1 Tbsp" olive oil), the way the recipe page shows it.
func recipeIngredientText(_ line: String) -> Text {
    let parts = RecipeIngredientParts.split(line)
    guard !parts.amount.isEmpty else { return Text(line) }
    var amount = AttributedString(parts.amount)
    amount.foregroundColor = HubTheme.accentText
    var result = amount
    if !parts.rest.isEmpty { result += AttributedString(" " + parts.rest) }
    return Text(result)
}

/// The editable list for ingredients or the method: a delete button, the text, and a handle to drag the line to a
/// new place. Return moves on to the next line, adding one after the last.
struct RecipeLineListEditor: View {
    enum Kind {
        case ingredients, method

        var addLabel: String { self == .ingredients ? "Add Ingredient" : "Add Step" }
        var placeholder: String { self == .ingredients ? "1 cup flour" : "Describe the step" }
        var noun: String { self == .ingredients ? "ingredient" : "step" }
    }

    let kind: Kind
    @Binding var lines: [EditableRecipeLine]
    @FocusState private var focused: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !lines.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        if index > 0 { Divider().overlay(HubTheme.line) }
                        row(line, index: index)
                    }
                }
                .padding(.horizontal, 12)
                .background(HubTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 8) {
                Button {
                    append(EditableRecipeLine())
                } label: {
                    Label(kind.addLabel, systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))

                Menu {
                    Button { append(EditableRecipeLine(isHeading: true)) } label: {
                        Label("Add Heading", systemImage: "textformat")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(HubTheme.accentText)
                        .minimumTapTarget()
                }
                .accessibilityLabel("More Options")
            }
        }
    }

    private func row(_ line: EditableRecipeLine, index: Int) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                withAnimation(.snappy) { lines.removeAll { $0.id == line.id } }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .minimumTapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(line.isHeading ? "Heading" : kind.noun.capitalized)")

            field(line, index: index)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(HubTheme.muted)
                .minimumTapTarget()
                .contentShape(Rectangle())
                .draggable(line.id.uuidString) {
                    Text(line.text.isEmpty ? kind.noun.capitalized : line.text)
                        .lineLimit(2)
                        .padding(10)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(HubTheme.tile, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityHidden(true)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let moved = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            move(moved, before: line.id)
            return true
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Move Up") { shift(line.id, by: -1) }
        .accessibilityAction(named: "Move Down") { shift(line.id, by: 1) }
    }

    @ViewBuilder
    private func field(_ line: EditableRecipeLine, index: Int) -> some View {
        let binding = Binding(
            get: { lines.first { $0.id == line.id }?.text ?? "" },
            set: { newValue in
                if let i = lines.firstIndex(where: { $0.id == line.id }) { lines[i].text = newValue }
            }
        )
        // An ingredient shows its amount in color until it is being edited. The field stays in place under the
        // colored text (its own text clear), so tapping and the keyboard work as usual.
        let highlighted = kind == .ingredients && !line.isHeading && focused != line.id && !line.text.isEmpty
        ZStack(alignment: .topLeading) {
            TextField(line.isHeading ? "Heading" : kind.placeholder, text: binding, axis: .vertical)
                .accessibilityLabel(line.isHeading ? "Heading" : "\(kind.noun.capitalized) \(index + 1)")
                .font(line.isHeading ? .subheadline.weight(.heavy) : .body)
                .foregroundStyle(highlighted ? Color.clear : (line.isHeading ? HubTheme.accentText : Color.primary))
                .focused($focused, equals: line.id)
                .submitLabel(.next)
                .onSubmit { submitted(line.id) }
            if highlighted {
                recipeIngredientText(line.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private func append(_ line: EditableRecipeLine) {
        withAnimation(.snappy) { lines.append(line) }
        focus(line.id)
    }

    private func submitted(_ id: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        if index + 1 < lines.count {
            focus(lines[index + 1].id)
        } else if !lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            append(EditableRecipeLine())
        } else {
            focused = nil
        }
    }

    private func focus(_ id: UUID) {
        DispatchQueue.main.async { focused = id }
    }

    private func move(_ id: UUID, before target: UUID) {
        guard id != target,
              let from = lines.firstIndex(where: { $0.id == id }),
              let to = lines.firstIndex(where: { $0.id == target }) else { return }
        withAnimation(.snappy) {
            let item = lines.remove(at: from)
            lines.insert(item, at: to)
        }
    }

    private func shift(_ id: UUID, by offset: Int) {
        guard let from = lines.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard lines.indices.contains(to) else { return }
        withAnimation(.snappy) { lines.swapAt(from, to) }
    }
}
