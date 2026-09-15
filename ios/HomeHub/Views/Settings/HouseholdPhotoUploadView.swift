import PhotosUI
import SwiftUI

struct HouseholdPhotoUploadView: View {
    let household: Household

    @EnvironmentObject private var appState: AppState
    @State private var selectedItem: PhotosPickerItem?
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
                    Text("Family photo")
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
                                    ProfilePhotoHelpers.hasPhoto(household.photo) ? "Replace" : "Add photo",
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

            appState.household = try await appState.api.uploadHouseholdPhoto(
                data: prepared.data,
                fileName: prepared.fileName,
                mimeType: prepared.mimeType
            )
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func removePhoto() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            appState.household = try await appState.api.removeHouseholdPhoto()
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
