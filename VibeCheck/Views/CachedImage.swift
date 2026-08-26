import SwiftUI
import ImageIO
import UIKit

/// Loads and caches leaderboard photos.
///
/// AsyncImage restarts its download every time a List row is recycled, which is
/// why the board loaded slowly and filled in out of order. This keeps decoded
/// thumbnails in an NSCache and downsamples while decoding, so scrolling reuses
/// work instead of redoing it.
actor ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init() {
        cache.countLimit = 300
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(url.absoluteString)|\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }

        // Coalesce: the same photo can appear in a row and its detail view.
        if let running = inFlight[key as String] { return await running.value }

        let task = Task<UIImage?, Never> { [maxPixel] in
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return Self.downsample(data, maxPixel: maxPixel)
        }
        inFlight[key as String] = task
        let result = await task.value
        inFlight[key as String] = nil

        if let result {
            cache.setObject(result, forKey: key, cost: Int(result.size.width * result.size.height * 4))
        }
        return result
    }

    /// Decode straight to the size actually needed. Full-resolution selfies
    /// decoded into a 54pt thumbnail is what made scrolling stutter.
    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct CachedImage: View {
    let url: URL?
    var maxPixel: CGFloat = 300

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Rectangle().fill(Theme.bgLift)
                if failed {
                    Image(systemName: "photo")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted.opacity(0.5))
                } else {
                    ProgressView().controlSize(.small).tint(Theme.muted)
                }
            }
        }
        .task(id: url) {
            guard let url, image == nil else { return }
            let loaded = await ImageLoader.shared.image(for: url, maxPixel: maxPixel)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) { image = loaded }
                failed = loaded == nil
            }
        }
    }
}
