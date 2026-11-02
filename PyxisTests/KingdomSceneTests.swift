//
//  KingdomSceneTests.swift
//  PyxisTests
//

import SpriteKit
import Testing
import UIKit
@testable import Pyxis

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

@MainActor
struct KingdomSceneTests {

    @Test func kingdomSceneShowsPersistedGold() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 123))
        let scene = makeScene(store: store)

        #expect(scene.titleTextForTesting == "Kingdom")
        #expect(scene.goldTextForTesting
            == "Gold " + CompactNumberFormatter.string(from: 123))
    }

    // MARK: - Treasury rows

    @Test("Exactly three Treasury rows show name, level, next effect and price with Buy enabled")
    func treasuryRowsShowContentAndEnabledBuy() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 123))
        let scene = makeScene(store: store)

        let warChest = try #require(scene.treasuryRowTextForTesting(.warChest))
        #expect(warChest.name == "War Chest")
        #expect(warChest.level == "Lv 0/4")
        #expect(warChest.price == "Cost 12 gold")
        #expect(warChest.effect.contains("→"))
        #expect(scene.isBuyEnabledForTesting(.warChest))

        let quartermaster = try #require(scene.treasuryRowTextForTesting(.quartermaster))
        #expect(quartermaster.name == "Quartermaster")
        #expect(quartermaster.level == "Lv 0/4")
        #expect(quartermaster.price == "Cost 14 gold")
        #expect(scene.isBuyEnabledForTesting(.quartermaster))
    }

    @Test("Max level replaces the price with MAX and disables Buy")
    func maxLevelShowsMaxAndDisablesBuy() throws {
        var state = KingdomGameState(gold: 100)
        state.treasury.setLevel(TreasuryUpgrade.warChest.maxLevel, for: .warChest)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        let warChest = try #require(scene.treasuryRowTextForTesting(.warChest))
        #expect(warChest.price == "MAX")
        #expect(!scene.isBuyEnabledForTesting(.warChest))
        #expect(scene.isBuyEnabledForTesting(.drillYard))
    }

    @Test("Unaffordable Buy stays disabled and still shows the disabled cost")
    func unaffordableBuyShowsDisabledCost() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 10))
        let scene = makeScene(store: store)

        let warChest = try #require(scene.treasuryRowTextForTesting(.warChest))
        #expect(warChest.price == "Cost 12 gold")
        #expect(!scene.isBuyEnabledForTesting(.warChest))
    }

    @Test("Drill Yard row shows the labeled rounded attack example with the no-change note")
    func drillYardRowShowsNoChangeExample() throws {
        // Default state: no camp buildings, infantry fallback level 1, City 1
        // standardWatch (neutral). 1 x 1.0 -> 1 and 1 x 1.05 -> 1, so the
        // example must not imply a guaranteed gain.
        let state = KingdomGameState(gold: 100)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        let drillYard = try #require(scene.treasuryRowTextForTesting(.drillYard))
        #expect(drillYard.effect == KingdomScene.drillYardExampleText(for: state))
        #expect(drillYard.effect == "Infantry Lv 1 vs this city's trait:\n1 → 1 attack (no damage change yet)")
    }

    @Test("Drill Yard example displays a real rounded gain when one exists")
    func drillYardExampleShowsRealGain() {
        // Infantry level 5 (base 4) at DY 2 -> 3 crosses the visible-gain
        // boundary inside the tuned 0...4 range: 4 x 1.10 -> 4, 4 x 1.15 -> 5,
        // so P -> Q must show a visible gain.
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: 1,
            cityBattleStates: [CityKey(
                countryNumber: 1,
                cityNumber: 1
            ).storageKey: CityBattleState(
                slots: [1: CityBuilding(type: .barracks, level: 5)]
            )]
        )
        state.treasury.setLevel(2, for: .drillYard)

        let text = KingdomScene.drillYardExampleText(for: state)
        #expect(text == "Infantry Lv 5 vs this city's trait:\n4 → 5 attack")
    }

    @Test("Header and row text labels sit inside their KingdomLayout text frames")
    func textLabelsSitInsideLayoutTextFrames() throws {
        // Compact phones included: the Drill Yard example must fit its text
        // frame (wrapped, fitted) on every size the layout accepts.
        for sceneSize in [
            CGSize(width: 393, height: 852),
            CGSize(width: 375, height: 812),
            CGSize(width: 320, height: 568)
        ] {
            let store = try makeStore(initialState: KingdomGameState(gold: 100))
            let scene = makeScene(size: sceneSize, store: store)
            let layout = try #require(scene.kingdomLayoutForTesting)

            let goldLabel = scene.goldLabelNodeForTesting
            let goldParent = try #require(goldLabel.parent)
            #expect(
                layout.goldFrame.contains(goldParent.convert(goldLabel.frame, to: scene)),
                "gold label outside header gold frame at \(sceneSize)"
            )

            let titleLabel = scene.titleLabelNodeForTesting
            let titleParent = try #require(titleLabel.parent)
            let titleSceneFrame = titleParent.convert(titleLabel.frame, to: scene)
            #expect(
                layout.titleFrame.contains(titleSceneFrame),
                "title label outside header title frame at \(sceneSize)"
            )
            // The title is center-aligned inside titleFrame — its midpoint
            // must land on the frame's, not the header panel's center.
            #expect(
                abs(titleSceneFrame.midX - layout.titleFrame.midX) < 1,
                "title label not centered in title frame at \(sceneSize)"
            )

            for (index, upgrade) in TreasuryUpgrade.allCases.enumerated() {
                let labels = try #require(scene.treasuryRowLabelNodesForTesting(upgrade))
                let textFrame = layout.textFrames[index]
                for label in labels {
                    let parent = try #require(label.parent)
                    #expect(
                        textFrame.contains(parent.convert(label.frame, to: scene)),
                        "\(upgrade) label '\(label.text ?? "")' outside its text frame at \(sceneSize)"
                    )
                }
            }
        }
    }

    // MARK: - Purchase flow

    @Test("Successful purchase persists once and redraws gold, level and price")
    func successfulPurchaseSavesOnceAndRedraws() throws {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(KingdomGameState(gold: 100))
        defaults.resetStateSaveCount()
        let scene = makeScene(store: store)
        defaults.resetStateSaveCount()

        let buyFrame = try #require(scene.buyHitFrameForTesting(.warChest))
        scene.handleTouchForTesting(at: buyFrame.center)

        let saved = store.load()
        #expect(saved.treasury.warChest == 1)
        #expect(saved.gold == 88)
        #expect(defaults.stateSaveCount == 1)
        #expect(scene.goldTextForTesting == "Gold " + CompactNumberFormatter.string(from: 88))
        let warChest = try #require(scene.treasuryRowTextForTesting(.warChest))
        #expect(warChest.level == "Lv 1/4")
        #expect(warChest.price == "Cost 22 gold")
    }

    @Test("Rejected purchase never spends gold or saves")
    func rejectedPurchaseNeverSaves() throws {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(KingdomGameState(gold: 10))
        defaults.resetStateSaveCount()
        let scene = makeScene(store: store)
        defaults.resetStateSaveCount()

        let buyFrame = try #require(scene.buyHitFrameForTesting(.warChest))
        scene.handleTouchForTesting(at: buyFrame.center)

        let saved = store.load()
        #expect(saved.gold == 10)
        #expect(saved.treasury == TreasuryState())
        #expect(defaults.stateSaveCount == 0)
    }

    @Test("A buy tap settles the armed interval before raising the Treasury level")
    func buySettlesArmedIntervalBeforePurchase() throws {
        // City 8 entry is nonlethal and re-arms the anchor; the buy settle
        // must credit the armed window at the OLD level (Drill Yard raises
        // attack only for intervals settled after the purchase).
        let start = Date(timeIntervalSinceNow: -60)
        var initialState = KingdomGameState(
            gold: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 8,
            completedCityCount: 7,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(store: store, router: RouteSpy())
        let entryAnchor = try #require(store.load().lastBackgroundedAt)

        // Stretch the armed window to one hour as if the player idled on
        // Kingdom before tapping Buy.
        var armed = store.load()
        let goldBeforeBuy = armed.gold
        let windowStart = entryAnchor.addingTimeInterval(-3_600)
        armed.lastBackgroundedAt = windowStart
        armed.cityBattleStates[armed.currentCityKey.storageKey]?
            .lastBuildingProgressResolvedAt = windowStart
        store.save(armed)

        let buyFrame = try #require(scene.buyHitFrameForTesting(.drillYard))
        scene.handleTouchForTesting(at: buyFrame.center)

        let saved = store.load()
        #expect(saved.treasury.drillYard == 1)
        #expect(saved.gold == goldBeforeBuy - TreasuryUpgrade.drillYard.price(forCurrentLevel: 0))
        #expect(saved.pendingBattleResult == nil)
        // The pre-buy window was settled at purchase time, not left armed
        // to resolve later at the new level.
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds >= 3_600)
        let postBuyAnchor = try #require(saved.lastBackgroundedAt)
        #expect(postBuyAnchor > entryAnchor)

        // A later foreground settle sees only the post-buy window.
        scene.sceneWillEnterForegroundForTesting(at: postBuyAnchor.addingTimeInterval(60))
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 60)
    }

    @Test("A buy-tap settlement conquest routes the report and still completes the purchase")
    func buySettleConquestRoutesReportAndCompletesPurchase() throws {
        // Entry is nonlethal; the store is then re-armed with a lethal
        // window so the tap's own settle conquers — the pending report
        // still routes pending-first, but Treasury has no stage gate: a
        // completed or pending city does not block a valid purchase, so
        // the buy must land (unlike Camp's stage-gated build/upgrade).
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        #expect(store.load().pendingBattleResult == nil)

        var armed = store.load()
        armed.lastBackgroundedAt = .distantPast
        armed.cityBattleStates[armed.currentCityKey.storageKey]?
            .lastBuildingProgressResolvedAt = .distantPast
        store.save(armed)

        let buyFrame = try #require(scene.buyHitFrameForTesting(.drillYard))
        scene.handleTouchForTesting(at: buyFrame.center)

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.pendingBattleResult?.conquestMode == .idle)
        // The settle credited the conquest reward, then the purchase spent
        // the level-0 Drill Yard price — gold is consistent with both.
        // `armed.gold` already reflects the barracks build cost from
        // makeNonlethalIdleState.
        #expect(saved.treasury.drillYard == 1)
        #expect(saved.gold == armed.gold
            + KingdomGameState.baseGoldReward(for: 3)
            - TreasuryUpgrade.drillYard.price(forCurrentLevel: 0))
        #expect(router.requestedTabs == [.battle])
    }

    @Test("Node tree stays stable across purchase and relayout")
    func nodeTreeStaysStable() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store)
        let initialChildCount = scene.children.count

        let buyFrame = try #require(scene.buyHitFrameForTesting(.warChest))
        scene.handleTouchForTesting(at: buyFrame.center)
        #expect(scene.children.count == initialChildCount)

        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.children.count == initialChildCount)

        scene.repeatDidMoveForTesting()
        #expect(scene.children.count == initialChildCount)
    }

    // MARK: - Accessibility identities

    @Test("Header, rows and Buy actions carry accessibility identities")
    func accessibilityIdentitiesArePresent() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store)

        #expect(scene.headerNodeForTesting?.name == "kingdomHeader")
        for upgrade in TreasuryUpgrade.allCases {
            let row = try #require(scene.treasuryRowNodeForTesting(upgrade))
            #expect(row.name == "kingdomTreasuryRow-\(upgrade.rawValue)")
            let buy = try #require(
                row.children.first { $0.name == "kingdomTreasuryBuy-\(upgrade.rawValue)" }
            )
            #expect(buy.name == "kingdomTreasuryBuy-\(upgrade.rawValue)")
        }
    }

    @Test("VoiceOver exposes the header, rows and Buy actions that drive a purchase")
    func accessibilityElementsExposeHeaderRowsAndBuy() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: store,
            safeAreaInsetsOverride: .init(top: 59, left: 0, bottom: 34, right: 0)
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let elements = try #require(view.accessibilityElements as? [UIAccessibilityElement])
        let identifiers = elements.compactMap(\.accessibilityIdentifier)
        #expect(identifiers.contains("kingdom-header"))
        for upgrade in TreasuryUpgrade.allCases {
            #expect(identifiers.contains("kingdom-row-\(upgrade.rawValue)"))
            #expect(identifiers.contains("kingdom-buy-\(upgrade.rawValue)"))
        }

        // A VoiceOver activation drives the same purchase path as a Buy tap.
        let buy = try #require(elements.first {
            $0.accessibilityIdentifier == "kingdom-buy-warChest"
        })
        #expect(buy.accessibilityTraits.contains(.button))
        #expect(!buy.accessibilityTraits.contains(.notEnabled))
        #expect(buy.accessibilityActivate())
        #expect(store.load().treasury.warChest == 1)
    }

    @Test("War Chest preview quotes the next unlocked city, not the already-paid one")
    func warChestPreviewQuotesNextCityReward() throws {
        // City 1 was just paid (pendingMap): the +10% boost applies to the
        // NEXT conquest, so the preview must quote City 2's reward — not
        // `cityLevel`, which still points at the already-paid city.
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        let warChest = try #require(scene.treasuryRowTextForTesting(.warChest))
        var projected = state
        projected.treasury.setLevel(1, for: .warChest)
        let expected = "City reward \(CompactNumberFormatter.string(from: state.goldReward(forCity: 2)))"
            + " → \(CompactNumberFormatter.string(from: projected.goldReward(forCity: 2))) gold"
        #expect(warChest.effect == expected)
    }

    @Test("A finished country keeps every valid Buy and drops the reward preview")
    func countryCompleteKeepsBuyAndDropsRewardPreview() throws {
        let state = KingdomGameState(
            gold: 10_000,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        // Treasury has no stage gate: an affordable, non-maxed upgrade
        // stays purchasable after the final city — saved gold can be
        // spent at any point, including after City 15.
        for upgrade in TreasuryUpgrade.allCases {
            #expect(scene.isBuyEnabledForTesting(upgrade))
        }
        let warChest = try #require(scene.treasuryRowTextForTesting(.warChest))
        #expect(warChest.effect == TreasuryUpgrade.warChest.effectName)

        let buyFrame = try #require(scene.buyHitFrameForTesting(.warChest))
        scene.handleTouchForTesting(at: buyFrame.center)

        let saved = store.load()
        #expect(saved.treasury.warChest == 1)
        #expect(saved.gold == 10_000 - TreasuryUpgrade.warChest.price(forCurrentLevel: 0))
    }

    @Test("Kingdom reuses the one shared Settings gear anchored at the layout frame")
    func singleSettingsGearIsAnchored() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store)

        let gears = scene.children.filter { $0 is SettingsGearNode }
        #expect(gears.count == 1)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        let layout = try #require(scene.kingdomLayoutForTesting)
        #expect(gearFrame == layout.settingsFrame)
    }

    @Test("Tab bar content selects Kingdom and mirrors stage availability")
    func tabContentMirrorsStage() throws {
        let activeStore = try makeStore(initialState: KingdomGameState(gold: 100))
        let activeScene = makeScene(store: activeStore)
        #expect(activeScene.gameplayTabContentForTesting.selected == .kingdom)
        #expect(activeScene.gameplayTabContentForTesting.enabledTabs == Set(GameplayTab.allCases))

        var conqueredState = KingdomGameState(
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        )
        conqueredState.gold = 100
        let conqueredScene = makeScene(store: try makeStore(initialState: conqueredState))
        #expect(conqueredScene.gameplayTabContentForTesting.enabledTabs == [.map, .kingdom])
    }

    // MARK: - Lifecycle: foreground settle and pending-report routing

    /// City 3 with a 1000s armed window: nonlethal at scene creation, so the
    /// entry settle is a no-op that clears and re-arms the anchor; a later
    /// settle can conquer.
    private func makeNonlethalIdleState() -> KingdomGameState {
        let start = Date(timeIntervalSinceNow: -1_000)
        var state = KingdomGameState(
            gold: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        return state
    }

    @Test("Kingdom foreground conquest routes the pending report exactly once")
    func foregroundConquestRoutesPendingReportOnce() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let t0 = Date()

        // The first foreground re-arms building progress (entry already
        // settled and re-armed the original anchor); the second conquers.
        scene.sceneWillEnterForegroundForTesting(at: t0)
        #expect(store.load().stageStatus == .battleActive)

        scene.sceneWillEnterForegroundForTesting(at: t0.addingTimeInterval(10_000))

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.pendingBattleResult?.conquestMode == .idle)
        #expect(saved.lastBackgroundedAt == nil)
        #expect(router.requestedTabs == [.battle])

        // A repeated foreground must not route or settle a second time.
        scene.sceneWillEnterForegroundForTesting(at: t0.addingTimeInterval(10_100))
        #expect(router.requestedTabs == [.battle])
        #expect(store.load() == saved)
    }

    @Test("Kingdom entry settles idle progress and routes the pending report once")
    func entrySettlesIdleConquestAndRoutesOnce() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()

        let scene = makeScene(store: store, router: router)

        // The entry settle conquered and recorded the report, but the route
        // is deferred to the first update — didMove runs inside
        // presentScene, so routing here would nest a second presentation.
        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
        #expect(router.requestedTabs.isEmpty)

        scene.update(0)
        #expect(router.requestedTabs == [.battle])

        // Exactly once: later updates do not re-route.
        scene.update(0)
        #expect(router.requestedTabs == [.battle])
    }

    @Test("Kingdom entry settle does not re-arm the idle anchor while the gate is paused")
    func entrySettleDoesNotRearmWhileGatePaused() throws {
        // The controller pauses the scene synchronously inside the gate
        // request (refreshLayoutSupport → layoutGateWillPause); the entry
        // settle that follows must NOT re-arm — otherwise time stuck on
        // the "can't fit" gate would later be credited as idle production.
        let router = RouteSpy()
        router.pausesSceneOnGateRequest = true
        let store = try makeStore(initialState: makeNonlethalIdleState())

        // A viewport too short for three rows requests the gate mid-didMove.
        let scene = makeScene(
            size: CGSize(width: 320, height: 330),
            store: store,
            router: router
        )

        #expect(router.requestedGateReason == .unsupportedGeometry)
        // The pause settle cleared the anchor and the entry settle did not
        // re-arm it.
        #expect(store.load().lastBackgroundedAt == nil)

        // Resuming re-arms for the still-active battle — accrual starts
        // from the resume, never from before the pause.
        scene.layoutGateWillResume(at: Date())
        #expect(store.load().lastBackgroundedAt != nil)
    }

    @Test("Kingdom entry re-arms the idle anchor so a backgrounded absence is credited")
    func entryRearmsIdleAnchorForLaterForeground() throws {
        // Armed 60s before entry: the entry settle is nonlethal and must
        // re-arm the anchor, otherwise the one-hour absence below resolves
        // nothing (the pre-fix bug lost the whole window). City 8's keep is
        // far above one Barracks' hourly idle damage, so the settle is
        // deterministically nonlethal.
        let start = Date(timeIntervalSinceNow: -60)
        var initialState = KingdomGameState(
            gold: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 8,
            completedCityCount: 7,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let t0 = Date()
        #expect(store.load().pendingBattleResult == nil)
        #expect(store.load().lastBackgroundedAt != nil)

        scene.sceneDidEnterBackgroundForTesting(at: t0)
        scene.sceneWillEnterForegroundForTesting(at: t0.addingTimeInterval(3_600))

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 3_600)
        // City 8 is nonlethal in an hour: no pending report is created, and a
        // repeated foreground neither duplicates nor loses one.
        #expect(store.load().pendingBattleResult == nil)
        #expect(store.load().stageStatus == .battleActive)
        #expect(router.requestedTabs.isEmpty)

        scene.sceneWillEnterForegroundForTesting(at: t0.addingTimeInterval(3_700))
        #expect(store.load().pendingBattleResult == nil)
        #expect(router.requestedTabs.isEmpty)
    }

    @Test("Kingdom gate pause conquest stays unrouted and routes once on resume")
    func gatePauseConquestStaysUnroutedUntilResume() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let t0 = Date()
        scene.sceneWillEnterForegroundForTesting(at: t0)

        scene.layoutGateWillPause(at: t0.addingTimeInterval(10_000))

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.pendingBattleResult?.conquestMode == .idle)
        #expect(router.requestedTabs.isEmpty)

        scene.layoutGateWillResume(at: t0.addingTimeInterval(10_100))

        #expect(store.load() == saved)
        #expect(router.requestedTabs == [.battle])
        #expect(scene.isRoutingToBattleForTesting)
    }

    @Test("Kingdom pending conquest foregrounded under a paused gate routes once on resume")
    func pendingConquestForegroundedUnderPausedGateRoutesOnResume() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let t0 = Date()
        scene.sceneWillEnterForegroundForTesting(at: t0)

        scene.layoutGateWillPause(at: t0.addingTimeInterval(10_000))
        scene.sceneDidEnterBackgroundForTesting(at: t0.addingTimeInterval(10_050))

        scene.sceneWillEnterForegroundForTesting(at: t0.addingTimeInterval(10_100))
        #expect(router.requestedTabs.isEmpty)

        scene.layoutGateWillResume(at: t0.addingTimeInterval(10_150))

        #expect(router.requestedTabs == [.battle])
        #expect(scene.isRoutingToBattleForTesting)
    }

    @Test("Kingdom pending conquest gate-resumed while backgrounded routes once on foreground")
    func pendingConquestResumedWhileBackgroundedRoutesOnForeground() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let t0 = Date()
        scene.sceneWillEnterForegroundForTesting(at: t0)

        scene.layoutGateWillPause(at: t0.addingTimeInterval(10_000))
        scene.sceneDidEnterBackgroundForTesting(at: t0.addingTimeInterval(10_050))

        scene.layoutGateWillResume(at: t0.addingTimeInterval(10_100))
        #expect(router.requestedTabs.isEmpty)

        scene.sceneWillEnterForegroundForTesting(at: t0.addingTimeInterval(10_150))

        #expect(router.requestedTabs == [.battle])
        #expect(scene.isRoutingToBattleForTesting)
    }

    @Test("Kingdom gate resume rearms building progress only in active battle")
    func gateResumeRearmsOnlyWhenBattleActive() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 3_000)
        // No persisted anchor: entry arms the anchor on the test-run clock and
        // the foreground hook re-arms it at a deterministic date.
        var activeState = KingdomGameState(gold: 100)
        activeState.cityBattleStates[activeState.currentCityKey.storageKey] = CityBattleState(
            slots: [1: CityBuilding(type: .barracks)],
            lastBuildingProgressResolvedAt: origin
        )
        let activeStore = try makeStore(initialState: activeState)
        let activeScene = makeScene(store: activeStore, router: RouteSpy())

        activeScene.sceneWillEnterForegroundForTesting(at: origin)

        activeScene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        #expect(activeScene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        activeScene.layoutGateWillPause(at: origin.addingTimeInterval(20))
        #expect(activeScene.lastIdleProgressResultForTesting.elapsedSeconds == 10)

        activeScene.layoutGateWillResume(at: origin.addingTimeInterval(30))
        #expect(activeStore.load().lastBackgroundedAt == origin.addingTimeInterval(30))

        var pendingState = KingdomGameState(
            lastBackgroundedAt: origin,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        )
        _ = pendingState.buildBuilding(.barracks, inSlot: 1, at: origin)
        let pendingStore = try makeStore(initialState: pendingState)
        let pendingScene = makeScene(store: pendingStore, router: RouteSpy())
        pendingScene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        pendingScene.layoutGateWillResume(at: origin.addingTimeInterval(30))

        #expect(pendingStore.load().lastBackgroundedAt == nil)
    }

    @Test("Kingdom tab exits settle and save before forwarding the route")
    func tabExitSettlesAndSavesBeforeRouting() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestGameplayTabForTesting(.map)

        #expect(router.requestedTabs == [.map])
        // The settle cleared the anchor; the successful hand-off re-arms it
        // for the inactive destination, so a later backgrounding from Map
        // still credits idle production.
        #expect(store.load().lastBackgroundedAt != nil)
    }

    @Test("Rejected routes never lose a settled pending conquest")
    func rejectedExitKeepsPendingConquest() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        router.acceptsAllRequests = false
        let scene = makeScene(store: store, router: router)

        // The entry settle conquered; the deferred route fires on the first
        // update and the router declines it.
        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
        scene.update(0)
        #expect(router.requestedTabs == [.battle])

        scene.requestGameplayTabForTesting(.map)

        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
        #expect(router.requestedTabs == [.battle, .map])
        #expect(!scene.isRoutingToBattleForTesting)
    }

    @Test("Header recovers after an unsupported-geometry resize")
    func headerRecoversAfterLayoutFailure() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 123))
        let scene = makeScene(store: store)
        let header = try #require(scene.headerNodeForTesting)
        #expect(!header.isHidden)

        // A viewport too short for three real rows forces the fail path,
        // which hides the header along with the rows and tab bar.
        scene.size = CGSize(width: 320, height: 330)
        #expect(scene.isTreasuryFitFailedForTesting)
        #expect(scene.kingdomLayoutForTesting == nil)
        #expect(header.isHidden)

        // Recovering to a supported size must unhide the header again.
        scene.size = CGSize(width: 393, height: 852)
        #expect(!scene.isTreasuryFitFailedForTesting)
        #expect(scene.kingdomLayoutForTesting != nil)
        #expect(!header.isHidden)
        #expect(scene.goldTextForTesting
            == "Gold " + CompactNumberFormatter.string(from: 123))
    }

    @Test("Successful Kingdom→Map hand-off re-arms the idle anchor for the destination")
    func successfulMapHandoffRearmsIdleAnchorForDestination() throws {
        // City 8 with a short armed window: the entry settle is nonlethal
        // and re-arms; the hand-off settle must re-arm again for Map.
        let start = Date(timeIntervalSinceNow: -60)
        var initialState = KingdomGameState(
            gold: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 8,
            completedCityCount: 7,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        // GameViewController constructs the destination synchronously
        // inside the routing call, so Map's didMove load sees whatever the
        // store holds at that instant — building it inside the callback is
        // what makes the save-before-route ordering observable.
        var destinationMap: CountryMapScene?
        router.onRequest = {
            destinationMap = self.makeMapScene(store: store)
        }

        scene.requestGameplayTabForTesting(.map)
        #expect(router.requestedTabs == [.map])
        let mapScene = try #require(destinationMap)

        // Without the pre-route re-arm, Map's didMove copy would carry a
        // cleared anchor and its non-gate background save below would
        // overwrite the armed one — the foreground settle would resolve
        // nothing.
        let armedAt = try #require(store.load().lastBackgroundedAt)

        mapScene.sceneDidEnterBackgroundForTesting(at: armedAt.addingTimeInterval(10))
        mapScene.sceneWillEnterForegroundForTesting(at: armedAt.addingTimeInterval(1_800))

        let result = mapScene.lastIdleProgressResultForTesting
        #expect(result.elapsedSeconds == 1_800)
        #expect(result.elapsedSeconds > 0)
        // City 8's keep is far above one Barracks' half-hour idle damage.
        #expect(result.conqueredCities == 0)
        #expect(store.load().stageStatus == .battleActive)
    }

    @Test("Battle destination never inherits a stale idle anchor")
    func battleDestinationGetsNoIdleAnchor() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestGameplayTabForTesting(.battle)

        #expect(router.requestedTabs == [.battle])
        // Battle drives buildings per-frame, so the hand-off must leave the
        // anchor cleared rather than arming a stale one.
        #expect(store.load().lastBackgroundedAt == nil)
    }

    // MARK: - Coverage: coder init, icons, max-level rows and input edges

    @Test("Kingdom init(coder:) restores a presentable scene through keyed archiving")
    func kingdomCoderInitRoundTripsThroughKeyedArchiver() throws {
        let archiveData: Data
        do {
            let scene = KingdomScene(
                size: CGSize(width: 393, height: 852),
                store: try makeStore(initialState: KingdomGameState(gold: 42)),
                safeAreaInsetsOverride: .init(top: 59, left: 0, bottom: 34, right: 0)
            )
            archiveData = try NSKeyedArchiver.archivedData(
                withRootObject: scene,
                requiringSecureCoding: false
            )
        }
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiveData)
        unarchiver.requiresSecureCoding = false
        let decoded = unarchiver.decodeObject(
            forKey: NSKeyedArchiveRootObjectKey
        ) as? KingdomScene
        unarchiver.finishDecoding()
        let scene = try #require(decoded)
        #expect(scene.size == CGSize(width: 393, height: 852))
        #expect(scene.kingdomLayoutForTesting == nil)
    }

    @Test("Treasury rows use sprite icons when the upgrade art loads")
    func treasuryRowsUseSpriteIconsWhenArtLoads() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, imageLoader: { _ in
            UIImage(systemName: "star.fill")
        })

        for upgrade in TreasuryUpgrade.allCases {
            let icon = try #require(
                scene.childNode(withName: "//kingdomTreasuryIcon-\(upgrade.rawValue)")
                    as? SKSpriteNode
            )
            #expect(icon.size == CGSize(
                width: KingdomLayout.rowIconSize,
                height: KingdomLayout.rowIconSize
            ))
        }
    }

    @Test("Max-level Quartermaster and Drill Yard rows show their static effect text")
    func maxLevelRowsShowStaticEffectText() {
        var state = KingdomGameState(gold: 100)
        state.treasury.setLevel(TreasuryUpgrade.quartermaster.maxLevel, for: .quartermaster)
        state.treasury.setLevel(TreasuryUpgrade.drillYard.maxLevel, for: .drillYard)

        #expect(KingdomScene.effectText(for: .quartermaster, state: state)
            == TreasuryUpgrade.quartermaster.effectName)

        // Drill Yard at max reports the current attack with no "→" projection.
        let current = KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry,
            level: 1,
            defenseTrait: state.currentCityDefenseTrait,
            upgradeMultiplier: 1.0 + 0.05 * Double(TreasuryUpgrade.drillYard.maxLevel)
        )
        #expect(KingdomScene.effectText(for: .drillYard, state: state)
            == "Infantry Lv 1 vs this city's trait: \(current) attack")
    }

    @Test("A failed Treasury layout ignores touches and still redraws the tab bar")
    func failedLayoutIgnoresTouchesAndRedraws() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.size = CGSize(width: 320, height: 330)
        #expect(scene.isTreasuryFitFailedForTesting)
        #expect(scene.kingdomLayoutForTesting == nil)

        // Touches return before tab routing or buying while layout is nil.
        scene.handleTouchForTesting(at: .zero)
        #expect(router.requestedTabs.isEmpty)
        #expect(store.load().treasury == TreasuryState())

        // The foreground settle still redraws; with no layout the tab bar
        // re-applies at a zero frame instead of keeping stale geometry.
        scene.sceneWillEnterForegroundForTesting(at: Date())
        #expect(scene.kingdomLayoutForTesting == nil)
    }

    @Test("Touches in the future-section gap buy nothing and route nowhere")
    func futureSectionTouchIsIgnored() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let layout = try #require(scene.kingdomLayoutForTesting)

        scene.handleTouchForTesting(at: CGPoint(
            x: layout.futureSectionFrame.midX,
            y: layout.futureSectionFrame.midY
        ))

        #expect(router.requestedTabs.isEmpty)
        #expect(store.load().treasury == TreasuryState())
    }

    @Test("An empty touch set ends without routing or purchasing")
    func touchesEndedWithEmptySetIsIgnored() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.touchesEnded([], with: nil)

        #expect(router.requestedTabs.isEmpty)
        #expect(store.load().treasury == TreasuryState())
    }

    @Test("Requesting the already-selected Kingdom tab is ignored")
    func kingdomTabRequestIsIgnored() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestGameplayTabForTesting(.kingdom)

        #expect(router.requestedTabs.isEmpty)
    }

    @Test("Tapping the Map tab hit target forwards the route request")
    func mapTabHitTargetRoutesTabRequest() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let layout = try #require(scene.kingdomLayoutForTesting)
        let mapIndex = try #require(GameplayTab.allCases.firstIndex(of: .map))

        scene.handleTouchForTesting(at: layout.tabHitFrames[mapIndex].center)

        #expect(router.requestedTabs == [.map])
    }

    @Test("A declined Kingdom hand-off re-arms the idle anchor anyway")
    func declinedHandoffRearmsIdleAnchor() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        router.acceptsAllRequests = false
        let scene = makeScene(store: store, router: router)
        let armedAtEntry = try #require(store.load().lastBackgroundedAt)

        scene.requestGameplayTabForTesting(.map)

        #expect(router.requestedTabs == [.map])
        #expect(!scene.isRoutingToBattleForTesting)
        // The declined exit re-arms the anchor for the same reason the
        // successful hand-off does: a backgrounding from the current scene
        // still credits idle production.
        let rearmed = try #require(store.load().lastBackgroundedAt)
        #expect(rearmed > armedAtEntry)
    }

    @Test("Posted lifecycle notifications drive the background/foreground settles")
    func lifecycleNotificationsDriveSettles() throws {
        let store = try makeStore(initialState: makeNonlethalIdleState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        NotificationCenter.default.post(name: .pyxisSceneDidEnterBackground, object: scene)
        #expect(store.load().stageStatus == .battleActive)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: scene)

        // The foreground settle resolved against the re-armed anchor; City 3
        // does not fall to under a second of idle building production.
        #expect(store.load().stageStatus == .battleActive)
        #expect(router.requestedTabs.isEmpty)
    }

    @Test("Gate pause while the app is backgrounded records the background entry")
    func gatePauseWhileBackgroundedRecordsBackgroundEntry() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store)
        let t0 = Date()

        scene.sceneDidEnterBackgroundForTesting(at: t0)
        scene.layoutGateWillPause(at: t0.addingTimeInterval(60))

        // enterBackground — not a settle — anchors the marker at pause time.
        #expect(store.load().lastBackgroundedAt == t0.addingTimeInterval(60))
    }

    @Test("Buy hit frames are unavailable before the first layout")
    func buyHitFrameIsNilBeforeLayout() throws {
        let scene = KingdomScene(
            size: CGSize(width: 393, height: 852),
            store: try makeStore(initialState: KingdomGameState(gold: 100))
        )
        #expect(scene.buyHitFrameForTesting(.warChest) == nil)
    }

    @Test("Settings gear, modal actions and accessibility elements share one controller")
    func settingsFlowDrivesModalAndAccessibilityActions() throws {
        let preferences = RecordingFeedbackPreferencesManager()
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: store,
            safeAreaInsetsOverride: .init(top: 59, left: 0, bottom: 34, right: 0),
            feedbackPreferences: preferences
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = UIWindow(frame: view.bounds)
        window.addSubview(view)
        defer { view.removeFromSuperview() }
        view.presentScene(scene)
        scene.didMove(to: view)

        // The gear accessibility element routes through the scene-gated open.
        let exposed = try #require(view.accessibilityElements as? [UIAccessibilityElement])
        let gearElement = try #require(exposed.first { $0.accessibilityLabel == "Settings" })
        #expect(gearElement.accessibilityActivate())
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // While the modal is visible the scene forwards touches to it.
        scene.handleTouchForTesting(at: .zero)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // A consumed accessibility action is ignored without dismissing.
        scene.activateFeedbackSettingsForTesting(.consumed)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // Modal accessibility elements drive the scene-gated actions.
        let modalElements = try #require(
            view.accessibilityElements as? [UIAccessibilityElement]
        )
        let soundElement = try #require(
            modalElements.first { $0.accessibilityLabel == "Sound Effects" }
        )
        #expect(soundElement.accessibilityActivate())
        #expect(!preferences.current.soundEffectsEnabled)
        let hapticsElement = try #require(
            modalElements.first { $0.accessibilityLabel == "Haptics" }
        )
        #expect(hapticsElement.accessibilityActivate())
        #expect(!preferences.current.hapticsEnabled)
        let closeElement = try #require(
            modalElements.first { $0.accessibilityLabel == "Close" }
        )
        #expect(closeElement.accessibilityActivate())
        #expect(!scene.isFeedbackSettingsVisibleForTesting)

        // Closing Settings re-exposes the scene's own elements alongside
        // the gear through the .openingGear dismiss path.
        let restoredElements = try #require(
            view.accessibilityElements as? [UIAccessibilityElement]
        )
        #expect(restoredElements.contains {
            $0.accessibilityIdentifier == "kingdom-buy-warChest"
        })

        // An action while the modal is closed is dropped by the guard.
        scene.activateFeedbackSettingsForTesting(.toggleSoundEffects)
        #expect(!preferences.current.soundEffectsEnabled)

        // The scene-space gear hit test opens the same modal.
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // A gear activation while the modal is already open is dropped too.
        #expect(gearElement.accessibilityActivate())
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(closeElement.accessibilityActivate())
        #expect(!scene.isFeedbackSettingsVisibleForTesting)

        // Repeat entry keeps the single controller instead of rebuilding it.
        scene.repeatDidMoveForTesting()
        #expect(scene.children.filter { $0 is SettingsGearNode }.count == 1)
    }

    // MARK: - HPA-671 Armory section

    @Test("Section selector switches sections without settling or saving")
    func sectionSelectorSwitchesWithoutSaving() throws {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(makeGearOwningState())
        let scene = makeScene(store: store)
        defaults.resetStateSaveCount()

        #expect(scene.selectedSectionForTesting == .treasury)

        let armoryHit = try #require(scene.armorySelectorHitFrameForTesting())
        scene.handleTouchForTesting(at: armoryHit.center)
        #expect(scene.selectedSectionForTesting == .armory)
        #expect(defaults.stateSaveCount == 0)

        let treasuryHit = try #require(scene.treasurySelectorHitFrameForTesting())
        scene.handleTouchForTesting(at: treasuryHit.center)
        #expect(scene.selectedSectionForTesting == .treasury)
        #expect(defaults.stateSaveCount == 0)
    }

    @Test("Armory rows show equipped name, effect, next drop, and dim locked types")
    func armoryRowsShowContentAndDimming() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(store: store)
        selectArmory(scene)

        let infantry = try #require(scene.armoryRowTextForTesting(.infantry))
        #expect(infantry.line1 == "Infantry · Willowford Blade")
        #expect(infantry.line2 == "Attack +15% · Drops at City 6")

        // Nothing equipped and the type still locked at City 1: the row
        // still announces the earliest drop.
        let archer = try #require(scene.armoryRowTextForTesting(.archer))
        #expect(archer.line1 == "Archer · None")
        #expect(archer.line2 == "Drops at City 2")

        // A type with every catalog item owned but deliberately unequipped.
        var complete = KingdomGameState(gold: 100)
        complete.ownedEquipmentIDs = EquipmentCatalog.forType(.archer).map(\.id)
        let completeScene = makeScene(store: try makeStore(initialState: complete))
        let allOwned = try #require(completeScene.armoryRowTextForTesting(.archer))
        #expect(allOwned.line1 == "Archer · None")
        #expect(allOwned.line2 == "All gear earned")

        // Specialist effect copy quotes the matched objective.
        var specialist = makeGearOwningState()
        specialist.ownedEquipmentIDs = ["c04-archer-tower"]
        specialist.equippedItemBySoldierType = ["archer": "c04-archer-tower"]
        let specialistScene = makeScene(store: try makeStore(initialState: specialist))
        let archerTower = try #require(specialistScene.armoryRowTextForTesting(.archer))
        #expect(archerTower.line2 == "vs Arrow Tower +40% · Drops at City 2")

        #expect(!scene.isArmoryRowDimmedForTesting(.infantry))
        #expect(scene.isArmoryRowDimmedForTesting(.archer))
        #expect(scene.isArmoryRowDimmedForTesting(.cavalry))
        #expect(scene.isArmoryRowDimmedForTesting(.mage))
        #expect(scene.isArmoryRowDimmedForTesting(.siege))

        // Only the selected section's rows are visible.
        #expect(scene.treasuryRowNodeForTesting(.warChest)?.isHidden == true)
        #expect(scene.armoryRowNodeForTesting(.mage)?.isHidden == false)
    }

    @Test("Armory row taps cycle None → owned in city order → None and save on change")
    func armoryRowTapCyclesOwnedChoices() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        selectArmory(scene)
        let hit = try #require(scene.armoryRowHitFrameForTesting(.infantry))

        scene.handleTouchForTesting(at: hit.center)
        #expect(store.load().equippedItemBySoldierType["infantry"] == "c03-infantry-toughness")
        scene.handleTouchForTesting(at: hit.center)
        #expect(store.load().equippedItemBySoldierType["infantry"] == nil)
        scene.handleTouchForTesting(at: hit.center)
        #expect(store.load().equippedItemBySoldierType["infantry"] == "c01-infantry-attack")
        #expect(router.requestedTabs.isEmpty)

        // The label redraws with the cycled choice.
        let infantry = try #require(scene.armoryRowTextForTesting(.infantry))
        #expect(infantry.line1 == "Infantry · Willowford Blade")
    }

    @Test("A row with no owned items does nothing — no settle, no save")
    func armoryRowWithoutOwnedItemsDoesNothing() throws {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(makeGearOwningState())
        let scene = makeScene(store: store)
        defaults.resetStateSaveCount()
        selectArmory(scene)

        scene.handleTouchForTesting(at: try #require(scene.armoryRowHitFrameForTesting(.mage)).center)

        #expect(defaults.stateSaveCount == 0)
        #expect(store.load().equippedItemBySoldierType["mage"] == nil)
        // The untouched infantry slot survives the rejected tap.
        #expect(store.load().equippedItemBySoldierType["infantry"] == "c01-infantry-attack")
    }

    @Test("An Armory row tap cycles an item its own settlement just granted")
    func armoryRowTapCyclesItemGrantedByOwnSettlement() throws {
        // Besieging City 3 with only the City 1 blade equipped: the tap's
        // own settle conquers City 3 and grants the City 3 toughness plate
        // mid-tap. The cycle must re-read post-settle ownership instead of
        // cycling the stale one-item list straight to None.
        var initialState = makeNonlethalIdleState()
        initialState.ownedEquipmentIDs = ["c01-infantry-attack"]
        initialState.equippedItemBySoldierType = ["infantry": "c01-infantry-attack"]
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        selectArmory(scene)

        var armed = store.load()
        armed.lastBackgroundedAt = .distantPast
        armed.cityBattleStates[armed.currentCityKey.storageKey]?
            .lastBuildingProgressResolvedAt = .distantPast
        store.save(armed)

        scene.handleTouchForTesting(at: try #require(scene.armoryRowHitFrameForTesting(.infantry)).center)

        let saved = store.load()
        // The settlement granted the City 3 plate and produced a pending
        // report; pending-first routing still fired.
        #expect(saved.ownedEquipmentIDs.contains("c03-infantry-toughness"))
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.pendingBattleResult?.conquestMode == .idle)
        #expect(router.requestedTabs == [.battle])
        // The cycle landed on the newly owned item, not skipped to None.
        #expect(saved.equippedItemBySoldierType["infantry"] == "c03-infantry-toughness")
        // The row redraws with the cycled choice.
        let infantry = try #require(scene.armoryRowTextForTesting(.infantry))
        #expect(infantry.line1 == "Infantry · Falconridge Bulwark")
    }

    @Test("Armory icons prefer equipment art and fall back to per-type glyphs")
    func armoryIconArtAndFallback() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(store: store, imageLoader: { name in
            name == "equipment-c01-infantry-attack" ? UIImage(systemName: "star.fill") : nil
        })

        let equippedIcon = try #require(scene.armoryIconNodeForTesting(.infantry))
        #expect(equippedIcon is SKSpriteNode)
        let fallbackIcon = try #require(scene.armoryIconNodeForTesting(.archer))
        #expect(fallbackIcon is SKShapeNode)
    }

    @Test("Selector, Settings and section content touches stay isolated")
    func selectorSettingsAndSectionTouchesIsolated() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(store: store)
        let layout = try #require(scene.kingdomLayoutForTesting)

        // The 8pt gap between the Armory control and Settings hits neither.
        scene.handleTouchForTesting(at: CGPoint(
            x: layout.armorySelectorFrame.maxX + 4,
            y: layout.armorySelectorFrame.midY
        ))
        #expect(scene.selectedSectionForTesting == .treasury)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)

        // A selector tap never opens Settings...
        scene.handleTouchForTesting(at: layout.armorySelectorFrame.center)
        #expect(scene.selectedSectionForTesting == .armory)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)

        // ...and the gear never switches sections.
        scene.handleTouchForTesting(at: layout.settingsFrame.center)
        #expect(scene.selectedSectionForTesting == .armory)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        scene.activateFeedbackSettingsForTesting(.close)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Treasury Buys and Armory rows respond only in their own section")
    func buysAndArmoryRowsAreSectionIsolated() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(store: store)
        let layout = try #require(scene.kingdomLayoutForTesting)

        // Find a point inside both a Treasury Buy target and an Armory row.
        let buyFrame = layout.buyHitFrames[0]
        let overlappingRow = try #require(
            layout.armoryRowFrames.first { $0.intersects(buyFrame) }
        )
        let shared = buyFrame.intersection(overlappingRow)
        let point = CGPoint(x: shared.midX, y: shared.midY)

        // Treasury active: the same point buys, never cycles gear.
        scene.handleTouchForTesting(at: point)
        #expect(store.load().treasury.warChest == 1)
        #expect(store.load().equippedItemBySoldierType["infantry"] == "c01-infantry-attack")

        // Armory active: the same point cycles, never buys.
        selectArmory(scene)
        scene.handleTouchForTesting(at: point)
        #expect(store.load().treasury.warChest == 1)
        #expect(store.load().equippedItemBySoldierType["infantry"] == "c03-infantry-toughness")
    }

    @Test("Node tree stays stable across section switches, equip cycles and relayout")
    func nodeTreeStaysStableAcrossSectionInteractions() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(store: store)
        let initialChildCount = scene.children.count

        selectArmory(scene)
        scene.handleTouchForTesting(at: try #require(scene.armoryRowHitFrameForTesting(.infantry)).center)
        #expect(scene.children.count == initialChildCount)

        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.children.count == initialChildCount)

        scene.repeatDidMoveForTesting()
        #expect(scene.children.count == initialChildCount)
    }

    @Test("Armory UI hides on unsupported geometry and recovers with its section")
    func armoryHidesOnUnsupportedGeometryAndRecovers() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(store: store)
        selectArmory(scene)

        scene.size = CGSize(width: 320, height: 330)
        #expect(scene.isTreasuryFitFailedForTesting)
        #expect(scene.headerNodeForTesting?.isHidden == true)
        #expect(scene.armoryRowNodeForTesting(.infantry)?.isHidden == true)

        scene.size = CGSize(width: 393, height: 852)
        #expect(!scene.isTreasuryFitFailedForTesting)
        #expect(scene.headerNodeForTesting?.isHidden == false)
        // The ephemeral section survives the fail/recover cycle.
        #expect(scene.selectedSectionForTesting == .armory)
        #expect(scene.armoryRowNodeForTesting(.infantry)?.isHidden == false)
        #expect(scene.treasuryRowNodeForTesting(.warChest)?.isHidden == true)
    }

    @Test("VoiceOver exposes section controls and Armory rows that drive the cycle")
    func accessibilityExposesSectionsAndArmoryRows() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: store,
            safeAreaInsetsOverride: .init(top: 59, left: 0, bottom: 34, right: 0)
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        func exposedIdentifiers() -> [String] {
            let elements = (view.accessibilityElements as? [UIAccessibilityElement]) ?? []
            return elements.compactMap(\.accessibilityIdentifier)
        }

        // Treasury is exposed by default; the section controls ride along.
        var identifiers = exposedIdentifiers()
        #expect(identifiers.contains("kingdom-section-treasury"))
        #expect(identifiers.contains("kingdom-section-armory"))
        #expect(identifiers.contains("kingdom-row-warChest"))
        #expect(!identifiers.contains("kingdom-armory-row-infantry"))

        let armorySection = try #require(
            (view.accessibilityElements as? [UIAccessibilityElement])?
                .first { $0.accessibilityIdentifier == "kingdom-section-armory" }
        )
        #expect(armorySection.accessibilityTraits.contains(.button))
        #expect(!armorySection.accessibilityTraits.contains(.selected))
        #expect(armorySection.accessibilityActivate())
        #expect(scene.selectedSectionForTesting == .armory)

        identifiers = exposedIdentifiers()
        for type in SoldierType.allCases {
            #expect(identifiers.contains("kingdom-armory-row-\(type.rawValue)"))
        }
        #expect(!identifiers.contains("kingdom-row-warChest"))

        let elements = (view.accessibilityElements as? [UIAccessibilityElement]) ?? []
        let infantryRow = try #require(
            elements.first { $0.accessibilityIdentifier == "kingdom-armory-row-infantry" }
        )
        #expect(infantryRow.accessibilityTraits.contains(.button))
        #expect(!infantryRow.accessibilityTraits.contains(.notEnabled))
        // Fuller flavor rides in the accessible value, not stacked text.
        #expect(infantryRow.accessibilityValue?.contains("Willowford Blade") == true)
        #expect(infantryRow.accessibilityValue?.contains("riverside smith") == true)
        #expect(infantryRow.accessibilityActivate())
        #expect(store.load().equippedItemBySoldierType["infantry"] == "c03-infantry-toughness")

        let siegeRow = try #require(
            elements.first { $0.accessibilityIdentifier == "kingdom-armory-row-siege" }
        )
        #expect(siegeRow.accessibilityTraits.contains(.notEnabled))
    }

    @Test("Kingdom title shrinks to fit the narrowed header line at 320×454")
    func titleFitsNarrowedHeaderLine() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(
            size: CGSize(width: 320, height: 454),
            store: store,
            safeAreaInsets: .zero
        )
        let layout = try #require(scene.kingdomLayoutForTesting)

        let titleLabel = scene.titleLabelNodeForTesting
        let parent = try #require(titleLabel.parent)
        #expect(layout.titleFrame.contains(parent.convert(titleLabel.frame, to: scene)))
        #expect(titleLabel.fontSize < 26)
        #expect(scene.titleTextForTesting == "Kingdom")
    }

    @Test("Armory rendered labels fit their reserved line boxes for every authored item")
    func armoryRowLabelsFitReservedLineBoxesAtBoundary() throws {
        // Every authored equipment choice at the narrowest accepted size,
        // not just representative ones: the layout's reserved line boxes
        // fitting is not enough — the RENDERED two-line copy must fit them
        // too. Each iteration owns the realistic city-1…N drop prefix and
        // equips one catalog item in its own row, so all 15 names, every
        // effect string, and every effect+next-drop combination renders;
        // the final iteration also covers the "All gear earned" rows.
        for item in EquipmentCatalog.items {
            var state = KingdomGameState(gold: 100)
            state.ownedEquipmentIDs = EquipmentCatalog.items
                .filter { $0.cityNumber <= item.cityNumber }
                .map(\.id)
            state.equippedItemBySoldierType = [item.soldierType.rawValue: item.id]

            let scene = makeScene(
                size: CGSize(width: 320, height: 454),
                store: try makeStore(initialState: state),
                safeAreaInsets: .zero
            )
            selectArmory(scene)
            let layout = try #require(scene.kingdomLayoutForTesting)

            for (index, type) in SoldierType.allCases.enumerated() {
                let labels = try #require(scene.armoryRowLabelNodesForTesting(type))
                for (box, label) in [
                    (layout.armoryLine1LabelFrames[index], labels.line1),
                    (layout.armoryLine2LabelFrames[index], labels.line2)
                ] {
                    let parent = try #require(label.parent)
                    let rendered = parent.convert(label.frame, to: scene)
                    // SpriteKit's convert runs in float32 — a flush fit can
                    // pick up ~1e-5pt of rounding, so tolerate far less
                    // than a visible point while staying strict.
                    let tolerance: CGFloat = 0.05
                    #expect(
                        box.insetBy(dx: -tolerance, dy: -tolerance).contains(rendered),
                        "city \(item.cityNumber) \(type.rawValue) '\(label.text ?? "")' → \(box) vs \(rendered)"
                    )
                }
                let rowFrame = layout.armoryRowFrames[index]
                for label in [labels.line1, labels.line2] {
                    let parent = try #require(label.parent)
                    #expect(rowFrame.contains(parent.convert(label.frame, to: scene)))
                }
            }
        }

        // The longest measured copy really is the authored specialist +
        // next-drop text (Bramblegate Broadhead on the city-1…4 prefix),
        // not an empty or shortened stand-in.
        var broadhead = KingdomGameState(gold: 100)
        broadhead.ownedEquipmentIDs = EquipmentCatalog.items
            .filter { $0.cityNumber <= 4 }
            .map(\.id)
        broadhead.equippedItemBySoldierType = ["archer": "c04-archer-tower"]
        let broadheadScene = makeScene(
            size: CGSize(width: 320, height: 454),
            store: try makeStore(initialState: broadhead),
            safeAreaInsets: .zero
        )
        let archer = try #require(broadheadScene.armoryRowTextForTesting(.archer))
        #expect(archer.line1 == "Archer · Bramblegate Broadhead")
        #expect(archer.line2 == "vs Arrow Tower +40% · Drops at City 9")
    }

    // MARK: - Helpers

    private func makeIdleAccruingState(since date: Date) -> KingdomGameState {
        var state = KingdomGameState()
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(
            slots: [1: CityBuilding(type: .barracks)],
            lastBuildingProgressResolvedAt: date
        )
        state.markCurrentCityBuildingProgressInactive(at: date)
        return state
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }

    /// Infantry owns the City 1 attack blade (equipped) and the City 3
    /// toughness plate; every other type owns nothing.
    private func makeGearOwningState() -> KingdomGameState {
        var state = KingdomGameState(gold: 100)
        state.ownedEquipmentIDs = ["c01-infantry-attack", "c03-infantry-toughness"]
        state.equippedItemBySoldierType = ["infantry": "c01-infantry-attack"]
        return state
    }

    /// Switches sections exactly the way a player tap does.
    private func selectArmory(_ scene: KingdomScene) {
        let hit = try? scene.armorySelectorHitFrameForTesting()
        scene.handleTouchForTesting(at: CGPoint(x: hit?.midX ?? 0, y: hit?.midY ?? 0))
    }

    private func makeScene(
        size: CGSize = CGSize(width: 393, height: 852),
        store: KingdomGameStore,
        router: (any KingdomSceneRouting)? = nil,
        safeAreaInsets: BattleChromeLayout.SafeAreaInsets = BattleChromeLayout.SafeAreaInsets(
            top: 59, left: 0, bottom: 34, right: 0
        ),
        imageLoader: ((String) -> UIImage?)? = nil
    ) -> KingdomScene {
        let scene = KingdomScene(
            size: size,
            store: store,
            router: router,
            safeAreaInsetsOverride: safeAreaInsets,
            imageLoaderOverride: imageLoader
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func makeMapScene(store: KingdomGameStore) -> CountryMapScene {
        let size = CGSize(width: 393, height: 852)
        let scene = CountryMapScene(
            size: size,
            store: store,
            layoutEnvironmentOverride: CountryMapLayoutEnvironment(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            ),
            feedbackPreferences: RecordingFeedbackPreferencesManager()
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private final class RouteSpy: KingdomSceneRouting {
        var acceptsAllRequests = true
        /// Runs inside the routing call, mirroring the controller's
        /// synchronous destination construction.
        var onRequest: (() -> Void)?
        /// When true, the spy pauses the scene inside the gate request —
        /// mirroring `GameViewController.refreshLayoutSupport`'s
        /// synchronous `layoutGateWillPause` call.
        var pausesSceneOnGateRequest = false
        private(set) var requestedTabs: [GameplayTab] = []
        private(set) var requestedGateReason: AppLayoutGateReason?

        func kingdomSceneDidRequestGameplayTab(_ scene: KingdomScene, tab: GameplayTab) -> Bool {
            requestedTabs.append(tab)
            onRequest?()
            return acceptsAllRequests
        }

        func kingdomScene(_ scene: KingdomScene, didRequestLayoutGate reason: AppLayoutGateReason) {
            requestedGateReason = reason
            if pausesSceneOnGateRequest {
                scene.layoutGateWillPause(at: Date())
            }
        }
    }

    private final class CountingUserDefaults: UserDefaults {
        private let countedKey: String
        private(set) var stateSaveCount = 0

        init?(suiteName: String, countedKey: String) {
            self.countedKey = countedKey
            super.init(suiteName: suiteName)
        }

        override func set(_ value: Any?, forKey defaultName: String) {
            if defaultName == countedKey {
                stateSaveCount += 1
            }
            super.set(value, forKey: defaultName)
        }

        func resetStateSaveCount() {
            stateSaveCount = 0
        }
    }
}
