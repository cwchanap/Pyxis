import SpriteKit
import Testing
import UIKit
@testable import Pyxis

#if DEBUG
@MainActor
struct ForgedVisualFixtureTests {
    @Test("DEBUG fixture parser accepts only the exact marker values")
    func parserAcceptsExactValues() {
        let expected: [(String, ForgedVisualFixture)] = [
            ("battle", .battle),
            ("battle-blocked", .battleBlocked),
            ("camp-empty", .campEmpty),
            ("camp-occupied", .campOccupied),
            ("map", .map),
            ("map-country-complete", .mapCountryComplete),
            ("conquest-live", .conquestLive),
            ("conquest-idle", .conquestIdle)
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
        #expect(liveResult.idleBuildingCount == nil)
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
        #expect(idleResult.idleBuildingCount == 2)
        let idleReport = ConquestReportContent.project(
            from: idleResult,
            title: "Falconridge Silenced"
        )
        #expect(idleReport.tiles.contains(.buildings(count: 2)))
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
                "Battle;stage=battleActive;mode=normal;city=1-3;manualLiving=0"
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
                + "deployments=0;losses=0;buildings=2;idleDamage=1"
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
                "Battle;stage=battleActive;mode=blocked;city=1-3;manualLiving=1"
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
                    + "attackableCity=4;laterLockedCity=5"
            ),
            (
                .mapCountryComplete,
                "Map;stage=countryComplete;completed=15;"
                    + "attackableCity=none;laterLockedCity=none"
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
