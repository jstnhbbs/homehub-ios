import PhotosUI
import SwiftUI

struct ProfilePhotoUploadView: View {
    let profile: Profile
    var onUpdated: () async -> Void

    @EnvironmentObject private var appState: AppState
    @State private var selectedItem: PhotosPickerItem?
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
                    Text("Profile photo")
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
                                ProfilePhotoHelpers.hasPhoto(profile.avatar) ? "Replace" : "Add photo",
                                systemImage: "camera.fill"
                            )
                            .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .disabled(isWorking)

                        if ProfilePhotoHelpers.hasPhoto(profile.avatar) {
                            Button("Remove", role: .destructive) {
                                Task { await removePhoto() }
                            }
                            .buttonStyle(.bordered)
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
                await uploadPhoto(from: item)
                selectedItem = nil
            }
        }
    }

    private func uploadPhoto(from item: PhotosPickerItem) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let prepared = ProfilePhotoHelpers.prepareUploadData(from: image) else {
                errorMessage = "Choose a JPEG, PNG, or WebP image under 5 MB."
                return
            }

            _ = try await appState.api.uploadProfilePhoto(
                id: profile.id,
                data: prepared.data,
                fileName: prepared.fileName,
                mimeType: prepared.mimeType
            )
            await onUpdated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removePhoto() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            _ = try await appState.api.removeProfilePhoto(id: profile.id)
            await onUpdated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
