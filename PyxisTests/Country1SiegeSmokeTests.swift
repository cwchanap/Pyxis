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

    /// Opt-in gate for the heavy alternate-lane comparisons (City 15, ~27 s wall each).
    /// Run with `TEST_RUNNER_COUNTRY1_SMOKE_ROUTES=1` so xcodebuild forwards the variable
    /// into the test process. Off by default to keep the always-on suite cheap.
    nonisolated static let routeComparisonsEnabled = ProcessInfo.processInfo.environment["COUNTRY1_SMOKE_ROUTES"] == "1"

    /// Opt-in gate for the chained 15-city greedy campaign (HPA-582 Task 0).
    /// Run with `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1`. Off by default pending the
    /// Task 0 wall-clock measurement (always-on only if comparable to the existing
    /// default-route smoke coverage).
    nonisolated static let campaignEnabled = ProcessInfo.processInfo.environment["COUNTRY1_SMOKE_CAMPAIGN"] == "1"

    /// Fixed seed for the chained campaign run so every baseline/comparison run
    /// plays the same player.
    nonisolated static let campaignSeed: UInt64 = 582

    /// Fixed purchase date for all campaign `buildBuilding`/`upgradeBuilding`
    /// calls: no ambient wall-clock time may leak into idle building-credit
    /// settlement between purchases.
    nonisolated static let campaignPurchaseDate = Date(timeIntervalSinceReferenceDate: 0)

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
        let initial = initialState(city: city, lane: lane, camp: camp, soldierUpgradeLevel: soldierUpgradeLevel)
        let outcome = run(
            initialState: initial,
            store: store,
            defaults: defaults,
            seed: seed,
            maxSimulatedSeconds: maxSimulatedSeconds,
            manualSpawnsEnabled: manualSpawnsEnabled
        )
        return Result(
            city: city,
            lane: lane,
            camp: camp,
            soldierUpgradeLevel: soldierUpgradeLevel,
            seed: seed,
            reachedConquest: outcome.reachedConquest,
            elapsedSeconds: outcome.elapsedSeconds,
            troopLosses: outcome.troopLosses,
            guardsSpawned: outcome.guardsSpawned,
            guardReserveRemaining: outcome.guardReserveRemaining,
            barracksShutdownSeconds: outcome.barracksShutdownSeconds,
            manualSpawnsEnabled: manualSpawnsEnabled
        )
    }

    /// Actual final-state output of a bounded siege run (HPA-582 Task 0 seam
    /// split): everything the per-fixture `Result` needs plus the final
    /// `KingdomGameState` so a chained campaign can carry real state, gold and
    /// rewards into the next city instead of fabricating levels.
    struct BattleOutcome {
        let reachedConquest: Bool
        let elapsedSeconds: Double
        let troopLosses: Int
        /// `nil` when the city has no Barracks and therefore no Guard reserve.
        let guardsSpawned: Int?
        let guardReserveRemaining: Int?
        /// Simulated second at which the Barracks reached 0 HP, if it did.
        let barracksShutdownSeconds: Double?
        let finalState: KingdomGameState
    }

    /// Runs one bounded siege from an explicit initial state persisted through
    /// `store`, and returns the summary plus the actual final state. A fresh
    /// `BattleScene` is created per call; the loop is the same 10 Hz
    /// `advanceCombatForTesting` rail the authored fixtures have always used.
    /// `defaults` must be the same suite `store` persists into (scene feedback
    /// preferences share the run's isolation).
    static func run(
        initialState: KingdomGameState,
        store: KingdomGameStore,
        defaults: UserDefaults,
        seed: UInt64,
        maxSimulatedSeconds: Double = maxSimulatedSeconds,
        manualSpawnsEnabled: Bool = true
    ) -> BattleOutcome {
        store.save(initialState)

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
        let barracksID = Country1CityCatalog
            .definition(for: initialState.cityNumberInCountry).siegeLayout.barracksObjective?.id
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
        return BattleOutcome(
            reachedConquest: finalState.pendingBattleResult != nil,
            elapsedSeconds: Double(tick) / Double(ticksPerSecond),
            troopLosses: losses.reduce(0) { $0 + $1.count },
            guardsSpawned: guards.map { Country1GuardRules.totalReserve - $0.remainingReserve },
            guardReserveRemaining: guards?.remainingReserve,
            barracksShutdownSeconds: barracksShutdownTick.map { Double($0) / Double(ticksPerSecond) },
            finalState: finalState
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

    /// Diagnostic line for one chained-campaign city; never an exact-value
    /// assertion, only stall/pacing evidence. Operates on the file-scope
    /// `Country1CampaignCityRecord`. `nonisolated` so test-keypath/closure
    /// access stays synchronous.
    nonisolated static func campaignLine(for record: Country1CampaignCityRecord) -> String {
        let camp = record.camp.isEmpty
            ? "none"
            : record.camp.map { "\($0.type.rawValue):L\($0.level)" }.joined(separator: ",")
        return [
            "COUNTRY1_SMOKE",
            "campaign=1",
            "city=\(record.city)",
            "lane=\(record.lane.displayName.lowercased())",
            "camp=\(camp)",
            "startGold=\(record.startGold)",
            "spentGold=\(record.spentGold)",
            "endGold=\(record.endGold)",
            "seed=\(campaignSeed)",
            "outcome=\(record.reachedConquest ? "conquered" : "stalled")",
            "elapsed=\(String(format: "%.1f", record.elapsedSeconds))",
            "losses=\(record.troopLosses)"
        ].joined(separator: " ")
    }

    /// Chained 15-city campaign from the production fresh state (HPA-582 Task
    /// 0): per city, enter through the real transitions, buy the camp under the
    /// deterministic test-only greedy buyer via the real purchase mutations at
    /// a fixed date, run the bounded siege rail, and carry the actual final
    /// state — gold, rewards, progression — into the next city. Stops at the
    /// first stall so the evidence is preserved; conquests are never fabricated
    /// and rewards are never double-counted.
    static func runGreedyCampaign(seed: UInt64) -> [Country1CampaignCityRecord] {
        let suiteName = "Country1SiegeSmokeCampaign.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KingdomGameStore(defaults: defaults, key: "state")

        var state = KingdomGameState()
        var records: [Country1CampaignCityRecord] = []

        for city in 1...KingdomGameState.firstCountryCityCount {
            if city > 1 {
                state.acknowledgePendingBattleResult()
                guard case .entered = state.startCityFromMap(city) else {
                    // Progression broke unexpectedly; keep the collected
                    // evidence instead of fabricating a city entry.
                    break
                }
            }

            let startGold = state.gold
            var spentGold = 0
            while state.stageStatus == .battleActive,
                  let action = GreedyCampBuyer.nextAction(for: state) {
                let goldBefore = state.gold
                let purchased: Bool
                switch action.kind {
                case .build:
                    if case .built = state.buildBuilding(action.type, inSlot: action.slot, at: campaignPurchaseDate) {
                        purchased = true
                    } else {
                        purchased = false
                    }
                case .upgrade:
                    if case .upgraded = state.upgradeBuilding(inSlot: action.slot, at: campaignPurchaseDate) {
                        purchased = true
                    } else {
                        purchased = false
                    }
                }
                guard purchased else { break }
                spentGold += goldBefore - state.gold
            }

            let camp = state.cityBattleStateForCurrentCity.slots
                .sorted { $0.key < $1.key }
                .map { Building(type: $0.value.type, level: $0.value.level) }
            let lane = state.siegeProgress.selectedLane

            let outcome = run(
                initialState: state,
                store: store,
                defaults: defaults,
                seed: seed
            )
            state = outcome.finalState
            let record = Country1CampaignCityRecord(
                city: city,
                lane: lane,
                camp: camp,
                startGold: startGold,
                spentGold: spentGold,
                endGold: state.gold,
                elapsedSeconds: outcome.elapsedSeconds,
                troopLosses: outcome.troopLosses,
                reachedConquest: outcome.reachedConquest
            )
            records.append(record)
            print(campaignLine(for: record))

            guard outcome.reachedConquest else { break }
        }

        return records
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

/// One chained-campaign city record (HPA-582 Task 0): the bought camp plus
/// the real gold and outcome the chain carried through the city. File-scope
/// (nonisolated) so test keypaths over records stay non-throwing.
struct Country1CampaignCityRecord {
    let city: Int
    let lane: BattleLane
    let camp: [Country1SiegeSmoke.Building]
    /// Gold on arrival at the city, before purchases.
    let startGold: Int
    /// Gold paid for the bought camp.
    let spentGold: Int
    /// Gold after the battle (includes the conquest reward when conquered).
    let endGold: Int
    let elapsedSeconds: Double
    let troopLosses: Int
    let reachedConquest: Bool
}

/// One matched comparison (HPA-477 Task 8). Reuses a city's committed camp and spawn policy on one lane.
/// Only conquests are asserted; the printed line carries the balance numbers, which are never exact-value
/// assertions.
struct Country1RouteComparison: CustomTestStringConvertible, Sendable {
    let city: Int
    let lane: BattleLane
    let camp: [Country1SiegeSmoke.Building]
    let manualSpawnsEnabled: Bool

    var testDescription: String {
        "City \(city) \(lane.displayName.lowercased()) lane, \(manualSpawnsEnabled ? "manual spawns" : "watch-only")"
    }
}

@MainActor
struct Country1SiegeSmokeTests {
    private static let seed: UInt64 = 477

    /// City 3 pilot camp (manual-spawn pilot, Falconridge): Barracks L2 (15 + 12 = 27) + Archery Range L1
    /// (18) = 45 gold. The cumulative budget through City 2 is 35 (15 + 8 + 12), so this shipped pilot camp
    /// is 10 gold over that convention. It is kept as authored; the pilot lines stay byte-identical.
    private static let city3Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 2),
        .init(type: .archeryRange, level: 1)
    ]

    private static let city1Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 1)
    ]

    /// City 5 pilot camp (manual-spawn pilot, Highcrest): Barracks L1 = 15 of the 76-gold cumulative budget
    /// (15 + 8 + 12 + 17 + 24). The camp is thin, which is why its watch-only runs stall on every lane; the
    /// stall is a camp-size effect, not a spawn-policy dependency. See `city5WatchOnlyCamp` for the watch-only case.
    private static let city5Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 1)
    ]

    /// City 5 watch-only camp: Barracks L3 (47) + Archery Range L1 (18) = 65 of the 76-gold cumulative budget
    /// (leftover 11), within budget. Default right lane (exposed, 0.80x Tower fire) conquers in 367.6 s with 65
    /// losses. Other lanes on the same camp: left conquers in 297.2 s (Barracks down at 18.2 s); centre
    /// conquers in 834.0 s, close to the bound.
    private static let city5WatchOnlyCamp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 3),
        .init(type: .archeryRange, level: 1)
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

    /// City 7: budget 162 (15 + 147); unlocked Barracks, Archery Range, Stable.
    /// Barracks L4 (15 + 12 + 20 + 33) + Archery Range L2 (18 + 14) + Stable L2 (28 + 22)
    /// = 162, exactly the budget.
    private static let city7Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 4),
        .init(type: .archeryRange, level: 2),
        .init(type: .stable, level: 2)
    ]

    /// City 8 watch-only camp (realistic, not accelerated; R8 is no longer used here). Budget 236
    /// (15 + 221); unlocked Barracks, Archery Range, Stable, Mage Tower. Barracks L4 (80) + Archery
    /// Range L3 (55) + Stable L2 (50) + Mage Tower L1 (40) = 225 (leftover 11). The Tower fires on
    /// every lane, so the standard right and fortified centre Gate routes stall at the bound with
    /// all 283 spawned soldiers lost. The exposed left route is the Tower's own route and conquers
    /// in 202.6 s, so City 8 defaults to it. No weight or progress sweep conquers a Gate route here.
    private static let city8Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 4),
        .init(type: .archeryRange, level: 3),
        .init(type: .stable, level: 2),
        .init(type: .mageTower, level: 1)
    ]

    /// City 9 watch-only camp: budget 344 (15 + 329 of rewards through City 8); unlocked
    /// Barracks, Archery Range, Stable, Mage Tower. Five Barracks L3 (5 x 47 = 235) +
    /// Archery Range L2 (32) + Stable L1 (28) + Mage Tower L1 (40) = 335 (leftover 9).
    /// One building per type stalls the Barracks route at the 900 s bound: the Tower's
    /// fire kills each lone soldier before it reaches a structure. Five Barracks keep
    /// enough soldiers in the field to outpace that fire. Within budget, no accelerated levels.
    private static let city9Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 3),
        .init(type: .barracks, level: 3),
        .init(type: .barracks, level: 3),
        .init(type: .barracks, level: 3),
        .init(type: .barracks, level: 3),
        .init(type: .archeryRange, level: 2),
        .init(type: .stable, level: 1),
        .init(type: .mageTower, level: 1)
    ]

    /// City 10 watch-only camp: budget 500 (15 + 485 of rewards through City 9); unlocked
    /// Barracks, Archery Range, Stable, Mage Tower. Five Barracks L4 (5 x 80 = 400) +
    /// Archery Range L2 (32) + Stable L2 (50) = 482 (leftover 18). As in the City 9 camp,
    /// five Barracks keep the soldier flow ahead of the Tower's fire. Within budget.
    private static let city10Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 4),
        .init(type: .barracks, level: 4),
        .init(type: .barracks, level: 4),
        .init(type: .barracks, level: 4),
        .init(type: .barracks, level: 4),
        .init(type: .archeryRange, level: 2),
        .init(type: .stable, level: 2)
    ]

    /// City 11 watch-only camp: budget 727 (15 + 712 of rewards through City 10); unlocked
    /// Barracks, Archery Range, Stable, Mage Tower, Siege Workshop. Five Barracks L5
    /// (5 x 134 = 670) + Archery Range L1 (18) + Stable L1 (28) = 716 (leftover 11). Within budget.
    private static let city11Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .archeryRange, level: 1),
        .init(type: .stable, level: 1)
    ]

    /// City 12 watch-only camp: budget 1056 (15 + 1041 of rewards through City 11); unlocked
    /// all five types. Five Barracks L5 (670) + Archery Range L3 x2 (2 x 55 = 110) + Stable L3 (86)
    /// + Mage Tower L2 (70) + Siege Workshop L2 (97) = 1033 (leftover 23). Within budget.
    private static let city12Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .archeryRange, level: 3),
        .init(type: .archeryRange, level: 3),
        .init(type: .stable, level: 3),
        .init(type: .mageTower, level: 2),
        .init(type: .siegeWorkshop, level: 2)
    ]

    /// City 13 watch-only camp (realistic, not accelerated): budget 1533 (15 + 1518 of rewards
    /// through City 12); all five types unlocked. Five Barracks L5 (5 x 134 = 670) + Archery Range
    /// L2 x5 (5 x 32 = 160) + Stable L1 x5 (140) + Mage Tower L1 x5 (200) + Siege Workshop L1 x5
    /// (275) = 1445 (leftover 88). Five buildings per type fill 25 slots, so the Keep's fire on
    /// every lane meets a steady soldier flow. A thinner camp (Barracks L5 x5, Archery L4 x2, Stable
    /// L4, Mage L3, Siege L3, 1288 gold) stalls the fortified left Gate lane at the 900 s bound
    /// (647 soldiers lost, no conquest).
    private static let city13Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .barracks, level: 5),
        .init(type: .archeryRange, level: 2),
        .init(type: .archeryRange, level: 2),
        .init(type: .archeryRange, level: 2),
        .init(type: .archeryRange, level: 2),
        .init(type: .archeryRange, level: 2),
        .init(type: .stable, level: 1),
        .init(type: .stable, level: 1),
        .init(type: .stable, level: 1),
        .init(type: .stable, level: 1),
        .init(type: .stable, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1)
    ]

    /// City 14 watch-only camp (realistic, not accelerated): budget 2224 (15 + 2209 of rewards
    /// through City 13); all five types unlocked. Five Barracks L6 (5 x 223 = 1115) + Archery Range
    /// L2 x5 (160) + Stable L2 x5 (250) + Mage Tower L2 x5 (350) + Siege Workshop L1 x5 (275) =
    /// 2150 (leftover 74). Five buildings per type fill 25 slots; no accelerated levels.
    private static let city14Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 6),
        .init(type: .barracks, level: 6),
        .init(type: .barracks, level: 6),
        .init(type: .barracks, level: 6),
        .init(type: .barracks, level: 6),
        .init(type: .archeryRange, level: 2),
        .init(type: .archeryRange, level: 2),
        .init(type: .archeryRange, level: 2),
        .init(type: .archeryRange, level: 2),
        .init(type: .archeryRange, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .mageTower, level: 2),
        .init(type: .mageTower, level: 2),
        .init(type: .mageTower, level: 2),
        .init(type: .mageTower, level: 2),
        .init(type: .mageTower, level: 2),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1)
    ]

    /// City 15 watch-only camp (realistic, not accelerated): budget 3226 (15 + 3211 of rewards
    /// through City 14); all five types unlocked. Five Barracks L6 (5 x 223 = 1115) + Archery Range
    /// L6 x5 (5 x 260 = 1300) + Stable L2 x5 (250) + Mage Tower L1 x5 (200) + Siege Workshop L1 x5
    /// (275) = 3140 (leftover 86). The Keep's 773076 HP makes this the longest siege; the realistic
    /// camp still conquers every lane inside the 900 s bound, so no accelerated levels are used.
    private static let city15Camp: [Country1SiegeSmoke.Building] = [
        .init(type: .barracks, level: 6),
        .init(type: .barracks, level: 6),
        .init(type: .barracks, level: 6),
        .init(type: .barracks, level: 6),
        .init(type: .barracks, level: 6),
        .init(type: .archeryRange, level: 6),
        .init(type: .archeryRange, level: 6),
        .init(type: .archeryRange, level: 6),
        .init(type: .archeryRange, level: 6),
        .init(type: .archeryRange, level: 6),
        .init(type: .stable, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .stable, level: 2),
        .init(type: .mageTower, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .mageTower, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1),
        .init(type: .siegeWorkshop, level: 1)
    ]

    /// Always-on alternate-lane comparisons. Each measures under about 2 s of wall time
    /// (City 1, 3, 5, 9 and 10 routes); no alternate lane here stalls at its matched camp.
    private static let alwaysOnRouteComparisons: [Country1RouteComparison] = [
        .init(city: 1, lane: .left, camp: city1Camp, manualSpawnsEnabled: false),
        .init(city: 1, lane: .right, camp: city1Camp, manualSpawnsEnabled: false),
        .init(city: 3, lane: .right, camp: city3Camp, manualSpawnsEnabled: true),
        .init(city: 5, lane: .center, camp: city5Camp, manualSpawnsEnabled: true),
        .init(city: 9, lane: .center, camp: city9Camp, manualSpawnsEnabled: false),
        .init(city: 9, lane: .right, camp: city9Camp, manualSpawnsEnabled: false),
        .init(city: 10, lane: .left, camp: city10Camp, manualSpawnsEnabled: false),
        .init(city: 10, lane: .right, camp: city10Camp, manualSpawnsEnabled: false)
    ]

    /// Opt-in alternate-lane comparisons for City 15 (about 27 s wall each). Enable with
    /// `TEST_RUNNER_COUNTRY1_SMOKE_ROUTES=1 xcodebuild ... -only-testing:PyxisTests/Country1SiegeSmokeTests test`.
    private static let optInRouteComparisons: [Country1RouteComparison] = [
        .init(city: 15, lane: .center, camp: city15Camp, manualSpawnsEnabled: false),
        .init(city: 15, lane: .right, camp: city15Camp, manualSpawnsEnabled: false)
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

    /// City 3 default lane (centre) on the committed pilot camp, watch-only: no manual spawns.
    @Test("City 3 default center lane watch-only conquers inside the bounded simulated budget")
    func city3WatchOnlyDefaultLaneConquersWithinBound() {
        Self.expectMatchedConquest(
            Country1RouteComparison(city: 3, lane: .center, camp: Self.city3Camp, manualSpawnsEnabled: false)
        )
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

    /// City 5 default lane (right, exposed) on the 65-gold watch-only camp: no manual spawns.
    @Test("City 5 default right lane watch-only conquers inside the bounded simulated budget")
    func city5WatchOnlyDefaultLaneConquersWithinBound() {
        Self.expectMatchedConquest(
            Country1RouteComparison(city: 5, lane: .right, camp: Self.city5WatchOnlyCamp, manualSpawnsEnabled: false)
        )
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

    @Test("City 7 default lane watch-only conquers inside the bounded simulated budget")
    func city7WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 7,
            lane: .center,
            camp: Self.city7Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    /// City 8 default lane is the exposed Tower route (left). The realistic 225-gold camp stalls both
    /// Gate routes at the bound, so the Tower route is the only default that conquers.
    @Test("City 8 default Tower lane watch-only conquers inside the bounded simulated budget")
    func city8WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 8,
            lane: .left,
            camp: Self.city8Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    /// City 9 Barracks route is the default (standard) lane. Barracks-first shuts the Guards
    /// down strictly before the first wave interval, so no Guards deploy and the reserve stays
    /// full (observed 27.4 s, reserve 12 unspent); the assertions cover that behavior, not the
    /// exact balance numbers.
    @Test("City 9 default Barracks lane watch-only conquers inside the bounded simulated budget")
    func city9WatchOnlyBarracksLaneConquersWithinBound() throws {
        let result = Country1SiegeSmoke.run(
            city: 9,
            lane: .left,
            camp: Self.city9Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
        let barracksShutdownSeconds = try #require(result.barracksShutdownSeconds)
        #expect(barracksShutdownSeconds < Country1GuardRules.waveIntervalSeconds)
        #expect(result.guardsSpawned == 0)
        #expect(result.guardReserveRemaining == Country1GuardRules.totalReserve)
    }

    /// City 10 default Gate lane is the standard lane (centre). The Tower route is the left lane.
    @Test("City 10 default lane watch-only conquers inside the bounded simulated budget")
    func city10WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 10,
            lane: .center,
            camp: Self.city10Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    /// City 11 default lane is the standard lane (right): the Barracks route. Guards deploy from
    /// its Barracks, and the Tower covers every lane.
    @Test("City 11 default Barracks lane watch-only conquers inside the bounded simulated budget")
    func city11WatchOnlyBarracksLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 11,
            lane: .right,
            camp: Self.city11Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    /// City 12 default lane is the standard lane (left): the Gate route. The Barracks and the
    /// Tower sit on the other two routes.
    @Test("City 12 default Gate lane watch-only conquers inside the bounded simulated budget")
    func city12WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 12,
            lane: .left,
            camp: Self.city12Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    /// City 13 default lane is the standard lane (centre): the Barracks route. The Keep fires on
    /// every lane, so the fortified left Gate lane is the slowest route.
    @Test("City 13 default Barracks lane watch-only conquers inside the bounded simulated budget")
    func city13WatchOnlyBarracksLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 13,
            lane: .center,
            camp: Self.city13Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    /// City 14 default lane is the standard lane (right): the second Gate's route, which never
    /// reaches the Tower. The Tower's fire covers every lane, so this route stays under fire.
    @Test("City 14 default Gate lane watch-only conquers inside the bounded simulated budget")
    func city14WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 14,
            lane: .right,
            camp: Self.city14Camp,
            soldierUpgradeLevel: 1,
            seed: Self.seed,
            manualSpawnsEnabled: false
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest)
    }

    /// City 15 default lane is the standard lane (left): the Tower route, whose first stop is the
    /// fire source. The Barracks and its Guard reserve sit on the centre route, so this line prints
    /// Guard waves and reserve that are fielded on the selected lane while the Barracks stands.
    @Test("City 15 default Tower lane watch-only conquers inside the bounded simulated budget")
    func city15WatchOnlyDefaultLaneConquersWithinBound() {
        let result = Country1SiegeSmoke.run(
            city: 15,
            lane: .left,
            camp: Self.city15Camp,
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

    @Test(
        "Always-on alternate lanes conquer inside the bounded simulated budget",
        arguments: Country1SiegeSmokeTests.alwaysOnRouteComparisons
    )
    func alwaysOnAlternateLaneConquersWithinBound(_ comparison: Country1RouteComparison) {
        Self.expectMatchedConquest(comparison)
    }

    @Test(
        "Opt-in City 15 alternate lanes conquer inside the bounded simulated budget",
        .enabled(if: Country1SiegeSmoke.routeComparisonsEnabled),
        arguments: Country1SiegeSmokeTests.optInRouteComparisons
    )
    func optInAlternateLaneConquersWithinBound(_ comparison: Country1RouteComparison) {
        Self.expectMatchedConquest(comparison)
    }

    /// Chained 15-city greedy campaign (HPA-582 Task 0), opt-in via
    /// `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1`. The per-city COUNTRY1_SMOKE
    /// campaign=1 lines are the balance evidence; the assertion is the
    /// eventual 15/15 gate (a stall is the baseline until Task 4 tunes).
    @Test(
        "Chained greedy campaign conquers every Country 1 city inside the bound",
        .enabled(if: Country1SiegeSmoke.campaignEnabled)
    )
    func chainedGreedyCampaignConquersEveryCityInsideBound() {
        let records = Country1SiegeSmoke.runGreedyCampaign(seed: Country1SiegeSmoke.campaignSeed)

        #expect(records.count == KingdomGameState.firstCountryCityCount)
        let stalledCities = records.filter { !$0.reachedConquest }
        #expect(
            stalledCities.isEmpty,
            Comment(rawValue: "Campaign ended early: " + (records.last.map { Country1SiegeSmoke.campaignLine(for: $0) }
                ?? "no cities reached"))
        )
    }

    /// Runs one matched comparison (an alternate or default lane on a committed camp and policy) and
    /// asserts only that it conquers inside the bound. The diagnostic line is the `#expect` message.
    private static func expectMatchedConquest(_ comparison: Country1RouteComparison) {
        let result = Country1SiegeSmoke.run(
            city: comparison.city,
            lane: comparison.lane,
            camp: comparison.camp,
            soldierUpgradeLevel: 1,
            seed: seed,
            manualSpawnsEnabled: comparison.manualSpawnsEnabled
        )
        print(Country1SiegeSmoke.line(for: result))
        #expect(result.reachedConquest, Comment(rawValue: Country1SiegeSmoke.line(for: result)))
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
        #expect(result.elapsedSeconds == 3.0)
    }
}
