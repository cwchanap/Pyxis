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
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 5), "Baseline app did not launch.")
        let frame = app.frame
        guard frame.size == CGSize(width: 393, height: 852) else {
            throw XCTSkip(
                "Capture smoke requires logical 393x852; got "
                    + "\(Int(frame.width))x\(Int(frame.height))."
            )
        }
        app.terminate()

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
            XCTAssertTrue(
                app.otherElements["pyxisGameplaySurface"].waitForExistence(timeout: 2),
                "Fixture " + fixture + " did not expose the gameplay surface."
            )
            let gameplaySurface = app.otherElements["pyxisGameplaySurface"]
            assertSemanticValue(gameplaySurface.value as? String, for: fixture)
            add(self.screenshotAttachment(for: app, name: "forged-" + fixture + "-native-393x852"))
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

    private func assertSemanticValue(
        _ value: String?,
        for fixture: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected: String
        switch fixture {
        case "battle":
            expected = "Battle;stage=battleActive;mode=normal;city=1-3;manualLiving=0"
        case "battle-blocked":
            expected = "Battle;stage=battleActive;mode=blocked;city=1-3;manualLiving=1"
        case "camp-empty":
            expected = "Camp;stage=battleActive;city=1-5;buildings=0;"
                + "selectedSlot=1;mode=builder"
        case "camp-occupied":
            expected = "Camp;stage=battleActive;city=1-5;buildings=6;"
                + "selectedSlot=1;mode=inspector"
        case "map":
            expected = "Map;stage=cityConqueredPendingMap;completed=3;"
                + "attackableCity=4;laterLockedCity=5"
        case "map-country-complete":
            expected = "Map;stage=countryComplete;completed=15;"
                + "attackableCity=none;laterLockedCity=none"
        case "conquest-live":
            expected = "Conquest;pending=true;mode=live;city=1-3;"
                + "source=manual;deployments=6;losses=1"
        case "conquest-idle":
            expected = "Conquest;pending=true;mode=idle;city=1-3;"
                + "source=idle;deployments=0;losses=0;buildings=2;idleDamage=1"
        default:
            XCTFail("Unexpected fixture: " + fixture, file: file, line: line)
            return
        }

        XCTAssertEqual(value, expected, file: file, line: line)
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
