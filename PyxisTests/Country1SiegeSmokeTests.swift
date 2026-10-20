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
        let manualSpawnsEnabled: Bool

        var stalled: Bool { !reachedConquest }
    }

    nonisolated static let maxSimulatedSeconds = 900.0
    static let ticksPerSecond = 10
    static let manualSpawnEveryTicks = 10

    /// `maxSimulatedSeconds` only exists so the stall check can use a short bound.
    /// `manualSpawnsEnabled: false` is the watch-only policy (controller R10): no
    /// manual spawns, so only building-spawned soldiers and automatic Captain/Rally act.
    static func run(
        city: Int,
        lane: BattleLane,
        camp: [Building],
        soldierUpgradeLevel: Int,
        seed: UInt64,
        maxSimulatedSeconds: Double = maxSimulatedSeconds,
        manualSpawnsEnabled: Bool = true
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
            if manualSpawnsEnabled, tick % manualSpawnEveryTicks == 0 {
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
            guardsSpawned: guards.map { Country1GuardRules.totalReserve - $0.remainingReserve },
            guardReserveRemaining: guards?.remainingReserve,
            barracksShutdownSeconds: barracksShutdownTick.map { Double($0) / Double(ticksPerSecond) },
            manualSpawnsEnabled: manualSpawnsEnabled
        )
    }

    static func line(for result: Result) -> String {
        let camp = result.camp.isEmpty
            ? "none"
            : result.camp.map { "\($0.type.rawValue):L\($0.level)" }.joined(separator: ",")
        let waves = result.guardsSpawned.map { String($0 / Country1GuardRules.guardsPerWave) } ?? "n/a"
        let reserve = result.guardReserveRemaining.map(String.init) ?? "n/a"
        let shutdown = result.barracksShutdownSeconds.map { String(format: "%.1f", $0) } ?? "none"
        // Appended only for watch-only runs so the default pilot lines stay byte-identical.
        let watchOnlyTokens = result.manualSpawnsEnabled ? [] : ["manualSpawns=off"]
        return ([
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
        ] + watchOnlyTokens).joined(separator: " ")
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
            guardReinforcements: layout.barracksObjective != nil ? .freshCountry1() : nil,
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

    private static let city1Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 1)
    ]

    private static let city5Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 1)
    ]

    /// Watch-only camps for the authored Country 1 cities (HPA-477). Budget is
    /// the production starting gold (15) plus the rewards earned through the
    /// previous city (`goldReward` 8, 12, 17, ...). Only building types unlocked
    /// by the city are used. Buildings are reset on conquest, so each camp is
    /// bought fresh. Soldier upgrade stays at 1, so soldiers cost nothing extra.
    ///
    /// City 2: budget 23 (15 + 8); unlocked Barracks, Archery Range.
    /// Barracks L1 = 15 (leftover 8).
    private static let city2Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 1)
    ]

    /// City 4: budget 52 (15 + 8 + 12 + 17); unlocked Barracks, Archery Range.
    /// Barracks L2 (15 + 12) + Archery Range L1 (18) = 45 (leftover 7).
    private static let city4Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 2),
        .init(type: .archeryRange, level: 1)
    ]

    /// City 6: budget 111 (15 + 96); unlocked Barracks, Archery Range, Stable.
    /// Barracks L3 (47) + Archery Range L2 (32) + Stable L1 (28) = 107 (leftover 4).
    private static let city6Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 3),
        .init(type: .archeryRange, level: 2),
        .init(type: .stable, level: 1)
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

    @Test("City 1 default lane watch-only conquers inside the bounded simulated budget")
    func city1WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 1,
            lane: .center,
            camp: Self.city1Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    @Test("City 2 default lane watch-only conquers inside the bounded simulated budget")
    func city2WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 2,
            lane: .right,
            camp: Self.city2Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    @Test("City 4 default lane watch-only conquers inside the bounded simulated budget")
    func city4WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 4,
            lane: .center,
            camp: Self.city4Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    @Test("City 6 default lane watch-only conquers inside the bounded simulated budget")
    func city6WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 6,
            lane: .left,
            camp: Self.city6Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    /// Discriminating pair for watch-only (controller R11): with an empty camp and
    /// manual spawns off nothing attacks, so the bounded run stalls. The same setup
    /// with manual spawns on conquers inside the same 30 simulated-second bound.
    @Test("City 1 empty-camp watch-only stalls inside 30 simulated seconds")
    func city1EmptyCampWatchOnlyStallsWithinThirtySeconds() {
        let result = Country1SiegeSmoke.run(
            city: 1,
            lane: .center,
            camp: [],
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            maxSimulatedSeconds: 30,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.stalled)
    }

    @Test("City 1 empty-camp manual spawns conquer inside the same 30 simulated seconds")
    func city1EmptyCampManualSpawnsConquerWithinThirtySeconds() {
        let result = Country1SiegeSmoke.run(
            city: 1,
            lane: .center,
            camp: [],
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            maxSimulatedSeconds: 30,
            manualSpawnsEnabled: true
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
