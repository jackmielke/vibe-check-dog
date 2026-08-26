import XCTest

final class VibeCheckUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch(_ args: [String] = ["-seedDemo"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += args
        app.launch()
        return app
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testDogPromptsForAVibeCheck() {
        let app = launch()
        XCTAssertTrue(app.buttons["takeVibeCheck"].waitForExistence(timeout: 6),
                      "The dog should offer to take a vibe check when none exists today")
    }

    func testTodaysResultIsRestoredOnLaunch() {
        let app = launch(["-seedDemo", "-seedToday"])
        XCTAssertTrue(app.staticTexts["vibeScore"].waitForExistence(timeout: 6),
                      "A check taken today should still be on screen after relaunch")
        XCTAssertEqual(app.staticTexts["vibeScore"].label, "71")
    }

    func testProfileOffersSignInWithApple() {
        let app = launch()
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["signInWithApple"].waitForExistence(timeout: 6))
    }

    func testLeaderboardLoadsRealEntries() {
        let app = launch()
        app.tabBars.buttons["Leaderboard"].tap()
        XCTAssertTrue(app.navigationBars["Vibe Leaderboard"].waitForExistence(timeout: 6))
        // The backend is live, so rows should arrive.
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 30),
                      "Leaderboard should render entries from the live backend")
    }

    func testLeaderboardSortTogglesBetweenTopAndRecent() {
        let app = launch()
        app.tabBars.buttons["Leaderboard"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 30))

        // "Top vibes" is score-ordered, so the first row should be a high score.
        let topFirst = app.cells.firstMatch.staticTexts.allElementsBoundByIndex.map(\.label)

        app.buttons["Most recent"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 30))
        // Give the reload a moment to replace the rows.
        Thread.sleep(forTimeInterval: 3)
        let recentFirst = app.cells.firstMatch.staticTexts.allElementsBoundByIndex.map(\.label)

        XCTAssertNotEqual(topFirst, recentFirst,
                          "Switching to Most recent should change which entry is first")
    }

    func testTappingAnEntryOpensDetail() {
        let app = launch()
        app.tabBars.buttons["Leaderboard"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 30))
        app.cells.firstMatch.tap()
        // The detail view is titled with the poster's name and shows a back button.
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 6),
                      "Tapping a leaderboard entry should push a detail view")
    }

    func testCaptureScreenshots() {
        let app = launch(["-seedDemo"])
        XCTAssertTrue(app.buttons["takeVibeCheck"].waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 1.2)
        shoot(app, "01-dog-prompt")

        app.terminate()
        let seeded = launch(["-seedDemo", "-seedToday"])
        XCTAssertTrue(seeded.staticTexts["vibeScore"].waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 1.2)
        shoot(seeded, "02-verdict")

        seeded.tabBars.buttons["Leaderboard"].tap()
        Thread.sleep(forTimeInterval: 6.0)      // let photos download
        shoot(seeded, "03-leaderboard")

        seeded.tabBars.buttons["You"].tap()
        Thread.sleep(forTimeInterval: 1.2)
        shoot(seeded, "04-you")
    }
}
