import PhotosUI
import SwiftUI

extension View {
    /// Adds a small camera button to the toolbar for photographing `drink` —
    /// Take Photo (when there's a camera) or Choose from Library. Never
    /// prompts on its own; it's there for when a drink is worth a record.
    func drinkPhotoButton(for drink: Drink) -> some View {
        modifier(DrinkPhotoButton(drink: drink))
    }
}

private struct DrinkPhotoButton: ViewModifier {
    let drink: Drink

    @EnvironmentObject private var photoStore: PhotoStore
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var savedCount = 0
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if CameraPicker.isAvailable {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }
                        }
                        Button {
                            showLibrary = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Add Photo", systemImage: "camera")
                                .symbolEffect(.bounce, value: savedCount)
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityLabel("Add a photo of this drink")
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in save(data) }
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images, photoLibrary: .shared())
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                libraryItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        save(data)
                    } else {
                        failed = true
                    }
                }
            }
            .sensoryFeedback(.success, trigger: savedCount)
            .alert("Couldn't save that photo", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The image couldn't be read. Try another photo.")
            }
    }

    private func save(_ data: Data) {
        isSaving = true
        Task {
            let photo = await photoStore.add(imageData: data, drinkID: drink.id, drinkName: drink.name)
            isSaving = false
            if photo == nil {
                failed = true
            } else {
                savedCount += 1
            }
        }
    }
}
