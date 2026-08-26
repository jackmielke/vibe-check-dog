import SwiftUI

@main
struct VibeCheckApp: App {
    @StateObject private var store = VibeStore(preloaded: DemoSeed.preloadedChecks())
    @StateObject private var auth = AppleSignIn()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(auth)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onAppear {
                    #if DEBUG
                    if IconRenderer.isRequested { IconRenderer.render() }
                    #endif
                }
        }
    }
}
