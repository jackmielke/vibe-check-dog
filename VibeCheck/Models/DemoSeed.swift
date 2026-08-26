import Foundation

/// Fixtures for UI tests and screenshot runs. DEBUG only, so no seeding path
/// can reach a release build.
enum DemoSeed {
    static func preloadedChecks() -> [VibeCheck]? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo") else { return nil }
        let cal = Calendar.current
        let rows: [(Int, Int, String)] = [
            (1, 74, "Confident hair, questionable lighting. The jacket is doing heavy lifting."),
            (2, 41, "You look like you're about to explain a podcast to someone."),
            (3, 88, "Genuinely good. Annoying, but good."),
            (4, 29, "This is the face of someone who just checked their bank balance."),
            (5, 63, "Solid effort. The background is a war crime.")
        ]
        var seeded = rows.map { daysAgo, score, analysis in
            VibeCheck(date: cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
                      score: score, analysis: analysis, photoFile: nil, posted: daysAgo % 2 == 0)
        }
        // -seedToday additionally puts a check on today, so the result state renders.
        if ProcessInfo.processInfo.arguments.contains("-seedToday") {
            seeded.insert(VibeCheck(date: Date(), score: 71,
                                    analysis: "Decent energy, chaotic collar situation. The dog respects the attempt.",
                                    photoFile: nil, posted: false), at: 0)
        }
        return seeded
        #else
        return nil
        #endif
    }
}
