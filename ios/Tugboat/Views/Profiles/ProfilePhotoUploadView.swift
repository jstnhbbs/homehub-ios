import PhotosUI
import SwiftUI

struct ProfilePhotoUploadView: View {
    let profile: Profile
    var editorSession: EditorSession? = nil
    var onUpdated: () async -> Void

    @EnvironmentObject private var appState: AppState
    @State private var selectedItem: PhotosPickerItem?
    @State private var cropCandidate: PhotoCropCandidate?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                ProfileAvatarView(
                    name: profile.name,
                    avatar: profile.avatar,
                    color: profile.color,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Profile Photo")
                        .font(.subheadline.weight(.bold))
                    Text("Upload, replace, or remove this family member's photo.")
                        .font(.caption)
                        .foregroundStyle(HubTheme.muted)

                    HStack(spacing: 8) {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label(
                                ProfilePhotoHelpers.hasPhoto(profile.avatar) ? "Replace" : "Add Photo",
                                systemImage: "camera.fill"
                            )
                            .font(.caption.weight(.bold))
                        }
                        .buttonStyle(HubButtonStyle(emphasis: .secondary))
                        .disabled(isWorking)

                        if ProfilePhotoHelpers.hasPhoto(profile.avatar) {
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
            PhotoCropView(image: candidate.image, shape: .circle) {
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
        guard !isWorking else { return }
        if let editorSession, !editorSession.beginOperation() { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false; editorSession?.endOperation() }

        let session = appState.auth.sessionVersion
        do {
            guard let prepared = try await ProfilePhotoHelpers.prepareUploadDataInBackground(from: image) else {
                errorMessage = "Choose a JPEG, PNG, or WebP image under 5 MB."
                return
            }

            guard session == appState.auth.sessionVersion, !Task.isCancelled else { return }
            _ = try await appState.api.uploadProfilePhoto(
                id: profile.id,
                data: prepared.data,
                fileName: prepared.fileName,
                mimeType: prepared.mimeType
            )
            guard session == appState.auth.sessionVersion, !Task.isCancelled else { return }
            await onUpdated()
        } catch {
            errorMessage = error.userFacingMessage
            appState.report(error)
        }
    }

    private func removePhoto() async {
        guard !isWorking else { return }
        if let editorSession, !editorSession.beginOperation() { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false; editorSession?.endOperation() }

        do {
            _ = try await appState.api.removeProfilePhoto(id: profile.id)
            await onUpdated()
        } catch {
            errorMessage = error.userFacingMessage
            appState.report(error)
        }
    }
}
