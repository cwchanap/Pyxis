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
/// round-trip through the store under the shared Country 1 Guard rules. They
/// also pin Guard-only ticks, lane switches with Guards fielded, the automatic
/// Captain Rally, and one non-final conquest payout on this same city.
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

    /// A recovering Captain (0 HP) that stays out of the fight for its full recovery window
    /// (`VanguardCaptainRules.recoverySeconds`), so Guard and lane tests stay focused. A test that
    /// advances live combat past that window lets it redeploy.
    private static var parkedCaptain: VanguardCaptainProgress {
        VanguardCaptainProgress(
            lane: .left,
            remainingHP: 0,
            recoveryRemainingSeconds: VanguardCaptainRules.recoverySeconds,
            rallyConsumed: false
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

    @Test("A guard-only Emberford tick persists Guard HP without any structure damage")
    func emberfordGuardOnlyTickPersistsGuardHPWithoutStructureDamage() throws {
        // The centre route is the Gate route, and the Keep's fire does not cover the centre lane,
        // so a lone soldier reaches its Guard unshot. The Gate starts at 2 HP, so any structure
        // hit shows up as a changed damage total.
        let gateID = try #require(Self.layout.objectives.first { $0.kind == .gate }?.id)
        let gateMax = Self.maxPower(of: gateID)
        var state = SiegeTestSupport.makeBattleState(
            atCity: Self.cityNumber,
            keepRemaining: Self.maxPower(of: Self.layout.keepObjective.id),
            supportDamage: [.gate: gateMax - 2],
            selectedLane: .center
        )
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .center, remainingHP: Country1GuardRules.maxHP)
        ]
        state.siegeProgress.captain = Self.parkedCaptain
        let store = Self.makeStore(initialState: state)
        let scene = Self.makeScene(store: store)
        scene.spawnSoldierForTesting()

        func persistedGuardHP() -> Int? {
            store.load().siegeProgress.guardReinforcements?.unresolvedGuards.first?.remainingHP
        }
        // Bounded below the first 30 s wave, so only the existing Guard can fight in the loop.
        var ticks = 0
        while ticks < 250, persistedGuardHP() == Country1GuardRules.maxHP {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
            ticks += 1
        }

        // The Guard took the soldier's hit, and its HP reached the save without a structure attack.
        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.unresolvedGuards.map(\.lane) == [.center])
        let guardHP = try #require(persisted.unresolvedGuards.first?.remainingHP)
        #expect(guardHP > 0 && guardHP < Country1GuardRules.maxHP)
        // No structure was hit: the Gate keeps its pre-set 2 HP, nothing touched the Barracks or Keep.
        #expect(store.load().siegeProgress.damageByObjectiveID[gateID] == gateMax - 2)
        #expect(store.load().siegeProgress.damageByObjectiveID[Self.barracksID] == nil)
        #expect(store.load().currentKeepRemainingPower == store.load().currentKeepMaxPower)
    }

    @Test("Switching the assault lane with Guards fielded persists the lane and keeps the roster's lanes")
    func emberfordLaneSwitchPersistsLaneAndExistingGuardRoster() throws {
        var entry = SiegeTestSupport.makeBattleState(
            atCity: Self.cityNumber,
            keepRemaining: Self.maxPower(of: Self.layout.keepObjective.id),
            selectedLane: .center
        )
        entry.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: 10,
            unresolvedGuards: [GuardSnapshot(lane: .center, remainingHP: 7)]
        )
        entry.siegeProgress.captain = Self.parkedCaptain
        let store = Self.makeStore(initialState: entry)
        let scene = Self.makeScene(store: store)

        let layout = try #require(scene.battleChromeLayoutForTesting)
        let leftChip = try #require(layout.laneChipHitFrames[.left])
        scene.handleTouchForTesting(at: CGPoint(x: leftChip.midX, y: leftChip.midY))

        // The new lane is saved, and the fielded Guard keeps its own lane and HP.
        #expect(store.load().siegeProgress.selectedLane == .left)
        #expect(store.load().siegeProgress.guardReinforcements?.unresolvedGuards == [
            GuardSnapshot(lane: .center, remainingHP: 7)
        ])

        // A relaunch restores the selected lane and the same roster on its original lane.
        let relaunched = Self.makeScene(store: store)
        #expect(relaunched.gameStateForTesting.siegeProgress.selectedLane == .left)
        #expect(Self.guardSnapshots(of: relaunched) == [GuardSnapshot(lane: .center, remainingHP: 7)])

        // The next wave deploys on the newly selected lane and never re-lanes the survivor.
        // 30.5 s, not 30.0: summed 0.1 s steps can land just under the 30 s wave boundary.
        relaunched.advanceCombatForTesting(deltaTime: 30.5)
        #expect(store.load().siegeProgress.guardReinforcements?.unresolvedGuards.map(\.lane) == [.center, .left, .left])
    }

    @Test("Emberford deploys its Captain at battle start on the selected lane with Rally unused")
    func emberfordCaptainDeploysAtBattleStart() throws {
        let state = SiegeTestSupport.makeBattleState(
            atCity: Self.cityNumber,
            keepRemaining: Self.maxPower(of: Self.layout.keepObjective.id),
            selectedLane: .right
        )
        let store = Self.makeStore(initialState: state)
        let scene = Self.makeScene(store: store)

        let captain = try #require(scene.livingCaptainForTesting)
        #expect(captain.lane == .right)
        #expect(captain.currentHP == VanguardCaptainRules.maxHP(for: 1))
        #expect(store.load().siegeProgress.captain?.rallyConsumed == false)
        #expect(scene.rallyRemainingSecondsForTesting == 0)
    }

    @Test("Emberford fires Rally automatically when Keep fire crosses an ordinary soldier below half HP")
    func emberfordAutoRallyFiresThroughLiveTick() throws {
        // As in the City 3 auto-Rally case, the Captain recovers behind the soldier so the Keep's fire
        // lands on the ordinary soldier first. The right lane is Emberford's exposed lane (0.80x fire),
        // so the soldier steps from full to below half HP and survives. The fortified left lane (1.25x)
        // would take it from half straight to dead.
        var state = SiegeTestSupport.makeBattleState(
            atCity: Self.cityNumber,
            keepRemaining: Self.maxPower(of: Self.layout.keepObjective.id),
            selectedLane: .right
        )
        state.siegeProgress.captain = VanguardCaptainProgress(
            lane: .right,
            remainingHP: 0,
            recoveryRemainingSeconds: 0.4,
            rallyConsumed: false
        )
        let store = Self.makeStore(initialState: state)
        let scene = Self.makeScene(store: store)
        scene.spawnSoldierForTesting()

        var rallyActivated = false
        for _ in 0..<400 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
            if scene.rallyRemainingSecondsForTesting > 0 {
                rallyActivated = true
                break
            }
        }
        #expect(rallyActivated)
        #expect(store.load().siegeProgress.captain?.rallyConsumed == true)
        #expect(scene.livingCaptainForTesting != nil)
    }

    @Test("An ordinary Emberford conquest pays its reward and presents its report exactly once")
    func emberfordOrdinaryConquestPaysOnceAndPresentsOneReport() throws {
        var state = SiegeTestSupport.makeBattleState(
            atCity: Self.cityNumber,
            gold: 100,
            keepRemaining: 1,
            selectedLane: .right
        )
        state.siegeProgress.captain = Self.parkedCaptain
        let store = Self.makeStore(initialState: state)
        let scene = Self.makeScene(store: store)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        let reward = state.goldReward(forCity: Self.cityNumber)
        let pending = try #require(store.load().pendingBattleResult)
        #expect(pending.cityKey == CityKey(countryNumber: 1, cityNumber: Self.cityNumber))
        #expect(pending.conquestMode == .live)
        #expect(pending.goldEarned == reward)
        #expect(store.load().gold == 100 + reward)
        #expect(scene.conquestEffectPresentationCountForTesting == 1)

        // A resize, a further tick and a relaunch never pay again or present a second report.
        scene.repeatDidMoveForTesting()
        scene.refreshLayoutForCurrentEnvironment()
        scene.advanceCombatForTesting(deltaTime: 3.0)
        let relaunched = Self.makeScene(store: store)
        relaunched.advanceCombatForTesting(deltaTime: 3.0)

        #expect(store.load().gold == 100 + reward)
        #expect(store.load().pendingBattleResult == pending)
        #expect(scene.conquestEffectPresentationCountForTesting == 1)
        // A restored pending report is static: it is never presented as a fresh effect.
        #expect(relaunched.conquestEffectPresentationCountForTesting == 0)
    }
}
