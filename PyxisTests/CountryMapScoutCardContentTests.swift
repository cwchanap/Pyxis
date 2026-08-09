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
                        displayTitle: "City 1 · Willowford",
                        defenseTrait: .standardWatch,
                        exposedLane: .right,
                        goldReward: KingdomGameState.goldReward(for: 1),
                        flavorText: "A quiet crossing where the campaign begins."
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
                    displayTitle: definition.displayTitle,
                    defenseTrait: definition.defenseTrait,
                    exposedLane: definition.laneDefenseProfile.exposedLane,
                    goldReward: KingdomGameState.goldReward(for: 2),
                    flavorText: definition.flavorText
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
                            displayTitle: definition.displayTitle,
                            defenseTrait: definition.defenseTrait,
                            exposedLane: definition.laneDefenseProfile.exposedLane,
                            goldReward: KingdomGameState.goldReward(for: nextCityNumber),
                            flavorText: definition.flavorText
                        )
                    )
            )
        }
    }

    @Test
    func eachUnlockedCityProjectsItsAuthoredScoutDetails() {
        let expected: [ExpectedScoutDetails] = [
            .init(1, .standardWatch, [], [], .right),
            .init(2, .standardWatch, [], [], .left),
            .init(3, .arrowTower, [.infantry, .cavalry], [.archer, .mage], .center),
            .init(4, .spikedGate, [.archer, .mage], [.infantry, .cavalry], .right),
            .init(5, .arrowTower, [.infantry, .cavalry], [.archer, .mage], .left),
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
                            flavorText: definition.flavorText
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

        #expect(state.displayCityTitle(for: 7) == "Emberford")
        #expect(state.displayCityTitle == "Emberford")
        #expect(BattleLane.left.displayName == "Left")
        #expect(BattleLane.center.displayName == "Center")
        #expect(BattleLane.right.displayName == "Right")
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
