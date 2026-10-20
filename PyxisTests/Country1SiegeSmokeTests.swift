//
//  Country1SiegeSmokeTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

/// Bounded, deterministic run-to-conquest smoke for Country 1 sieges (HPA-477).
///
/// Drives the production `BattleScene` through its existing DEBUG seams
/// (`advanceCombatForTesting`, `spawnSoldierForTesting`, ...) with a fixed
/// RNG seed, a fixed camp, a fixed upgrade level, and a fixed manual-spawn
/// cadence. It is a smoke rail, not a balance oracle: assertions cover
/// conquest inside a simulated-time bound and never exact balance values.
@MainActor
enum Country1SiegeSmoke {
    struct Building: Equatable {
        let type: BuildingType
        let level: Int
    }

    struct Result: Equatable {
        let city: Int
        let lane: BattleLane
        let camp: [Building]
        let soldierUpgradeLevel: Int
        let seed: UInt64
        let reachedConquest: Bool
        let elapsedSeconds: Double
        let troopLosses: Int
        /// `nil` when the city has no Barracks and therefore no Guard reserve.
        let guardsSpawned: Int?
        let guardReserveRemaining: Int?
        /// Simulated second at which the Barracks reached 0 HP, if it did.
        let barracksShutdownSeconds: Double?

        var stalled: Bool { !reachedConquest }
    }

    static let maxSimulatedSeconds = 900.0
    static let ticksPerSecond = 10
    static let manualSpawnEveryTicks = 10

    /// `maxSimulatedSeconds` only exists so the stall check can use a short bound.
    static func run(
        city: Int,
        lane: BattleLane,
        camp: [Building],
        soldierUpgradeLevel: Int,
        seed: UInt64,
        maxSimulatedSeconds: Double = maxSimulatedSeconds
    ) -> Result {
        let suiteName = "Country1SiegeSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState(city: city, lane: lane, camp: camp, soldierUpgradeLevel: soldierUpgradeLevel))

        let size = CGSize(width: 390, height: 844)
        let scene = BattleScene(
            size: size,
            store: store,
            feedback: NoOpGameplayFeedbackProvider(),
            feedbackPreferences: FeedbackPreferencesStore(defaults: defaults, keyPrefix: "prefs"),
            launchArguments: [],
            combatSeed: seed
        )
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: size)))

        let spawnTypes = scene.manualSpawnableSoldierTypesForTesting
        let barracksID = Country1CityCatalog.definition(for: city).siegeLayout.barracksObjective?.id
        let maxTicks = Int((maxSimulatedSeconds * Double(ticksPerSecond)).rounded(.down))
        var tick = 0
        var spawnCount = 0
        var barracksShutdownTick: Int?
        while tick < maxTicks, scene.gameStateForTesting.pendingBattleResult == nil {
            if tick % manualSpawnEveryTicks == 0 {
                scene.selectManualSoldierTypeForTesting(spawnTypes[spawnCount % spawnTypes.count])
                scene.spawnSoldierForTesting()
                spawnCount += 1
            }
            scene.advanceCombatForTesting(deltaTime: 1.0 / Double(ticksPerSecond))
            tick += 1
            if barracksShutdownTick == nil,
               let barracksID,
               scene.gameStateForTesting.currentSiegeSnapshot.objectiveRemainingPower[barracksID] == 0 {
                barracksShutdownTick = tick
            }
        }

        let finalState = scene.gameStateForTesting
        let guards = finalState.siegeProgress.guardReinforcements
        let losses = finalState.pendingBattleResult?.losses ?? finalState.activeSiegeSession?.losses ?? []
        return Result(
            city: city,
            lane: lane,
            camp: camp,
            soldierUpgradeLevel: soldierUpgradeLevel,
            seed: seed,
            reachedConquest: finalState.pendingBattleResult != nil,
            elapsedSeconds: Double(tick) / Double(ticksPerSecond),
            troopLosses: losses.reduce(0) { $0 + $1.count },
            guardsSpawned: guards.map { HighcrestGuardRules.totalReserve - $0.remainingReserve },
            guardReserveRemaining: guards?.remainingReserve,
            barracksShutdownSeconds: barracksShutdownTick.map { Double($0) / Double(ticksPerSecond) }
        )
    }

    static func line(for result: Result) -> String {
        let camp = result.camp.isEmpty
            ? "none"
            : result.camp.map { "\($0.type.rawValue):L\($0.level)" }.joined(separator: ",")
        let waves = result.guardsSpawned.map { String($0 / HighcrestGuardRules.guardsPerWave) } ?? "n/a"
        let reserve = result.guardReserveRemaining.map(String.init) ?? "n/a"
        let shutdown = result.barracksShutdownSeconds.map { String(format: "%.1f", $0) } ?? "none"
        return [
            "COUNTRY1_SMOKE",
            "city=\(result.city)",
            "lane=\(result.lane.displayName.lowercased())",
            "camp=\(camp)",
            "soldierUpgrade=\(result.soldierUpgradeLevel)",
            "seed=\(result.seed)",
            "outcome=\(result.reachedConquest ? "conquered" : "stalled")",
            "elapsed=\(String(format: "%.1f", result.elapsedSeconds))",
            "losses=\(result.troopLosses)",
            "guardWaves=\(waves)",
            "guardReserve=\(reserve)",
            "barracksShutdown=\(shutdown)"
        ].joined(separator: " ")
    }

    /// Mirrors `KingdomGameState.startCityFromMap` for a fresh entry, except the
    /// lane and camp are fixed inputs. Buildings are placed in slots 1...n.
    private static func initialState(
        city: Int,
        lane: BattleLane,
        camp: [Building],
        soldierUpgradeLevel: Int
    ) -> KingdomGameState {
        var slots: [Int: CityBuilding] = [:]
        for (index, building) in camp.enumerated() {
            slots[index + 1] = CityBuilding(type: building.type, level: building.level)
        }
        var state = KingdomGameState(
            gold: 0,
            normalSoldierUpgradeLevel: soldierUpgradeLevel,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [CityKey(countryNumber: 1, cityNumber: city).storageKey: CityBattleState(slots: slots)]
        )
        let layout = state.currentSiegeLayout
        state.siegeProgress = SiegeProgress(
            selectedLane: lane,
            damageByObjectiveID: [:],
            guardReinforcements: layout.barracksObjective != nil ? .freshHighcrest() : nil,
            captain: VanguardCaptainRules.isAvailable(cityNumber: city)
                ? .freshCaptain(selectedLane: lane, upgradeLevel: soldierUpgradeLevel)
                : nil
        )
        return state
    }
}

@MainActor
struct Country1SiegeSmokeTests {
    private static let seed: UInt64 = 477

    private static let city3Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 2),
        .init(type: .archeryRange, level: 1)
    ]

    private static let city5Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 1)
    ]

    @Test("City 3 default lane conquers inside the bounded simulated budget")
    func city3DefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 3,
            lane: .center,
            camp: Self.city3Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    @Test("City 3 alternate tower lane conquers inside the bounded simulated budget")
    func city3AlternateLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 3,
            lane: .left,
            camp: Self.city3Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    @Test("City 5 default lane conquers inside the bounded simulated budget")
    func city5DefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 5,
            lane: .right,
            camp: Self.city5Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    @Test("City 5 Barracks lane conquers inside the bounded simulated budget")
    func city5BarracksLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 5,
            lane: .left,
            camp: Self.city5Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    @Test("A siege that cannot finish inside its bound stops as a stall instead of hanging")
    func boundedHarnessReportsStallInsteadOfHanging() {
        let result = Country1SiegeSmoke.run(
            city: 5,
            lane: .right,
            camp: [],
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            maxSimulatedSeconds: 3
        )
        #expect(result.stalled)
        #expect(result.elapsedSeconds <= 3)
    }
}
