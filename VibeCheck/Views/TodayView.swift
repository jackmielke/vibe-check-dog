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
    @State private var error: String?
    @State private var line = DogLines.waiting.randomElement() ?? "Let me get your vibe check."
    @State private var posting = false
    @State private var shownScore = 0
    @State private var revealed = false
    @AppStorage("mascot") private var mascotRaw: String = Mascot.original.rawValue

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
                    VStack(spacing: 18) {
                        MascotView(mascot: Mascot(rawValue: mascotRaw) ?? .original,
                                   mood: mood,
                                   size: isResult ? 132 : 210)
                            .accessibilityHidden(true)
                            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isResult)

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
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear(perform: restoreToday)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in Task { await score(image) } }
        }
    }

    private var isResult: Bool { if case .result = phase { return true }; return false }

    // MARK: - Pieces

    private var speechBubble: some View {
        Text(line)
            .font(Theme.display(19, .bold))
            .foregroundStyle(Theme.cream)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.bgLift))
            .overlay(alignment: .top) {
                Triangle().fill(Theme.bgLift).frame(width: 22, height: 12).offset(y: -11)
            }
            .padding(.horizontal, 6)
            .animation(.easeInOut(duration: 0.2), value: line)
    }

    private var promptControls: some View {
        VStack(spacing: 12) {
            Button {
                error = nil
                SFX.tap()
                showCamera = true
            } label: {
                Label(store.hasCheckedToday ? "Go again" : "Take my vibe check", systemImage: "camera.fill")
                    .font(Theme.display(18, .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(Theme.bg)
            }
            .accessibilityIdentifier("takeVibeCheck")

            if store.streak > 0 {
                Label("\(store.streak) day streak", systemImage: "flame.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var scoringControls: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large).tint(Theme.accent)
            Text("Judging you…").font(.subheadline).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 14)
    }

    private func resultBlock(_ check: VibeCheck) -> some View {
        VStack(spacing: 14) {
            Text(DogLines.emoji(for: check.score))
                .font(.system(size: 54))
                .scaleEffect(revealed ? 1 : 0.4)
                .opacity(revealed ? 1 : 0)

            Text("\(shownScore)")
                .font(Theme.display(80, .black))
                .foregroundStyle(Theme.scoreColor(check.score))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityIdentifier("vibeScore")

            Text(check.analysis)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.cream)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .vibeCard()
                .opacity(revealed ? 1 : 0)

            if let image = store.photo(for: check) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            postControls(check)

            Button("Take another") {
                error = nil
                SFX.tap()
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
        } else if auth.canPost {
            Button {
                Task { await post(check) }
            } label: {
                Group {
                    if posting { ProgressView().tint(Theme.bg) }
                    else { Label("Post as \(auth.postingName)", systemImage: "trophy.fill") }
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
                Text("Add a name to put this on the leaderboard. Until then it stays on your phone.")
                    .font(.footnote).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                NavigationLink {
                    ProfileView()
                } label: {
                    Text("Set up posting")
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
            shownScore = today.score
            revealed = true
            line = DogLines.forScore(today.score)
        } else {
            phase = .prompt
            line = DogLines.waiting.randomElement() ?? "Let me get your vibe check."
        }
    }

    private func score(_ image: UIImage) async {
        error = nil
        shownScore = 0
        revealed = false
        withAnimation { phase = .scoring }
        line = DogLines.thinking.randomElement() ?? "Hold on."
        SFX.thinking()
        do {
            let rating = try await VibeAPI.analyze(image: image)
            let check = store.record(score: rating.score, analysis: rating.analysis,
                                     image: image, posted: false)
            withAnimation {
                line = DogLines.forScore(rating.score)
                phase = .result(check)
            }
            countUp(to: rating.score)
        } catch {
            self.error = error.localizedDescription
            withAnimation {
                line = "Something broke. Not your fault. Probably."
                phase = .prompt
            }
        }
    }

    /// Counts the score up over ~1.6s with ticks, then lands the sting. The
    /// slow reveal is most of the joke.
    private func countUp(to target: Int) {
        guard target > 0 else {
            revealed = true
            SFX.score(0)
            return
        }
        let steps = min(target, 45)
        let interval = 1.6 / Double(steps)
        var step = 0
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            step += 1
            withAnimation(.linear(duration: interval)) {
                shownScore = Int(Double(target) * Double(step) / Double(steps))
            }
            if step % 3 == 0 { SFX.tick() }
            if step >= steps {
                t.invalidate()
                shownScore = target
                SFX.score(target)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { revealed = true }
            }
        }
    }

    private func post(_ check: VibeCheck) async {
        guard let image = store.photo(for: check) else { return }
        posting = true
        defer { posting = false }
        do {
            _ = try await VibeAPI.submit(image: image, name: auth.postingName, ownerKey: auth.ownerKey)
            store.markPosted(check)
            if let updated = store.checks.first(where: { $0.id == check.id }) {
                withAnimation { phase = .result(updated) }
            }
            SFX.score(95)
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
        "I've got all day. You don't.",
        "This is a safe space. It is not a kind one.",
        "Chin up. Not like that."
    ]

    static let thinking = [
        "Hold on. I'm looking.",
        "Hmm.",
        "Interesting choice.",
        "Give me a second here.",
        "Consulting the other dogs.",
        "Oh."
    ]

    static func emoji(for score: Int) -> String {
        switch score {
        case 90...: return "🔥"
        case 75..<90: return "✨"
        case 60..<75: return "😎"
        case 40..<60: return "😐"
        default: return "💀"
        }
    }

    static func forScore(_ score: Int) -> String {
        switch score {
        case ..<20:  return "I'm going to pretend I didn't see that."
        case ..<35:  return "Woof. And not the good kind."
        case ..<50:  return "We've all had days like this."
        case ..<62:  return "That's a solid 'sure'."
        case ..<75:  return "Okay, not bad at all."
        case ..<88:  return "Now we're talking."
        case ..<96:  return "Okay show-off. Genuinely impressive."
        default:     return "I have never given this out before. Don't waste it."
        }
    }
}
