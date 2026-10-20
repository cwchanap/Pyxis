//
//  CountryMapScoutCardContentTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct CountryMapScoutCardContentTests {
    @Test func selectedCityProjectionUsesStatusWithoutMutatingState() {
        let state = KingdomGameState(
            cityLevel: 3,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        let current = CountryMapScoutCardContent.project(
            from: state,
            selectedCityNumber: 3
        )
        let completed = CountryMapScoutCardContent.project(
            from: state,
            selectedCityNumber: 2
        )
        let locked = CountryMapScoutCardContent.project(
            from: state,
            selectedCityNumber: 4
        )

        guard case .scout(let currentScout) = current,
              case .scout(let completedScout) = completed,
              case .scout(let lockedScout) = locked else {
            Issue.record("Expected selected city Scout projections")
            return
        }

        #expect(currentScout.status == .current)
        #expect(completedScout.status == .completed)
        #expect(lockedScout.status == .locked)
        #expect(currentScout.actionTitle == "RETURN")
        #expect(completedScout.actionTitle == nil)
        #expect(lockedScout.actionTitle == nil)
        #expect(state.cityNumberInCountry == 3)
        #expect(state.completedCityCount == 2)
    }

    @Test func selectedUnlockedCityProjectsMarchWithoutChangingPersistedState() {
        let state = KingdomGameState(
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )

        guard case .scout(let scout) = CountryMapScoutCardContent.project(
            from: state,
            selectedCityNumber: 2
        ) else {
            Issue.record("Expected selected unlocked Scout projection")
            return
        }

        #expect(scout.status == .attackable)
        #expect(scout.actionTitle == "MARCH")
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.cityNumberInCountry == 1)
    }

    @Test
    func freshBattleProjectsCityOne() {
        let state = KingdomGameState()

        #expect(
            CountryMapScoutCardContent.project(from: state)
                == .scout(
                    .init(
                        cityNumber: 1,
                        displayTitle: "City 1 · Willowford",
                        defenseTrait: .standardWatch,
                        exposedLane: .right,
                        goldReward: KingdomGameState.goldReward(for: 1),
                        flavorText: "A quiet crossing where the campaign begins.",
                        tacticalFooter: "L/C Gate",
                        status: .current
                    )
                )
        )
    }

    @Test
    func pendingMapProjectsTheNextUnlockedCityInsteadOfTheStaleBattleCity() {
        let state = KingdomGameState(
            gold: 15,
            cityLevel: 1,
            countryNumber: 1,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )

        let content = CountryMapScoutCardContent.project(from: state)
        let definition = Country1CityCatalog.definition(for: 2)

        #expect(
            content == .scout(
                .init(
                    cityNumber: 2,
                    displayTitle: definition.displayTitle,
                    defenseTrait: definition.defenseTrait,
                    exposedLane: definition.laneDefenseProfile.exposedLane,
                    goldReward: KingdomGameState.goldReward(for: 2),
                    flavorText: definition.flavorText,
                    tacticalFooter: Self.expectedTacticalFooter(for: 2)
                )
            )
        )
        #expect(KingdomGameState.goldReward(for: 2) != KingdomGameState.goldReward(for: state.cityLevel))
    }

    @Test
    func everyIncompletePendingMapStateProjectsOnlyTheFollowingCity() {
        for completedCityCount in 1..<KingdomGameState.firstCountryCityCount {
            let nextCityNumber = completedCityCount + 1
            let state = KingdomGameState(
                cityLevel: completedCityCount,
                cityNumberInCountry: completedCityCount,
                completedCityCount: completedCityCount,
                stageStatus: .cityConqueredPendingMap
            )
            let definition = Country1CityCatalog.definition(for: nextCityNumber)

            #expect(state.unlockedMapCityNumber == nextCityNumber)
            #expect(
                Country1CityCatalog.cityRange.filter { state.mapStatus(for: $0) == .unlocked }
                    == [nextCityNumber]
            )
            #expect(
                CountryMapScoutCardContent.project(from: state)
                    == .scout(
                        .init(
                            cityNumber: nextCityNumber,
                            displayTitle: definition.displayTitle,
                            defenseTrait: definition.defenseTrait,
                            exposedLane: definition.laneDefenseProfile.exposedLane,
                            goldReward: KingdomGameState.goldReward(for: nextCityNumber),
                            flavorText: definition.flavorText,
                            tacticalFooter: Self.expectedTacticalFooter(for: nextCityNumber)
                        )
                    )
            )
        }
    }

    @Test func highcrestScoutTeachesBarracksRoute() {
        let layout = Country1CityCatalog.definition(for: 5).siegeLayout
        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "L Barracks")
    }

    @Test
    func falconridgeScoutProjectsConciseTacticalFooter() {
        let state = KingdomGameState(
            cityLevel: 3,
            cityNumberInCountry: 3,
            completedCityCount: 2
        )

        guard case .scout(let scout) = CountryMapScoutCardContent.project(from: state) else {
            Issue.record("Expected Falconridge Scout projection")
            return
        }

        #expect(scout.tacticalFooter == "L Tower · C/R Gate")

        for cityNumber in Country1CityCatalog.cityRange where cityNumber != 3 {
            let other = KingdomGameState(
                cityLevel: cityNumber,
                cityNumberInCountry: cityNumber,
                completedCityCount: cityNumber - 1
            )
            guard case .scout(let plain) = CountryMapScoutCardContent.project(from: other) else {
                Issue.record("Expected Scout projection for city \(cityNumber)")
                continue
            }
            #expect(plain.tacticalFooter == Self.expectedTacticalFooter(for: cityNumber))
        }
    }

    @Test func twoSupportFooterKeepsEverySupportEntryInAuthoredOrder() {
        let layout = Self.syntheticLayout(
            supports: [.init("barracks", .barracks, 0.72), .init("tower", .arrowTower, 0.80)],
            routes: [.left: ["barracks", "keep"], .center: ["keep"], .right: ["tower", "keep"]],
            fireSourceID: "tower"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "L Barracks · R Tower")
    }

    @Test func ironthornFooterShowsOnlyItsTowerOverTwoGates() {
        let layout = Self.syntheticLayout(
            supports: [
                .init("tower", .arrowTower, 0.80),
                .init("gate-centre", .gate, 0.78),
                .init("gate-right", .gate, 0.84)
            ],
            routes: [.left: ["tower", "keep"], .center: ["gate-centre", "keep"], .right: ["gate-right", "keep"]],
            fireSourceID: "tower"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "L Tower")
    }

    @Test func kingshieldFooterShowsItsBarracksOverTowerAndGate() {
        let layout = Self.syntheticLayout(
            supports: [
                .init("tower", .arrowTower, 0.80),
                .init("gate", .gate, 0.82),
                .init("barracks", .barracks, 0.72)
            ],
            routes: [.left: ["tower", "keep"], .center: ["gate", "keep"], .right: ["barracks", "keep"]],
            fireSourceID: "tower"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "R Barracks")
    }

    @Test func ashbridgeFooterShowsItsBarracksEvenWhenAuthoredAfterAGate() {
        let layout = Self.syntheticLayout(
            supports: [
                .init("gate", .gate, 0.80),
                .init("barracks", .barracks, 0.72),
                .init("tower", .arrowTower, 0.83)
            ],
            routes: [.left: ["gate", "keep"], .center: ["barracks", "keep"], .right: ["tower", "keep"]],
            fireSourceID: "tower"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "C Barracks")
    }

    @Test func starveilFooterShowsItsKeepSourcedBarracksOverTwoGates() {
        let layout = Self.syntheticLayout(
            supports: [
                .init("gate-left", .gate, 0.80),
                .init("barracks", .barracks, 0.72),
                .init("gate-right", .gate, 0.83)
            ],
            routes: [.left: ["gate-left", "keep"], .center: ["barracks", "keep"], .right: ["gate-right", "keep"]],
            fireSourceID: "keep"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "C Barracks")
    }

    @Test func stonecrownFooterShowsItsTowerOverTwoGates() {
        let layout = Self.syntheticLayout(
            supports: [
                .init("gate-left", .gate, 0.77),
                .init("tower", .arrowTower, 0.82),
                .init("gate-right", .gate, 0.84)
            ],
            routes: [.left: ["gate-left", "keep"], .center: ["tower", "keep"], .right: ["gate-right", "keep"]],
            fireSourceID: "tower"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "C Tower")
    }

    @Test func crownspireFooterShowsOnlyTheBarracksOfFourSupports() {
        let layout = Self.syntheticLayout(
            supports: [
                .init("tower", .arrowTower, 0.78),
                .init("barracks", .barracks, 0.72),
                .init("gate-left", .gate, 0.84),
                .init("gate-right", .gate, 0.82)
            ],
            routes: [
                .left: ["tower", "gate-left", "keep"],
                .center: ["barracks", "gate-left", "keep"],
                .right: ["gate-right", "keep"]
            ],
            fireSourceID: "tower"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "C Barracks")
    }

    @Test func gateGateTowerFooterShowsTheTowerNotAnyGate() {
        let layout = Self.syntheticLayout(
            supports: [
                .init("gate-left", .gate, 0.58),
                .init("gate-centre", .gate, 0.76),
                .init("tower", .arrowTower, 0.68)
            ],
            routes: [.left: ["gate-left", "keep"], .center: ["gate-centre", "keep"], .right: ["tower", "keep"]],
            fireSourceID: "tower"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "R Tower")
    }

    @Test func sharedBarracksFooterKeepsEveryLaneOfItsSingleEntry() {
        let layout = Self.syntheticLayout(
            supports: [
                .init("barracks", .barracks, 0.72),
                .init("tower", .arrowTower, 0.80),
                .init("gate", .gate, 0.84)
            ],
            routes: [.left: ["barracks", "keep"], .center: ["barracks", "keep"], .right: ["tower", "gate", "keep"]],
            fireSourceID: "tower"
        )

        #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "L/C Barracks")
    }

    @Test
    func eachUnlockedCityProjectsItsAuthoredScoutDetails() {
        let expected: [ExpectedScoutDetails] = [
            .init(1, .standardWatch, [], [], .right),
            .init(2, .standardWatch, [], [], .left),
            .init(3, .arrowTower, [.infantry, .cavalry], [.archer, .mage], .left),
            .init(4, .spikedGate, [.archer, .mage], [.infantry, .cavalry], .right),
            .init(5, .arrowTower, [.infantry, .cavalry], [.archer, .mage], .right),
            .init(6, .stoneWall, [.mage, .siege], [.archer], .center),
            .init(7, .burningOil, [.archer, .mage, .cavalry], [.infantry, .siege], .right),
            .init(8, .stoneWall, [.mage, .siege], [.archer], .left),
            .init(9, .arcaneWard, [.infantry, .cavalry, .siege], [.mage], .center),
            .init(10, .spikedGate, [.archer, .mage], [.infantry, .cavalry], .right),
            .init(11, .reinforcedKeep, [.siege], [.archer, .infantry], .left),
            .init(12, .burningOil, [.archer, .mage, .cavalry], [.infantry, .siege], .center),
            .init(13, .arcaneWard, [.infantry, .cavalry, .siege], [.mage], .right),
            .init(14, .stoneWall, [.mage, .siege], [.archer], .left),
            .init(15, .reinforcedKeep, [.siege], [.archer, .infantry], .center)
        ]

        for item in expected {
            let state = KingdomGameState(
                cityLevel: item.cityNumber,
                cityNumberInCountry: item.cityNumber,
                completedCityCount: item.cityNumber - 1
            )
            let definition = Country1CityCatalog.definition(for: item.cityNumber)

            #expect(state.unlockedMapCityNumber == item.cityNumber)
            #expect(Country1CityCatalog.cityRange.filter { state.mapStatus(for: $0) == .unlocked } == [item.cityNumber])
            #expect(definition.defenseTrait == item.trait)
            #expect(definition.defenseTrait.favorableSoldierTypes == item.favorable)
            #expect(definition.defenseTrait.disadvantagedSoldierTypes == item.disadvantaged)
            #expect(definition.laneDefenseProfile.exposedLane == item.exposedLane)
            #expect(
                CountryMapScoutCardContent.project(from: state)
                    == .scout(
                        .init(
                            cityNumber: item.cityNumber,
                            displayTitle: definition.displayTitle,
                            defenseTrait: item.trait,
                            exposedLane: item.exposedLane,
                            goldReward: KingdomGameState.goldReward(for: item.cityNumber),
                            flavorText: definition.flavorText,
                            tacticalFooter: Self.expectedTacticalFooter(for: item.cityNumber),
                            status: .current
                        )
                    )
            )
        }
    }

    @Test
    func countryCompleteProjectsOnlyTheCountryCompleteContent() {
        let state = KingdomGameState(
            cityLevel: 15,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )

        #expect(
            CountryMapScoutCardContent.project(from: state)
                == .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep")
        )
    }

    @Test
    func displayTitlesAndLaneNamesUsePlayerFacingNames() {
        let state = KingdomGameState(cityNumberInCountry: 7, completedCityCount: 6)

        #expect(state.displayCityTitle(for: 7) == "Emberford")
        #expect(state.displayCityTitle == "Emberford")
        #expect(BattleLane.left.displayName == "Left")
        #expect(BattleLane.center.displayName == "Center")
        #expect(BattleLane.right.displayName == "Right")
    }
}

private extension CountryMapScoutCardContentTests {
    /// Synthetic layout for footer projection shapes the catalog does not
    /// author yet (3-4 supports). The Keep is the first objective, as authored,
    /// and the final stop on every route; `fireSourceID` names the Tower or the
    /// Keep and covers every lane.
    static func syntheticLayout(
        supports: [SyntheticSupport],
        routes: [BattleLane: [String]],
        fireSourceID: String
    ) -> CitySiegeLayout {
        let keep = CitySiegeLayout.Objective(
            id: "keep",
            kind: .keep,
            durabilityWeight: 1,
            visualLane: .center,
            visualProgress: 1.0
        )
        let objectives = [keep] + supports.map { support in
            CitySiegeLayout.Objective(
                id: support.id,
                kind: support.kind,
                durabilityWeight: 1,
                visualLane: .center,
                visualProgress: support.progress
            )
        }
        return CitySiegeLayout(
            objectives: objectives,
            routes: routes,
            defaultLane: .center,
            defensiveFire: .init(sourceObjectiveID: fireSourceID, coveredLanes: BattleLane.allCases)
        )
    }

    /// Authored tactical footers per city, one route-derived line per support
    /// objective (Falconridge's Tower/Gate split, Highcrest's left-lane Barracks
    /// (HPA-469), and the HPA-477 two-support cities); single-Keep cities nil.
    static func expectedTacticalFooter(for cityNumber: Int) -> String? {
        expectedTacticalFooters[cityNumber]
    }

    private static var expectedTacticalFooters: [Int: String] {
        [
            1: "L/C Gate",
            2: "L/R Gate",
            3: "L Tower · C/R Gate",
            4: "L/C Gate · R Gate",
            5: "L Barracks",
            6: "L/C Gate · R Tower",
            7: "L Barracks · C Gate",
            8: "L Tower · C/R Gate",
            9: "L Barracks · R Tower",
            10: "L Tower"
        ]
    }
}

/// One support objective in a synthetic footer layout (see `syntheticLayout`).
private struct SyntheticSupport {
    let id: String
    let kind: CitySiegeLayout.ObjectiveKind
    let progress: Double

    init(_ id: String, _ kind: CitySiegeLayout.ObjectiveKind, _ progress: Double) {
        self.id = id
        self.kind = kind
        self.progress = progress
    }
}

private struct ExpectedScoutDetails {
    let cityNumber: Int
    let trait: CityDefenseTrait
    let favorable: [SoldierType]
    let disadvantaged: [SoldierType]
    let exposedLane: BattleLane

    init(
        _ cityNumber: Int,
        _ trait: CityDefenseTrait,
        _ favorable: [SoldierType],
        _ disadvantaged: [SoldierType],
        _ exposedLane: BattleLane
    ) {
        self.cityNumber = cityNumber
        self.trait = trait
        self.favorable = favorable
        self.disadvantaged = disadvantaged
        self.exposedLane = exposedLane
    }
}
