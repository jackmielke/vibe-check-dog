import SwiftUI

/// The set of posters this device has blocked.
///
/// The server is the source of truth - `leaderboard-api` already filters blocked
/// posters out of what it returns, which is what makes a block survive a
/// reinstall. This local mirror exists for one reason: guideline 1.2 says a
/// block must remove the content from the user's feed *instantly*, and waiting
/// for a network round trip before the row disappears is not instantly.
@MainActor
final class BlockList: ObservableObject {
    @Published private(set) var blocked: Set<String> = []

    private let key = "blockedPosterIDs"

    init() {
        blocked = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func isBlocked(_ posterID: String?) -> Bool {
        guard let posterID else { return false }
        return blocked.contains(posterID)
    }

    /// Hides the poster immediately, then tells the server. If the call fails the
    /// local block stands: erring toward hiding too much is the right failure
    /// mode for a safety control, and the next sync will reconcile it.
    func block(_ posterID: String, ownerKey: String, entryID: String? = nil) async {
        blocked.insert(posterID)
        persist()
        do {
            try await VibeAPI.block(ownerKey: ownerKey, posterID: posterID, entryID: entryID)
        } catch {
            print("Block did not reach the server, keeping it locally: \(error)")
        }
    }

    /// Unblocking is the opposite: only drop it locally once the server agrees,
    /// so a failed call cannot silently un-hide someone.
    func unblock(_ posterID: String, ownerKey: String) async throws {
        try await VibeAPI.unblock(ownerKey: ownerKey, posterID: posterID)
        blocked.remove(posterID)
        persist()
    }

    /// Pulls the authoritative list, so a block made on a previous install of the
    /// app is reflected here too.
    func sync(ownerKey: String) async {
        guard let remote = try? await VibeAPI.blockedPosters(ownerKey: ownerKey) else { return }
        // Union rather than replace: a block made moments ago may not have
        // reached the server yet, and it must not flicker back into view.
        blocked.formUnion(remote)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(blocked), forKey: key)
    }
}
