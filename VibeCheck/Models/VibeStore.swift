import UIKit

/// One vibe check taken on this device.
struct VibeCheck: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var score: Int
    var analysis: String
    /// Filename inside the app's photos directory.
    var photoFile: String?
    /// True once this check has been posted to the public leaderboard.
    var posted: Bool = false
}

/// Local history. Everything here stays on device unless the user signs in and
/// explicitly posts, which is what makes the "keeps it local until then" promise real.
@MainActor
final class VibeStore: ObservableObject {
    @Published private(set) var checks: [VibeCheck] = []

    private let fileURL: URL
    private let photosDir: URL

    init(preloaded: [VibeCheck]? = nil) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("vibe-checks.json")
        photosDir = docs.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        if let preloaded { checks = preloaded } else { load() }
    }

    // MARK: - Today

    var todaysCheck: VibeCheck? {
        checks.first { Calendar.current.isDateInToday($0.date) }
    }

    var hasCheckedToday: Bool { todaysCheck != nil }

    var best: VibeCheck? { checks.max { $0.score < $1.score } }

    var average: Int {
        guard !checks.isEmpty else { return 0 }
        return Int((Double(checks.reduce(0) { $0 + $1.score }) / Double(checks.count)).rounded())
    }

    /// Consecutive days ending today or yesterday.
    var streak: Int {
        let cal = Calendar.current
        let days = Set(checks.map { cal.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        var cursor = cal.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let y = cal.date(byAdding: .day, value: -1, to: cursor), days.contains(y) else { return 0 }
            cursor = y
        }
        var n = 0
        while days.contains(cursor) {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return n
    }

    // MARK: - Mutation

    @discardableResult
    func record(score: Int, analysis: String, image: UIImage?, posted: Bool) -> VibeCheck {
        var file: String?
        if let image, let jpeg = image.jpegData(compressionQuality: 0.8) {
            let name = "\(UUID().uuidString).jpg"
            try? jpeg.write(to: photosDir.appendingPathComponent(name), options: .atomic)
            file = name
        }
        let check = VibeCheck(score: score, analysis: analysis, photoFile: file, posted: posted)
        checks.insert(check, at: 0)
        save()
        return check
    }

    func markPosted(_ check: VibeCheck) {
        guard let i = checks.firstIndex(where: { $0.id == check.id }) else { return }
        checks[i].posted = true
        save()
    }

    func photo(for check: VibeCheck) -> UIImage? {
        guard let file = check.photoFile else { return nil }
        return UIImage(contentsOfFile: photosDir.appendingPathComponent(file).path)
    }

    func delete(_ check: VibeCheck) {
        if let file = check.photoFile {
            try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(file))
        }
        checks.removeAll { $0.id == check.id }
        save()
    }

    func clearAll() {
        for c in checks where c.photoFile != nil {
            try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(c.photoFile!))
        }
        checks.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([VibeCheck].self, from: data) else { return }
        checks = decoded.sorted { $0.date > $1.date }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(checks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
