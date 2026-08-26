import SwiftUI

/// What the dog is currently doing. Drives eyes, ears, and head tilt.
enum DogMood: Equatable {
    case waiting          // deadpan, judging you gently
    case thinking         // squinting at your photo
    case verdict(Int)     // reacting to a score

    var headTilt: Double {
        switch self {
        case .waiting:        return -3
        case .thinking:       return 7
        case .verdict(let s): return s >= 80 ? -6 : (s < 35 ? 5 : 0)
        }
    }

    /// 0 = wide open, 1 = fully shut.
    var lid: CGFloat {
        switch self {
        case .waiting:        return 0.42      // permanently unimpressed
        case .thinking:       return 0.66
        case .verdict(let s): return s >= 80 ? 0.12 : (s < 35 ? 0.55 : 0.34)
        }
    }

    var browAngle: Double {
        switch self {
        case .waiting:        return 9
        case .thinking:       return 17
        case .verdict(let s): return s >= 80 ? -6 : (s < 35 ? 20 : 9)
        }
    }
}

/// An original flat illustration of a very unimpressed dog in a cap and hoodie,
/// composed entirely from SwiftUI primitives so it stays sharp at any size and
/// can animate. Designed against a 240pt box and scaled from there.
struct DogView: View {
    var mood: DogMood = .waiting
    var size: CGFloat = 240
    /// The icon artwork wants the head on its own, without the hoodie.
    var showBody: Bool = true
    /// Eyewear tells the characters apart at a glance.
    var accessory: DogAccessory = .none

    @State private var blink = false
    @State private var breathe = false

    private var u: CGFloat { size / 240 }   // one design unit

    var body: some View {
        ZStack {
            if showBody { hoodie }
            head
                .rotationEffect(.degrees(mood.headTilt), anchor: .bottom)
        }
        .frame(width: size, height: size * (showBody ? 1.15 : 1.0))
        .scaleEffect(breathe ? 1.015 : 1.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: mood)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
            scheduleBlink()
        }
    }

    // MARK: - Body and hood

    private var hoodie: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46 * u, style: .continuous)
                .fill(Theme.hoodie)
                .frame(width: 214 * u, height: 130 * u)
                .offset(y: 112 * u)
            // hood bunched behind the neck
            Capsule()
                .fill(Theme.hoodieLift)
                .frame(width: 158 * u, height: 62 * u)
                .offset(y: 74 * u)
            // neck
            Capsule()
                .fill(Theme.furDark)
                .frame(width: 78 * u, height: 66 * u)
                .offset(y: 58 * u)
        }
    }

    // MARK: - Head

    private var head: some View {
        ZStack {
            ears
            // skull
            Ellipse()
                .fill(Theme.fur)
                .frame(width: 174 * u, height: 158 * u)
            // subtle shading down the right side
            Ellipse()
                .fill(Theme.furDark.opacity(0.28))
                .frame(width: 174 * u, height: 158 * u)
                .mask(
                    Rectangle()
                        .frame(width: 60 * u, height: 158 * u)
                        .offset(x: 57 * u)
                )
            muzzle
            eyes
            brows
            cap
            eyewear
        }
    }

    @ViewBuilder
    private var eyewear: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .sunglasses:
            // Two lenses and a bridge, not one bar - a single wide rectangle
            // reads as a censor strip rather than shades.
            ZStack {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    RoundedRectangle(cornerRadius: 13 * u, style: .continuous)
                        .fill(Color.black.opacity(0.88))
                        .frame(width: 46 * u, height: 34 * u)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13 * u, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 46 * u, height: 11 * u)
                                .offset(y: -9 * u)
                        )
                        .offset(x: side * 34 * u)
                }
                Rectangle()
                    .fill(Color.black.opacity(0.88))
                    .frame(width: 24 * u, height: 7 * u)
                    .offset(y: -3 * u)
                // arms reaching back toward the ears
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 22 * u, height: 6 * u)
                        .offset(x: side * 66 * u, y: -6 * u)
                }
            }
            .offset(y: -15 * u)
        case .roundGlasses:
            ZStack {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: 5 * u)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                        .frame(width: 42 * u, height: 42 * u)
                        .offset(x: side * 34 * u)
                }
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 26 * u, height: 4.5 * u)
            }
            .offset(y: -14 * u)
        }
    }

    private var ears: some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(Theme.furDark)
                    .frame(width: 50 * u, height: 82 * u)
                    .rotationEffect(.degrees(side * 20))
                    .offset(x: side * 86 * u, y: 0 * u)
            }
        }
    }

    private var muzzle: some View {
        ZStack {
            Ellipse()
                .fill(Theme.furLight)
                .frame(width: 116 * u, height: 82 * u)
                .offset(y: 36 * u)
            // nose
            RoundedRectangle(cornerRadius: 13 * u, style: .continuous)
                .fill(Theme.snout)
                .frame(width: 42 * u, height: 30 * u)
                .offset(y: 16 * u)
            // nostrils
            HStack(spacing: 12 * u) {
                Capsule().fill(Theme.furLight.opacity(0.45)).frame(width: 5 * u, height: 10 * u)
                Capsule().fill(Theme.furLight.opacity(0.45)).frame(width: 5 * u, height: 10 * u)
            }
            .offset(y: 17 * u)
            // mouth: a flat, unamused line that dips at each end
            MouthShape()
                .stroke(Theme.snout.opacity(0.75), style: StrokeStyle(lineWidth: 4 * u, lineCap: .round))
                .frame(width: 64 * u, height: 22 * u)
                .offset(y: 48 * u)
        }
    }

    private var eyes: some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                ZStack {
                    Circle()
                        .fill(Theme.snout)
                        .frame(width: 28 * u, height: 28 * u)
                    // catchlight
                    Circle()
                        .fill(Theme.cream.opacity(0.9))
                        .frame(width: 8 * u, height: 8 * u)
                        .offset(x: -5 * u, y: -6 * u)
                    // heavy lid: the whole personality lives here
                    Rectangle()
                        .fill(Theme.fur)
                        .frame(width: 32 * u, height: 32 * u * currentLid)
                        .offset(y: -16 * u + (16 * u * currentLid))
                }
                .frame(width: 28 * u, height: 28 * u)
                .clipShape(Circle())
                .offset(x: side * 34 * u, y: -14 * u)
            }
        }
    }

    private var brows: some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                RoundedRectangle(cornerRadius: 6 * u, style: .continuous)
                    .fill(Theme.furDark)
                    .frame(width: 42 * u, height: 12 * u)
                    .rotationEffect(.degrees(side * mood.browAngle))
                    .offset(x: side * 36 * u, y: -38 * u)
            }
        }
    }

    private var cap: some View {
        ZStack {
            // dome
            Ellipse()
                .fill(Theme.cap)
                .frame(width: 178 * u, height: 94 * u)
                .offset(y: -64 * u)
            // brim
            Ellipse()
                .fill(Theme.cap)
                .frame(width: 190 * u, height: 44 * u)
                .offset(y: -46 * u)
            // button on top
            Circle()
                .fill(Theme.capLift)
                .frame(width: 14 * u, height: 14 * u)
                .offset(y: -108 * u)
        }
    }

    // MARK: - Blinking

    private var currentLid: CGFloat {
        blink ? 1.0 : mood.lid
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.4...5.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.07)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.easeOut(duration: 0.1)) { blink = false }
                scheduleBlink()
            }
        }
    }
}

/// What the character is wearing on its face.
enum DogAccessory {
    case none, sunglasses, roundGlasses
}

/// A flat mouth line that turns down slightly at both ends.
private struct MouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height * 0.55))
        p.addQuadCurve(
            to: CGPoint(x: rect.width / 2, y: rect.height * 0.1),
            control: CGPoint(x: rect.width * 0.25, y: rect.height * 0.1)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.55),
            control: CGPoint(x: rect.width * 0.75, y: rect.height * 0.1)
        )
        return p
    }
}
