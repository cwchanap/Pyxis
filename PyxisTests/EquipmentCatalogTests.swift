//
//  EquipmentCatalogTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct EquipmentCatalogTests {
    /// One authored row transcribed verbatim from the HPA-671 design
    /// spec ("Authored catalog — one item per city").
    private struct AuthoredRow: Equatable {
        let city: Int
        let id: String
        let type: SoldierType
        let effect: EquipmentEffect
    }

    private static let authoredRows: [AuthoredRow] = [
        AuthoredRow(city: 1, id: "c01-infantry-attack", type: .infantry, effect: .attackBonus(0.15)),
        AuthoredRow(city: 2, id: "c02-archer-attack", type: .archer, effect: .attackBonus(0.15)),
        AuthoredRow(city: 3, id: "c03-infantry-toughness", type: .infantry, effect: .maxHPBonus(0.25)),
        AuthoredRow(
            city: 4,
            id: "c04-archer-tower",
            type: .archer,
            effect: .specialistBonus(target: .arrowTower, fraction: 0.40)
        ),
        AuthoredRow(city: 5, id: "c05-cavalry-attack", type: .cavalry, effect: .attackBonus(0.15)),
        AuthoredRow(
            city: 6,
            id: "c06-infantry-gate",
            type: .infantry,
            effect: .specialistBonus(target: .gate, fraction: 0.40)
        ),
        AuthoredRow(city: 7, id: "c07-cavalry-toughness", type: .cavalry, effect: .maxHPBonus(0.25)),
        AuthoredRow(city: 8, id: "c08-mage-attack", type: .mage, effect: .attackBonus(0.15)),
        AuthoredRow(city: 9, id: "c09-archer-toughness", type: .archer, effect: .maxHPBonus(0.25)),
        AuthoredRow(
            city: 10,
            id: "c10-cavalry-barracks",
            type: .cavalry,
            effect: .specialistBonus(target: .barracks, fraction: 0.40)
        ),
        AuthoredRow(city: 11, id: "c11-siege-attack", type: .siege, effect: .attackBonus(0.15)),
        AuthoredRow(
            city: 12,
            id: "c12-mage-barracks",
            type: .mage,
            effect: .specialistBonus(target: .barracks, fraction: 0.40)
        ),
        AuthoredRow(city: 13, id: "c13-siege-toughness", type: .siege, effect: .maxHPBonus(0.25)),
        AuthoredRow(city: 14, id: "c14-mage-toughness", type: .mage, effect: .maxHPBonus(0.25)),
        AuthoredRow(
            city: 15,
            id: "c15-siege-keep",
            type: .siege,
            effect: .specialistBonus(target: .keep, fraction: 0.40)
        )
    ]

    @Test func catalogMatchesTheAuthoredTableExactly() throws {
        #expect(EquipmentCatalog.items.count == 15)
        #expect(EquipmentCatalog.items.map(\.cityNumber) == Array(1...15))
        #expect(Set(EquipmentCatalog.items.map(\.id)).count == 15)

        for row in Self.authoredRows {
            let item = try #require(EquipmentCatalog.byCity(row.city))
            #expect(item.id == row.id)
            #expect(item.soldierType == row.type)
            #expect(item.effect == row.effect)
            #expect(EquipmentCatalog.byID(row.id) == item)
        }
    }

    @Test func everyTypeOwnsExactlyOneAttackToughnessAndSpecialistItem() {
        for soldierType in SoldierType.allCases {
            let typeItems = EquipmentCatalog.forType(soldierType)
            #expect(typeItems.count == 3)

            var kinds: Set<Int> = []
            for item in typeItems {
                switch item.effect {
                case .attackBonus: kinds.insert(0)
                case .maxHPBonus: kinds.insert(1)
                case .specialistBonus: kinds.insert(2)
                }
            }
            #expect(kinds == [0, 1, 2])
        }
    }

    @Test func dropsNeverPrecedeTheirSoldierTypesBuildingUnlock() throws {
        let unlockCityByType: [SoldierType: Int] = try #require(
            Dictionary(
                uniqueKeysWithValues: BuildingType.allCases.map {
                    ($0.soldierType, KingdomGameState.unlockCity(for: $0))
                }
            )
        )

        for item in EquipmentCatalog.items {
            #expect(item.cityNumber >= unlockCityByType[item.soldierType, default: .max])
        }
    }

    @Test func lookupsResolveCityIDAndTypeInCityOrder() {
        #expect(EquipmentCatalog.byCity(0) == nil)
        #expect(EquipmentCatalog.byCity(16) == nil)
        #expect(EquipmentCatalog.byID("not-a-catalog-item") == nil)
        #expect(EquipmentCatalog.forType(.infantry).map(\.cityNumber) == [1, 3, 6])
        #expect(EquipmentCatalog.forType(.archer).map(\.cityNumber) == [2, 4, 9])
        #expect(EquipmentCatalog.forType(.cavalry).map(\.cityNumber) == [5, 7, 10])
        #expect(EquipmentCatalog.forType(.mage).map(\.cityNumber) == [8, 12, 14])
        #expect(EquipmentCatalog.forType(.siege).map(\.cityNumber) == [11, 13, 15])
    }

    @Test func namesAndFlavorAreAuthoredNotDerivedFromSlugs() {
        #expect(Set(EquipmentCatalog.items.map(\.name)).count == 15)
        for item in EquipmentCatalog.items {
            #expect(!item.name.isEmpty)
            #expect(!item.flavorText.isEmpty)
        }
    }
}
