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
        #expect(warChest.level == "Lv 0/10")
        #expect(warChest.price == "Cost 40 gold")
        #expect(warChest.effect.contains("→"))
        #expect(scene.isBuyEnabledForTesting(.warChest))

        let quartermaster = try #require(scene.treasuryRowTextForTesting(.quartermaster))
        #expect(quartermaster.name == "Quartermaster")
        #expect(quartermaster.level == "Lv 0/8")
        #expect(quartermaster.price == "Cost 45 gold")
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
        #expect(warChest.price == "Cost 40 gold")
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
        #expect(drillYard.effect == "Infantry Lv 1 vs this city's trait: 1 → 1 attack (no damage change yet)")
    }

    @Test("Drill Yard example displays a real rounded gain when one exists")
    func drillYardExampleShowsRealGain() {
        // Infantry level 2 (base 2) at DY 4 -> 5 crosses the 2.5 rounding
        // boundary: 2 x 1.25 -> 3, so P -> Q must show a visible gain.
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: 1,
            cityBattleStates: [CityKey(
                countryNumber: 1,
                cityNumber: 1
            ).storageKey: CityBattleState(
                slots: [1: CityBuilding(type: .barracks, level: 2)]
            )]
        )
        state.treasury.setLevel(4, for: .drillYard)

        let text = KingdomScene.drillYardExampleText(for: state)
        #expect(text == "Infantry Lv 2 vs this city's trait: 2 → 3 attack")
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
        #expect(saved.gold == 60)
        #expect(defaults.stateSaveCount == 1)
        #expect(scene.goldTextForTesting == "Gold " + CompactNumberFormatter.string(from: 60))
        let warChest = try #require(scene.treasuryRowTextForTesting(.warChest))
        #expect(warChest.level == "Lv 1/10")
        #expect(warChest.price == "Cost 72 gold")
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
    /// entry settle is a no-op that only clears the anchor; a foreground hook
    /// then re-arms and a later settle can conquer.
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
        // settled the original anchor); the second foreground conquers.
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

        _ = makeScene(store: store, router: router)

        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
        #expect(router.requestedTabs == [.battle])
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
        // No persisted anchor: the entry settle is a no-op and the foreground
        // hook arms the anchor at a deterministic date.
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
        #expect(store.load().lastBackgroundedAt == nil)
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

        // The entry settle conquered and tried to route; the router declined.
        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
        #expect(router.requestedTabs == [.battle])

        scene.requestGameplayTabForTesting(.map)

        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
        #expect(router.requestedTabs == [.battle, .map])
        #expect(!scene.isRoutingToBattleForTesting)
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

    private final class RouteSpy: KingdomSceneRouting {
        var acceptsAllRequests = true
        private(set) var requestedTabs: [GameplayTab] = []
        private(set) var requestedGateReason: AppLayoutGateReason?

        func kingdomSceneDidRequestGameplayTab(_ scene: KingdomScene, tab: GameplayTab) -> Bool {
            requestedTabs.append(tab)
            return acceptsAllRequests
        }

        func kingdomScene(_ scene: KingdomScene, didRequestLayoutGate reason: AppLayoutGateReason) {
            requestedGateReason = reason
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
