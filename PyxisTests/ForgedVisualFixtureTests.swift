import SpriteKit
import Testing
import UIKit
@testable import Pyxis

#if DEBUG
@MainActor
struct ForgedVisualFixtureTests {
    private struct LandmarkCase {
        let fixture: ForgedVisualFixture
        let cityNumber: Int
        let family: CityVisualFamily
    }

    @Test("DEBUG fixture parser accepts only the exact marker values")
    func parserAcceptsExactValues() {
        let expected: [(String, ForgedVisualFixture)] = [
            ("battle", .battle),
            ("battle-blocked", .battleBlocked),
            ("camp-empty", .campEmpty),
            ("camp-occupied", .campOccupied),
            ("map", .map),
            ("map-partial", .mapPartial),
            ("map-country-complete", .mapCountryComplete),
            ("conquest-live", .conquestLive),
            ("conquest-idle", .conquestIdle),
            ("battle-damaged", .battleDamaged),
            ("battle-breached", .battleBreached),
            ("battle-emberford", .battleEmberford),
            ("battle-runewatch", .battleRunewatch),
            ("battle-crownspire", .battleCrownspire),
            ("return-damage", .returnDamage),
            ("battle-highcrest-wave", .battleHighcrestWave),
            ("battle-highcrest-guard-damaged", .battleHighcrestGuardDamaged),
            ("battle-highcrest-shutdown", .battleHighcrestShutdown),
            ("battle-highcrest-final", .battleHighcrestFinal)
        ]

        for (rawValue, fixture) in expected {
            #expect(
                ForgedVisualFixture(launchArguments: [
                    "Pyxis",
                    ForgedVisualFixture.launchArgument,
                    rawValue
                ]) == fixture
            )
        }

        #expect(ForgedVisualFixture(launchArguments: ["Pyxis"]) == nil)
        #expect(ForgedVisualFixture(launchArguments: [
            "Pyxis",
            ForgedVisualFixture.launchArgument
        ]) == nil)
        #expect(ForgedVisualFixture(launchArguments: [
            "Pyxis",
            ForgedVisualFixture.launchArgument,
            "unknown"
        ]) == nil)
    }

    @Test("DEBUG battle fixture pins the authored City 3 setup")
    func battleFixturePinsCityThreeSetup() throws {
        let state = ForgedVisualFixture.battle.makeState()

        #expect(state.cityNumberInCountry == 3)
        #expect(state.completedCityCount == 2)
        #expect(state.gold == 4_200)
        #expect(state.stageStatus == .battleActive)
        #expect(state.pendingBattleResult == nil)
        #expect(state.cityBattleStateForCurrentCity.slots == [
            1: CityBuilding(type: .barracks, level: 2),
            2: CityBuilding(type: .archeryRange, level: 1)
        ])
        // Fresh Falconridge: intact Keep at its authored 35/35 share.
        #expect(state.currentKeepMaxPower == 35)
        #expect(state.currentKeepRemainingPower == 35)
    }

    @Test("DEBUG damaged/breached fixtures pin City 1 living-kingdom thresholds")
    func damagedAndBreachedFixturesPinCityOneThresholds() {
        let damaged = ForgedVisualFixture.battleDamaged.makeState()
        #expect(damaged.cityNumberInCountry == 1)
        #expect(damaged.cityMaxPower == 20)
        #expect(damaged.currentKeepMaxPower == 20)
        #expect(damaged.currentKeepRemainingPower == 12)
        #expect(damaged.stageStatus == .battleActive)
        #expect(damaged.pendingBattleResult == nil)

        let breached = ForgedVisualFixture.battleBreached.makeState()
        #expect(breached.cityNumberInCountry == 1)
        #expect(breached.cityMaxPower == 20)
        #expect(breached.currentKeepMaxPower == 20)
        #expect(breached.currentKeepRemainingPower == 5)
        #expect(breached.stageStatus == .battleActive)
        #expect(breached.pendingBattleResult == nil)
    }

    @Test("DEBUG landmark fixtures pin full-HP family cities")
    func landmarkFixturesPinFullHPStates() {
        let landmarks = [
            LandmarkCase(fixture: .battleEmberford, cityNumber: 7, family: .ember),
            LandmarkCase(fixture: .battleRunewatch, cityNumber: 9, family: .arcane),
            LandmarkCase(fixture: .battleCrownspire, cityNumber: 15, family: .royal)
        ]

        for landmark in landmarks {
            let state = landmark.fixture.makeState()
            #expect(state.cityNumberInCountry == landmark.cityNumber)
            #expect(state.stageStatus == .battleActive)
            #expect(state.pendingBattleResult == nil)
            #expect(state.currentKeepRemainingPower == state.currentKeepMaxPower)
            #expect(
                Country1CityCatalog.definition(for: landmark.cityNumber).visualFamily
                    == landmark.family
            )
        }
    }

    @Test("DEBUG return-damage fixture pins seeded background and fixed foreground return")
    func returnDamageFixturePinsSeededBackgroundState() {
        let state = ForgedVisualFixture.returnDamage.makeState()
        #expect(state.cityNumberInCountry == 3)
        #expect(state.stageStatus == .battleActive)
        #expect(state.pendingBattleResult == nil)
        #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 1)
        #expect(state.cityBattleStateForCurrentCity.slots[1]?.type == .barracks)
        #expect(state.lastBackgroundedAt == Date(timeIntervalSince1970: 1_000))

        #expect(
            ForgedVisualFixture.returnDamage.foregroundReturnDate
                == Date(timeIntervalSince1970: 4_600)
        )
        for fixture in ForgedVisualFixture.allCases where fixture != .returnDamage {
            #expect(fixture.foregroundReturnDate == nil)
        }
    }

    @Test("DEBUG blocked battle reuses the deterministic battle state")
    func blockedBattleFixtureReusesBattleState() {
        #expect(
            ForgedVisualFixture.battleBlocked.makeState()
                == ForgedVisualFixture.battle.makeState()
        )
    }

    @Test("DEBUG camp fixtures pin empty and six-lot City 5 states")
    func campFixturesPinCityFiveStates() {
        let empty = ForgedVisualFixture.campEmpty.makeState()
        #expect(empty.cityNumberInCountry == 5)
        #expect(empty.gold == 1_000)
        #expect(empty.cityBattleStateForCurrentCity.slots.isEmpty)

        let occupied = ForgedVisualFixture.campOccupied.makeState()
        #expect(occupied.cityNumberInCountry == 5)
        #expect(occupied.gold == DevJumpState.gold)
        #expect(occupied.cityBattleStateForCurrentCity.occupiedSlotCount == 6)
        #expect(occupied.cityBattleStateForCurrentCity.slots == [
            1: CityBuilding(type: .barracks, level: 2),
            3: CityBuilding(type: .barracks, level: 1),
            6: CityBuilding(type: .archeryRange, level: 2),
            8: CityBuilding(type: .barracks, level: 1),
            11: CityBuilding(type: .archeryRange, level: 1),
            12: CityBuilding(type: .barracks, level: 3)
        ])
    }

    @Test("DEBUG map fixtures pin pending-next-map and completed-country states")
    func mapFixturesPinStageProgress() {
        let map = ForgedVisualFixture.map.makeState()
        #expect(map.countryNumber == 1)
        #expect(map.completedCityCount == 3)
        #expect(map.stageStatus == .cityConqueredPendingMap)
        #expect(map.pendingBattleResult == nil)

        let partial = ForgedVisualFixture.mapPartial.makeState()
        #expect(partial.countryNumber == 1)
        #expect(partial.cityNumberInCountry == 8)
        #expect(partial.completedCityCount == 7)
        #expect(partial.stageStatus == .cityConqueredPendingMap)
        #expect(partial.pendingBattleResult == nil)

        let complete = ForgedVisualFixture.mapCountryComplete.makeState()
        #expect(complete.countryNumber == 1)
        #expect(complete.completedCityCount == KingdomGameState.firstCountryCityCount)
        #expect(complete.stageStatus == .countryComplete)
        #expect(complete.cityNumberInCountry == KingdomGameState.firstCountryCityCount)
    }

    @Test("DEBUG conquest fixtures pin live and idle report data")
    func conquestFixturesPinReportData() throws {
        let live = ForgedVisualFixture.conquestLive.makeState()
        let liveResult = try #require(live.pendingBattleResult)
        #expect(liveResult.goldEarned == 640)
        #expect(liveResult.activeBattleSeconds == 74)
        #expect(liveResult.mvpSoldierType == .infantry)
        #expect(liveResult.totalDeploymentCount == 6)
        #expect(liveResult.totalLossCount == 1)
        #expect(liveResult.usedFavorableUnit)
        #expect(liveResult.usedExposedLane)

        let idle = ForgedVisualFixture.conquestIdle.makeState()
        let idleResult = try #require(idle.pendingBattleResult)
        #expect(idleResult.goldEarned == KingdomGameState.goldReward(for: 3))
        #expect(idleResult.mvpSoldierType == .infantry)
        #expect(idleResult.mvpDamageSharePercent == 100)
        #expect(idleResult.totalDeploymentCount == 0)
        #expect(idleResult.totalLossCount == 0)
        #expect(!idleResult.idleDamageByType.isEmpty)
        #expect(idleResult.totalIdleDamage == 1)
        let idleReport = ConquestReportContent.project(
            from: idleResult,
            title: "Falconridge Silenced"
        )
        #expect(idleReport.tiles.contains(.idleDamage(damage: 1)))
        #expect(!idleResult.usedFavorableUnit)
        #expect(!idleResult.usedExposedLane)
    }

    @Test("DEBUG fixture hook leaves an existing save unchanged without a marker")
    func hookLeavesSaveUnchangedWithoutMarker() throws {
        let initial = KingdomGameState(gold: 73, cityNumberInCountry: 2)
        let store = try makeStore(initialState: initial)
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

        #expect(!controller.installForgedVisualFixtureIfRequested(
            in: view,
            arguments: ["Pyxis"]
        ))
        #expect(store.load() == initial)
    }

    @Test("DEBUG battle fixture hook reports an active normal battle")
    func hookReportsNormalBattleSemantics() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 73))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

        #expect(controller.installForgedVisualFixtureIfRequested(
            in: view,
            arguments: [
                "Pyxis",
                ForgedVisualFixture.launchArgument,
                ForgedVisualFixture.battle.rawValue
            ]
        ))
        #expect(view.scene is BattleScene)
        #expect(
            view.accessibilityValue ==
                "Battle;stage=battleActive;mode=normal;city=1-3;manualLiving=0;"
                + "family=frontier;fortress=intact"
        )
    }

    @Test("DEBUG battle fixture hooks project family and fortress stage semantics")
    func hookProjectsBattleFamilyAndFortressStage() throws {
        let fixtures: [(ForgedVisualFixture, String)] = [
            (
                .battleDamaged,
                "Battle;stage=battleActive;mode=normal;city=1-1;manualLiving=0;"
                    + "family=frontier;fortress=damaged"
            ),
            (
                .battleBreached,
                "Battle;stage=battleActive;mode=normal;city=1-1;manualLiving=0;"
                    + "family=frontier;fortress=breached"
            ),
            (
                .battleEmberford,
                "Battle;stage=battleActive;mode=normal;city=1-7;manualLiving=0;"
                    + "family=ember;fortress=intact"
            ),
            (
                .battleRunewatch,
                "Battle;stage=battleActive;mode=normal;city=1-9;manualLiving=0;"
                    + "family=arcane;fortress=intact"
            ),
            (
                .battleCrownspire,
                "Battle;stage=battleActive;mode=normal;city=1-15;manualLiving=0;"
                    + "family=royal;fortress=intact"
            )
        ]

        for (fixture, expectedValue) in fixtures {
            let store = try makeStore(initialState: KingdomGameState(gold: 73))
            let controller = GameViewController(store: store)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

            #expect(controller.installForgedVisualFixtureIfRequested(
                in: view,
                arguments: [
                    "Pyxis",
                    ForgedVisualFixture.launchArgument,
                    fixture.rawValue
                ]
            ))
            #expect(view.scene is BattleScene)
            #expect(view.accessibilityValue == expectedValue)
        }
    }

    @Test("DEBUG return-damage hook settles fixed idle return with compact damage copy")
    func hookSettlesReturnDamageWithCompactCopy() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 73))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

        #expect(controller.installForgedVisualFixtureIfRequested(
            in: view,
            arguments: [
                "Pyxis",
                ForgedVisualFixture.launchArgument,
                ForgedVisualFixture.returnDamage.rawValue
            ]
        ))
        let battle = try #require(view.scene as? BattleScene)
        #expect(battle.feedbackTextForTesting == "Buildings dealt 36 idle damage.")
        // Objective-aware idle settlement (HPA-468): 36 damage spends down the
        // selected center route — Gate absorbs 11, Keep absorbs 25 → 10/35.
        #expect(battle.keepRemainingPowerForTesting == 10)
        #expect(battle.gameStateForTesting.pendingBattleResult == nil)
        #expect(store.load().lastBackgroundedAt == nil)
        #expect(
            view.accessibilityValue ==
                "Battle;stage=battleActive;mode=normal;city=1-3;manualLiving=0;"
                + "family=frontier;fortress=damaged;"
                + "feedback=Buildings dealt 36 idle damage."
        )
    }

    @Test("DEBUG fixture hook saves through normal routing and pending conquest opens Battle")
    func hookRoutesPendingConquestToBattle() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 73))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

        #expect(controller.installForgedVisualFixtureIfRequested(
            in: view,
            arguments: [
                "Pyxis",
                ForgedVisualFixture.launchArgument,
                ForgedVisualFixture.conquestLive.rawValue
            ]
        ))
        #expect(store.load().pendingBattleResult?.goldEarned == 640)
        #expect(view.scene is BattleScene)
        #expect(
            view.accessibilityValue ==
                "Conquest;pending=true;mode=live;city=1-3;source=manual;deployments=6;losses=1"
        )

        let idleStore = try makeStore(initialState: KingdomGameState(gold: 73))
        let idleController = GameViewController(store: idleStore)
        let idleView = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        #expect(idleController.installForgedVisualFixtureIfRequested(
            in: idleView,
            arguments: [
                "Pyxis",
                ForgedVisualFixture.launchArgument,
                ForgedVisualFixture.conquestIdle.rawValue
            ]
        ))
        #expect(idleView.scene is BattleScene)
        #expect(
            idleView.accessibilityValue ==
                "Conquest;pending=true;mode=idle;city=1-3;source=idle;"
                + "deployments=0;losses=0;idleDamage=1"
        )
    }

    @Test("DEBUG blocked battle hook seeds one transient manual soldier")
    func hookRoutesBlockedBattleWithTransientManualSoldier() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 73))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

        #expect(controller.installForgedVisualFixtureIfRequested(
            in: view,
            arguments: [
                "Pyxis",
                ForgedVisualFixture.launchArgument,
                ForgedVisualFixture.battleBlocked.rawValue
            ]
        ))
        let battle = try #require(view.scene as? BattleScene)
        #expect(battle.manualLiveSoldierCountForTesting == 1)
        #expect(battle.isFeedbackTooltipVisibleForTesting)
        #expect(battle.feedbackTextForTesting == "Finish the current squad before building.")
        #expect(store.load().activeSiegeSession == nil)
        #expect(store.load().pendingBattleResult == nil)
        #expect(
            view.accessibilityValue ==
                "Battle;stage=battleActive;mode=blocked;city=1-3;manualLiving=1;"
                + "family=frontier;fortress=intact;"
                + "feedback=Finish the current squad before building."
        )
    }

    @Test("DEBUG fixture hook routes non-pending fixtures through the stage authority")
    func hookRoutesNonPendingFixturesThroughStageAuthority() throws {
        let fixtures: [(ForgedVisualFixture, String)] = [
            (
                .campEmpty,
                "Camp;stage=battleActive;city=1-5;buildings=0;selectedSlot=1;mode=builder"
            ),
            (
                .campOccupied,
                "Camp;stage=battleActive;city=1-5;buildings=6;selectedSlot=1;mode=inspector"
            )
        ]

        for (fixture, expectedValue) in fixtures {
            let store = try makeStore(initialState: KingdomGameState(gold: 73))
            let controller = GameViewController(store: store)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

            #expect(controller.installForgedVisualFixtureIfRequested(
                in: view,
                arguments: [
                    "Pyxis",
                    ForgedVisualFixture.launchArgument,
                    fixture.rawValue
                ]
            ))
            #expect(view.scene is BuildingViewScene)
            #expect(view.accessibilityValue == expectedValue)
        }
    }

    @Test("DEBUG map fixture hook reports attackable, locked, and complete semantics")
    func hookReportsMapSemantics() throws {
        let fixtures: [(ForgedVisualFixture, String)] = [
            (
                .map,
                "Map;stage=cityConqueredPendingMap;completed=3;"
                    + "attackableCity=4;laterLockedCity=5;"
                    + "secured=3;caravan=1,2;patch=lk-map-route-6-7-worn"
            ),
            (
                .mapCountryComplete,
                "Map;stage=countryComplete;completed=15;"
                    + "attackableCity=none;laterLockedCity=none;"
                    + "secured=15;caravan=1,2;patch=lk-map-route-6-7-repaired"
            )
        ]

        for (fixture, expectedValue) in fixtures {
            let store = try makeStore(initialState: KingdomGameState(gold: 73))
            let controller = GameViewController(store: store)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

            #expect(controller.installForgedVisualFixtureIfRequested(
                in: view,
                arguments: [
                    "Pyxis",
                    ForgedVisualFixture.launchArgument,
                    fixture.rawValue
                ]
            ))
            #expect(view.scene is CountryMapScene)
            #expect(view.accessibilityValue == expectedValue)
        }
    }

    @Test("DEBUG Highcrest fixtures pin active-wave, damaged-Guard, shutdown, and final states")
    func highcrestFixturesPinGuardStates() throws {
        let keepMax = Country1CityCatalog.definition(for: 5).siegeLayout
            .maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 5))[
                Country1CityCatalog.definition(for: 5).siegeLayout.keepObjective.id
            ] ?? 0
        let barracksMax = Country1CityCatalog.definition(for: 5).siegeLayout
            .maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 5))[
                Country1CityCatalog.definition(for: 5).siegeLayout.barracksObjective!.id
            ] ?? 0
        let barracksID = Country1CityCatalog.definition(for: 5).siegeLayout
            .objectives.first { $0.kind == .barracks }!.id

        let wave = ForgedVisualFixture.battleHighcrestWave.makeState()
        #expect(wave.cityNumberInCountry == 5)
        #expect(wave.stageStatus == .battleActive)
        #expect(wave.pendingBattleResult == nil)
        #expect(wave.siegeProgress.selectedLane == .left)
        #expect(wave.currentKeepRemainingPower == keepMax)
        #expect(wave.currentSiegeSnapshot.objectiveRemainingPower[barracksID] == barracksMax)
        #expect(wave.siegeProgress.guardReinforcements?.remainingReserve == 6)
        #expect(wave.siegeProgress.guardReinforcements?.unresolvedGuards == [
            GuardSnapshot(lane: .left, remainingHP: 12),
            GuardSnapshot(lane: .left, remainingHP: 12)
        ])

        let damaged = ForgedVisualFixture.battleHighcrestGuardDamaged.makeState()
        #expect(damaged.currentKeepRemainingPower == keepMax)
        #expect(damaged.siegeProgress.guardReinforcements?.unresolvedGuards == [
            GuardSnapshot(lane: .left, remainingHP: 12),
            GuardSnapshot(lane: .left, remainingHP: 5)
        ])
        #expect(damaged.siegeProgress.guardReinforcements?.remainingReserve == 6)

        let shutdown = ForgedVisualFixture.battleHighcrestShutdown.makeState()
        #expect(shutdown.currentKeepRemainingPower == keepMax)
        #expect(shutdown.currentSiegeSnapshot.objectiveRemainingPower[barracksID] == 0)
        #expect(shutdown.siegeProgress.guardReinforcements?.unresolvedGuards == [
            GuardSnapshot(lane: .left, remainingHP: 7)
        ])

        let final = ForgedVisualFixture.battleHighcrestFinal.makeState()
        #expect(final.currentKeepRemainingPower == keepMax)
        let finalProgress = try #require(final.siegeProgress.guardReinforcements)
        #expect(finalProgress.remainingReserve == 0)
        #expect(finalProgress.unresolvedGuards.count == 8)
        #expect(finalProgress.unresolvedGuards.allSatisfy { $0.lane == .left })
    }

    @Test("DEBUG Highcrest fixture hook projects Guard capture semantics")
    func highcrestFixtureHookProjectsGuardSemantics() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 73))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

        #expect(controller.installForgedVisualFixtureIfRequested(
            in: view,
            arguments: [
                "Pyxis",
                ForgedVisualFixture.launchArgument,
                ForgedVisualFixture.battleHighcrestWave.rawValue
            ]
        ))
        let battle = try #require(view.scene as? BattleScene)
        #expect(view.accessibilityValue ==
            "Battle;stage=battleActive;mode=normal;city=1-5;manualLiving=0;"
                + "family=frontier;fortress=intact")
        #expect(battle.guardNodeCountForTesting == 2)
        let waveLabel = try #require(
            battle.siegeObjectiveNodeForTesting(.barracks)?.childNode(
                withName: "siegeBarracksStatus"
            ) as? SKLabelNode
        )
        #expect(waveLabel.text == "GUARDS 2")

        let shutdownStore = try makeStore(initialState: KingdomGameState(gold: 73))
        let shutdownController = GameViewController(store: shutdownStore)
        let shutdownView = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        #expect(shutdownController.installForgedVisualFixtureIfRequested(
            in: shutdownView,
            arguments: [
                "Pyxis",
                ForgedVisualFixture.launchArgument,
                ForgedVisualFixture.battleHighcrestShutdown.rawValue
            ]
        ))
        let shutdownBattle = try #require(shutdownView.scene as? BattleScene)
        #expect(shutdownBattle.guardNodeCountForTesting == 1)
        let shutdownLabel = try #require(
            shutdownBattle.siegeObjectiveNodeForTesting(.barracks)?.childNode(
                withName: "siegeBarracksStatus"
            ) as? SKLabelNode
        )
        #expect(shutdownLabel.text == "SHUT DOWN")
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "ForgedVisualFixtureTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }
}
#endif
