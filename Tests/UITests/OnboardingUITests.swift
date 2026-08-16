import XCTest

/// UI test scaffolding for the onboarding and logging flows (§0.6).
/// Fleshed out once the Xcode project is generated and running in CI on a
/// macOS host with simulators.
final class OnboardingUITests: XCTestCase {

    @MainActor
    func testOnboardingCompletesToTodayScreen() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Get started"].tap()
        app.buttons["Next: day boundary"].tap()
        app.buttons["Next: your goal"].tap()
        app.buttons["Finish"].tap()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
    }
}
