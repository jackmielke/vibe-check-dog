import UIKit

/// Talks to the existing Supabase edge functions behind Vibe Check.
/// The anon key is a publishable key - it is designed to ship in clients.
enum VibeAPI {
    private static let base = "https://hzrdpoyxamsptfbgrhru.supabase.co/functions/v1"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh6cmRwb3l4YW1zcHRmYmdyaHJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA4MDA0MzUsImV4cCI6MjA3NjM3NjQzNX0.WPUeaxtfH-wyGK7BUKNUT8V1FgO63ygEiKTva-j7GAU"

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
    static func analyze(image: UIImage) async throws -> Rating {
        let payload = ["imageData": image.vibeDataURL()]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(request("analyze-vibe", method: "POST", body: body))
        guard let r = try? JSONDecoder().decode(Rating.self, from: data) else { throw APIError.decoding }
        return r
    }

    /// Scores a photo, uploads it, and puts it on the public leaderboard.
    static func submit(image: UIImage, name: String) async throws -> LeaderboardEntry {
        let payload = ["imageData": image.vibeDataURL(), "name": name]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(request("submit-vibe", method: "POST", body: body))
        struct Wrapper: Decodable { let success: Bool; let data: LeaderboardEntry }
        guard let w = try? JSONDecoder().decode(Wrapper.self, from: data) else { throw APIError.decoding }
        return w.data
    }

    // MARK: - Leaderboard

    static func leaderboard(limit: Int = 100) async throws -> [LeaderboardEntry] {
        let data = try await send(request("leaderboard-api?limit=\(limit)", method: "GET"))
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
