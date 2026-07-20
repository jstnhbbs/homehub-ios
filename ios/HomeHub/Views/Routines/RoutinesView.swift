import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RoutinesViewModel()

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if viewModel.isLoading && viewModel.routines.isEmpty {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                    } else if viewModel.routines.isEmpty {
                        EmptyStateView(text: "Your first routine will appear here.")
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(viewModel.routines) { routine in
                                RoutineCard(routine: routine, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if viewModel.canManage {
                addPanel
                    .frame(width: 330)
            }
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Small steps, smoother days")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(HubTheme.sage)
            Text("Routines")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
        }
    }

    private var addPanel: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("New routine", systemImage: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)
                RoutineFormView(
                    profiles: viewModel.profiles,
                    submitLabel: "Add routine"
                ) { input in
                    await viewModel.createRoutine(input)
                }
            }
        }
    }
}

private struct RoutineCard: View {
    let routine: Routine
    @ObservedObject var viewModel: RoutinesViewModel

    private var meta: (label: String, icon: String, color: Color) {
        switch routine.period {
        case .morning: ("Morning", "sun.max.fill", HubTheme.sunSoft)
        case .afternoon: ("After school", "sunset.fill", Color(red: 0.95, green: 0.88, blue: 0.85))
        case .evening: ("Bedtime", "moon.fill", Color(red: 0.88, green: 0.91, blue: 0.96))
        }
    }

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meta.label.uppercased())
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(HubTheme.muted)
                        Text(routine.name)
                            .font(.title2.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: meta.icon)
                        .font(.title3)
                        .frame(width: 48, height: 48)
                        .background(meta.color)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                let pending = viewModel.pendingSteps(for: routine)
                let profile = viewModel.profile(for: routine.profileId)

                if pending.isEmpty, !(routine.steps ?? []).isEmpty {
                    Text("All done for today!")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HubTheme.tileQuiet)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ForEach(pending) { step in
                        RoutineStepCheckRow(step: step, color: profile?.color) {
                            await viewModel.toggleStep(step.id)
                        }
                    }
                }

                if viewModel.canManage {
                    DisclosureGroup(
                        "Edit \(routine.name)",
                        isExpanded: Binding(
                            get: { viewModel.editingRoutineId == routine.id },
                            set: { viewModel.editingRoutineId = $0 ? routine.id : nil }
                        )
                    ) {
                        RoutineFormView(
                            profiles: viewModel.profiles,
                            routine: routine,
                            submitLabel: "Save routine",
                            onSubmit: { input in
                                await viewModel.updateRoutine(id: routine.id, input: input)
                            },
                            onDelete: {
                                await viewModel.deleteRoutine(id: routine.id)
                            }
                        )
                        .padding(.top, 8)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                }
            }
        }
    }
}

private struct RoutineStepCheckRow: View {
    let step: RoutineStep
    var color: String?
    let onToggle: () async -> Void

    @State private var isChecked = false
    @State private var isHidden = false

    var body: some View {
        if !isHidden {
            Button {
                Task {
                    isChecked = true
                    await onToggle()
                    withAnimation { isHidden = true }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .foregroundStyle(HubTheme.muted)
                    Text(step.label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(HubTheme.tileQuiet)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .leading) {
                    if let color {
                        Circle()
                            .fill(HubTheme.profileColor(color))
                            .frame(width: 8, height: 8)
                            .padding(.leading, 6)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
