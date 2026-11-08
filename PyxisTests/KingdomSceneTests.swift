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
        // Only the first bought Drill Yard rank guarantees +1 — later
        // ranks are nondecreasing and can still round away. At infantry
        // Lv 1 the second rank is such a tie: the raw 1 x 1.10 -> 1 stays
        // under the floored 2, so the example must not imply a gain.
        var state = KingdomGameState(gold: 100)
        state.treasury.setLevel(1, for: .drillYard)
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: try makeStore(initialState: state),
            safeAreaInsetsOverride: .init(top: 59, left: 0, bottom: 34, right: 0)
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let drillYard = try #require(scene.treasuryRowTextForTesting(.drillYard))
        #expect(drillYard.effect == KingdomScene.drillYardExampleText(for: state))
        #expect(drillYard.effect == "Infantry Lv 1 vs this city's trait:\n2 → 2 attack (no damage change yet)")

        // VoiceOver reads the same un-compacted disclosure.
        let row = try #require(
            (view.accessibilityElements as? [UIAccessibilityElement])?
                .first { $0.accessibilityIdentifier == "kingdom-row-drillYard" }
        )
        #expect(row.accessibilityValue == drillYard.effect)
    }

    @Test("A later-rank Drill Yard tie stays disclosed on the narrowest row")
    func laterRankDrillYardTieStaysDisclosedAtNarrowWidth() throws {
        var state = KingdomGameState(gold: 100)
        state.treasury.setLevel(1, for: .drillYard)
        let size = CGSize(width: 264, height: 454)
        let scene = KingdomScene(
            size: size,
            store: try makeStore(initialState: state),
            safeAreaInsetsOverride: .zero
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        let layout = try #require(scene.kingdomLayoutForTesting)
        let index = try #require(TreasuryUpgrade.allCases.firstIndex(of: .drillYard))
        let labels = try #require(scene.treasuryRowLabelNodesForTesting(.drillYard))
        for label in labels {
            let parent = try #require(label.parent)
            #expect(layout.textFrames[index].contains(parent.convert(label.frame, to: scene)))
        }
        // The parenthesized no-change disclosure survives whichever
        // abbreviations the compact row renders.
        #expect(labels[2].text?.contains("(no") == true)
        let row = try #require(
            (view.accessibilityElements as? [UIAccessibilityElement])?
                .first { $0.accessibilityIdentifier == "kingdom-row-drillYard" }
        )
        #expect(row.accessibilityValue == KingdomScene.drillYardExampleText(for: state))
        #expect(row.accessibilityValue?.contains("(no damage change yet)") == true)
    }

    @Test("Drill Yard example displays a real rounded gain when one exists")
    func drillYardExampleShowsRealGain() {
        // A later-rank gain needs the raw round to clear the nondecreasing
        // floor: infantry level 10 (base 19) crosses the boundary at DY
        // 2 -> 3 — 19 x 1.10 -> 21, 19 x 1.15 -> 22.
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: 1,
            cityBattleStates: [CityKey(
                countryNumber: 1,
                cityNumber: 1
            ).storageKey: CityBattleState(
                slots: [1: CityBuilding(type: .barracks, level: 10)]
            )]
        )
        state.treasury.setLevel(2, for: .drillYard)

        let text = KingdomScene.drillYardExampleText(for: state)
        #expect(text == "Infantry Lv 10 vs this city's trait:\n21 → 22 attack")
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
    private func makeNonlethalIdleState(
        ownedEquipmentIDs: [String] = [],
        equippedItemBySoldierType: [String: String] = [:]
    ) -> KingdomGameState {
        let start = Date(timeIntervalSinceNow: -1_000)
        var state = KingdomGameState(
            gold: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive,
            ownedEquipmentIDs: ownedEquipmentIDs,
            equippedItemBySoldierType: equippedItemBySoldierType
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

        // Drill Yard at max reports the current attack with no "→"
        // projection — quoted through the instance effective projection
        // (first-rank floor included), never the raw static fold.
        let current = state.traitAdjustedSoldierAttackPower(for: .infantry, level: 1)
        #expect(current == 2)
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
        #expect(infantry.line2 == "Attack Lv 1 · +15% (atk 1 → 2) · Drops at City 6")

        // Nothing equipped and the type still locked at City 1: the row
        // still announces the earliest drop.
        let archer = try #require(scene.armoryRowTextForTesting(.archer))
        #expect(archer.line1 == "Archer · None")
        #expect(archer.line2 == "Drops at City 2")

        // A type with every catalog item owned but deliberately unequipped.
        let complete = KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: EquipmentCatalog.forType(.archer).map(\.id)
        )
        let completeScene = makeScene(store: try makeStore(initialState: complete))
        let allOwned = try #require(completeScene.armoryRowTextForTesting(.archer))
        #expect(allOwned.line1 == "Archer · None")
        #expect(allOwned.line2 == "All gear earned")

        // Specialist effect copy quotes the matched objective.
        let specialist = KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: ["c04-archer-tower"],
            equippedItemBySoldierType: ["archer": "c04-archer-tower"]
        )
        let specialistScene = makeScene(store: try makeStore(initialState: specialist))
        let archerTower = try #require(specialistScene.armoryRowTextForTesting(.archer))
        #expect(archerTower.line2 == "vs Arrow Tower Lv 1 · +40% (no gain yet) · Drops at City 2")

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
        let initialState = makeNonlethalIdleState(
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"]
        )
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

        // An EQUIPPED row whose art is missing falls back too.
        let missingArtScene = makeScene(store: store, imageLoader: { _ in nil })
        let equippedFallbackIcon = try #require(missingArtScene.armoryIconNodeForTesting(.infantry))
        #expect(equippedFallbackIcon is SKShapeNode)
    }

    @Test("Armory icons reuse their node until the equipped item changes")
    func armoryIconsReuseNodeAcrossUnchangedRedraws() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(store: store)
        selectArmory(scene)
        let firstIcon = try #require(scene.armoryIconNodeForTesting(.infantry))

        // Section switches redraw every label but must not rebuild icons.
        scene.handleTouchForTesting(
            at: try #require(scene.treasurySelectorHitFrameForTesting()).center
        )
        scene.handleTouchForTesting(
            at: try #require(scene.armorySelectorHitFrameForTesting()).center
        )
        #expect(scene.armoryIconNodeForTesting(.infantry) === firstIcon)

        // Cycling the equipped item rebuilds exactly that row's icon.
        scene.handleTouchForTesting(
            at: try #require(scene.armoryRowHitFrameForTesting(.infantry)).center
        )
        let secondIcon = try #require(scene.armoryIconNodeForTesting(.infantry))
        #expect(secondIcon !== firstIcon)
    }

    @Test("Armory icon holder and icon child own distinct node names")
    func armoryIconHolderAndChildNamesAreDistinct() throws {
        let store = try makeStore(initialState: makeGearOwningState())
        let scene = makeScene(store: store)
        selectArmory(scene)

        let row = try #require(scene.armoryRowNodeForTesting(.infantry))
        let holder = try #require(
            row.childNode(withName: "kingdomArmoryIconHolder-infantry")
        )
        let icon = try #require(
            row.childNode(withName: "//kingdomArmoryIcon-infantry")
        )
        // The icon prefix resolves to the rendered icon, never the holder.
        #expect(icon === scene.armoryIconNodeForTesting(.infantry))
        #expect(holder !== icon)
    }

    @Test("KingdomSection enumerates every section exactly once")
    func kingdomSectionAllCasesCoversSections() {
        #expect(KingdomSection.allCases == [.treasury, .armory, .ascend])
    }

    @Test("Armory drops the no-gain note once the bonus survives rounding")
    func armoryEffectNoteOnlyShowsWhenRoundedAway() throws {
        // Level-5 barracks: base 4 × 1.15 = 4.6 → 5 vs the bare 4 — the
        // first equipped attack rank guarantees the gain, so the row
        // reports the realized bare → equipped delta, no no-gain note.
        var state = KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"]
        )
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, level: 5)]
        )
        let scene = makeScene(store: try makeStore(initialState: state))
        selectArmory(scene)

        let infantry = try #require(scene.armoryRowTextForTesting(.infantry))
        #expect(infantry.line2 == "Attack Lv 1 · +15% (atk 4 → 5) · Drops at City 3")
    }

    @Test("Armory attack row discloses the realized bare → equipped attack")
    func armoryAttackRowDisclosesRealizedDelta() throws {
        // The nominal +15% is joined by the realized integers the spawn
        // path produces — the first equipped attack rank floors bare 1
        // to 2 — and VoiceOver announces the same delta.
        let state = KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"]
        )
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: try makeStore(initialState: state),
            safeAreaInsetsOverride: .init(top: 59, left: 0, bottom: 34, right: 0)
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        selectArmory(scene)

        let infantry = try #require(scene.armoryRowTextForTesting(.infantry))
        #expect(infantry.line2 == "Attack Lv 1 · +15% (atk 1 → 2) · Drops at City 3")
        let row = try #require(
            (view.accessibilityElements as? [UIAccessibilityElement])?
                .first { $0.accessibilityIdentifier == "kingdom-armory-row-infantry" }
        )
        #expect(row.accessibilityValue?.contains("Attack Lv 1 · +15%") == true)
        #expect(row.accessibilityValue?.contains("(atk 1 → 2)") == true)
    }

    @Test("Armory rows show the owned level and effective fractional percent")
    func armoryRowsShowLevelAndEffectivePercent() throws {
        // The blade at Lv2/Lv3 and the plate at Lv1: effect text reads the
        // leveled effect through `equippedEffect(for:)` — +22.5% stays
        // fractional, never rounding up to a claimed 23%.
        let bladeScene = makeScene(store: try makeStore(initialState: KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: ["c01-infantry-attack", "c03-infantry-toughness"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"],
            equipmentLevelsByID: ["c01-infantry-attack": 2]
        )))
        selectArmory(bladeScene)
        let blade = try #require(bladeScene.armoryRowTextForTesting(.infantry))
        #expect(blade.line2.contains("Attack Lv 2 · +22.5%"))
        #expect(!blade.line2.contains("23%"))

        var cappedState = KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: ["c01-infantry-attack", "c03-infantry-toughness"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"],
            equipmentLevelsByID: ["c01-infantry-attack": 3]
        )
        let ramScene = makeScene(store: try makeStore(initialState: cappedState))
        selectArmory(ramScene)
        let capped = try #require(ramScene.armoryRowTextForTesting(.infantry))
        #expect(capped.line2.contains("Attack Lv 3 · +30%"))

        _ = cappedState.equip(itemID: "c03-infantry-toughness")
        let plateScene = makeScene(store: try makeStore(initialState: cappedState))
        selectArmory(plateScene)
        let plate = try #require(plateScene.armoryRowTextForTesting(.infantry))
        #expect(plate.line2.contains("Max HP Lv 1 · +25%"))
    }

    @Test("Effect text formats every kind and level band with one decimal")
    func equipmentEffectTextUsesMaxOneDecimalPercent() {
        #expect(KingdomScene.equipmentEffectText(
            for: EquipmentEffect.attackBonus(0.15).scaled(toLevel: 1), level: 1
        ) == "Attack Lv 1 · +15%")
        #expect(KingdomScene.equipmentEffectText(
            for: EquipmentEffect.attackBonus(0.15).scaled(toLevel: 2), level: 2
        ) == "Attack Lv 2 · +22.5%")
        #expect(KingdomScene.equipmentEffectText(
            for: EquipmentEffect.attackBonus(0.15).scaled(toLevel: 3), level: 3
        ) == "Attack Lv 3 · +30%")
        #expect(KingdomScene.equipmentEffectText(
            for: EquipmentEffect.maxHPBonus(0.25).scaled(toLevel: 2), level: 2
        ) == "Max HP Lv 2 · +37.5%")
        #expect(KingdomScene.equipmentEffectText(
            for: EquipmentEffect.specialistBonus(target: .arrowTower, fraction: 0.4)
                .scaled(toLevel: 3),
            level: 3
        ) == "vs Arrow Tower Lv 3 · +80%")
    }

    @Test("Drill Yard example identifies equipped attack gear")
    func drillYardExampleIncludesAndLabelsEquippedGear() {
        var state = KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"]
        )
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, level: 5)]
        )
        state.treasury.setLevel(2, for: .drillYard)

        // The equipped blade Lv1 lifts the example's own projection: the
        // first gear rank floors +1 over bare at every DY rank, so both
        // sides of this later-rank tie read one higher than unequipped.
        #expect(KingdomScene.drillYardExampleText(for: state)
            == "Infantry Lv 5 + gear, city trait:\n6 → 6 attack (no damage change yet)")
        state.unequip(soldierType: .infantry)
        #expect(KingdomScene.drillYardExampleText(for: state)
            == "Infantry Lv 5 vs this city's trait:\n5 → 5 attack (no damage change yet)")
    }

    @Test("Drill Yard example labels Renown whenever it folds into the numbers")
    func drillYardExampleLabelsRenown() {
        var state = KingdomGameState(
            gold: 100,
            cityBattleStates: [CityKey(
                countryNumber: 1,
                cityNumber: 1
            ).storageKey: CityBattleState(
                slots: [1: CityBuilding(type: .barracks, level: 5)]
            )],
            ascensionCount: 1
        )
        state.treasury.setLevel(1, for: .drillYard)

        // Renown alone folds ×1.25 into the first-round seam — the label
        // must credit it, not silently imply gear is the only modifier.
        // Infantry Lv 5: 4 × 1.25 = 5 at DY 0, the first rank floors +1
        // to 6 at DY 1, and DY 2's raw 4 × 1.10 × 1.25 = 5.5 → 6 can
        // only tie it — a disclosed later-rank no-gain.
        #expect(KingdomScene.drillYardExampleText(for: state)
            == "Infantry Lv 5 + Renown, city trait:\n6 → 6 attack (no damage change yet)")

        // Gear + Renown: both modifiers named in order.
        state = KingdomGameState(
            gold: 100,
            cityBattleStates: [CityKey(
                countryNumber: 1,
                cityNumber: 1
            ).storageKey: CityBattleState(
                slots: [1: CityBuilding(type: .barracks, level: 5)]
            )],
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"],
            ascensionCount: 1
        )
        state.treasury.setLevel(2, for: .drillYard)
        let combined = KingdomScene.drillYardExampleText(for: state)
        #expect(combined.hasPrefix("Infantry Lv 5 + gear + Renown, city trait:\n"))
    }

    @Test("Equipped Drill Yard example fits the narrow Treasury row")
    func equippedDrillYardExampleFitsNarrowRow() throws {
        let state = KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"]
        )
        let size = CGSize(width: 264, height: 454)
        let scene = KingdomScene(
            size: size,
            store: try makeStore(initialState: state),
            safeAreaInsetsOverride: .zero
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        let layout = try #require(scene.kingdomLayoutForTesting)
        let index = try #require(TreasuryUpgrade.allCases.firstIndex(of: .drillYard))
        let labels = try #require(scene.treasuryRowLabelNodesForTesting(.drillYard))
        for label in labels {
            let parent = try #require(label.parent)
            #expect(layout.textFrames[index].contains(parent.convert(label.frame, to: scene)))
        }
        #expect(labels[2].text?.contains("gear + trait") == true)
        let row = try #require(
            (view.accessibilityElements as? [UIAccessibilityElement])?
                .first { $0.accessibilityIdentifier == "kingdom-row-drillYard" }
        )
        #expect(row.accessibilityValue == KingdomScene.drillYardExampleText(for: state))
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

        // A production gate-pause callback (same redraw path as foreground)
        // while unsupported must not reveal the selected section's stale
        // rows behind the translucent gate.
        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 3_000))
        #expect(scene.isTreasuryFitFailedForTesting)
        #expect(scene.armoryRowNodeForTesting(.infantry)?.isHidden == true)
        #expect(scene.treasuryRowNodeForTesting(.warChest)?.isHidden == true)

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

    @Test("Armory VoiceOver values carry the level and effective percent")
    func armoryVoiceOverIncludesLevelAndEffectivePercent() throws {
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: try makeStore(initialState: KingdomGameState(
                gold: 100,
                ownedEquipmentIDs: ["c01-infantry-attack"],
                equippedItemBySoldierType: ["infantry": "c01-infantry-attack"],
                equipmentLevelsByID: ["c01-infantry-attack": 2]
            )),
            safeAreaInsetsOverride: .init(top: 59, left: 0, bottom: 34, right: 0)
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        selectArmory(scene)

        let row = try #require(
            (view.accessibilityElements as? [UIAccessibilityElement])?
                .first { $0.accessibilityIdentifier == "kingdom-armory-row-infantry" }
        )
        // Complete value: item name, owned level, the effective
        // fractional percent (never a rounded-up 23%) and the realized
        // bare → equipped integer delta.
        #expect(row.accessibilityValue?.contains("Willowford Blade") == true)
        #expect(row.accessibilityValue?.contains("Lv 2") == true)
        #expect(row.accessibilityValue?.contains("+22.5%") == true)
        #expect(row.accessibilityValue?.contains("(atk 1 → 2)") == true)
        #expect(row.accessibilityValue?.contains("23%") == false)
    }

    @Test("Selector labels fit at or above the 9pt floor at both boundary widths")
    func selectorLabelsFitAboveFloorAtBoundaries() throws {
        for width in [CGFloat(264), 320, 393] {
            let store = try makeStore(initialState: makeGearOwningState())
            let scene = makeScene(
                size: CGSize(width: width, height: 454),
                store: store,
                safeAreaInsets: .zero
            )
            let layout = try #require(scene.kingdomLayoutForTesting)

            for (section, frame) in [
                (KingdomSection.treasury, layout.treasurySelectorFrame),
                (KingdomSection.armory, layout.armorySelectorFrame),
                (KingdomSection.ascend, layout.ascendSelectorFrame)
            ] {
                let label = try #require(scene.sectionSelectorLabelForTesting(section))
                #expect(label.fontSize >= 9, "\(section) below 9pt at \(width)")
                let parent = try #require(label.parent)
                #expect(
                    frame.contains(parent.convert(label.frame, to: scene)),
                    "\(section) label outside its selector frame at \(width)"
                )
            }
        }
    }

    @Test(
        "Armory rendered labels fit their reserved line boxes for every authored item",
        arguments: [CGFloat(264), 320]
    )
    func armoryRowLabelsFitReservedLineBoxesAtBoundary(width: CGFloat) throws {
        // Every authored equipment choice at both narrow boundary sizes,
        // not just representative ones: the layout's reserved line boxes
        // fitting is not enough — the RENDERED two-line copy must fit them
        // too. Each iteration owns the realistic city-1…N drop prefix and
        // equips one catalog item in its own row, so all 15 names, every
        // effect string, and every effect+next-drop combination renders;
        // the final iteration also covers the "All gear earned" rows.
        for item in EquipmentCatalog.items {
            let state = KingdomGameState(
                gold: 100,
                ownedEquipmentIDs: EquipmentCatalog.items
                    .filter { $0.cityNumber <= item.cityNumber }
                    .map(\.id),
                equippedItemBySoldierType: [item.soldierType.rawValue: item.id]
            )

            let scene = makeScene(
                size: CGSize(width: width, height: 454),
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
                        "width \(width), city \(item.cityNumber), \(type.rawValue): \(rendered) in \(box)"
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
        let broadhead = KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: EquipmentCatalog.items
                .filter { $0.cityNumber <= 4 }
                .map(\.id),
            equippedItemBySoldierType: ["archer": "c04-archer-tower"]
        )
        let broadheadScene = makeScene(
            size: CGSize(width: 320, height: 454),
            store: try makeStore(initialState: broadhead),
            safeAreaInsets: .zero
        )
        let archer = try #require(broadheadScene.armoryRowTextForTesting(.archer))
        #expect(archer.line1 == "Archer · Bramblegate Broadhead")
        #expect(archer.line2 == "vs Arrow Tower Lv 1 · +40% (no gain yet) · Drops at City 9")
    }

    @Test("Narrow Armory rows retain the full drop hint for VoiceOver")
    func narrowArmoryDropHintRemainsAccessible() throws {
        let state = KingdomGameState(
            ownedEquipmentIDs: EquipmentCatalog.items.filter { $0.cityNumber <= 4 }.map(\.id),
            equippedItemBySoldierType: ["archer": "c04-archer-tower"]
        )
        let size = CGSize(width: 264, height: 454)
        let scene = KingdomScene(
            size: size,
            store: try makeStore(initialState: state),
            safeAreaInsetsOverride: .zero
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        selectArmory(scene)

        let labels = try #require(scene.armoryRowLabelNodesForTesting(.archer))
        // At 264pt even the compacted hint overflows: the visible label
        // drops the next-drop segment, keeping effect, level, percent and
        // the no-gain disclosure legible.
        #expect(labels.line2.text == "vs Arrow Tower Lv 1 · +40% (no gain yet)")
        let row = try #require(
            (view.accessibilityElements as? [UIAccessibilityElement])?
                .first { $0.accessibilityIdentifier == "kingdom-armory-row-archer" }
        )
        #expect(row.accessibilityValue?.contains("Drops at City 9") == true)
    }

    // MARK: - HPA-672 Ascend section

    /// Country 1 complete with permanent gear: the one eligible shape.
    private func makeCountryCompleteState(ascensionCount: Int = 0) -> KingdomGameState {
        KingdomGameState(
            gold: 500,
            completedCityCount: KingdomGameState.firstCountryCityCount,
            stageStatus: .countryComplete,
            ownedEquipmentIDs: ["c01-infantry-attack", "c03-infantry-toughness"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"],
            equipmentLevelsByID: ["c01-infantry-attack": 2],
            ascensionCount: ascensionCount
        )
    }

    /// Switches to the Ascend section exactly the way a player tap does —
    /// and fails the test when the selector has no laid-out frame instead
    /// of tapping the scene origin.
    private func selectAscend(_ scene: KingdomScene) throws {
        let hit = try #require(scene.ascendSelectorHitFrameForTesting())
        scene.handleTouchForTesting(at: hit.center)
    }

    @Test("Ascend section shows renown header, bonus and reset/keep preview")
    func ascendSectionShowsContent() throws {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(makeCountryCompleteState(ascensionCount: 2))
        let scene = makeScene(store: store)
        defaults.resetStateSaveCount()

        // Count > 0: the two-label bottom header shows "Renown 2 · +50%".
        #expect(scene.renownTextForTesting == "Renown 2 · +50%")
        #expect(scene.selectedSectionForTesting == .treasury)

        try selectAscend(scene)
        #expect(scene.selectedSectionForTesting == .ascend)
        #expect(defaults.stateSaveCount == 0)

        let content = try #require(scene.ascendContentTextForTesting())
        #expect(content.bonus == "Renown bonus +50% → +75%")
        // The disclosure must state the full reset/keep matrix — asserted
        // as independent facts, never by comparing with the production
        // constants it was rendered from.
        expectCompleteResetKeepDisclosure(resets: content.resets, keeps: content.keeps)
        // Action enabled and no pending report: no visible requirement.
        #expect(content.requirement == nil)

        // The section shares the band: only the selected section shows.
        #expect(scene.treasuryRowNodeForTesting(.warChest)?.isHidden == true)
        #expect(scene.armoryRowNodeForTesting(.mage)?.isHidden == true)
        #expect(scene.ascendPanelNodeForTesting?.isHidden == false)
        #expect(scene.ascendActionTextForTesting == "Ascend")
        #expect(scene.isAscendActionEnabledForTesting)

        // Zero count: gold-only header (spec), bonus still starts at +0%.
        let freshScene = makeScene(store: try makeStore(initialState: makeCountryCompleteState()))
        #expect(freshScene.renownTextForTesting == nil)
        #expect(KingdomScene.ascendBonusText(for: makeCountryCompleteState())
            == "Renown bonus +0% → +25%")
    }

    @Test("Gold and Renown header labels fit together at both boundary widths")
    func renownAndGoldLabelsFitTogether() throws {
        for width in [CGFloat(264), 320] {
            let scene = makeScene(
                size: CGSize(width: width, height: 454),
                store: try makeStore(initialState: makeCountryCompleteState(ascensionCount: 2)),
                safeAreaInsets: .zero
            )
            let layout = try #require(scene.kingdomLayoutForTesting)

            let renown = scene.renownLabelNodeForTesting
            #expect(!renown.isHidden)
            #expect(renown.fontSize >= 10)
            let renownParent = try #require(renown.parent)
            #expect(layout.renownFrame.contains(
                renownParent.convert(renown.frame, to: scene)
            ))

            // The fitted gold label keeps clear of the renown box.
            let gold = scene.goldLabelNodeForTesting
            #expect(gold.fontSize >= 10)
            let goldParent = try #require(gold.parent)
            let goldFrame = goldParent.convert(gold.frame, to: scene)
            #expect(goldFrame.maxX <= layout.renownFrame.minX - 8)
            #expect(layout.goldFrame.contains(goldFrame))
        }
    }

    @Test("Ascend action is disabled mid-campaign and its taps change nothing")
    func ascendActionDisabledBeforeCompletion() throws {
        let store = try makeStore(initialState: KingdomGameState(
            gold: 100,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        try selectAscend(scene)

        // Inspectable but locked: the bonus still renders.
        let content = try #require(scene.ascendContentTextForTesting())
        #expect(content.bonus == "Renown bonus +0% → +25%")
        #expect(!scene.isAscendActionEnabledForTesting)
        // The unlock requirement is VISIBLE text in the content band, not
        // an accessibility-only value.
        #expect(content.requirement == "Requires Country 1 complete")

        let hit = try #require(scene.ascendPrimaryActionHitFrameForTesting())
        scene.handleTouchForTesting(at: hit.center)

        #expect(!scene.isAscendConfirmationArmedForTesting)
        #expect(router.requestedTabs.isEmpty)
        #expect(store.load().ascensionCount == 0)
        #expect(store.load().gold == 100)
    }

    @Test("A pending final report keeps Ascension disabled")
    func pendingFinalReportKeepsAscensionDisabled() throws {
        var state = makeCountryCompleteState()
        state.pendingBattleResult = BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: 15),
            conquestMode: .live,
            activeBattleSeconds: 60,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: nil,
            mvpDamageSharePercent: nil,
            usedFavorableUnit: false,
            usedExposedLane: false,
            goldEarned: 10
        )
        let store = try makeStore(initialState: state)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        try selectAscend(scene)

        #expect(!scene.isAscendActionEnabledForTesting)
        // The pending-report state names its own visible requirement.
        #expect(scene.ascendContentTextForTesting()?.requirement
            == "Confirm the final report first")
        scene.handleTouchForTesting(
            at: try #require(scene.ascendPrimaryActionHitFrameForTesting()).center
        )

        // The awaiting report is never acknowledged or discarded.
        #expect(!scene.isAscendConfirmationArmedForTesting)
        #expect(store.load().pendingBattleResult != nil)
        #expect(store.load().ascensionCount == 0)
        #expect(router.requestedTabs.isEmpty)
    }

    @Test("Two-tap Ascension confirms, saves once and routes to Battle")
    func ascendTwoTapConfirmCommitsOnce() throws {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        var state = makeCountryCompleteState(ascensionCount: 1)
        state.treasury.setLevel(2, for: .warChest)
        store.save(state)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        defaults.resetStateSaveCount()
        try selectAscend(scene)

        let action = try #require(scene.ascendPrimaryActionHitFrameForTesting())

        // First tap only arms the in-scene confirmation.
        scene.handleTouchForTesting(at: action.center)
        #expect(scene.isAscendConfirmationArmedForTesting)
        #expect(scene.ascendActionTextForTesting == "Confirm Ascension")
        #expect(defaults.stateSaveCount == 0)
        #expect(router.requestedTabs.isEmpty)

        // The Cancel target exists and is distinct from Confirm.
        let cancel = try #require(scene.ascendCancelHitFrameForTesting())
        #expect(!cancel.intersects(action))

        // The distinct Confirm Ascension tap commits once.
        scene.handleTouchForTesting(at: action.center)
        let saved = store.load()
        #expect(saved.ascensionCount == 2)
        #expect(saved.gold == 0)
        #expect(saved.cityNumberInCountry == 1)
        #expect(saved.completedCityCount == 0)
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.treasury == TreasuryState())
        #expect(saved.ownedEquipmentIDs == ["c01-infantry-attack", "c03-infantry-toughness"])
        #expect(saved.equippedItemBySoldierType["infantry"] == "c01-infantry-attack")
        #expect(saved.equipmentLevel(for: "c01-infantry-attack") == 2)
        #expect(defaults.stateSaveCount == 1)
        #expect(router.requestedTabs == [.battle])
        #expect(scene.isRoutingToBattleForTesting)

        // Repeated taps after the commit change nothing.
        scene.handleTouchForTesting(at: action.center)
        #expect(defaults.stateSaveCount == 1)
        #expect(router.requestedTabs == [.battle])
        #expect(store.load().ascensionCount == 2)
    }

    @Test("Cancel, section change and reconstruction disarm the confirmation")
    func cancelSectionChangeAndReconstructionDisarm() throws {
        let store = try makeStore(initialState: makeCountryCompleteState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        try selectAscend(scene)
        let action = try #require(scene.ascendPrimaryActionHitFrameForTesting())

        scene.handleTouchForTesting(at: action.center)
        #expect(scene.isAscendConfirmationArmedForTesting)

        scene.handleTouchForTesting(
            at: try #require(scene.ascendCancelHitFrameForTesting()).center
        )
        #expect(!scene.isAscendConfirmationArmedForTesting)
        #expect(scene.ascendActionTextForTesting == "Ascend")
        #expect(store.load().ascensionCount == 0)

        // A section change disarms without saving.
        scene.handleTouchForTesting(at: action.center)
        #expect(scene.isAscendConfirmationArmedForTesting)
        scene.handleTouchForTesting(
            at: try #require(scene.treasurySelectorHitFrameForTesting()).center
        )
        #expect(!scene.isAscendConfirmationArmedForTesting)
        #expect(store.load().ascensionCount == 0)

        // Reconstruction starts disarmed (the arming is transient).
        let rebuilt = makeScene(store: store, router: router)
        #expect(!rebuilt.isAscendConfirmationArmedForTesting)
    }

    @Test("A layout-gate pause disarms and blocks the confirmation while paused")
    func layoutGatePauseDisarmsAndBlocksAscension() throws {
        let store = try makeStore(initialState: makeCountryCompleteState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        try selectAscend(scene)
        let action = try #require(scene.ascendPrimaryActionHitFrameForTesting())
        scene.handleTouchForTesting(at: action.center)
        #expect(scene.isAscendConfirmationArmedForTesting)

        // The gate pause itself disarms: an armed Confirm must not survive
        // a pause that can outlast hours.
        scene.layoutGateWillPause(at: Date())
        #expect(!scene.isAscendConfirmationArmedForTesting)
        #expect(scene.ascendActionTextForTesting == "Ascend")

        // While paused the action is dead — no arm, no commit, no route.
        scene.handleTouchForTesting(at: action.center)
        #expect(!scene.isAscendConfirmationArmedForTesting)
        #expect(store.load().ascensionCount == 0)
        #expect(router.requestedTabs.isEmpty)

        // Resuming restores a fresh first tap: one tap re-arms, it does
        // not commit.
        scene.layoutGateWillResume(at: Date())
        scene.handleTouchForTesting(at: action.center)
        #expect(scene.isAscendConfirmationArmedForTesting)
        #expect(store.load().ascensionCount == 0)
        #expect(router.requestedTabs.isEmpty)
    }

    @Test("System backgrounding disarms and a resumed scene needs a fresh first tap")
    func backgroundDisarmsAscensionConfirmation() throws {
        let store = try makeStore(initialState: makeCountryCompleteState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        try selectAscend(scene)
        let action = try #require(scene.ascendPrimaryActionHitFrameForTesting())
        scene.handleTouchForTesting(at: action.center)
        #expect(scene.isAscendConfirmationArmedForTesting)

        let t0 = Date()
        scene.sceneDidEnterBackgroundForTesting(at: t0)
        #expect(!scene.isAscendConfirmationArmedForTesting)

        // While backgrounded the action stays dead.
        scene.handleTouchForTesting(at: action.center)
        #expect(!scene.isAscendConfirmationArmedForTesting)
        #expect(store.load().ascensionCount == 0)
        #expect(router.requestedTabs.isEmpty)

        // Foregrounding hours later: still disarmed, and the next tap only
        // re-arms — a single resumed tap never finishes the wipe.
        scene.sceneWillEnterForegroundForTesting(at: t0.addingTimeInterval(14_400))
        #expect(!scene.isAscendConfirmationArmedForTesting)
        scene.handleTouchForTesting(at: action.center)
        #expect(scene.isAscendConfirmationArmedForTesting)
        #expect(store.load().ascensionCount == 0)
        #expect(router.requestedTabs.isEmpty)
    }

    @Test("An accepted tab exit and scene dismissal disarm the confirmation")
    func tabExitAndDismissalDisarmConfirmation() throws {
        let store = try makeStore(initialState: makeCountryCompleteState())
        let router = RouteSpy()
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: store,
            router: router,
            safeAreaInsetsOverride: BattleChromeLayout.SafeAreaInsets(
                top: 59, left: 0, bottom: 34, right: 0
            )
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        try selectAscend(scene)
        scene.handleTouchForTesting(at: try #require(scene.ascendPrimaryActionHitFrameForTesting()).center)
        #expect(scene.isAscendConfirmationArmedForTesting)

        // The accepted exit leaves the scene: the controller presents the
        // destination inside the routing call — the spy dismisses the same
        // way, and the willMove(from:) dismissal owns the disarm. A
        // retained instance must not still offer Confirm without a fresh
        // first tap.
        router.onRequest = { [weak view] in view?.presentScene(nil) }
        scene.requestGameplayTabForTesting(.map)
        #expect(router.requestedTabs == [.map])
        #expect(!scene.isAscendConfirmationArmedForTesting)

        // Dismissal + re-presentation of the SAME instance: presenting
        // nil removes the scene (willMove(from:)) — the dismissal itself
        // must clear the arming; re-presenting (didMove) keeps it cleared
        // (spec: leaving the scene disarms).
        let retained = KingdomScene(
            size: size,
            store: store,
            router: router,
            safeAreaInsetsOverride: BattleChromeLayout.SafeAreaInsets(
                top: 59, left: 0, bottom: 34, right: 0
            )
        )
        let retainedView = SKView(frame: CGRect(origin: .zero, size: size))
        retainedView.presentScene(retained)
        try selectAscend(retained)
        retained.handleTouchForTesting(
            at: try #require(retained.ascendPrimaryActionHitFrameForTesting()).center
        )
        #expect(retained.isAscendConfirmationArmedForTesting)
        retainedView.presentScene(nil)
        #expect(!retained.isAscendConfirmationArmedForTesting)
        retainedView.presentScene(retained)
        #expect(!retained.isAscendConfirmationArmedForTesting)
        #expect(retained.ascendActionTextForTesting == "Ascend")
    }

    @Test("The complete reset/keep disclosure fits at the compact sizes")
    func ascendDisclosureFitsAtCompactSizes() throws {
        for width in [CGFloat(264), 320] {
            // Mid-campaign: every summary line including the visible
            // requirement renders at once — the worst case for collisions.
            let scene = makeScene(
                size: CGSize(width: width, height: 454),
                store: try makeStore(initialState: KingdomGameState(
                    gold: 100,
                    cityNumberInCountry: 3,
                    completedCityCount: 2,
                    stageStatus: .battleActive
                )),
                safeAreaInsets: .zero
            )
            try selectAscend(scene)
            let layout = try #require(scene.kingdomLayoutForTesting)
            let resets = try #require(scene.ascendResetsLabelNodeForTesting)
            let keeps = try #require(scene.ascendKeepsLabelNodeForTesting)
            let requirement = try #require(scene.ascendRequirementLabelNodeForTesting)

            // Every required fact is stated in the rendered text —
            // including deliberately empty slots.
            expectCompleteResetKeepDisclosure(
                resets: resets.text ?? "",
                keeps: keeps.text ?? ""
            )

            // Fitted inside its reserved box at the 9pt floor: no fact is
            // lost to overflow at either supported compact width.
            let boxes = [
                (resets, layout.ascendResetsLabelFrame),
                (keeps, layout.ascendKeepsLabelFrame),
                (requirement, layout.ascendRequirementLabelFrame)
            ]
            var renderedFrames: [CGRect] = []
            for (label, box) in boxes {
                #expect(!label.isHidden)
                #expect(label.fontSize >= 9)
                let parent = try #require(label.parent)
                let rendered = parent.convert(label.frame, to: scene)
                #expect(rendered.minX >= box.minX)
                #expect(rendered.maxX <= box.maxX)
                renderedFrames.append(rendered)
            }
            // Stacked summary lines never collide (spec: shrink within
            // tested bounds, never collide).
            for (upper, lower) in zip(renderedFrames, renderedFrames.dropFirst()) {
                #expect(!upper.intersects(lower))
            }
        }
    }

    @Test("The unlock requirement renders visibly and fits at the compact sizes")
    func ascendRequirementLabelFitsAtCompactSizes() throws {
        for width in [CGFloat(264), 320] {
            let scene = makeScene(
                size: CGSize(width: width, height: 454),
                store: try makeStore(initialState: KingdomGameState(
                    gold: 100,
                    cityNumberInCountry: 3,
                    completedCityCount: 2,
                    stageStatus: .battleActive
                )),
                safeAreaInsets: .zero
            )
            try selectAscend(scene)
            let layout = try #require(scene.kingdomLayoutForTesting)
            let label = try #require(scene.ascendRequirementLabelNodeForTesting)

            #expect(!label.isHidden)
            #expect(label.text == "Requires Country 1 complete")
            // Measured fit at the 9pt floor: the rendered text stays
            // inside its reserved box's width.
            #expect(label.fontSize >= 9)
            let parent = try #require(label.parent)
            let rendered = parent.convert(label.frame, to: scene)
            #expect(rendered.minX >= layout.ascendRequirementLabelFrame.minX)
            #expect(rendered.maxX <= layout.ascendRequirementLabelFrame.maxX)
        }
    }

    @Test("A confirm whose re-read store state is ineligible changes nothing")
    func confirmReReadsLatestStoreAndRespectsIneligibility() throws {
        let store = try makeStore(initialState: makeCountryCompleteState(ascensionCount: 1))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        try selectAscend(scene)
        let action = try #require(scene.ascendPrimaryActionHitFrameForTesting())
        scene.handleTouchForTesting(at: action.center)
        #expect(scene.isAscendConfirmationArmedForTesting)

        // Another surface overwrites the save mid-confirmation with a
        // mid-campaign state: the commit's re-read must reject it.
        store.save(KingdomGameState(
            gold: 7,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        scene.handleTouchForTesting(at: action.center)

        #expect(store.load().ascensionCount == 0)
        #expect(store.load().gold == 7)
        #expect(router.requestedTabs.isEmpty)
        #expect(!scene.isAscendConfirmationArmedForTesting)
    }

    @Test("Ascend icon prefers ascension-renown art with a vector fallback")
    func ascendIconArtAndFallback() throws {
        let artScene = makeScene(
            store: try makeStore(initialState: makeCountryCompleteState()),
            imageLoader: { $0 == "ascension-renown" ? UIImage(systemName: "star.fill") : nil }
        )
        try selectAscend(artScene)
        #expect(artScene.ascendIconNodeForTesting is SKSpriteNode)

        let fallbackScene = makeScene(
            store: try makeStore(initialState: makeCountryCompleteState()),
            imageLoader: { _ in nil }
        )
        #expect(fallbackScene.ascendIconNodeForTesting is SKShapeNode)
    }

    @Test("Ascend Confirm/Cancel stay isolated from the tab bar and Settings")
    func ascendHitTargetsStayIsolated() throws {
        let store = try makeStore(initialState: makeCountryCompleteState())
        let router = RouteSpy()
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: store,
            router: router,
            safeAreaInsetsOverride: BattleChromeLayout.SafeAreaInsets(
                top: 59, left: 0, bottom: 34, right: 0
            )
        )
        // The accepted exit presents the destination inside the routing
        // call; the spy dismisses the same way so willMove(from:) fires.
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        router.onRequest = { [weak view] in view?.presentScene(nil) }
        try selectAscend(scene)
        let layout = try #require(scene.kingdomLayoutForTesting)

        let primary = try #require(scene.ascendPrimaryActionHitFrameForTesting())
        // Scene y grows upward: the band sits ABOVE the bottom tab bar.
        #expect(primary.minY >= layout.tabBarFrame.maxY)
        #expect(!primary.intersects(layout.settingsFrame))

        // A Settings tap never arms or confirms Ascension.
        scene.handleTouchForTesting(at: layout.settingsFrame.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(!scene.isAscendConfirmationArmedForTesting)
        scene.activateFeedbackSettingsForTesting(.close)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)

        // A tab-bar tap while armed routes the exit and never commits.
        scene.handleTouchForTesting(at: primary.center)
        #expect(scene.isAscendConfirmationArmedForTesting)
        let mapIndex = try #require(GameplayTab.allCases.firstIndex(of: .map))
        scene.handleTouchForTesting(at: layout.tabHitFrames[mapIndex].center)
        #expect(router.requestedTabs == [.map])
        #expect(store.load().ascensionCount == 0)
        // The accepted exit's dismissal also disarms the confirmation.
        #expect(!scene.isAscendConfirmationArmedForTesting)
    }

    @Test("Ascend UI hides on unsupported geometry and recovers with its section")
    func ascendHidesOnUnsupportedGeometryAndRecovers() throws {
        let store = try makeStore(initialState: makeCountryCompleteState())
        let scene = makeScene(store: store)
        try selectAscend(scene)

        scene.size = CGSize(width: 320, height: 330)
        #expect(scene.isTreasuryFitFailedForTesting)
        #expect(scene.headerNodeForTesting?.isHidden == true)
        #expect(scene.ascendPanelNodeForTesting?.isHidden == true)

        scene.size = CGSize(width: 393, height: 852)
        #expect(!scene.isTreasuryFitFailedForTesting)
        #expect(scene.headerNodeForTesting?.isHidden == false)
        #expect(scene.selectedSectionForTesting == .ascend)
        #expect(scene.ascendPanelNodeForTesting?.isHidden == false)
        #expect(scene.treasuryRowNodeForTesting(.warChest)?.isHidden == true)
    }

    @Test("VoiceOver exposes the Ascend section, action state and reset/keep values")
    func accessibilityExposesAscendSection() throws {
        let size = CGSize(width: 393, height: 852)
        let insets = BattleChromeLayout.SafeAreaInsets(top: 59, left: 0, bottom: 34, right: 0)

        struct Exposed {
            let scene: KingdomScene
            let view: SKView
            let store: KingdomGameStore
            // The scene's router reference is weak — the test must retain
            // the spy or the commit's route request silently targets nil.
            let router: RouteSpy
        }
        func makeExposedScene(state: KingdomGameState) throws -> Exposed {
            let store = try makeStore(initialState: state)
            let router = RouteSpy()
            let scene = KingdomScene(
                size: size,
                store: store,
                router: router,
                safeAreaInsetsOverride: insets
            )
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            scene.didMove(to: view)
            return Exposed(scene: scene, view: view, store: store, router: router)
        }

        func element(_ identifier: String, in view: SKView) throws -> UIAccessibilityElement {
            try #require(
                (view.accessibilityElements as? [UIAccessibilityElement])?
                    .first { $0.accessibilityIdentifier == identifier }
            )
        }

        // Mid-campaign: the section is exposed, the action disabled.
        let locked = try makeExposedScene(state: KingdomGameState(
            gold: 100,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let lockedScene = locked.scene
        let lockedView = locked.view
        let lockedSection = try element("kingdom-section-ascend", in: lockedView)
        #expect(lockedSection.accessibilityActivate())
        #expect(lockedScene.selectedSectionForTesting == .ascend)

        let info = try element("kingdom-ascend-info", in: lockedView)
        #expect(info.accessibilityValue?.contains("Renown bonus +0% → +25%") == true)
        // VoiceOver reads the SAME complete reset/keep matrix — every
        // required fact, asserted independently of the scene constants.
        let valueParts = (info.accessibilityValue ?? "")
            .components(separatedBy: ". ")
        #expect(valueParts.count == 3)
        if valueParts.count == 3 {
            expectCompleteResetKeepDisclosure(
                resets: valueParts[1],
                keeps: valueParts[2]
            )
        }
        // Touch exploration over every visible summary line — including
        // the Keeps text and the visible requirement line — must land
        // inside the element that reads it (unit-test views have no
        // window, so the adapter keeps view-local flipped-Y frames).
        let lockedLayout = try #require(lockedScene.kingdomLayoutForTesting)
        for summaryFrame in [
            lockedLayout.ascendKeepsLabelFrame,
            lockedLayout.ascendRequirementLabelFrame
        ] {
            let screenFrame = CGRect(
                x: summaryFrame.minX,
                y: lockedView.bounds.height - summaryFrame.maxY,
                width: summaryFrame.width,
                height: summaryFrame.height
            )
            #expect(info.accessibilityFrame.contains(screenFrame))
        }
        let lockedAction = try element("kingdom-ascend-action", in: lockedView)
        #expect(lockedAction.accessibilityTraits.contains(.notEnabled))
        #expect(lockedAction.accessibilityValue?.contains("Country 1 complete") == true)
        // A disabled activation changes nothing.
        #expect(lockedAction.accessibilityActivate())
        #expect(!lockedScene.isAscendConfirmationArmedForTesting)

        // Complete: the same element arms, exposes Cancel, then commits.
        let exposed = try makeExposedScene(state: makeCountryCompleteState(ascensionCount: 1))
        let scene = exposed.scene
        let view = exposed.view
        let store = exposed.store
        let router = exposed.router
        let section = try element("kingdom-section-ascend", in: view)
        #expect(section.accessibilityActivate())

        let action = try element("kingdom-ascend-action", in: view)
        #expect(action.accessibilityLabel == "Ascend")
        #expect(!action.accessibilityTraits.contains(.notEnabled))
        #expect(action.accessibilityActivate())
        #expect(scene.isAscendConfirmationArmedForTesting)
        #expect(action.accessibilityLabel == "Confirm Ascension")

        let cancel = try element("kingdom-ascend-cancel", in: view)
        #expect(cancel.accessibilityActivate())
        #expect(!scene.isAscendConfirmationArmedForTesting)

        #expect(action.accessibilityActivate())
        #expect(action.accessibilityActivate())
        #expect(scene.isRoutingToBattleForTesting)
        #expect(router.requestedTabs == [.battle])
        #expect(store.load().ascensionCount == 2)
        #expect(store.load().stageStatus == .battleActive)
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
        KingdomGameState(
            gold: 100,
            ownedEquipmentIDs: ["c01-infantry-attack", "c03-infantry-toughness"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"]
        )
    }

    /// Switches sections exactly the way a player tap does.
    private func selectArmory(_ scene: KingdomScene) {
        let hit = try? scene.armorySelectorHitFrameForTesting()
        scene.handleTouchForTesting(at: CGPoint(x: hit?.midX ?? 0, y: hit?.midY ?? 0))
    }

    /// The spec's reset/keep matrix as independent required facts. The
    /// disclosure (visible text and accessibility value alike) must state
    /// each one — comparing rendered text with its own production
    /// constants would prove nothing.
    private func expectCompleteResetKeepDisclosure(resets: String, keeps: String) {
        let resetFacts = [
            "resets", "countr", "city", "building", "gold", "treasury"
        ]
        let keepFacts = [
            "keeps", "equipment", "selection", "slot", "empty", "level",
            "renown", "sound", "haptic"
        ]
        for fact in resetFacts {
            #expect(resets.lowercased().contains(fact), "resets line missing: \(fact)")
        }
        for fact in keepFacts {
            #expect(keeps.lowercased().contains(fact), "keeps line missing: \(fact)")
        }
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
