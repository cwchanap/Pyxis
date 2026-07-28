//
//  CountryMapScoutCardContentTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct CountryMapScoutCardContentTests {
    @Test
    func freshBattleProjectsCityOne() {
        let state = KingdomGameState()

        #expect(
            CountryMapScoutCardContent.project(from: state)
                == .scout(
                    .init(
                        cityNumber: 1,
                        displayTitle: "Country 1 - City 1",
                        defenseTrait: .standardWatch,
                        exposedLane: .right,
                        goldReward: KingdomGameState.goldReward(for: 1)
                    )
                )
        )
    }

    @Test
    func pendingMapProjectsTheNextUnlockedCityInsteadOfTheStaleBattleCity() {
        let state = KingdomGameState(
            gold: 15,
            cityLevel: 1,
            cityRemainingPower: 0,
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
                    displayTitle: "Country 1 - City 2",
                    defenseTrait: definition.defenseTrait,
                    exposedLane: definition.laneDefenseProfile.exposedLane,
                    goldReward: KingdomGameState.goldReward(for: 2)
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
                cityRemainingPower: 0,
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
                            displayTitle: "Country 1 - City \(nextCityNumber)",
                            defenseTrait: definition.defenseTrait,
                            exposedLane: definition.laneDefenseProfile.exposedLane,
                            goldReward: KingdomGameState.goldReward(for: nextCityNumber)
                        )
                    )
            )
        }
    }

    @Test
    func eachUnlockedCityProjectsItsAuthoredScoutDetails() {
        let expected: [(cityNumber: Int, trait: CityDefenseTrait, favorable: [SoldierType], disadvantaged: [SoldierType], exposedLane: BattleLane)] = [
            (1, .standardWatch, [], [], .right),
            (2, .standardWatch, [], [], .left),
            (3, .arrowTower, [.infantry, .cavalry], [.archer, .mage], .center),
            (4, .spikedGate, [.archer, .mage], [.infantry, .cavalry], .right),
            (5, .arrowTower, [.infantry, .cavalry], [.archer, .mage], .left),
            (6, .stoneWall, [.mage, .siege], [.archer], .center),
            (7, .burningOil, [.archer, .mage, .cavalry], [.infantry, .siege], .right),
            (8, .stoneWall, [.mage, .siege], [.archer], .left),
            (9, .arcaneWard, [.infantry, .cavalry, .siege], [.mage], .center),
            (10, .spikedGate, [.archer, .mage], [.infantry, .cavalry], .right),
            (11, .reinforcedKeep, [.siege], [.archer, .infantry], .left),
            (12, .burningOil, [.archer, .mage, .cavalry], [.infantry, .siege], .center),
            (13, .arcaneWard, [.infantry, .cavalry, .siege], [.mage], .right),
            (14, .stoneWall, [.mage, .siege], [.archer], .left),
            (15, .reinforcedKeep, [.siege], [.archer, .infantry], .center)
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
                            displayTitle: "Country 1 - City \(item.cityNumber)",
                            defenseTrait: item.trait,
                            exposedLane: item.exposedLane,
                            goldReward: KingdomGameState.goldReward(for: item.cityNumber)
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

        #expect(CountryMapScoutCardContent.project(from: state) == .countryComplete(countryNumber: 1))
    }

    @Test
    func displayTitlesAndLaneNamesUsePlayerFacingNames() {
        let state = KingdomGameState(cityNumberInCountry: 7, completedCityCount: 6)

        #expect(state.displayCityTitle(for: 7) == "Country 1 - City 7")
        #expect(state.displayCityTitle == "Country 1 - City 7")
        #expect(BattleLane.left.displayName == "Left")
        #expect(BattleLane.center.displayName == "Center")
        #expect(BattleLane.right.displayName == "Right")
    }
}
