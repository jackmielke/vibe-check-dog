import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject private var store: VibeStore
    @EnvironmentObject private var auth: AppleSignIn
    @State private var editingName = false
    @State private var draftName = ""
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if auth.isSignedIn { signedInCard } else { signInCard }
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
            DogView(mood: .waiting, size: 110).accessibilityHidden(true)
            Text("Sign in to post")
                .font(Theme.display(19, .bold))
                .foregroundStyle(Theme.cream)
            Text("Your vibe checks stay on this phone until you sign in and post one. Signing in just gives the leaderboard a name to show.")
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
        }
        .frame(maxWidth: .infinity)
        .vibeCard(20)
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

    private var dangerCard: some View {
        VStack(spacing: 10) {
            if auth.isSignedIn {
                Button("Sign out") { auth.signOut() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Button(role: .destructive) { confirmClear = true } label: {
                Text("Delete all my data on this phone")
                    .font(.system(size: 15, weight: .medium))
            }
            .disabled(store.checks.isEmpty && !auth.isSignedIn)
        }
        .frame(maxWidth: .infinity)
        .vibeCard(16)
        .alert("Delete everything on this phone?", isPresented: $confirmClear) {
            Button("Delete", role: .destructive) {
                store.clearAll()
                auth.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your local vibe checks, photos, and sign-in will be removed. Anything already posted to the leaderboard stays there - email jackcmielke@gmail.com to have it taken down.")
        }
    }
}
