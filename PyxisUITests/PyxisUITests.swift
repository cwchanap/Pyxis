//
//  PyxisUITests.swift
//  PyxisUITests
//
//  Created by Chan Wai Chan on 5/5/2026.
//

import XCTest

final class PyxisUITests: XCTestCase {

    private let fixtureArgument = "-pyxis-forged-fixture"
    private let freezeCombatArgument = "-pyxis-freeze-combat"

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLaunchesGameScene() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testForgedFixtureParitySmoke393x852() throws {
        let app = XCUIApplication()

        let fixtures = [
            "battle",
            "battle-blocked",
            "camp-empty",
            "camp-occupied",
            "map",
            "map-country-complete",
            "conquest-live",
            "conquest-idle"
        ]

        for fixture in fixtures {
            app.launchArguments = [fixtureArgument, fixture, freezeCombatArgument]
            app.launch()
            XCTAssertTrue(app.waitForExistence(timeout: 5), "Fixture " + fixture + " did not launch.")
            XCTAssertEqual(app.state, .runningForeground, "Fixture " + fixture + " did not stay foreground.")
            XCTAssertEqual(
                app.frame.size,
                CGSize(width: 393, height: 852),
                "Run this smoke on the dedicated native iPhone 15 Pro 393x852 destination."
            )
            XCTAssertTrue(
                app.otherElements["pyxisGameplaySurface"].waitForExistence(timeout: 2),
                "Fixture " + fixture + " did not expose the gameplay surface."
            )
            let gameplaySurface = app.otherElements["pyxisGameplaySurface"]
            XCTAssertEqual(gameplaySurface.value as? String, fixture)
            add(self.screenshotAttachment(for: app, name: "forged-" + fixture + "-native-393x852"))
            if fixture == "map" {
                add(self.screenshotAttachment(for: app, name: "forged-map-attackable-native-393x852"))
                add(self.screenshotAttachment(for: app, name: "forged-map-locked-native-393x852"))
            }
            app.terminate()
        }

        app.launchArguments = [fixtureArgument, "battle", freezeCombatArgument]
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 5))

        let gameplaySurface = app.otherElements["pyxisGameplaySurface"]
        XCTAssertTrue(gameplaySurface.waitForExistence(timeout: 2))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.10)).tap()
        XCTAssertTrue(
            (gameplaySurface.value as? String)?.hasPrefix("Settings;") == true,
            "Settings did not open."
        )
        let before = gameplaySurface.value as? String
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.84)).tap()
        let after = gameplaySurface.value as? String
        XCTAssertNotEqual(before, after, "Settings toggle did not update its semantic value.")
        add(self.screenshotAttachment(for: app, name: "forged-settings-toggle-native-393x852"))
    }

    private func screenshotAttachment(for app: XCUIApplication, name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
