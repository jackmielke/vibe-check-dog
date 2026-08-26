import Foundation

/// A row on the public leaderboard, as returned by the edge functions.
struct LeaderboardEntry: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let score: Int
    let createdAt: Date?
    let imageURL: String?
    let vibeAnalysis: String?

    enum CodingKeys: String, CodingKey {
        case id, name, score
        case createdAt = "created_at"
        case imageURL = "image_url"
        case vibeAnalysis = "vibe_analysis"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Anonymous"
        score = LeaderboardEntry.decodeScore(from: c)
        imageURL = try? c.decodeIfPresent(String.self, forKey: .imageURL)
        vibeAnalysis = try? c.decodeIfPresent(String.self, forKey: .vibeAnalysis)
        // Postgres timestamps arrive with fractional seconds; the plain
        // ISO8601 formatter rejects those, so try both shapes.
        if let raw = try? c.decodeIfPresent(String.self, forKey: .createdAt) ?? nil {
            createdAt = LeaderboardEntry.parseDate(raw)
        } else {
            createdAt = nil
        }
    }

    init(id: String, name: String, score: Int, createdAt: Date?, imageURL: String?, vibeAnalysis: String?) {
        self.id = id; self.name = name; self.score = score
        self.createdAt = createdAt; self.imageURL = imageURL; self.vibeAnalysis = vibeAnalysis
    }

    /// The model occasionally returns a fractional score (88.5), and older rows
    /// may carry it as a string, so accept all three shapes rather than dropping
    /// the row to zero.
    static func decodeScore(from c: KeyedDecodingContainer<CodingKeys>) -> Int {
        if let i = try? c.decode(Int.self, forKey: .score) { return i }
        if let d = try? c.decode(Double.self, forKey: .score) { return Int(d.rounded()) }
        if let s = try? c.decode(String.self, forKey: .score), let d = Double(s) { return Int(d.rounded()) }
        return 0
    }

    /// Postgres emits a variable number of fractional-second digits (".57929"),
    /// which ISO8601DateFormatter rejects - it insists on exactly three. Trim the
    /// fraction and parse the plain form.
    static func parseDate(_ raw: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: raw) { return d }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: raw) { return d }

        // Strip ".123456" from between the seconds and the timezone offset.
        if let dot = raw.firstIndex(of: "."),
           let tzStart = raw[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let trimmed = String(raw[raw.startIndex..<dot]) + String(raw[tzStart...])
            return plain.date(from: trimmed)
        }
        return nil
    }
}
