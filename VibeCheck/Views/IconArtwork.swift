import SwiftUI

/// The app icon, drawn from the same view the app uses, so the mark on the home
/// screen is literally the same dog. Rendered to PNG by the -renderIcon path.
struct IconArtwork: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.745, blue: 0.361),
                         Color(red: 0.953, green: 0.604, blue: 0.188)],
                startPoint: .top, endPoint: .bottom
            )
            DogView(mood: .waiting, size: 1010, showBody: false)
                .offset(y: 132)
        }
        .frame(width: 1024, height: 1024)
    }
}

#if DEBUG
import UIKit

enum IconRenderer {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-renderIcon")
    }

    /// Writes AppIcon-1024.png into the app's Documents directory so it can be
    /// pulled out of the simulator container.
    @MainActor
    static func render() {
        let renderer = ImageRenderer(content: IconArtwork())
        renderer.scale = 1
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppIcon-1024.png")
        try? data.write(to: url, options: .atomic)
        print("ICON WRITTEN \(url.path) \(image.size)")
    }
}
#endif
