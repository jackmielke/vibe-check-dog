import XCTest
@testable import Vibe_Check

/// These cover shapes that the live backend actually returns and that the
/// obvious decoder gets wrong.
final class LeaderboardEntryTests: XCTestCase {

    private func decode(_ json: String) throws -> LeaderboardEntry {
        try JSONDecoder().decode(LeaderboardEntry.self, from: Data(json.utf8))
    }

    func testWholeNumberScore() throws {
        let e = try decode(#"{"id":"a","name":"Cait","score":87}"#)
        XCTAssertEqual(e.score, 87)
    }

    func testFractionalScoreIsRoundedNotDroppedToZero() throws {
        // A real row: the model returned 88.5 and the Int-only decoder read it as 0,
        // which sorted a high score to the bottom of the leaderboard.
        let e = try decode(#"{"id":"b","name":"Lauren","score":88.5}"#)
        XCTAssertEqual(e.score, 89)
    }

    func testStringScore() throws {
        let e = try decode(#"{"id":"c","name":"X","score":"73"}"#)
        XCTAssertEqual(e.score, 73)
    }

    func testMissingScoreFallsBackToZero() throws {
        let e = try decode(#"{"id":"d","name":"X"}"#)
        XCTAssertEqual(e.score, 0)
    }

    func testMissingNameFallsBackToAnonymous() throws {
        let e = try decode(#"{"id":"e","score":10}"#)
        XCTAssertEqual(e.name, "Anonymous")
    }

    func testTimestampWithSixFractionalDigits() throws {
        let e = try decode(#"{"id":"f","name":"X","score":1,"created_at":"2025-10-27T03:12:49.220221+00:00"}"#)
        XCTAssertNotNil(e.createdAt, "Postgres microsecond timestamps must parse")
    }

    func testTimestampWithFiveFractionalDigits() throws {
        let e = try decode(#"{"id":"g","name":"X","score":1,"created_at":"2026-06-27T08:12:48.57929+00:00"}"#)
        XCTAssertNotNil(e.createdAt, "Variable-length fractional seconds must parse")
    }

    func testTimestampWithoutFraction() throws {
        let e = try decode(#"{"id":"h","name":"X","score":1,"created_at":"2026-06-27T08:12:48Z"}"#)
        XCTAssertNotNil(e.createdAt)
    }
}
