import SwiftUI
import UniformTypeIdentifiers

/// Imports recipes exported from the Crouton app: pick the folder of `.crumb` files (or the files
/// themselves) and watch them come in. Safe to run twice, since recipes already imported are skipped.
struct CroutonImportView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CroutonImportViewModel()
    @State private var showingPicker = false
    @State private var pickerError: String?
    @State private var showingProblems = false

    /// Called when an import finishes, so the recipe list can reload.
    let onFinished: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch model.phase {
            case .choosing:
                chooser
            case .working:
                progress
            case .finished:
                summary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { model.bind(to: appState) }
        .onDisappear { model.cancel() }
        .interactiveDismissDisabled(model.isRunning)
        .onChange(of: model.phase) { _, phase in
            if phase == .finished {
                Task { await onFinished() }
            }
        }
        .fileImporter(
            isPresented: $showingPicker,
            // A folder, or any file: Crouton's .crumb isn't a type iOS knows unless Crouton is installed.
            allowedContentTypes: [.folder, .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                pickerError = nil
                model.start(picked: urls)
            case .failure(let error):
                pickerError = error.localizedDescription
            }
        }
    }

    // MARK: Choosing

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Import from Crouton", systemImage: "square.and.arrow.down.on.square")
                .font(.headline)
            Text("Export your recipes from Crouton as .crumb files into the Files app, then choose that folder here, or pick individual files. Ingredients, steps, times, tags, notes, nutrition and photos come across.")
                .font(.footnote)
                .foregroundStyle(HubTheme.muted)
            Text("Importing the same recipes again is safe: ones already in Beacon are skipped, and any that are missing their photo get it.")
                .font(.footnote)
                .foregroundStyle(HubTheme.muted)

            if let pickerError {
                Text(pickerError).font(.footnote).foregroundStyle(.red)
            }

            Button {
                showingPicker = true
            } label: {
                Label("Choose Folder or Files", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
        }
    }

    // MARK: Working

    private var progress: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Importing recipes", systemImage: "arrow.down.circle")
                .font(.headline)
            ProgressView(value: Double(model.processed), total: Double(max(model.total, 1)))
                .tint(HubTheme.sage)
            HStack {
                Text("\(model.processed) of \(model.total)")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(model.created) added")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
            if model.photosQueued > 0 {
                HStack {
                    Label("Photos", systemImage: "photo")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                    Spacer()
                    Text("\(min(model.photosSaved + model.photosFailed, model.photosQueued)) of \(model.photosQueued)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                        .monospacedDigit()
                }
            }
            if !model.currentTitle.isEmpty {
                Text(model.currentTitle)
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)
                    .lineLimit(1)
            }
            Text("Keep this screen open until it finishes.")
                .font(.footnote)
                .foregroundStyle(HubTheme.muted)
            Button {
                model.cancel()
            } label: {
                Text("Stop").frame(maxWidth: .infinity)
            }
            .buttonStyle(HubButtonStyle(emphasis: .secondary))
        }
    }

    // MARK: Finished

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryTitle

            if let message = model.message {
                Text(message).font(.footnote).foregroundStyle(HubTheme.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                summaryRow("\(model.created) recipe\(model.created == 1 ? "" : "s") added", systemImage: "plus.circle.fill", tint: HubTheme.sage)
                if model.duplicates > 0 {
                    summaryRow("\(model.duplicates) already in Beacon, skipped", systemImage: "equal.circle", tint: HubTheme.muted)
                }
                if model.photosSaved > 0 {
                    summaryRow("\(model.photosSaved) photo\(model.photosSaved == 1 ? "" : "s") saved", systemImage: "photo", tint: HubTheme.muted)
                }
                if model.photosFailed > 0 {
                    summaryRow("\(model.photosFailed) photo\(model.photosFailed == 1 ? "" : "s") couldn't be saved", systemImage: "photo.badge.exclamationmark", tint: HubTheme.coral)
                }
                if !model.problems.isEmpty {
                    summaryRow("\(model.problems.count) couldn't be imported", systemImage: "exclamationmark.triangle.fill", tint: HubTheme.coral)
                }
            }

            if let note = model.photoNote {
                Text(note).font(.footnote).foregroundStyle(HubTheme.muted)
            }

            if !model.problems.isEmpty {
                DisclosureGroup("What went wrong", isExpanded: $showingProblems) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.problems) { problem in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(problem.title).font(.subheadline.weight(.bold))
                                Text(problem.reason).font(.footnote).foregroundStyle(HubTheme.muted)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.subheadline.weight(.bold))
            }

            HStack(spacing: 10) {
                Button {
                    model.startOver()
                } label: {
                    Text("Import More").frame(maxWidth: .infinity)
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))

                Button {
                    dismiss()
                } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
            }
        }
    }

    @ViewBuilder
    private var summaryTitle: some View {
        if model.stoppedEarly {
            Label("The import didn't finish", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(HubTheme.coral)
        } else if model.wasCancelled {
            Label("Import stopped", systemImage: "stop.circle")
                .font(.headline)
                .foregroundStyle(HubTheme.muted)
        } else if model.created == 0 && model.duplicates == 0 {
            Label("Nothing was imported", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(HubTheme.coral)
        } else {
            Label("Import finished", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(HubTheme.sage)
        }
    }

    private func summaryRow(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text).font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: systemImage).foregroundStyle(tint)
        }
    }
}
