import SwiftUI
import UIKit

/// Which photos a strip or viewer shows. Resolved live against the store,
/// so a delete in the viewer updates everything at once.
enum PhotoScope: Hashable {
    case drink(String)
    case shiftNight(Date)

    @MainActor
    func photos(in store: PhotoStore) -> [DrinkPhoto] {
        switch self {
        case .drink(let id): return store.photos(for: id)
        case .shiftNight(let night): return store.photos(onShiftNight: night)
        }
    }
}

/// A row of photo thumbnails, newest first. Tapping one opens the
/// full-screen viewer at that photo.
struct PhotoStrip: View {
    let scope: PhotoScope
    var height: CGFloat = 120
    /// Show which drink each photo is of (for a night's mixed photos).
    var showsDrinkName = false

    @EnvironmentObject private var photoStore: PhotoStore
    @State private var viewing: DrinkPhoto?

    var body: some View {
        let photos = scope.photos(in: photoStore)
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(photos) { photo in
                    Button {
                        viewing = photo
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            PhotoThumbnail(photo: photo)
                                .frame(width: height * 0.8, height: height)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                            Text(showsDrinkName ? photo.drinkName : photo.takenAt.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: height * 0.8, alignment: .leading)
                        }
                    }
                    .buttonStyle(.pressable)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .accessibilityLabel("Photo of \(photo.drinkName), \(photo.takenAt.formatted(date: .abbreviated, time: .shortened))")
                }
            }
            .padding(.vertical, 2)
            .animation(Theme.spring, value: photos.map(\.id))
        }
        .fullScreenCover(item: $viewing) { photo in
            PhotoViewer(scope: scope, startingAt: photo.id)
                .environmentObject(photoStore)
        }
    }
}

/// One photo's thumbnail, decoded off the main thread and faded in.
struct PhotoThumbnail: View {
    let photo: DrinkPhoto
    @EnvironmentObject private var photoStore: PhotoStore
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color(.tertiarySystemFill))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .clipped()
        .task(id: photo.id) {
            let url = photoStore.thumbnailURL(for: photo)
            let loaded = await Task.detached(priority: .utility) { UIImage(contentsOfFile: url.path) }.value
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}
