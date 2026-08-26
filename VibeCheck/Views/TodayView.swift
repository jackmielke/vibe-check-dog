import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: VibeStore
    @EnvironmentObject private var auth: AppleSignIn

    private enum Phase: Equatable {
        case prompt
        case scoring
        case result(VibeCheck)
    }

    @State private var phase: Phase = .prompt
    @State private var showCamera = false
    @State private var pickedImage: UIImage?
    @State private var error: String?
    @State private var line = DogLines.waiting.randomElement() ?? "Let me get your vibe check."
    @State private var posting = false

    private var mood: DogMood {
        switch phase {
        case .prompt:  return .waiting
        case .scoring: return .thinking
        case .result(let c): return .verdict(c.score)
        }
    }

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            GeometryReader { geo in
              ScrollView {
                VStack(spacing: 20) {
                    DogView(mood: mood, size: 210)
                        .padding(.top, 8)
                        .accessibilityHidden(true)

                    speechBubble

                    switch phase {
                    case .prompt:  promptControls
                    case .scoring: scoringControls
                    case .result(let check): resultBlock(check)
                    }

                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Theme.scoreColor(10))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
              }
              .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear(perform: restoreToday)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                pickedImage = image
                Task { await score(image) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Pieces

    private var speechBubble: some View {
        Text(line)
            .font(Theme.display(19, .bold))
            .foregroundStyle(Theme.cream)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.bgLift))
            .overlay(alignment: .top) {
                // little tail pointing back up at the dog
                Triangle()
                    .fill(Theme.bgLift)
                    .frame(width: 22, height: 12)
                    .offset(y: -11)
            }
            .padding(.horizontal, 6)
            .animation(.easeInOut(duration: 0.2), value: line)
    }

    private var promptControls: some View {
        VStack(spacing: 12) {
            Button {
                error = nil
                showCamera = true
            } label: {
                Label(store.hasCheckedToday ? "Go again" : "Take my vibe check",
                      systemImage: "camera.fill")
                    .font(Theme.display(18, .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(Theme.bg)
            }
            .accessibilityIdentifier("takeVibeCheck")

            if !CameraView.cameraAvailable {
                Text("No camera here, so this will open your photo library.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            if store.streak > 0 {
                Label("\(store.streak) day streak", systemImage: "flame.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
            }
        }
    }

    private var scoringControls: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.accent)
            Text("Judging you…")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 18)
    }

    private func resultBlock(_ check: VibeCheck) -> some View {
        VStack(spacing: 16) {
            Text("\(check.score)")
                .font(Theme.display(76, .black))
                .foregroundStyle(Theme.scoreColor(check.score))
                .monospacedDigit()
                .accessibilityIdentifier("vibeScore")

            Text(check.analysis)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.cream)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .vibeCard()

            if let image = store.photo(for: check) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            postControls(check)

            Button("Take another") {
                error = nil
                showCamera = true
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder
    private func postControls(_ check: VibeCheck) -> some View {
        if check.posted {
            Label("On the leaderboard", systemImage: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.scoreColor(90))
        } else if auth.isSignedIn {
            Button {
                Task { await post(check) }
            } label: {
                Group {
                    if posting {
                        ProgressView().tint(Theme.bg)
                    } else {
                        Label("Post to the leaderboard", systemImage: "trophy.fill")
                    }
                }
                .font(Theme.display(16, .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Theme.cream))
                .foregroundStyle(Theme.bg)
            }
            .disabled(posting)
        } else {
            VStack(spacing: 8) {
                Text("Sign in to put this on the leaderboard. Until then it stays on your phone.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                NavigationLink {
                    ProfileView()
                } label: {
                    Text("Sign in with Apple")
                        .font(Theme.display(16, .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(Theme.cream))
                        .foregroundStyle(Theme.bg)
                }
            }
        }
    }

    // MARK: - Behaviour

    private func restoreToday() {
        if let today = store.todaysCheck {
            phase = .result(today)
            line = DogLines.forScore(today.score)
        } else {
            phase = .prompt
            line = DogLines.waiting.randomElement() ?? "Let me get your vibe check."
        }
    }

    private func score(_ image: UIImage) async {
        error = nil
        withAnimation { phase = .scoring }
        line = DogLines.thinking.randomElement() ?? "Hold on."
        do {
            // Always score locally first. Posting is a separate, explicit step.
            let rating = try await VibeAPI.analyze(image: image)
            let check = store.record(score: rating.score, analysis: rating.analysis,
                                     image: image, posted: false)
            withAnimation {
                line = DogLines.forScore(rating.score)
                phase = .result(check)
            }
        } catch {
            self.error = error.localizedDescription
            withAnimation {
                line = "Something went wrong. Not your fault. Probably."
                phase = .prompt
            }
        }
    }

    private func post(_ check: VibeCheck) async {
        guard let image = store.photo(for: check) else { return }
        posting = true
        defer { posting = false }
        do {
            _ = try await VibeAPI.submit(image: image, name: auth.postingName)
            store.markPosted(check)
            if let updated = store.checks.first(where: { $0.id == check.id }) {
                withAnimation { phase = .result(updated) }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Speech-bubble tail.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

enum DogLines {
    static let waiting = [
        "Let me get your vibe check.",
        "Stand still. I'm looking at you.",
        "Show me what we're working with.",
        "Alright. Face the dog.",
        "I've got all day. You don't."
    ]

    static let thinking = [
        "Hold on. I'm looking.",
        "Hmm.",
        "Interesting choice.",
        "Give me a second here."
    ]

    static func forScore(_ score: Int) -> String {
        switch score {
        case ..<25:  return "Woof. And not the good kind."
        case ..<45:  return "We've all had days like this."
        case ..<60:  return "That's a solid 'sure'."
        case ..<75:  return "Okay, not bad at all."
        case ..<90:  return "Now we're talking."
        default:     return "Okay show-off. Genuinely impressive."
        }
    }
}
