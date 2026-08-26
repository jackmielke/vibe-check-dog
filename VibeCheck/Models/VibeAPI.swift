import UIKit

/// Talks to the existing Supabase edge functions behind Vibe Check.
/// The anon key is a publishable key - it is designed to ship in clients.
enum VibeAPI {
    // Jack's own Supabase project. Scoring runs on OpenRouter with the key held
    // server-side; the app only ever holds the publishable key.
    private static let base = "https://hkakpvfytmuqpjympmwx.supabase.co/functions/v1"
    private static let anonKey = "sb_publishable_dogOXtLQrX6WzGrNO7hIQw_Qn3FHgns"

    enum APIError: LocalizedError {
        case badResponse(Int)
        case decoding
        case message(String)

        var errorDescription: String? {
            switch self {
            case .badResponse(let code) where code == 429:
                return "The dog is overwhelmed. Try again in a minute."
            case .badResponse:
                return "The dog could not be reached. Check your connection."
            case .decoding:
                return "The dog said something incomprehensible."
            case .message(let m):
                return m
            }
        }
    }

    private static func request(_ path: String, method: String, body: Data? = nil) -> URLRequest {
        var r = URLRequest(url: URL(string: "\(base)/\(path)")!)
        r.httpMethod = method
        r.setValue(anonKey, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = body
        r.timeoutInterval = 90        // vision models are not fast
        return r
    }

    private static func send(_ r: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw APIError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            // The functions return {"error": "..."} on failure; surface it if present.
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String {
                throw APIError.message(msg)
            }
            throw APIError.badResponse(http.statusCode)
        }
        return data
    }

    // MARK: - Scoring

    struct Rating: Decodable {
        let score: Int
        let analysis: String
    }

    /// Scores a photo without posting it anywhere. Used before sign-in.
    static func analyze(image: UIImage, persona: String) async throws -> Rating {
        let payload = ["imageData": image.vibeDataURL(), "persona": persona]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(request("analyze-vibe", method: "POST", body: body))
        guard let r = try? JSONDecoder().decode(Rating.self, from: data) else { throw APIError.decoding }
        return r
    }

    /// Scores a photo, uploads it, and puts it on the public leaderboard.
    /// `ownerKey` is what later lets this device delete its own posts.
    static func submit(image: UIImage, name: String, ownerKey: String, persona: String) async throws -> LeaderboardEntry {
        let payload = ["imageData": image.vibeDataURL(), "name": name,
                       "ownerKey": ownerKey, "persona": persona]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(request("submit-vibe", method: "POST", body: body))
        struct Wrapper: Decodable { let success: Bool; let data: LeaderboardEntry }
        guard let w = try? JSONDecoder().decode(Wrapper.self, from: data) else { throw APIError.decoding }
        return w.data
    }

    /// Removes this owner's posts from the public leaderboard, photos included.
    /// Used by account deletion, which App Review requires for Sign in with Apple.
    @discardableResult
    static func deletePosts(ownerKey: String) async throws -> Int {
        let body = try JSONSerialization.data(withJSONObject: ["ownerKey": ownerKey])
        let data = try await send(request("delete-vibe", method: "POST", body: body))
        struct Wrapper: Decodable { let success: Bool; let deleted: Int }
        return (try? JSONDecoder().decode(Wrapper.self, from: data))?.deleted ?? 0
    }

    // MARK: - Leaderboard

    enum Sort: String { case top, recent }

    static func leaderboard(limit: Int = 100, sort: Sort = .top) async throws -> [LeaderboardEntry] {
        let data = try await send(request("leaderboard-api?limit=\(limit)&sort=\(sort.rawValue)", method: "GET"))
        struct Wrapper: Decodable { let success: Bool; let data: [LeaderboardEntry] }
        guard let w = try? JSONDecoder().decode(Wrapper.self, from: data) else { throw APIError.decoding }
        return w.data
    }
}

extension UIImage {
    /// Downscale and compress before sending - full-resolution selfies are far
    /// larger than the vision model needs and make the round trip slow.
    ///
    /// `UIImage.size` is in points, and UIGraphicsImageRenderer defaults to the
    /// screen scale, so the naive version of this renders 3x larger than asked
    /// on a 3x device. Work in pixels and pin the format scale to 1.
    func vibeDataURL(maxEdge: CGFloat = 1024, quality: CGFloat = 0.7) -> String {
        let pixels = CGSize(width: size.width * scale, height: size.height * scale)
        let factor = min(1, maxEdge / max(pixels.width, pixels.height))
        let target = CGSize(width: (pixels.width * factor).rounded(),
                            height: (pixels.height * factor).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        let jpeg = resized.jpegData(compressionQuality: quality) ?? Data()
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }
}
