import SwiftUI

/// Who is judging you. The original photo is the default because it is funnier
/// than anything drawn; the vector dog stays as an alternative.
enum Mascot: String, CaseIterable, Identifiable {
    case original      // the deadpan photo from the original app
    case drawn         // the SwiftUI illustration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: return "The Dog"
        case .drawn:    return "Cartoon Dog"
        }
    }

    var blurb: String {
        switch self {
        case .original: return "Unimpressed. Photographic."
        case .drawn:    return "Same energy, fewer pixels."
        }
    }

    static var current: Mascot {
        Mascot(rawValue: UserDefaults.standard.string(forKey: "mascot") ?? "") ?? .original
    }
}

/// Renders whichever mascot is selected at a given size.
struct MascotView: View {
    var mascot: Mascot = .current
    var mood: DogMood = .waiting
    var size: CGFloat = 210

    var body: some View {
        switch mascot {
        case .original:
            Image("VibeBot")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(Theme.accent.opacity(0.85), lineWidth: 4)
                )
                .shadow(color: Theme.accent.opacity(glow), radius: glowRadius)
                .scaleEffect(mood == .thinking ? 0.97 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: mood)
        case .drawn:
            DogView(mood: mood, size: size)
        }
    }

    /// A hot verdict makes the ring glow harder.
    private var glow: Double {
        if case .verdict(let s) = mood { return s >= 80 ? 0.55 : 0.22 }
        return 0.28
    }

    private var glowRadius: CGFloat {
        if case .verdict(let s) = mood { return s >= 80 ? 34 : 18 }
        return 20
    }
}
