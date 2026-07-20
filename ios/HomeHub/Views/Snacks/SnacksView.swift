import SwiftUI

struct SnacksView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SnacksViewModel()

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if let success = viewModel.successMessage {
                        Text(success).font(.footnote).foregroundStyle(HubTheme.sage)
                    }
                    checklistSection
                }
            }
            .frame(maxWidth: .infinity)

            if viewModel.canManage {
                optionsPanel
                    .frame(width: 330)
            }
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Grab and go")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(HubTheme.sage)
                Text("Today's snacks")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                if !viewModel.dateLabel.isEmpty {
                    Text(viewModel.dateLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
            }
            Spacer()
            if !viewModel.snackOptions.isEmpty {
                Button {
                    Task { await viewModel.resetChecklist() }
                } label: {
                    Label("Reset checklist", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isWorking)
            }
        }
    }

    private var checklistSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Snack checklist", systemImage: "carrot.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)
                Text("Check off snacks as they're eaten. Each item can only be checked once per day.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)

                if viewModel.isLoading && viewModel.snackOptions.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                } else if viewModel.snackOptions.isEmpty {
                    EmptyStateView(
                        text: viewModel.canManage
                            ? "Add snack options in the panel."
                            : "No snacks listed yet."
                    )
                } else if viewModel.allEaten {
                    Text("All snacks eaten for today!")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 96)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.pendingSnacks, id: \.self) { snack in
                            SnackCheckRow(label: snack) {
                                await viewModel.toggleSnack(snack)
                            }
                        }
                    }
                }

                if !viewModel.snackOptions.isEmpty {
                    Text("\(viewModel.eaten.count) of \(viewModel.snackOptions.count) eaten today")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var optionsPanel: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Snack options", systemImage: "list.bullet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)
                Text("Keep a running list of snacks the family can grab anytime.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)

                TextField(
                    "Apples\nYogurt tubes\nCheese sticks",
                    text: $viewModel.snackOptionsText,
                    axis: .vertical
                )
                .lineLimit(6...12)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

                Text("Put each snack on a new line.")
                    .font(.caption2)
                    .foregroundStyle(HubTheme.muted)

                Button("Save snack list") {
                    Task { _ = await viewModel.saveSnackOptions() }
                }
                .buttonStyle(.borderedProminent)
                .tint(HubTheme.sage)
                .disabled(viewModel.isWorking)
            }
        }
    }
}

private struct SnackCheckRow: View {
    let label: String
    var onToggle: () async -> Void

    @State private var isChecked = false
    @State private var isHidden = false
    @State private var isWorking = false

    var body: some View {
        if !isHidden {
            CheckItemView(
                label: label,
                isChecked: $isChecked,
                removeWhenChecked: true
            ) {
                isWorking = true
                defer { isWorking = false }
                await onToggle()
                isChecked = true
                withAnimation {
                    isHidden = true
                }
            }
            .disabled(isWorking)
        }
    }
}
