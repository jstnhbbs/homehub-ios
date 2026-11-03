import PhotosUI
import SwiftUI

struct HouseholdPhotoUploadView: View {
    let household: Household

    @EnvironmentObject private var appState: AppState
    @State private var selectedItem: PhotosPickerItem?
    @State private var cropCandidate: PhotoCropCandidate?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                HouseholdMarkView(
                    name: household.name,
                    photo: household.photo,
                    ownerName: household.ownerName,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Family Photo")
                        .font(.subheadline.weight(.bold))
                    Text("Optional. Replaces the family-name letter in the sidebar.")
                        .font(.caption)
                        .foregroundStyle(HubTheme.muted)

                    if appState.canManageHousehold {
                        HStack(spacing: 8) {
                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label(
                                    ProfilePhotoHelpers.hasPhoto(household.photo) ? "Replace" : "Add Photo",
                                    systemImage: "camera.fill"
                                )
                                .font(.caption.weight(.bold))
                            }
                            .buttonStyle(HubButtonStyle(emphasis: .secondary))
                            .disabled(isWorking)

                            if ProfilePhotoHelpers.hasPhoto(household.photo) {
                                Button("Remove", role: .destructive) {
                                    Task { await removePhoto() }
                                }
                                .buttonStyle(HubButtonStyle(emphasis: .secondary))
                                .disabled(isWorking)
                            }

                            if isWorking {
                                ProgressView()
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                await prepareCrop(from: item)
                selectedItem = nil
            }
        }
        .fullScreenCover(item: $cropCandidate) { candidate in
            PhotoCropView(image: candidate.image, shape: .roundedSquare) {
                cropCandidate = nil
            } onDone: { cropped in
                cropCandidate = nil
                Task { await uploadPhoto(cropped) }
            }
        }
    }

    /// Loads the chosen photo and opens the crop screen for it.
    private func prepareCrop(from item: PhotosPickerItem) async {
        guard !isWorking else { return }
        let session = appState.auth.sessionVersion
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = try await ProfilePhotoHelpers.cropSourceInBackground(from: data) else {
                errorMessage = "Choose a JPEG, PNG, or WebP image under 5 MB."
                return
            }
            guard session == appState.auth.sessionVersion, !Task.isCancelled else { return }
            cropCandidate = PhotoCropCandidate(image: image)
        } catch {
            errorMessage = error.userFacingMessage
            appState.report(error)
        }
    }

    private func uploadPhoto(_ image: UIImage) async {
        guard appState.canManageHousehold, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let session = appState.auth.sessionVersion
        do {
            guard let prepared = try await ProfilePhotoHelpers.prepareUploadDataInBackground(from: image) else {
                errorMessage = "Choose a JPEG, PNG, or WebP image under 5 MB."
                return
            }

            guard session == appState.auth.sessionVersion, !Task.isCancelled else { return }
            let updated = try await appState.api.uploadHouseholdPhoto(
                data: prepared.data,
                fileName: prepared.fileName,
                mimeType: prepared.mimeType
            )
            guard session == appState.auth.sessionVersion, !Task.isCancelled else { return }
            appState.household = updated
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.userFacingMessage
            appState.report(error)
        }
    }

    private func removePhoto() async {
        guard appState.canManageHousehold, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let session = appState.auth.sessionVersion
        do {
            let updated = try await appState.api.removeHouseholdPhoto()
            guard session == appState.auth.sessionVersion, !Task.isCancelled else { return }
            appState.household = updated
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.userFacingMessage
            appState.report(error)
        }
    }
}
