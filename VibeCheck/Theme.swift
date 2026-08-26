import SwiftUI

/// Warm, dark, and a bit silly. Dark-only by design.
enum Theme {
    static let bg        = Color(red: 0.078, green: 0.075, blue: 0.098)
    static let bgLift    = Color(red: 0.129, green: 0.125, blue: 0.157)
    static let card      = Color(red: 0.157, green: 0.153, blue: 0.192)
    static let cream     = Color(red: 0.965, green: 0.945, blue: 0.906)
    static let accent    = Color(red: 1.000, green: 0.686, blue: 0.259)
    static let muted     = Color(red: 0.596, green: 0.580, blue: 0.639)

    // The dog
    static let fur       = Color(red: 0.545, green: 0.475, blue: 0.424)
    static let furDark   = Color(red: 0.404, green: 0.345, blue: 0.310)
    static let furLight  = Color(red: 0.792, green: 0.729, blue: 0.671)
    static let snout     = Color(red: 0.161, green: 0.137, blue: 0.145)
    static let cap       = Color(red: 0.106, green: 0.118, blue: 0.180)
    static let capLift   = Color(red: 0.169, green: 0.184, blue: 0.259)
    static let hoodie    = Color(red: 0.145, green: 0.180, blue: 0.310)
    static let hoodieLift = Color(red: 0.204, green: 0.243, blue: 0.396)

    static let backdrop = LinearGradient(
        colors: [Color(red: 0.098, green: 0.090, blue: 0.125), bg],
        startPoint: .top, endPoint: .bottom
    )

    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Colour for a 0-100 vibe score.
    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case ..<35:  return Color(red: 0.914, green: 0.353, blue: 0.353)
        case ..<60:  return Color(red: 0.965, green: 0.620, blue: 0.286)
        case ..<80:  return accent
        default:     return Color(red: 0.408, green: 0.851, blue: 0.573)
        }
    }
}

extension View {
    func vibeCard(_ padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
    }
}
