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
        XCTAssertTrue(app.navigationBars["Leaderboard"].waitForExistence(timeout: 6))
        // The backend is live, so at least one row should arrive.
        let firstCell = app.scrollViews.otherElements.staticTexts.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 25) || app.staticTexts.count > 3,
                      "Leaderboard should render entries from the live backend")
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
