import SwiftUI

/// Who is judging you. Each character has its own artwork *and* its own
/// scoring criteria on the server, so switching genuinely changes the verdict.
enum Mascot: String, CaseIterable, Identifiable {
    case original      // the deadpan photo from the original app
    case drawn         // the SwiftUI illustration, same judge
    case chill         // extremely relaxed, only cares how chilled out you look
    case critic        // insufferable art critic, judges composition

    var id: String { rawValue }

    /// The persona id sent to the scoring function.
    var persona: String {
        switch self {
        case .original, .drawn: return "dog"
        case .chill:            return "chill"
        case .critic:           return "critic"
        }
    }

    var title: String {
        switch self {
        case .original: return "The Dog"
        case .drawn:    return "Cartoon Dog"
        case .chill:    return "Chill Dog"
        case .critic:   return "The Critic"
        }
    }

    var blurb: String {
        switch self {
        case .original: return "Judges how together you look."
        case .drawn:    return "Same judge, fewer pixels."
        case .chill:    return "Only cares how relaxed you are."
        case .critic:   return "Judges it as fine art."
        }
    }

    var accessory: DogAccessory {
        switch self {
        case .chill:  return .sunglasses
        case .critic: return .roundGlasses
        default:      return .none
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
                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.85), lineWidth: 4))
                .shadow(color: Theme.accent.opacity(glow), radius: glowRadius)
                .scaleEffect(mood == .thinking ? 0.97 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: mood)
        default:
            DogView(mood: mood, size: size, accessory: mascot.accessory)
        }
    }

    private var glow: Double {
        if case .verdict(let s) = mood { return s >= 80 ? 0.55 : 0.22 }
        return 0.28
    }

    private var glowRadius: CGFloat {
        if case .verdict(let s) = mood { return s >= 80 ? 34 : 18 }
        return 20
    }
}
