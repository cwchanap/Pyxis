//
//  Country1EmberfordGuardTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

/// City 7 (Emberford) is the first Country 1 Barracks city besides the Highcrest
/// pilot (HPA-477). These scene tests prove that its Guard waves follow the
/// Barracks, stop once it falls while the Guards already fielded remain, and
/// round-trip through the store under the shared Country 1 Guard rules.
@MainActor
struct Country1EmberfordGuardTests {
    private static let cityNumber = 7

    private static var layout: CitySiegeLayout {
        Country1CityCatalog.definition(for: cityNumber).siegeLayout
    }

    private static var barracksID: String {
        layout.barracksObjective?.id ?? ""
    }

    private static func maxPower(of objectiveID: String) -> Int {
        layout.maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: cityNumber))[objectiveID] ?? 0
    }

    /// Fresh City 7 entry at full Keep HP on the default centre lane.
    private static func freshEntryState() -> KingdomGameState {
        SiegeTestSupport.makeBattleState(
            atCity: cityNumber,
            gold: 0,
            keepRemaining: maxPower(of: layout.keepObjective.id)
        )
    }

    private static func makeStore(initialState: KingdomGameState) -> KingdomGameStore {
        let suiteName = "Country1EmberfordGuard.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }

    private static func makeScene(store: KingdomGameStore) -> BattleScene {
        let size = CGSize(width: 390, height: 844)
        let suiteName = "Country1EmberfordGuardPrefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let scene = BattleScene(
            size: size,
            store: store,
            feedback: NoOpGameplayFeedbackProvider(),
            feedbackPreferences: FeedbackPreferencesStore(defaults: defaults, keyPrefix: "prefs"),
            launchArguments: [],
            combatSeed: 477
        )
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: size)))
        return scene
    }

    private static func guardSnapshots(of scene: BattleScene) -> [GuardSnapshot] {
        scene.livingGuardsForTesting.map { GuardSnapshot(lane: $0.lane, remainingHP: $0.currentHP) }
    }

    private static func barracksStatusText(of scene: BattleScene) throws -> String? {
        let barracks = try #require(scene.siegeObjectiveNodeForTesting(.barracks))
        let label = try #require(barracks.childNode(withName: "siegeBarracksStatus") as? SKLabelNode)
        return label.text
    }

    @Test("Emberford Guard waves follow its Barracks and stop once it falls")
    func emberfordGuardWavesFollowBarracksAndStopWhenItFalls() throws {
        let entry = Self.freshEntryState()
        #expect(entry.siegeProgress.guardReinforcements == .freshCountry1())
        let store = Self.makeStore(initialState: entry)
        let scene = Self.makeScene(store: store)

        // Before the first wave is due, nothing is fielded and the full reserve remains.
        scene.advanceCombatForTesting(deltaTime: 29.9)
        #expect(Self.guardSnapshots(of: scene).isEmpty)
        #expect(store.load().siegeProgress.guardReinforcements?.remainingReserve == Country1GuardRules.totalReserve)

        // The first wave is due at 30 s: two full-HP Guards and a reserve of 10.
        scene.advanceCombatForTesting(deltaTime: 0.2)
        #expect(Self.guardSnapshots(of: scene) == [
            GuardSnapshot(lane: .center, remainingHP: Country1GuardRules.maxHP),
            GuardSnapshot(lane: .center, remainingHP: Country1GuardRules.maxHP)
        ])
        #expect(try Self.barracksStatusText(of: scene) == "GUARDS 2")
        #expect(store.load().siegeProgress.guardReinforcements?.remainingReserve == 10)

        // The schedule keeps going while the Barracks stands: the second wave takes the reserve to 8.
        scene.advanceCombatForTesting(deltaTime: 30.0)
        #expect(store.load().siegeProgress.guardReinforcements?.remainingReserve == 8)

        // Destroy the Barracks through the production attack path and reload the save.
        // The Guards already fielded must come back intact, and no later wave may spawn.
        let beforeFall = store.load()
        let fielded = try #require(beforeFall.siegeProgress.guardReinforcements?.unresolvedGuards)
        var fallen = beforeFall
        _ = fallen.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: Self.barracksID,
                appliedDamage: Self.maxPower(of: Self.barracksID)
            )
        ])
        store.save(fallen)

        let shutdownScene = Self.makeScene(store: store)
        #expect(try Self.barracksStatusText(of: shutdownScene) == "SHUT DOWN")
        #expect(Self.guardSnapshots(of: shutdownScene) == fielded)

        shutdownScene.advanceCombatForTesting(deltaTime: 90.0)
        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.remainingReserve == 8)
        // The Vanguard Captain (auto-deployed from City 3) engages the fielded Guards during the extra
        // 90 s, so the roster may shrink. Guards still remain: the shutdown and time never clear the
        // roster, none is added, and the save matches the live roster.
        let survivors = Self.guardSnapshots(of: shutdownScene)
        #expect(!survivors.isEmpty)
        #expect(survivors.count <= fielded.count)
        #expect(persisted.unresolvedGuards == survivors)
    }

    @Test("Emberford Guard state round-trips through the store and restores into combat")
    func emberfordGuardStateRoundTripsThroughStore() throws {
        // A damaged Guard mid-wave: the persisted roster must restore without healing.
        var state = Self.freshEntryState()
        state.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 12.5,
            remainingReserve: 10,
            unresolvedGuards: [GuardSnapshot(lane: .center, remainingHP: 5)]
        )
        let store = Self.makeStore(initialState: state)
        let scene = Self.makeScene(store: store)
        let keepProgress = Self.layout.keepObjective.visualProgress

        // Restored at Keep progress with its HP intact.
        #expect(Self.guardSnapshots(of: scene) == [GuardSnapshot(lane: .center, remainingHP: 5)])
        #expect(scene.livingGuardsForTesting.first?.position == keepProgress)

        // A tick persists the same roster and reserve back to the save.
        scene.advanceCombatForTesting(deltaTime: 0.2)
        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.unresolvedGuards == [GuardSnapshot(lane: .center, remainingHP: 5)])
        #expect(persisted.remainingReserve == 10)

        // A relaunch restores the same Guard, still damaged.
        let relaunched = Self.makeScene(store: store)
        #expect(Self.guardSnapshots(of: relaunched) == [GuardSnapshot(lane: .center, remainingHP: 5)])
        #expect(relaunched.livingGuardsForTesting.first?.position == keepProgress)
    }
}
