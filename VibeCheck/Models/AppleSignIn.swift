import AuthenticationServices
import SwiftUI

/// Sign in with Apple, used purely to attach a real name to leaderboard posts.
///
/// Apple hands over the user's name only on the very first authorization, so it
/// is persisted here. No account is created on any server: the identifier and
/// name live in UserDefaults on this device and are cleared on sign out.
@MainActor
final class AppleSignIn: ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var displayName: String?
    /// Surfaced in the UI. Previously a failed authorization was swallowed
    /// silently, so tapping the button appeared to do nothing at all.
    @Published var lastError: String?

    private let idKey = "appleUserID"
    private let nameKey = "appleDisplayName"
    private let ownerKeyKey = "vibeOwnerKey"

    init() {
        userID = UserDefaults.standard.string(forKey: idKey)
        displayName = UserDefaults.standard.string(forKey: nameKey)
    }

    var isSignedIn: Bool { userID != nil }

    /// Posting needs a name, not necessarily an Apple account. Sign in with
    /// Apple is the quick path; typing a name is the fallback so the
    /// leaderboard is never blocked by an auth problem.
    var canPost: Bool { displayName?.isEmpty == false }

    /// Stable random identifier, created once per install, used only to prove
    /// ownership of leaderboard posts so they can be deleted later. It is not
    /// derived from the Apple account and identifies nobody. It deliberately
    /// survives sign-out, so signing back in still owns the same posts.
    var ownerKey: String {
        if let existing = UserDefaults.standard.string(forKey: ownerKeyKey) { return existing }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: ownerKeyKey)
        return fresh
    }

    /// The name posted to the leaderboard.
    var postingName: String { displayName ?? "Anonymous" }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            // A user-cancelled sheet is not worth shouting about; anything else is.
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                lastError = nil
            } else {
                lastError = "Apple sign-in failed: \(error.localizedDescription). You can just type a name instead."
            }
            return
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                lastError = "Apple returned an unexpected credential. Type a name instead."
                return
            }
            apply(cred)
        }
    }

    private func apply(_ cred: ASAuthorizationAppleIDCredential) {
        lastError = nil

        let id = cred.user
        // Only present on first authorization - keep whatever we already stored otherwise.
        let fresh = [cred.fullName?.givenName, cred.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        userID = id
        UserDefaults.standard.set(id, forKey: idKey)

        if !fresh.isEmpty {
            displayName = fresh
            UserDefaults.standard.set(fresh, forKey: nameKey)
        } else if displayName == nil {
            displayName = "Anonymous"
            UserDefaults.standard.set("Anonymous", forKey: nameKey)
        }
    }

    func rename(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        displayName = String(trimmed.prefix(24))
        UserDefaults.standard.set(displayName, forKey: nameKey)
    }

    func signOut() {
        userID = nil
        displayName = nil
        UserDefaults.standard.removeObject(forKey: idKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
    }

    /// Full deletion: forget the account *and* the ownership key, after posts
    /// have been removed server-side.
    func forgetEverything() {
        signOut()
        UserDefaults.standard.removeObject(forKey: ownerKeyKey)
    }
}
