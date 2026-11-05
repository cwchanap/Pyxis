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
            "battle-falconridge-ruined",
            "battle-captain-deployed",
            "battle-rally-active",
            "battle-guard-animation",
            "battle-highcrest-wave",
            "battle-highcrest-shutdown",
            "battle-blocked",
            "camp-empty",
            "camp-occupied",
            "map",
            "map-partial",
            "map-country-complete",
            "conquest-live",
            "conquest-idle",
            "battle-damaged",
            "battle-breached",
            "battle-emberford",
            "battle-runewatch",
            "battle-crownspire",
            "return-damage"
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
    }

    @MainActor
    func testForgedSettingsToggleUpdatesSemanticValue393x852() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 5), "Baseline app did not launch.")
        guard app.frame.size == CGSize(width: 393, height: 852) else {
            throw XCTSkip(
                "Settings evidence requires logical 393x852; got "
                    + "\(Int(app.frame.width))x\(Int(app.frame.height))."
            )
        }
        app.terminate()

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
        XCTAssertTrue(
            after?.hasPrefix("Settings;") == true,
            "Settings did not stay presented across the toggle."
        )
        add(self.screenshotAttachment(for: app, name: "forged-settings-toggle-native-393x852"))
    }

    private func assertSemanticValue(
        _ value: String?,
        for fixture: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected: String?
        switch fixture {
        case "battle", "battle-falconridge-ruined", "battle-captain-deployed", "battle-rally-active",
             "battle-guard-animation", "battle-highcrest-wave", "battle-highcrest-shutdown",
             "battle-blocked", "battle-damaged", "battle-breached",
             "battle-emberford", "battle-runewatch", "battle-crownspire", "return-damage":
            expected = battleSemanticValue(for: fixture)
        case "camp-empty", "camp-occupied":
            expected = campSemanticValue(for: fixture)
        case "map", "map-partial", "map-country-complete":
            expected = mapSemanticValue(for: fixture)
        case "conquest-live", "conquest-idle":
            expected = conquestSemanticValue(for: fixture)
        default:
            XCTFail("Unexpected fixture: " + fixture, file: file, line: line)
            return
        }

        XCTAssertEqual(value, expected, file: file, line: line)
    }

    private func battleSemanticValue(for fixture: String) -> String {
        if let tacticalValue = tacticalBattleSemanticValue(for: fixture) {
            return tacticalValue
        }
        switch fixture {
        case "battle", "battle-falconridge-ruined":
            return "Battle;stage=battleActive;mode=normal;city=1-3;manualLiving=0;"
                + "family=frontier;fortress=intact;captain=deployed;rally=inactive;protected=0"
        case "battle-blocked":
            return "Battle;stage=battleActive;mode=blocked;city=1-3;manualLiving=1;"
                + "family=frontier;fortress=intact;"
                + "feedback=Finish the current squad before building.;captain=deployed;rally=inactive;protected=0"
        case "battle-damaged":
            return "Battle;stage=battleActive;mode=normal;city=1-1;manualLiving=0;"
                + "family=frontier;fortress=damaged;captain=absent;rally=inactive;protected=0"
        case "battle-breached":
            return "Battle;stage=battleActive;mode=normal;city=1-1;manualLiving=0;"
                + "family=frontier;fortress=breached;captain=absent;rally=inactive;protected=0"
        case "battle-emberford":
            return "Battle;stage=battleActive;mode=normal;city=1-7;manualLiving=0;"
                + "family=ember;fortress=intact;captain=deployed;rally=inactive;protected=0"
        case "battle-runewatch":
            return "Battle;stage=battleActive;mode=normal;city=1-9;manualLiving=0;"
                + "family=arcane;fortress=intact;captain=deployed;rally=inactive;protected=0"
        case "battle-crownspire":
            return "Battle;stage=battleActive;mode=normal;city=1-15;manualLiving=0;"
                + "family=royal;fortress=intact;captain=deployed;rally=inactive;protected=0"
        case "return-damage":
            return "Battle;stage=battleActive;mode=normal;city=1-3;manualLiving=0;"
                + "family=frontier;fortress=damaged;"
                + "feedback=Buildings dealt 24 idle damage.;captain=deployed;rally=inactive;protected=0"
        default:
            return ""
        }
    }

    private func tacticalBattleSemanticValue(for fixture: String) -> String? {
        switch fixture {
        case "battle-captain-deployed":
            return "Battle;stage=battleActive;mode=normal;city=1-5;manualLiving=0;"
                + "family=frontier;fortress=intact;captain=deployed;rally=inactive;protected=0"
        case "battle-rally-active":
            return "Battle;stage=battleActive;mode=blocked;city=1-5;manualLiving=1;"
                + "family=frontier;fortress=intact;captain=deployed;rally=active;protected=1"
        case "battle-guard-animation":
            return "Battle;stage=battleActive;mode=blocked;city=1-5;manualLiving=1;"
                + "family=frontier;fortress=intact;captain=deployed;rally=inactive;protected=0"
        case "battle-highcrest-wave", "battle-highcrest-shutdown":
            return "Battle;stage=battleActive;mode=normal;city=1-5;manualLiving=0;"
                + "family=frontier;fortress=intact;captain=deployed;rally=inactive;protected=0"
        default:
            return nil
        }
    }

    private func campSemanticValue(for fixture: String) -> String {
        switch fixture {
        case "camp-empty":
            return "Camp;stage=battleActive;city=1-5;buildings=0;"
                + "selectedSlot=1;mode=builder"
        case "camp-occupied":
            return "Camp;stage=battleActive;city=1-5;buildings=6;"
                + "selectedSlot=1;mode=inspector"
        default:
            return ""
        }
    }

    private func mapSemanticValue(for fixture: String) -> String {
        switch fixture {
        case "map":
            return "Map;stage=cityConqueredPendingMap;completed=3;"
                + "attackableCity=4;laterLockedCity=5;"
                + "secured=3;caravan=1,2;patch=lk-map-route-6-7-worn"
        case "map-partial":
            // Fixture is pendingMap with city 8; init normalization makes city 8
            // the just-conquered city (completed=8), so city 9 is the unlock.
            return "Map;stage=cityConqueredPendingMap;completed=8;"
                + "attackableCity=9;laterLockedCity=10;"
                + "secured=8;caravan=1,2;patch=lk-map-route-6-7-repaired"
        case "map-country-complete":
            return "Map;stage=countryComplete;completed=15;"
                + "attackableCity=none;laterLockedCity=none;"
                + "secured=15;caravan=1,2;patch=lk-map-route-6-7-repaired"
        default:
            return ""
        }
    }

    private func conquestSemanticValue(for fixture: String) -> String {
        switch fixture {
        case "conquest-live":
            return "Conquest;pending=true;mode=live;city=1-3;"
                + "source=manual;deployments=6;losses=1"
        case "conquest-idle":
            return "Conquest;pending=true;mode=idle;city=1-3;"
                + "source=idle;deployments=0;losses=0;idleDamage=1"
        default:
            return ""
        }
    }

    /// HPA-672 evidence captures (Task 6): the real Ascension flow from the
    /// seeded `map-country-complete` fixture through production routing —
    /// Kingdom Ascend section → armed confirm → Battle City 1 at zero gold
    /// → a real manual-infantry replay conquest → the Lv 2 reward report →
    /// the post-ascension Renown header and Armory. Runs unfrozen (the
    /// replay conquest must really play). Taps go through the same
    /// SpriteKit-exposed node frames and chrome geometry the scenes
    /// author, and state assertions read the gameplay surface's semantic
    /// value — the same channels the forged-fixture parity smoke uses.
    /// Attachments are exported to `evidence/hpa-672/` on this PR.
    @MainActor
    func testHPA672AscensionFlowEvidence() throws {
        let app = XCUIApplication()
        app.launchArguments = [fixtureArgument, "map-country-complete"]
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 5), "Fixture did not launch.")
        let frame = app.frame
        guard frame.width >= 320, frame.height >= 500 else {
            throw XCTSkip("Ascension evidence requires a supported portrait viewport; got "
                + "\(Int(frame.width))x\(Int(frame.height)).")
        }
        let surface = app.otherElements["pyxisGameplaySurface"]
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        XCTAssertTrue(
            waitForSurfaceValue(surface, prefix: "Map;stage=countryComplete", timeout: 5),
            "The completed-country fixture did not present the Map."
        )

        // Map → Kingdom tab: the four gameplay tabs (battle, camp, map,
        // kingdom) share one bottom-bar geometry, so this coordinate tap
        // targets the real fourth tab hit frame.
        tap(app, at: kingdomTabPoint(mapTabGeometry: frame))
        let treasurySelector = topmostElement(labeled: "Treasury", in: app)
        XCTAssertTrue(
            treasurySelector.waitForExistence(timeout: 5),
            "Kingdom did not present its section selector row."
        )

        // 01 — the unarmed Ascend prompt with the section selected. The
        // selector label and the (unarmed) action label are both "Ascend";
        // the selector sits in the top header row, the action at the
        // bottom of the content band.
        let ascendSelector = topmostElement(labeled: "Ascend", in: app)
        tapCenter(of: ascendSelector, in: app)
        let action = bottommostElement(labeled: "Ascend", in: app)
        XCTAssertTrue(action.waitForExistence(timeout: 3), "Ascend action node missing.")
        add(screenshotAttachment(for: app, name: "hpa672-01-kingdom-ascend-prompt"))

        // 02 — the armed two-tap confirmation: the action's own label
        // becomes "Confirm Ascension" only while armed.
        tapCenter(of: action, in: app)
        let confirm = uniqueElement(labeled: "Confirm Ascension", in: app)
        XCTAssertTrue(
            confirm.waitForExistence(timeout: 3),
            "The first Ascend tap did not arm the confirmation."
        )
        add(screenshotAttachment(for: app, name: "hpa672-02-kingdom-ascend-armed"))

        // Cancel disarms without committing; re-arm, then the distinct
        // Confirm Ascension tap commits and routes to Battle (City 1).
        tapCenter(of: uniqueElement(labeled: "Cancel", in: app), in: app)
        XCTAssertTrue(
            waitForNonExistence(confirm, timeout: 3),
            "Cancel did not disarm the confirmation."
        )
        tapCenter(of: bottommostElement(labeled: "Ascend", in: app), in: app)
        XCTAssertTrue(
            confirm.waitForExistence(timeout: 3),
            "Re-arming after Cancel failed."
        )
        tapCenter(of: confirm, in: app)
        XCTAssertTrue(
            waitForSurfaceValue(surface, prefix: "Battle;stage=battleActive", timeout: 10),
            "Ascension did not route to the City 1 battle."
        )
        add(screenshotAttachment(for: app, name: "hpa672-03-battle-city1-zero-gold"))

        // Real replay conquest: manual infantry only (zero gold, no camp).
        // Extra taps are capped no-ops and the pending report swallows
        // them, so a generous fixed window is safe. Charges refill in real
        // time, hence the paced cadence.
        let deploy = deployActionPoint(battleChromeGeometry: frame)
        for _ in 0..<40 {
            tap(app, at: deploy)
            Thread.sleep(forTimeInterval: 0.9)
        }
        // The report's own Continue row ("MARCH ON") is the presented
        // signal — the surface value only republishes on scene
        // presentation, so it cannot announce an in-scene report.
        let marchOn = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "MARCH ON")).firstMatch
        XCTAssertTrue(
            marchOn.waitForExistence(timeout: 30),
            "The real manual-infantry replay conquest never completed."
        )
        // The repeat conquest's truthful receipt renders as the report's
        // fail-open gear line (owned item levels 1 → 2). HPA-671 never
        // renders the line on compact report heights (BattleScene's own
        // <780pt threshold), so it is only asserted where it renders.
        if frame.height >= 780 {
            let gearLine = app.descendants(matching: .any)
                .matching(
                    NSPredicate(format: "label == %@", "Gear upgraded: Willowford Blade · Lv 2")
                )
                .firstMatch
            XCTAssertTrue(
                gearLine.waitForExistence(timeout: 3),
                "The replay conquest report is missing its Lv 2 gear-upgrade line."
            )
        }
        add(screenshotAttachment(for: app, name: "hpa672-04-city1-replay-lv2-reward"))

        // Continue acknowledges the report and routes to the Map; the
        // surface value republishes at the Map presentation.
        tapCenter(of: marchOn, in: app)
        XCTAssertTrue(
            waitForSurfaceValue(
                surface, prefix: "Map;stage=cityConqueredPendingMap", timeout: 10
            ),
            "Continue never acknowledged the Lv 2 report and routed to the Map."
        )

        // Map → Kingdom: the post-ascension bottom header reads the Renown
        // summary (rendered only while ascensionCount > 0), and the Armory
        // infantry row reflects its leveled Lv 2 blade already equipped —
        // matching a real run where the first-earned drop was auto-equipped.
        tap(app, at: kingdomTabPoint(mapTabGeometry: frame))
        let renown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Renown 1 · +25%"))
            .firstMatch
        XCTAssertTrue(
            renown.waitForExistence(timeout: 5),
            "The Renown header is missing after ascension."
        )
        tapCenter(of: topmostElement(labeled: "Armory", in: app), in: app)
        let equippedRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Infantry · Willowford Blade"))
            .firstMatch
        XCTAssertTrue(
            equippedRow.waitForExistence(timeout: 5),
            "The Armory did not present the City 1 infantry row."
        )
        let infantryLv2 = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Attack Lv 2"))
            .firstMatch
        XCTAssertTrue(
            infantryLv2.waitForExistence(timeout: 5),
            "The leveled City 1 blade did not read its Lv 2 effect."
        )
        add(screenshotAttachment(for: app, name: "hpa672-05-kingdom-renown-armory-lv2"))

        app.terminate()
    }

    private func tap(_ app: XCUIApplication, at point: CGPoint) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: point.x, dy: point.y))
            .tap()
    }

    /// Taps the center of an accessibility element through a synthesized
    /// coordinate touch, so SpriteKit's own hit testing receives it.
    private func tapCenter(of element: XCUIElement, in app: XCUIApplication) {
        let frame = element.frame
        tap(app, at: CGPoint(x: frame.midX, y: frame.midY))
    }

    private func waitForSurfaceValue(
        _ surface: XCUIElement,
        prefix: String,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "value BEGINSWITH %@", prefix)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: surface)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result == .completed { return true }
        // XCUIElement sometimes needs a re-fetch after a scene swap.
        return (surface.value as? String)?.hasPrefix(prefix) == true
    }

    private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == %@", NSNumber(value: false))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
            || element.exists == false
    }

    /// SpriteKit exposes the scene's labels with real screen frames, but a
    /// label can appear on several (hidden) nodes at once — e.g. both the
    /// Ascend selector and the unarmed Ascend action read "Ascend" — so
    /// taps pick the occurrence by vertical position in the layout.
    private func topmostElement(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        element(labeled: label, in: app, orderedBy: { $0.frame.minY < $1.frame.minY })
    }

    private func bottommostElement(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        element(labeled: label, in: app, orderedBy: { $0.frame.minY > $1.frame.minY })
    }

    private func uniqueElement(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        visibleElements(labeled: label, in: app).first
            ?? app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func element(
        labeled label: String,
        in app: XCUIApplication,
        orderedBy areInIncreasingOrder: (XCUIElement, XCUIElement) -> Bool
    ) -> XCUIElement {
        visibleElements(labeled: label, in: app)
            .sorted(by: areInIncreasingOrder).first
            ?? app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func visibleElements(labeled label: String, in app: XCUIApplication) -> [XCUIElement] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .allElementsBoundByIndex
            .filter { $0.frame.width > 0 && $0.frame.height > 0 }
    }

    /// Mirrors `CountryMapScene.layoutGameplayTabBar` (and KingdomLayout's
    /// identical content column): four tabs across the full width minus the
    /// horizontal margins, hit band centered at 60pt above the bottom edge.
    /// Kingdom is the fourth tab (battle, camp, map, kingdom).
    private func kingdomTabPoint(mapTabGeometry frame: CGRect) -> CGPoint {
        let margin = frame.width <= 440
            ? 16.0
            : min(22.0, max(16.0, frame.width * 0.05))
        let tabWidth = frame.width - margin * 2
        return CGPoint(x: margin + tabWidth * 7 / 8, y: frame.height - 60)
    }

    /// Mirrors `BattleChromeLayout`'s deploy frame: the Deploy action is
    /// the ~56-58pt band left of the Captain strip — scene y 90 (reference)
    /// or 10pt above the 82pt tab bar + half the 56pt height (compact) —
    /// both centered at ~119-120pt above the bottom edge.
    private func deployActionPoint(battleChromeGeometry frame: CGRect) -> CGPoint {
        let contentWidth = min(560.0, frame.width - 32)
        let contentX = (frame.width - contentWidth) / 2
        return CGPoint(
            x: contentX + (contentWidth - 140) / 2,
            y: frame.height - (frame.height < 780 ? 120 : 119)
        )
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
