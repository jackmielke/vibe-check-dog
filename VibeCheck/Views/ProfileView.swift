import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject private var store: VibeStore
    @EnvironmentObject private var auth: AppleSignIn
    @State private var editingName = false
    @State private var draftName = ""
    @State private var confirmClear = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var typedName = ""
    @AppStorage("mascot") private var mascotRaw: String = Mascot.original.rawValue
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if auth.canPost { signedInCard } else { signInCard }
                    mascotCard
                    soundCard
                    statsCard
                    if !store.checks.isEmpty { historySection }
                    dangerCard
                    Text("Vibe Check is a joke. The dog is not a real judge of anything.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("You")
    }

    private var signInCard: some View {
        VStack(spacing: 12) {
            MascotView(mascot: Mascot(rawValue: mascotRaw) ?? .original, size: 96)
                .accessibilityHidden(true)
            Text("Pick a name to post")
                .font(Theme.display(19, .bold))
                .foregroundStyle(Theme.cream)
            Text("Your vibe checks stay on this phone until you post one. All the leaderboard needs is a name.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                auth.handle(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 48)
            .clipShape(Capsule())
            .accessibilityIdentifier("signInWithApple")

            if let err = auth.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Theme.scoreColor(10))
                    .multilineTextAlignment(.center)
            }

            Text("or")
                .font(.caption).foregroundStyle(Theme.muted.opacity(0.7))

            HStack(spacing: 8) {
                TextField("Type a name", text: $typedName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.bgLift))
                    .submitLabel(.done)
                    .onSubmit { auth.rename(typedName) }
                    .accessibilityIdentifier("nameField")
                Button {
                    SFX.tap()
                    auth.rename(typedName)
                } label: {
                    Text("Use")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(Theme.bg)
                }
                .disabled(typedName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .frame(maxWidth: .infinity)
        .vibeCard(20)
    }

    private var mascotCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHO JUDGES YOU")
                .font(.caption.weight(.bold)).tracking(1.2)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                ForEach(Mascot.allCases) { m in
                    Button {
                        SFX.tap()
                        mascotRaw = m.rawValue
                    } label: {
                        VStack(spacing: 8) {
                            MascotView(mascot: m, size: 66)
                            Text(m.title)
                                .font(.system(size: 13, weight: .semibold))
                            Text(m.blurb)
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(mascotRaw == m.rawValue ? Theme.accent.opacity(0.16) : Theme.bgLift)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(mascotRaw == m.rawValue ? Theme.accent : .clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(Theme.cream)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vibeCard(16)
    }

    private var soundCard: some View {
        Toggle(isOn: $soundEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sound effects").font(.system(size: 16, weight: .medium))
                Text("Shutter clicks and the verdict sting.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
        }
        .tint(Theme.accent)
        .vibeCard(16)
    }

    private var signedInCard: some View {
        VStack(spacing: 12) {
            Text("Posting as")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            if editingName {
                TextField("Your name", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(Theme.display(22, .bold))
                    .foregroundStyle(Theme.cream)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .onSubmit {
                        auth.rename(draftName)
                        editingName = false
                    }
            } else {
                Text(auth.postingName)
                    .font(Theme.display(24, .bold))
                    .foregroundStyle(Theme.cream)
            }
            Button(editingName ? "Save" : "Change name") {
                if editingName {
                    auth.rename(draftName)
                } else {
                    draftName = auth.postingName
                }
                editingName.toggle()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .vibeCard(20)
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat("\(store.checks.count)", "checks")
            divider
            stat("\(store.average)", "average")
            divider
            stat("\(store.best?.score ?? 0)", "best")
            divider
            stat("\(store.streak)", store.streak == 1 ? "day" : "days")
        }
        .vibeCard(16)
    }

    private var divider: some View {
        Rectangle().fill(Theme.bgLift).frame(width: 1, height: 34)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.display(21, .black))
                .foregroundStyle(Theme.cream)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR CHECKS")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
                .tracking(1.2)
            ForEach(store.checks.prefix(20)) { check in
                HStack(spacing: 12) {
                    if let image = store.photo(for: check) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.analysis)
                            .font(.caption)
                            .foregroundStyle(Theme.cream)
                            .lineLimit(2)
                        Text(check.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 4)
                    if check.posted {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.accent.opacity(0.8))
                    }
                    Text("\(check.score)")
                        .font(Theme.display(19, .black))
                        .foregroundStyle(Theme.scoreColor(check.score))
                        .monospacedDigit()
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                .contextMenu {
                    Button(role: .destructive) { store.delete(check) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    /// Server first: if the leaderboard delete fails we stop and say so, rather
    /// than wiping the local ownership key and orphaning the posts forever.
    private func deleteEverything() async {
        deleting = true
        deleteError = nil
        defer { deleting = false }
        do {
            try await VibeAPI.deletePosts(ownerKey: auth.ownerKey)
        } catch {
            deleteError = "Could not remove your leaderboard posts: \(error.localizedDescription)"
            return
        }
        store.clearAll()
        auth.forgetEverything()
    }

    private var dangerCard: some View {
        VStack(spacing: 10) {
            if auth.canPost {
                Button("Sign out") { auth.signOut() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Button(role: .destructive) { confirmClear = true } label: {
                if deleting {
                    ProgressView().tint(Theme.muted)
                } else {
                    Text("Delete my account and all my data")
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .disabled(deleting)
            if let deleteError {
                Text(deleteError)
                    .font(.caption)
                    .foregroundStyle(Theme.scoreColor(10))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .vibeCard(16)
        .alert("Delete everything on this phone?", isPresented: $confirmClear) {
            Button("Delete", role: .destructive) { Task { await deleteEverything() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your posts and photos from the leaderboard, then deletes your vibe checks and sign-in from this phone. It cannot be undone.")
        }
    }
}
