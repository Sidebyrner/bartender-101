import SwiftUI
import UIKit

/// Full-screen photos: swipe between them, pinch or double-tap to zoom,
/// share, or delete (with a confirmation). Closes itself when the last
/// photo in its scope is deleted.
struct PhotoViewer: View {
    let scope: PhotoScope
    let startingAt: UUID

    @EnvironmentObject private var photoStore: PhotoStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID?
    @State private var confirmDelete = false
    @State private var chromeHidden = false

    private var photos: [DrinkPhoto] { scope.photos(in: photoStore) }
    private var current: DrinkPhoto? { photos.first { $0.id == selection } ?? photos.first }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    ZoomableImage(url: photoStore.imageURL(for: photo)) {
                        withAnimation(.easeInOut(duration: 0.2)) { chromeHidden.toggle() }
                    }
                    .tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            if !chromeHidden, let current {
                chrome(for: current)
                    .transition(.opacity)
            }
        }
        .statusBarHidden(chromeHidden)
        .onAppear { selection = startingAt }
        .onChange(of: photos.count) { _, count in
            if count == 0 { dismiss() }
        }
        .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Photo", role: .destructive, action: deleteCurrent)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private func chrome(for photo: DrinkPhoto) -> some View {
        VStack {
            HStack(alignment: .top) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
                VStack(spacing: 2) {
                    Text(photo.drinkName)
                        .font(.system(.headline, design: .serif))
                    Text(photo.takenAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .opacity(0.8)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            HStack {
                ShareLink(item: photoStore.imageURL(for: photo), preview: SharePreview(photo.drinkName)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .foregroundStyle(.white)
        .padding()
        .environment(\.colorScheme, .dark)
    }

    private func deleteCurrent() {
        guard let current else { return }
        let list = photos
        let index = list.firstIndex(of: current) ?? 0
        let next = list.indices.contains(index + 1) ? list[index + 1] : (index > 0 ? list[index - 1] : nil)
        withAnimation(Theme.spring) {
            selection = next?.id
            photoStore.delete(id: current.id)
        }
    }
}

/// A photo that pinch-zooms and pans, double-tap toggles 2× zoom, and a
/// single tap hides or shows the viewer's controls.
private struct ZoomableImage: View {
    let url: URL
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .transition(.opacity)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { value in scale = max(1, min(5, lastScale * value.magnification)) }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1 { resetZoom() }
                    }
            )
            .simultaneousGesture(scale > 1 ? DragGesture()
                .onChanged { value in
                    offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                }
                .onEnded { _ in lastOffset = offset } : nil)
            .onTapGesture(count: 2) {
                withAnimation(Theme.spring) {
                    if scale > 1 { resetZoom() } else { scale = 2; lastScale = 2 }
                }
            }
            .onTapGesture(count: 1, perform: onTap)
        }
        .task(id: url) {
            let loaded = await Task.detached(priority: .userInitiated) { UIImage(contentsOfFile: url.path) }.value
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
        .accessibilityElement()
        .accessibilityLabel("Photo")
        .accessibilityAddTraits(.isImage)
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
