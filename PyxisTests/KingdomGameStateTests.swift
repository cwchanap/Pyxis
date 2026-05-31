//
//  KingdomGameStateTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct KingdomGameStateTests {
    @Test func formulasMatchMVPBalanceCurve() {
        #expect(KingdomGameState.cityMaxPower(for: 1) == 20)
        #expect(KingdomGameState.cityMaxPower(for: 2) == 43)
        #expect(KingdomGameState.cityMaxPower(for: 3) == 92)
        #expect(KingdomGameState.cityMaxPower(for: 10) == 19633)

        #expect(KingdomGameState.goldReward(for: 1) == 8)
        #expect(KingdomGameState.goldReward(for: 2) == 12)

        #expect(KingdomGameState.normalSoldierAttackPower(for: 1) == 1)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 2) == 2)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 4) == 3)

        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 1) == 10)
        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 2) == 17)
    }

    @Test func expandedSoldierCatalogHasDisplayNames() {
        #expect(SoldierType.allCases == [.infantry, .archer, .cavalry, .mage, .siege])
        #expect(SoldierType.infantry.displayName == "Infantry")
        #expect(SoldierType.archer.displayName == "Archer")
        #expect(SoldierType.cavalry.displayName == "Cavalry")
        #expect(SoldierType.mage.displayName == "Mage")
        #expect(SoldierType.siege.displayName == "Siege")
    }

    @Test func expandedBuildingCatalogMapsToSoldierTypes() {
        #expect(BuildingType.allCases == [.barracks, .archeryRange, .stable, .mageTower, .siegeWorkshop])
        #expect(BuildingType.barracks.displayName == "Barracks")
        #expect(BuildingType.archeryRange.displayName == "Archery Range")
        #expect(BuildingType.stable.displayName == "Stable")
        #expect(BuildingType.mageTower.displayName == "Mage Tower")
        #expect(BuildingType.siegeWorkshop.displayName == "Siege Workshop")

        #expect(BuildingType.barracks.shortDisplayName == "Barracks")
        #expect(BuildingType.archeryRange.shortDisplayName == "Archery")
        #expect(BuildingType.stable.shortDisplayName == "Stable")
        #expect(BuildingType.mageTower.shortDisplayName == "Mage")
        #expect(BuildingType.siegeWorkshop.shortDisplayName == "Siege")

        #expect(BuildingType.barracks.soldierType == .infantry)
        #expect(BuildingType.archeryRange.soldierType == .archer)
        #expect(BuildingType.stable.soldierType == .cavalry)
        #expect(BuildingType.mageTower.soldierType == .mage)
        #expect(BuildingType.siegeWorkshop.soldierType == .siege)
    }

    @Test func cityDefenseTraitsExposeDisplayAndCounterMetadata() throws {
        #expect(CityDefenseTrait.allCases == [
            .standardWatch,
            .arrowTower,
            .spikedGate,
            .stoneWall,
            .arcaneWard,
            .burningOil,
            .reinforcedKeep
        ])

        #expect(CityDefenseTrait.standardWatch.displayName == "Standard Watch")
        #expect(CityDefenseTrait.arrowTower.displayName == "Arrow Tower")
        #expect(CityDefenseTrait.spikedGate.displayName == "Spiked Gate")
        #expect(CityDefenseTrait.stoneWall.displayName == "Stone Wall")
        #expect(CityDefenseTrait.arcaneWard.displayName == "Arcane Ward")
        #expect(CityDefenseTrait.burningOil.displayName == "Burning Oil")
        #expect(CityDefenseTrait.reinforcedKeep.displayName == "Reinforced Keep")
        #expect(
            CityDefenseTrait.arcaneWard.shortDescription
                == "Infantry, Cavalry, and Siege avoid the ward's resistance."
        )

        let expectedMultipliers: [(trait: CityDefenseTrait, multipliers: [SoldierType: Double])] = [
            (
                .standardWatch,
                [.infantry: 1.0, .archer: 1.0, .cavalry: 1.0, .mage: 1.0, .siege: 1.0]
            ),
            (
                .arrowTower,
                [.infantry: 1.25, .archer: 0.80, .cavalry: 1.25, .mage: 0.80, .siege: 1.0]
            ),
            (
                .spikedGate,
                [.infantry: 0.80, .archer: 1.25, .cavalry: 0.80, .mage: 1.25, .siege: 1.0]
            ),
            (
                .stoneWall,
                [.infantry: 1.0, .archer: 0.80, .cavalry: 1.0, .mage: 1.25, .siege: 1.25]
            ),
            (
                .arcaneWard,
                [.infantry: 1.25, .archer: 1.0, .cavalry: 1.25, .mage: 0.80, .siege: 1.25]
            ),
            (
                .burningOil,
                [.infantry: 0.80, .archer: 1.25, .cavalry: 1.25, .mage: 1.25, .siege: 0.80]
            ),
            (
                .reinforcedKeep,
                [.infantry: 0.80, .archer: 0.80, .cavalry: 1.0, .mage: 1.0, .siege: 1.25]
            )
        ]

        #expect(expectedMultipliers.map(\.trait) == CityDefenseTrait.allCases)
        for (trait, multipliers) in expectedMultipliers {
            for soldierType in SoldierType.allCases {
                let expectedMultiplier = try #require(multipliers[soldierType])
                #expect(trait.damageMultiplier(for: soldierType) == expectedMultiplier)
            }
        }
    }

    @Test func buildingUnlocksProgressAcrossCountryOne() {
        #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 1) == [.barracks])
        #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 2) == [.barracks, .archeryRange])
        #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 4) == [.barracks, .archeryRange])
        #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 5) == [.barracks, .archeryRange, .stable])
        #expect(
            KingdomGameState.unlockedBuildingTypes(forCityNumber: 8)
                == [.barracks, .archeryRange, .stable, .mageTower]
        )
        #expect(
            KingdomGameState.unlockedBuildingTypes(forCityNumber: 11)
                == [.barracks, .archeryRange, .stable, .mageTower, .siegeWorkshop]
        )
        #expect(
            KingdomGameState.unlockedBuildingTypes(forCityNumber: 99)
                == [.barracks, .archeryRange, .stable, .mageTower, .siegeWorkshop]
        )
    }

    @Test func buildingCostsCoverExpandedCatalog() {
        #expect(KingdomGameState.buildingBuildCost(for: .barracks) == 15)
        #expect(KingdomGameState.buildingBuildCost(for: .archeryRange) == 18)
        #expect(KingdomGameState.buildingBuildCost(for: .stable) == 28)
        #expect(KingdomGameState.buildingBuildCost(for: .mageTower) == 40)
        #expect(KingdomGameState.buildingBuildCost(for: .siegeWorkshop) == 55)

        #expect(KingdomGameState.buildingUpgradeCost(for: .stable, currentLevel: 1) == 22)
        #expect(KingdomGameState.buildingUpgradeCost(for: .mageTower, currentLevel: 1) == 30)
        #expect(KingdomGameState.buildingUpgradeCost(for: .siegeWorkshop, currentLevel: 1) == 42)
    }

    @Test func activeSpawnIntervalsCoverExpandedCatalog() {
        #expect(KingdomGameState.activeSpawnInterval(for: .barracks) == 10)
        #expect(KingdomGameState.activeSpawnInterval(for: .archeryRange) == 12)
        #expect(KingdomGameState.activeSpawnInterval(for: .stable) == 14)
        #expect(KingdomGameState.activeSpawnInterval(for: .mageTower) == 16)
        #expect(KingdomGameState.activeSpawnInterval(for: .siegeWorkshop) == 20)
    }

    @Test func traitAdjustedSoldierAttackPowerUsesCounterMultiplier() {
        #expect(KingdomGameState.soldierAttackPower(for: .infantry, level: 1) == 1)
        #expect(KingdomGameState.soldierAttackPower(for: .siege, level: 4) == 3)

        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .siege,
            level: 4,
            defenseTrait: .reinforcedKeep
        ) == 4)

        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .archer,
            level: 4,
            defenseTrait: .reinforcedKeep
        ) == 2)

        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry,
            level: 1,
            defenseTrait: .reinforcedKeep
        ) == 1)
    }

    @Test func traitAdjustedRoundsHalfAwayFromZero() {
        // Level 2: ceil(1.38^1) = 2 → 2 × 1.25 = 2.5 → rounded = 3
        let basePower = KingdomGameState.soldierAttackPower(for: .infantry, level: 2)
        #expect(basePower == 2)

        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry,
            level: 2,
            defenseTrait: .arrowTower
        ) == 3)
    }

    @Test func lockedBuildingsCannotBeBuiltBeforeUnlockCity() {
        var state = KingdomGameState(gold: 500, cityNumberInCountry: 4, completedCityCount: 3)

        #expect(state.buildBuilding(.stable, inSlot: 1) == .lockedBuilding(unlocksAtCity: 5))
        #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
        #expect(state.gold == 500)
    }

    @Test func unlockedBuildingsCanBeBuiltAtUnlockCity() {
        var state = KingdomGameState(gold: 500, cityNumberInCountry: 5, completedCityCount: 4)

        #expect(state.buildBuilding(.stable, inSlot: 1) == .built(cost: 28, remainingGold: 472))
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.type == .stable)
    }

    @Test func manualSoldierLevelRequiresMatchingCurrentCityBuilding() {
        var state = KingdomGameState(gold: 500, cityNumberInCountry: 8, completedCityCount: 7)

        // Non-infantry types still require a building
        #expect(state.manualSoldierLevel(for: .mage) == nil)

        #expect(state.buildBuilding(.mageTower, inSlot: 1) == .built(cost: 40, remainingGold: 460))
        #expect(state.manualSoldierLevel(for: .mage) == 1)

        #expect(state.buildBuilding(.mageTower, inSlot: 2) == .built(cost: 40, remainingGold: 420))
        #expect(state.upgradeBuilding(inSlot: 2) == .upgraded(cost: 30, newLevel: 2, remainingGold: 390))
        #expect(state.manualSoldierLevel(for: .mage) == 2)
    }

    @Test func manualSoldierLevelIsIsolatedAcrossTypes() {
        var state = KingdomGameState(gold: 500, cityNumberInCountry: 8, completedCityCount: 7)

        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 485))
        #expect(state.upgradeBuilding(inSlot: 1) == .upgraded(cost: 12, newLevel: 2, remainingGold: 473))
        #expect(state.upgradeBuilding(inSlot: 1) == .upgraded(cost: 20, newLevel: 3, remainingGold: 453))

        // Barracks is level 3; cavalry/archer/mage/siege have no buildings
        #expect(state.manualSoldierLevel(for: .infantry) == 3)
        #expect(state.manualSoldierLevel(for: .cavalry) == nil)
        #expect(state.manualSoldierLevel(for: .archer) == nil)
        #expect(state.manualSoldierLevel(for: .mage) == nil)
        #expect(state.manualSoldierLevel(for: .siege) == nil)

        // Adding a cavalry building doesn't affect infantry level
        #expect(state.buildBuilding(.stable, inSlot: 2) == .built(cost: 28, remainingGold: 425))
        #expect(state.manualSoldierLevel(for: .infantry) == 3)
        #expect(state.manualSoldierLevel(for: .cavalry) == 1)
    }

    @Test func infantryAlwaysAvailableAtLevel1WithoutBuilding() {
        // Infantry is the starter unit — always spawnable at level 1 even
        // when the current city has no buildings, preventing a soft-lock
        // after city conquest clears buildings and the player can't afford
        // a new Barracks.
        let state = KingdomGameState(gold: 0, cityNumberInCountry: 2, completedCityCount: 1)

        #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
        #expect(state.manualSoldierLevel(for: .infantry) == 1)
        #expect(state.manualSpawnableSoldierTypes() == [.infantry])

        // Non-infantry types still require buildings
        #expect(state.manualSoldierLevel(for: .archer) == nil)
        #expect(state.manualSoldierLevel(for: .cavalry) == nil)
        #expect(state.manualSoldierLevel(for: .mage) == nil)
        #expect(state.manualSoldierLevel(for: .siege) == nil)
    }

    @Test func buildingBarracksUpgradesInfantryBeyondFallbackLevel() {
        var state = KingdomGameState(gold: 500, cityNumberInCountry: 2, completedCityCount: 1)

        // Base fallback level
        #expect(state.manualSoldierLevel(for: .infantry) == 1)

        // Building a Barracks still gives level 1 (matches fallback)
        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 485))
        #expect(state.manualSoldierLevel(for: .infantry) == 1)

        // Upgrading the Barracks pushes infantry above the fallback
        #expect(state.upgradeBuilding(inSlot: 1) == .upgraded(cost: 12, newLevel: 2, remainingGold: 473))
        #expect(state.manualSoldierLevel(for: .infantry) == 2)
    }

    @Test func currentCityDefenseTraitUsesAuthoredProgression() {
        let expected: [Int: CityDefenseTrait] = [
            1: .standardWatch,
            2: .standardWatch,
            3: .arrowTower,
            4: .spikedGate,
            5: .arrowTower,
            6: .stoneWall,
            7: .burningOil,
            8: .stoneWall,
            9: .arcaneWard,
            10: .spikedGate,
            11: .reinforcedKeep,
            12: .burningOil,
            13: .arcaneWard,
            14: .stoneWall,
            15: .reinforcedKeep
        ]

        for (cityNumber, trait) in expected {
            #expect(KingdomGameState.defenseTrait(forCityNumber: cityNumber) == trait)
        }

        let state = KingdomGameState(cityNumberInCountry: 11, completedCityCount: 10)
        #expect(state.currentCityDefenseTrait == .reinforcedKeep)
    }

    @Test func formulasClampInvalidLevelsToOne() {
        #expect(KingdomGameState.cityMaxPower(for: 0) == 20)
        #expect(KingdomGameState.goldReward(for: 0) == 8)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 0) == 1)
        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 0) == 10)
    }

    @Test func decodingInvalidPersistedStateClampsValues() throws {
        let data = """
        {
          "gold": -25,
          "cityLevel": 0,
          "cityRemainingPower": -9,
          "normalSoldierUpgradeLevel": 0,
          "lastBackgroundedAt": null,
          "countryNumber": 0,
          "cityNumberInCountry": 0,
          "completedCityCount": -3,
          "stageStatus": "battleActive"
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 0)
        #expect(state.cityLevel == 1)
        #expect(state.cityRemainingPower == 1)
        #expect(state.normalSoldierUpgradeLevel == 1)
        #expect(state.lastBackgroundedAt == nil)
        #expect(state.countryNumber == 1)
        #expect(state.cityNumberInCountry == 1)
        #expect(state.completedCityCount == 0)
        #expect(state.stageStatus == .battleActive)
    }

    @Test func decodingOldPrototypeSaveInfersCampaignProgressFromCityLevel() throws {
        let data = """
        {
          "gold": 40,
          "cityLevel": 4,
          "cityRemainingPower": 12,
          "normalSoldierUpgradeLevel": 2
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 40)
        #expect(state.cityLevel == 4)
        #expect(state.cityNumberInCountry == 4)
        #expect(state.completedCityCount == 3)
        #expect(state.stageStatus == .battleActive)
        #expect(state.cityRemainingPower == 12)
    }

    @Test func decodingOldTwoUnitBuildingSaveStillSucceeds() throws {
        let data = """
        {
          "gold": 100,
          "cityLevel": 2,
          "cityRemainingPower": 20,
          "normalSoldierUpgradeLevel": 4,
          "countryNumber": 1,
          "cityNumberInCountry": 2,
          "completedCityCount": 1,
          "stageStatus": "battleActive",
          "cityBattleStates": {
            "1-2": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 2,
                  "spawnTimerElapsed": 3
                },
                "2": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 4
                }
              },
              "lastBuildingProgressResolvedAt": null
            }
          }
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.type == .barracks)
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 2)?.type == .archeryRange)
        #expect(state.normalSoldierUpgradeLevel == 4)
        #expect(state.currentCityDefenseTrait == .standardWatch)
    }

    @Test func decodingInvalidStageStatusFallsBackWithoutDiscardingRecoverableFields() throws {
        let data = """
        {
          "gold": 40,
          "cityLevel": 4,
          "cityRemainingPower": 12,
          "normalSoldierUpgradeLevel": 2,
          "countryNumber": 1,
          "cityNumberInCountry": 4,
          "completedCityCount": 3,
          "stageStatus": "renamedStatus"
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 40)
        #expect(state.cityLevel == 4)
        #expect(state.cityRemainingPower == 12)
        #expect(state.normalSoldierUpgradeLevel == 2)
        #expect(state.countryNumber == 1)
        #expect(state.cityNumberInCountry == 4)
        #expect(state.completedCityCount == 3)
        #expect(state.stageStatus == .battleActive)
    }

    @Test func decodingDropsMalformedCityBattleStateStorageKeys() throws {
        let data = """
        {
          "gold": 100,
          "cityLevel": 1,
          "cityRemainingPower": 12,
          "normalSoldierUpgradeLevel": 1,
          "countryNumber": 1,
          "cityNumberInCountry": 1,
          "completedCityCount": 0,
          "stageStatus": "battleActive",
          "cityBattleStates": {
            "1-4": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "junk-1-2": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1-junk-2": {
              "slots": {
                "1": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1-2-extra": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1-2-3": {
              "slots": {
                "1": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            }
          }
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(Set(state.cityBattleStates.keys) == Set(["1-4"]))
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 4)).building(inSlot: 1)?.type == .barracks)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 2)).occupiedSlotCount == 0)
    }

    @Test func decodingDropsNonCanonicalNumericCityBattleStateStorageKeys() throws {
        let data = """
        {
          "gold": 100,
          "cityLevel": 1,
          "cityRemainingPower": 12,
          "normalSoldierUpgradeLevel": 1,
          "countryNumber": 1,
          "cityNumberInCountry": 1,
          "completedCityCount": 0,
          "stageStatus": "battleActive",
          "cityBattleStates": {
            "1-4": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "0-4": {
              "slots": {
                "2": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1-0": {
              "slots": {
                "3": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1-99": {
              "slots": {
                "4": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            }
          }
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(Set(state.cityBattleStates.keys) == Set(["1-4"]))
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 1)).occupiedSlotCount == 0)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 4)).building(inSlot: 1)?.type == .barracks)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 15)).occupiedSlotCount == 0)
    }

    @Test func decodingDropsParseableNonCanonicalCityBattleStateStorageKeys() throws {
        let data = """
        {
          "gold": 100,
          "cityLevel": 1,
          "cityRemainingPower": 12,
          "normalSoldierUpgradeLevel": 1,
          "countryNumber": 1,
          "cityNumberInCountry": 1,
          "completedCityCount": 0,
          "stageStatus": "battleActive",
          "cityBattleStates": {
            "1-5": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "01-4": {
              "slots": {
                "2": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "+1-6": {
              "slots": {
                "3": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1-04": {
              "slots": {
                "4": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            " 1-7": {
              "slots": {
                "5": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1-7 ": {
              "slots": {
                "6": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            }
          }
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(Set(state.cityBattleStates.keys) == Set(["1-5"]))
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 4)).occupiedSlotCount == 0)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 5)).building(inSlot: 1)?.type == .barracks)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 6)).occupiedSlotCount == 0)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 7)).occupiedSlotCount == 0)
    }

    @Test func decodingDropsCompletedCityBuildingStates() throws {
        let data = """
        {
          "gold": 100,
          "cityLevel": 3,
          "cityRemainingPower": 12,
          "normalSoldierUpgradeLevel": 1,
          "countryNumber": 1,
          "cityNumberInCountry": 3,
          "completedCityCount": 2,
          "stageStatus": "battleActive",
          "cityBattleStates": {
            "1-2": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            },
            "1-3": {
              "slots": {
                "1": {
                  "type": "archeryRange",
                  "level": 2,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            }
          }
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.completedCityCount == 2)
        #expect(Set(state.cityBattleStates.keys) == Set(["1-3"]))
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 2)).occupiedSlotCount == 0)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 3)).building(inSlot: 1)?.type == .archeryRange)
    }

    @Test func countryCompleteInitializationNormalizesCompletedCityCount() {
        let state = KingdomGameState(
            cityLevel: 4,
            countryNumber: 1,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .countryComplete
        )

        #expect(state.completedCityCount == KingdomGameState.firstCountryCityCount)
        #expect(state.cityNumberInCountry == KingdomGameState.firstCountryCityCount)
        #expect(state.cityLevel == KingdomGameState.firstCountryCityCount)
        #expect(state.stageStatus == .countryComplete)
        #expect(state.mapStatus(for: 15) == .completed)
        #expect(state.hasNextCityInCountry == false)
    }

    @Test func pendingMapStateIncludesCurrentCityInCompletedCount() {
        let state = KingdomGameState(
            cityLevel: 4,
            cityRemainingPower: 0,
            countryNumber: 1,
            cityNumberInCountry: 4,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )

        #expect(state.cityLevel == 4)
        #expect(state.cityNumberInCountry == 4)
        #expect(state.completedCityCount == 4)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.mapStatus(for: 4) == .completed)
        #expect(state.mapStatus(for: 5) == .unlocked)
    }

    @Test func activeBattleNormalizesAwayFromCompletedCity() {
        let state = KingdomGameState(
            cityLevel: 2,
            cityRemainingPower: 11,
            countryNumber: 1,
            cityNumberInCountry: 2,
            completedCityCount: 5,
            stageStatus: .battleActive
        )

        #expect(state.cityNumberInCountry == 6)
        #expect(state.cityLevel == 6)
        #expect(state.completedCityCount == 5)
        #expect(state.stageStatus == .battleActive)
        #expect(state.cityRemainingPower == 11)
        #expect(state.mapStatus(for: 5) == .completed)
        #expect(state.mapStatus(for: 6) == .unlocked)
    }

    @Test func firstLaunchStartsBattleReadyAtCountryOneCityOne() {
        let state = KingdomGameState()

        #expect(state.countryNumber == 1)
        #expect(state.cityNumberInCountry == 1)
        #expect(state.completedCityCount == 0)
        #expect(state.cityLevel == 1)
        #expect(state.stageStatus == .battleActive)
        #expect(state.displayCityTitle == "Country 1 - City 1")
        #expect(state.mapStatus(for: 1) == .unlocked)
        #expect(state.mapStatus(for: 2) == .locked)
    }

    @Test func firstLaunchCanAffordStarterBarracks() {
        let state = KingdomGameState()
        let barracksCost = KingdomGameState.buildingBuildCost(for: .barracks)

        #expect(state.gold >= barracksCost)
    }

    @Test func firstLaunchCanBuildBarracksAndSpawnSoldiers() {
        var state = KingdomGameState()
        let barracksCost = KingdomGameState.buildingBuildCost(for: .barracks)

        let result = state.buildBuilding(.barracks, inSlot: 1)
        guard case .built(let cost, let remainingGold) = result else {
            Issue.record("Expected barracks to build, got \(result)")
            return
        }
        #expect(cost == barracksCost)
        #expect(remainingGold == state.gold)

        let level = state.manualSoldierLevel(for: .infantry)
        #expect(level == 1)
        #expect(state.manualSpawnableSoldierTypes() == [.infantry])
    }

    @Test func currentCityStartsWithEmptyBuildingGrid() {
        let state = KingdomGameState()
        let cityState = state.cityBattleStateForCurrentCity

        #expect(cityState.slotCount == 25)
        #expect(cityState.occupiedSlotCount == 0)
        #expect(cityState.buildingCount(for: .barracks) == 0)
        #expect(cityState.buildingCount(for: .archeryRange) == 0)
    }

    @Test func cityBuildingDecodingClampsLevelAndSpawnTimer() throws {
        let data = """
        {
          "type": "barracks",
          "level": -4,
          "spawnTimerElapsed": -2.5
        }
        """.data(using: .utf8)!

        let building = try JSONDecoder().decode(CityBuilding.self, from: data)

        #expect(building.type == .barracks)
        #expect(building.level == 1)
        #expect(building.spawnTimerElapsed == 0)
    }

    @Test func cityBattleStateNormalizeDropsInvalidSlotsAndCapsBuildingsByTypeInSlotOrder() {
        var state = CityBattleState(slots: [
            0: CityBuilding(type: .barracks),
            1: CityBuilding(type: .barracks),
            2: CityBuilding(type: .barracks),
            3: CityBuilding(type: .barracks),
            4: CityBuilding(type: .barracks),
            5: CityBuilding(type: .barracks),
            6: CityBuilding(type: .barracks),
            10: CityBuilding(type: .archeryRange),
            11: CityBuilding(type: .archeryRange),
            12: CityBuilding(type: .archeryRange),
            13: CityBuilding(type: .archeryRange),
            14: CityBuilding(type: .archeryRange),
            15: CityBuilding(type: .archeryRange),
            26: CityBuilding(type: .archeryRange)
        ])

        state.normalize()

        #expect(state.building(inSlot: 0) == nil)
        #expect(state.building(inSlot: 26) == nil)
        #expect(state.buildingCount(for: .barracks) == 5)
        #expect(state.buildingCount(for: .archeryRange) == 5)

        for slot in 1...5 {
            #expect(state.building(inSlot: slot)?.type == .barracks)
        }
        #expect(state.building(inSlot: 6) == nil)

        for slot in 10...14 {
            #expect(state.building(inSlot: slot)?.type == .archeryRange)
        }
        #expect(state.building(inSlot: 15) == nil)
    }

    @Test func cityBattleStateDecodingLossilyNormalizesSlotsAndBuildings() throws {
        let data = """
        {
          "slots": {
            "0": {
              "type": "barracks",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "1": {
              "type": "barracks",
              "level": -2,
              "spawnTimerElapsed": -4.5
            },
            "2": {
              "type": "barracks",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "3": {
              "type": "barracks",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "4": {
              "type": "barracks",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "5": {
              "type": "barracks",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "6": {
              "type": "barracks",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "10": {
              "type": "archeryRange",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "11": {
              "type": "archeryRange",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "12": {
              "type": "archeryRange",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "13": {
              "type": "archeryRange",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "14": {
              "type": "archeryRange",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "15": {
              "type": "archeryRange",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "26": {
              "type": "archeryRange",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "junk": {
              "type": "barracks",
              "level": 1,
              "spawnTimerElapsed": 0
            },
            "20": {
              "type": "unknown",
              "level": 1,
              "spawnTimerElapsed": 0
            }
          },
          "lastBuildingProgressResolvedAt": null
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(CityBattleState.self, from: data)

        #expect(state.building(inSlot: 0) == nil)
        #expect(state.building(inSlot: 26) == nil)
        #expect(state.building(inSlot: 20) == nil)
        #expect(state.building(inSlot: 1)?.level == 1)
        #expect(state.building(inSlot: 1)?.spawnTimerElapsed == 0)
        #expect(state.buildingCount(for: .barracks) == 5)
        #expect(state.buildingCount(for: .archeryRange) == 5)

        for slot in 1...5 {
            #expect(state.building(inSlot: slot)?.type == .barracks)
        }
        #expect(state.building(inSlot: 6) == nil)

        for slot in 10...14 {
            #expect(state.building(inSlot: slot)?.type == .archeryRange)
        }
        #expect(state.building(inSlot: 15) == nil)
    }

    @Test func buildingConsumesGoldAndOccupiesSelectedSlot() {
        var state = KingdomGameState(gold: 100)

        let result = state.buildBuilding(.barracks, inSlot: 7, at: Date(timeIntervalSinceReferenceDate: 100))

        #expect(result == .built(cost: 15, remainingGold: 85))
        #expect(state.gold == 85)
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 7)?.type == .barracks)
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 7)?.level == 1)
    }

    @Test func buildingRejectsInvalidOccupiedUnaffordableAndTypeCapCases() {
        var state = KingdomGameState(gold: 200)

        #expect(state.buildBuilding(.barracks, inSlot: 0) == .invalidSlot)
        #expect(state.buildBuilding(.barracks, inSlot: 26) == .invalidSlot)

        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 185))
        #expect(state.buildBuilding(.barracks, inSlot: 1) == .slotOccupied)

        #expect(state.buildBuilding(.barracks, inSlot: 2) == .built(cost: 15, remainingGold: 170))
        #expect(state.buildBuilding(.barracks, inSlot: 3) == .built(cost: 15, remainingGold: 155))
        #expect(state.buildBuilding(.barracks, inSlot: 4) == .built(cost: 15, remainingGold: 140))
        #expect(state.buildBuilding(.barracks, inSlot: 5) == .built(cost: 15, remainingGold: 125))
        #expect(state.buildBuilding(.barracks, inSlot: 6) == .typeCapReached(maximum: 5))

        var poorState = KingdomGameState(gold: 14)
        #expect(poorState.buildBuilding(.barracks, inSlot: 1) == .insufficientGold(cost: 15, currentGold: 14))
        #expect(poorState.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
    }

    @Test func buildingIsUnavailableOutsideActiveBattle() {
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )

        #expect(state.buildBuilding(.barracks, inSlot: 1) == .unavailable)
        #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
    }

    @Test func firstBuildingInitializesProgressTimestamp() {
        let firstDate = Date(timeIntervalSinceReferenceDate: 100)
        var state = KingdomGameState(gold: 100)

        #expect(state.buildBuilding(.barracks, inSlot: 1, at: firstDate) == .built(cost: 15, remainingGold: 85))
        #expect(state.cityBattleStateForCurrentCity.lastBuildingProgressResolvedAt == firstDate)
    }

    @Test func buildBuildingWithDefaultDatePreservesResolvedTimestamp() {
        // When called without an explicit date, buildBuilding must still set
        // lastBuildingProgressResolvedAt so that later idle resolution does not
        // fall back to lastBackgroundedAt and credit time before the building existed.
        var state = KingdomGameState(gold: 100, cityRemainingPower: 10_000)

        let before = Date()
        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 85))
        let after = Date()

        let resolved = state.cityBattleStateForCurrentCity.lastBuildingProgressResolvedAt
        #expect(resolved != nil)
        #expect(resolved! >= before)
        #expect(resolved! <= after)
    }

    @Test func buildingNewSlotAdvancesProgressTimestampSoNewBuildingIsNotBackdated() {
        let firstDate = Date(timeIntervalSinceReferenceDate: 100)
        let secondDate = firstDate.addingTimeInterval(100)
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 10_000,
            cityNumberInCountry: 2,
            completedCityCount: 1
        )

        #expect(state.buildBuilding(.barracks, inSlot: 1, at: firstDate) == .built(cost: 15, remainingGold: 85))
        #expect(state.cityBattleStateForCurrentCity.lastBuildingProgressResolvedAt == firstDate)

        #expect(state.buildBuilding(.archeryRange, inSlot: 2, at: secondDate) == .built(cost: 18, remainingGold: 67))
        // settleCurrentCityBuildingProgress advances the timestamp to secondDate
        #expect(state.cityBattleStateForCurrentCity.lastBuildingProgressResolvedAt == secondDate)

        // The first barracks accumulated 100s of idle time (10s effective active),
        // producing 1 spawn at level 1 (1 damage). The new archery range should NOT
        // get credited for time before it existed.
        // cityRemainingPower should have 1 damage from the first building only.
        #expect(state.cityRemainingPower == 10_000 - 1)
    }

    @Test func upgradingBuildingSettlesProgressSoOldLevelIsUsedForPendingTime() {
        let startDate = Date(timeIntervalSinceReferenceDate: 100)
        let upgradeDate = startDate.addingTimeInterval(200)
        let resolveDate = upgradeDate.addingTimeInterval(100)
        var state = KingdomGameState(gold: 200, cityRemainingPower: 10_000)

        #expect(state.buildBuilding(.barracks, inSlot: 1, at: startDate) == .built(cost: 15, remainingGold: 185))

        state.enterBackground(at: startDate)

        // Upgrade the building while there is pending idle progress
        let upgradeResult = state.upgradeBuilding(inSlot: 1, at: upgradeDate)
        #expect(upgradeResult == .upgraded(cost: 12, newLevel: 2, remainingGold: 173))

        // Settle during upgrade dealt: 200s idle = 20s effective = 2 spawns at level 1 = 2 damage
        #expect(state.cityRemainingPower == 10_000 - 2)

        // Now resolve the remaining idle progress (100s, building now at level 2)
        let result = state.returnFromBackground(at: resolveDate)

        // 100s idle / 10 = 10s effective = 1 spawn at level 2 = 2 damage
        #expect(result.damageDealt == 2)
        #expect(state.cityRemainingPower == 10_000 - 2 - 2)
    }

    @Test func upgradingBuildingConsumesGoldAndIncreasesLevel() {
        var state = KingdomGameState(gold: 100, cityNumberInCountry: 2, completedCityCount: 1)
        #expect(state.buildBuilding(.archeryRange, inSlot: 4) == .built(cost: 18, remainingGold: 82))

        let result = state.upgradeBuilding(inSlot: 4)

        #expect(result == .upgraded(cost: 14, newLevel: 2, remainingGold: 68))
        #expect(state.gold == 68)
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 4)?.level == 2)
    }

    @Test func upgradingRejectsMissingBuildingAndInsufficientGold() {
        var state = KingdomGameState(gold: 100, cityNumberInCountry: 2, completedCityCount: 1)

        #expect(state.upgradeBuilding(inSlot: 3) == .missingBuilding)

        #expect(state.buildBuilding(.archeryRange, inSlot: 3) == .built(cost: 18, remainingGold: 82))
        state.gold = 0

        #expect(state.upgradeBuilding(inSlot: 3) == .insufficientGold(cost: 14, currentGold: 0))
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 3)?.level == 1)
    }

    @Test func upgradingBuildingRejectsInvalidSlotAndUnavailableState() {
        var state = KingdomGameState(gold: 100)

        #expect(state.upgradeBuilding(inSlot: 0) == .invalidSlot)
        #expect(state.upgradeBuilding(inSlot: 26) == .invalidSlot)

        var pausedState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )

        #expect(pausedState.upgradeBuilding(inSlot: 1) == .unavailable)
    }

    @Test func buildingStateIsIsolatedByCityAndClearedAfterConquest() {
        var state = KingdomGameState(gold: 200, cityRemainingPower: 1)
        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 185))

        _ = state.applyLiveCombatDamage(1)

        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 1)).occupiedSlotCount == 0)

        _ = state.startCityFromMap(2)
        #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
        #expect(state.buildBuilding(.archeryRange, inSlot: 1) == .built(cost: 18, remainingGold: 175))
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 2)).building(inSlot: 1)?.type == .archeryRange)
    }

    @Test func liveCombatDamageReducesCurrentCityHP() {
        var state = KingdomGameState(cityRemainingPower: 20)

        let result = state.applyLiveCombatDamage(6)

        #expect(result.attackApplied)
        #expect(result.damageDealt == 6)
        #expect(result.conqueredCities == 0)
        #expect(result.goldEarned == 0)
        #expect(state.cityRemainingPower == 14)
        #expect(state.stageStatus == .battleActive)
    }

    @Test func liveCombatDamageIsCappedAndConquersCurrentCity() {
        var state = KingdomGameState(gold: 0, cityRemainingPower: 3)

        let result = state.applyLiveCombatDamage(9)

        #expect(result.attackApplied)
        #expect(result.damageDealt == 3)
        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == 8)
        #expect(state.gold == 8)
        #expect(state.cityRemainingPower == 0)
        #expect(state.completedCityCount == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func liveCombatDamageIsRejectedWhenBattleIsPaused() {
        var state = KingdomGameState(gold: 0, cityRemainingPower: 1)
        _ = state.applyLiveCombatDamage(1)

        let result = state.applyLiveCombatDamage(5)

        #expect(!result.attackApplied)
        #expect(result.damageDealt == 0)
        #expect(state.gold == 8)
        #expect(state.cityRemainingPower == 0)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func startingNextUnlockedCityAdvancesAndRestoresFullHP() {
        var state = KingdomGameState(cityRemainingPower: 1)
        _ = state.applyLiveCombatDamage(1)

        let result = state.startCityFromMap(2)

        #expect(result == .entered(country: 1, city: 2))
        #expect(state.cityNumberInCountry == 2)
        #expect(state.cityLevel == 2)
        #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
        #expect(state.stageStatus == .battleActive)
    }

    @Test func noSoftLockAfterConquestWithInsufficientGoldForBarracks() {
        // Regression: after spending all starting gold on a Barracks, conquering
        // city 1 awards only 8g — not enough for another Barracks (15g). The
        // player must still be able to spawn infantry on city 2.
        var state = KingdomGameState(gold: 15, cityRemainingPower: 1)
        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 0))

        _ = state.applyLiveCombatDamage(1)
        #expect(state.gold == 8)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)

        _ = state.startCityFromMap(2)
        #expect(state.stageStatus == .battleActive)
        #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)

        // Can't afford Barracks, but infantry is still spawnable
        #expect(state.gold < KingdomGameState.buildingBuildCost(for: .barracks))
        #expect(state.manualSoldierLevel(for: .infantry) == 1)
        #expect(state.manualSpawnableSoldierTypes() == [.infantry])
    }

    @Test func startingCurrentActiveCityDoesNotResetHP() {
        var state = KingdomGameState(cityLevel: 2, cityRemainingPower: 17, cityNumberInCountry: 2, completedCityCount: 1)

        let result = state.startCityFromMap(2)

        #expect(result == .entered(country: 1, city: 2))
        #expect(state.cityNumberInCountry == 2)
        #expect(state.cityLevel == 2)
        #expect(state.cityRemainingPower == 17)
        #expect(state.stageStatus == .battleActive)
    }

    @Test func lockedFutureCityEntryIsRejected() {
        var state = KingdomGameState(cityRemainingPower: 1)
        _ = state.applyLiveCombatDamage(1)

        let result = state.startCityFromMap(3)

        #expect(result == .locked)
        #expect(state.cityNumberInCountry == 1)
        #expect(state.cityLevel == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func completedCityEntryIsRejected() {
        var state = KingdomGameState(cityRemainingPower: 1)
        _ = state.applyLiveCombatDamage(1)

        let result = state.startCityFromMap(1)

        #expect(result == .alreadyCompleted)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func cityFifteenConquestCompletesCountry() {
        var state = KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 1,
            countryNumber: 1,
            cityNumberInCountry: 15,
            completedCityCount: 14
        )

        let result = state.applyLiveCombatDamage(1)

        #expect(result.conqueredCities == 1)
        #expect(state.completedCityCount == 15)
        #expect(state.stageStatus == .countryComplete)
        #expect(state.mapStatus(for: 15) == .completed)
        #expect(state.startCityFromMap(15) == .countryComplete)
    }

    @Test func successfulUpgradeSpendsGoldAndRaisesAttackPower() {
        var state = KingdomGameState(gold: 30)

        let result = state.upgradeNormalSoldier()

        #expect(result == .upgraded(cost: 10, newAttackPower: 2))
        #expect(state.gold == 20)
        #expect(state.normalSoldierUpgradeLevel == 2)
        #expect(state.normalSoldierAttackPower == 2)
    }

    @Test func failedUpgradeDoesNotMutateState() {
        let original = KingdomGameState(gold: 9)
        var state = original

        let result = state.upgradeNormalSoldier()

        #expect(result == .insufficientGold(cost: 10, currentGold: 9))
        #expect(state == original)
    }

    @Test func upgradeIsRejectedWhenBattleIsPausedForMap() {
        let original = KingdomGameState(
            gold: 30,
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        var state = original

        _ = state.upgradeNormalSoldier()

        #expect(state == original)
    }

    @Test func idleCatchUpDealsZeroDamageWithoutBuildings() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let end = start.addingTimeInterval(5_000)
        var state = KingdomGameState(cityRemainingPower: 20)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        // No buildings → no idle damage; building-based system requires buildings to produce soldiers
        #expect(result.elapsedSeconds == 5_000)
        #expect(result.damageDealt == 0)
        #expect(result.conqueredCities == 0)
        #expect(result.goldEarned == 0)
        #expect(state.cityRemainingPower == 20)
        #expect(state.completedCityCount == 0)
        #expect(state.stageStatus == .battleActive)
        #expect(state.lastBackgroundedAt == nil)
    }

    @Test func idleCatchUpWithoutBuildingsDealsNoDamage() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let end = start.addingTimeInterval(5)
        var state = KingdomGameState(cityRemainingPower: 20)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        // No buildings → no idle damage
        #expect(result.elapsedSeconds == 5)
        #expect(result.damageDealt == 0)
        #expect(result.conqueredCities == 0)
        #expect(state.cityRemainingPower == 20)
        #expect(state.stageStatus == .battleActive)
        #expect(state.lastBackgroundedAt == nil)
    }

    @Test func buildingIdleDamageUsesSlowerBuildingProductionAndPreservesPartialProgress() {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        let end = start.addingTimeInterval(100)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 50)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result.elapsedSeconds == 100)
        #expect(result.damageDealt == 1)
        #expect(result.conqueredCities == 0)
        #expect(state.cityRemainingPower == 49)
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.spawnTimerElapsed == 0)
    }

    @Test func idleDamageUsesCurrentCityDefenseTraitCounters() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let end = start.addingTimeInterval(1_000)
        var state = KingdomGameState(
            gold: 500,
            cityRemainingPower: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 11,
            completedCityCount: 10
        )

        #expect(state.buildBuilding(.siegeWorkshop, inSlot: 1, at: start) == .built(cost: 55, remainingGold: 445))
        #expect(state.upgradeBuilding(inSlot: 1, at: start) == .upgraded(cost: 42, newLevel: 2, remainingGold: 403))
        #expect(state.upgradeBuilding(inSlot: 1, at: start) == .upgraded(cost: 69, newLevel: 3, remainingGold: 334))
        state.enterBackground(at: start)

        let result = state.returnFromBackground(at: end)

        #expect(state.currentCityDefenseTrait == .reinforcedKeep)
        #expect(result.elapsedSeconds == 1000)
        #expect(result.damageDealt == 15)
        #expect(state.cityRemainingPower == 85)
    }

    @Test func idleDamagePenaltyStillDealsAtLeastOneWhenBaseDamageIsPositive() {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        let end = start.addingTimeInterval(1_000)
        var state = KingdomGameState(
            gold: 500,
            cityRemainingPower: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 11,
            completedCityCount: 10
        )

        #expect(state.buildBuilding(.archeryRange, inSlot: 1, at: start) == .built(cost: 18, remainingGold: 482))
        state.enterBackground(at: start)

        let result = state.returnFromBackground(at: end)

        #expect(state.currentCityDefenseTrait == .reinforcedKeep)
        #expect(result.damageDealt > 0)
    }

    @Test func idleCatchUpDoesNothingWhenBattleIsPausedForMap() {
        let start = Date(timeIntervalSinceReferenceDate: 2_500)
        let end = start.addingTimeInterval(80)
        var state = KingdomGameState(gold: 0, cityRemainingPower: 1)

        _ = state.applyLiveCombatDamage(1)
        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result == .none)
        #expect(state.lastBackgroundedAt == nil)
        #expect(state.gold == 8)
        #expect(state.cityRemainingPower == 0)
        #expect(state.completedCityCount == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func idleCatchUpDoesNothingWhenCountryIsComplete() {
        let start = Date(timeIntervalSinceReferenceDate: 2_600)
        let end = start.addingTimeInterval(80)
        var state = KingdomGameState(
            gold: 100,
            cityLevel: 15,
            cityRemainingPower: 0,
            countryNumber: 1,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result == .none)
        #expect(state.lastBackgroundedAt == nil)
        #expect(state.gold == 100)
        #expect(state.completedCityCount == 15)
        #expect(state.cityRemainingPower == 0)
        #expect(state.stageStatus == .countryComplete)
    }

    @Test func buildingIdleDamageCanConquerCurrentCity() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        let end = start.addingTimeInterval(1_000)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 2)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        #expect(state.buildBuilding(.barracks, inSlot: 2, at: start) == .built(cost: 15, remainingGold: 70))

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result.elapsedSeconds == 1_000)
        #expect(result.damageDealt == 2)
        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == 8)
        #expect(state.cityRemainingPower == 0)
        #expect(state.completedCityCount == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 1)).occupiedSlotCount == 0)
    }

    @Test func activeBuildingSpawnsAdvanceTimersAndEmitSpawnEvents() {
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 30,
            cityNumberInCountry: 2,
            completedCityCount: 1
        )
        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 85))
        #expect(state.buildBuilding(.archeryRange, inSlot: 2) == .built(cost: 18, remainingGold: 67))

        let firstTick = state.resolveActiveBuildingSpawns(deltaTime: 9.9)
        #expect(firstTick.isEmpty)

        let secondTick = state.resolveActiveBuildingSpawns(deltaTime: 0.1)
        #expect(secondTick == [BuildingSpawn(soldierType: .infantry, level: 1, sourceSlot: 1)])

        let thirdTick = state.resolveActiveBuildingSpawns(deltaTime: 2.0)
        #expect(thirdTick == [BuildingSpawn(soldierType: .archer, level: 1, sourceSlot: 2)])
    }

    @Test func activeBuildingSpawnsDoNotPersistEmptyCityStateWithoutBuildings() {
        var state = KingdomGameState(cityRemainingPower: 30)

        let spawns = state.resolveActiveBuildingSpawns(deltaTime: 10)

        #expect(spawns.isEmpty)
        #expect(state.cityBattleStates.isEmpty)
    }

    @Test func activeBuildingSpawnsClampLargeDeltaToBoundSpawnWork() {
        var state = KingdomGameState(gold: 100, cityRemainingPower: 30)
        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 85))

        let spawns = state.resolveActiveBuildingSpawns(deltaTime: 600)

        #expect(spawns == [
            BuildingSpawn(soldierType: .infantry, level: 1, sourceSlot: 1),
            BuildingSpawn(soldierType: .infantry, level: 1, sourceSlot: 1),
            BuildingSpawn(soldierType: .infantry, level: 1, sourceSlot: 1),
            BuildingSpawn(soldierType: .infantry, level: 1, sourceSlot: 1),
            BuildingSpawn(soldierType: .infantry, level: 1, sourceSlot: 1),
            BuildingSpawn(soldierType: .infantry, level: 1, sourceSlot: 1)
        ])
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.spawnTimerElapsed == 0)
    }

    @Test func activeBuildingSpawnsProduceWorkAtExactCapBoundary() {
        var state = KingdomGameState(gold: 100, cityRemainingPower: 30)
        #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 85))

        // Exactly 60s (the cap) should still produce spawns, not drop them.
        let spawns = state.resolveActiveBuildingSpawns(deltaTime: 60)

        #expect(spawns.count == 6)
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.spawnTimerElapsed == 0)
    }

    @Test func idleCatchUpCannotBeAppliedTwice() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        let end = start.addingTimeInterval(5)
        var state = KingdomGameState(cityRemainingPower: 20)

        state.enterBackground(at: start)
        _ = state.returnFromBackground(at: end)
        let secondResult = state.returnFromBackground(at: end.addingTimeInterval(5))

        // Second call has no backgroundedAt (cleared by first call)
        #expect(secondResult == .none)
        // First call dealt zero damage (no buildings)
        #expect(state.cityRemainingPower == 20)
    }

    @Test func buildingIdleCatchUpCannotBeAppliedTwiceWithoutFreshBackgroundSignal() {
        let start = Date(timeIntervalSinceReferenceDate: 3_100)
        let firstEnd = start.addingTimeInterval(100)
        let secondEnd = firstEnd.addingTimeInterval(50)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 20)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))

        state.enterBackground(at: start)
        let firstResult = state.returnFromBackground(at: firstEnd)
        let secondResult = state.returnFromBackground(at: secondEnd)

        #expect(firstResult.damageDealt == 1)
        #expect(secondResult == .none)
        #expect(state.cityRemainingPower == 19)
        #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.spawnTimerElapsed == 0)
    }

    @Test func idleCatchUpIsCappedAtEightHours() {
        let start = Date(timeIntervalSinceReferenceDate: 4_000)
        let end = start.addingTimeInterval(Double(KingdomGameState.maxIdleCatchUpSeconds + 120))
        var state = KingdomGameState(gold: 100, cityRemainingPower: 30_000)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result.elapsedSeconds == KingdomGameState.maxIdleCatchUpSeconds)
        #expect(result.damageDealt == KingdomGameState.maxIdleCatchUpSeconds / 100)
    }

    @Test func idleCatchUpIsCappedAtEightHoursWithoutBuildings() {
        let start = Date(timeIntervalSinceReferenceDate: 4_000)
        let end = start.addingTimeInterval(Double(KingdomGameState.maxIdleCatchUpSeconds + 120))
        var state = KingdomGameState(cityRemainingPower: 30_000)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        // No buildings → zero idle damage; elapsed is still capped
        #expect(result.elapsedSeconds == KingdomGameState.maxIdleCatchUpSeconds)
        #expect(result.damageDealt == 0)
        #expect(state.cityRemainingPower == 30_000)
    }

    @Test func idleCatchUpFromBuildingViewPreservesEntireIdlePeriod() {
        // Simulates: enter building view at T0, background at T5, foreground at T6
        // The idle catch-up should cover T0→T6, not just T5→T6
        let t0 = Date(timeIntervalSinceReferenceDate: 5_000)
        let t5 = t0.addingTimeInterval(500)
        let t6 = t5.addingTimeInterval(60)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 10_000)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: t0) == .built(cost: 15, remainingGold: 85))

        // BattleScene calls markCurrentCityBuildingProgressInactive when entering building view
        state.enterBackground(at: t0)

        // Building view backgrounds — with the fix, just save (don't call enterBackground again)
        // so lastBackgroundedAt stays at t0

        // Foreground resolves from t0 to t6 = 560 seconds idle
        let result = state.returnFromBackground(at: t6)

        #expect(result.elapsedSeconds == 560)
        // 560s idle / 10 scale = 56s effective active = 5 spawns at level 1 = 5 damage
        #expect(result.damageDealt == 5)
        #expect(state.cityRemainingPower == 10_000 - 5)
    }

    @Test func newBuildingDoesNotGetBackdatedIdleProgress() {
        // Build first building at T0, then build second building at T5
        // The second building should only get progress from T5 onward
        let t0 = Date(timeIntervalSinceReferenceDate: 6_000)
        let t5 = t0.addingTimeInterval(500)
        let t10 = t5.addingTimeInterval(500)
        var state = KingdomGameState(
            gold: 200,
            cityRemainingPower: 10_000,
            cityNumberInCountry: 2,
            completedCityCount: 1
        )

        #expect(state.buildBuilding(.barracks, inSlot: 1, at: t0) == .built(cost: 15, remainingGold: 185))
        state.enterBackground(at: t0)

        // Build a second building at T5 — settle should resolve first building's progress
        #expect(state.buildBuilding(.archeryRange, inSlot: 2, at: t5) == .built(cost: 18, remainingGold: 167))

        // Now resolve the remaining idle time (T5 → T10 = 500s)
        let result = state.returnFromBackground(at: t10)

        // From T5→T10: 500s idle / 10 = 50s effective active
        // barracks (10s interval) = 5 spawns at level 1 = 5 damage
        // archeryRange (12s interval) = 4 spawns at level 1 = 4 damage
        // Total from this window = 9 damage
        let archeryDamage = 4
        let barracksDamage = 5
        let settleDamage = 5  // From T0→T5 settle: 500s/10 = 50s effective, barracks = 5 spawns
        #expect(result.damageDealt == archeryDamage + barracksDamage)
        #expect(state.cityRemainingPower == 10_000 - settleDamage - result.damageDealt)
    }

    @Test func buildingSettlementConquestDoesNotRestoreCompletedCityLots() {
        let past = Date(timeIntervalSinceReferenceDate: 1_000)
        let now = past.addingTimeInterval(100)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 1)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: past) == .built(cost: 15, remainingGold: 85))

        // Building a second slot settles 100s of progress → 1 damage → conquers city
        let result = state.buildBuilding(.barracks, inSlot: 2, at: now)

        #expect(result == .cityConqueredDuringSettlement(goldEarned: 8, remainingGold: 85 + 8))
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.cityBattleStates[state.currentCityKey.storageKey] == nil)
        #expect(state.gold == 85 + 8) // remaining gold + level 1 conquest reward
    }

    @Test func upgradeSettlementConquestDoesNotRestoreCompletedCityLots() {
        let past = Date(timeIntervalSinceReferenceDate: 1_000)
        let now = past.addingTimeInterval(100)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 1)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: past) == .built(cost: 15, remainingGold: 85))

        // Upgrading settles 100s of progress → 1 damage → conquers city
        let result = state.upgradeBuilding(inSlot: 1, at: now)

        #expect(result == .cityConqueredDuringSettlement(goldEarned: 8, remainingGold: 85 + 8))
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.cityBattleStates[state.currentCityKey.storageKey] == nil)
        #expect(state.gold == 85 + 8)
    }
}
