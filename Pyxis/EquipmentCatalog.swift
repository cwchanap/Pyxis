//
//  EquipmentCatalog.swift
//  Pyxis
//

import Foundation

/// One authored conquest-gear effect (HPA-671). Exactly one kind per item;
/// values are the authored fractions from the design table (attack +0.15,
/// max HP +0.25, specialist +0.40). Task 3 owns how combat consumes them.
enum EquipmentEffect: Equatable {
    case attackBonus(Double)
    case maxHPBonus(Double)
    case specialistBonus(target: CitySiegeLayout.ObjectiveKind, fraction: Double)

    /// The single level-scaling authority (HPA-672): the fractional bonus
    /// multiplies by exactly 1 / 1.5 / 2 at owned levels 1 / 2 / 3, with the
    /// kind and target preserved. Every combat projection, the Armory text
    /// and the campaign scorer consume this — never a raw catalog fraction
    /// once an item can be leveled. Out-of-range levels clamp to the band.
    func scaled(toLevel level: Int) -> EquipmentEffect {
        let clamped = min(3, max(1, level))
        let scale = [1: 1.0, 2: 1.5, 3: 2.0][clamped, default: 1.0]
        switch self {
        case .attackBonus(let fraction):
            return .attackBonus(fraction * scale)
        case .maxHPBonus(let fraction):
            return .maxHPBonus(fraction * scale)
        case .specialistBonus(let target, let fraction):
            return .specialistBonus(target: target, fraction: fraction * scale)
        }
    }
}

/// A compile-time catalog row: stable slug `id` (also the HPA-673 art name
/// contract), its Country 1 city, soldier type, and authored name/flavor.
/// Names and flavor never enter the save (HPA-671).
struct EquipmentItem: Equatable {
    let id: String
    let cityNumber: Int
    let soldierType: SoldierType
    let name: String
    let flavorText: String
    let effect: EquipmentEffect
}

/// The single authored source of Country 1 conquest gear: one fixed item
/// per City 1–15, three per soldier type (attack / toughness / specialist).
/// Pure compile-time table plus lookups — no loot service, no buff registry.
enum EquipmentCatalog {
    static let items: [EquipmentItem] = [
        EquipmentItem(
            id: "c01-infantry-attack",
            cityNumber: 1,
            soldierType: .infantry,
            name: "Willowford Blade",
            flavorText: "A riverside smith's first clean edge.",
            effect: .attackBonus(0.15)
        ),
        EquipmentItem(
            id: "c02-archer-attack",
            cityNumber: 2,
            soldierType: .archer,
            name: "Pinewatch Longbow",
            flavorText: "Cut from heartwood that remembers the watch fires.",
            effect: .attackBonus(0.15)
        ),
        EquipmentItem(
            id: "c03-infantry-toughness",
            cityNumber: 3,
            soldierType: .infantry,
            name: "Falconridge Bulwark",
            flavorText: "Ridge-iron plate that shrugs off falling arrows.",
            effect: .maxHPBonus(0.25)
        ),
        EquipmentItem(
            id: "c04-archer-tower",
            cityNumber: 4,
            soldierType: .archer,
            name: "Bramblegate Broadhead",
            flavorText: "Forged to split the timber of a tower's spine.",
            effect: .specialistBonus(target: .arrowTower, fraction: 0.40)
        ),
        EquipmentItem(
            id: "c05-cavalry-attack",
            cityNumber: 5,
            soldierType: .cavalry,
            name: "Highcrest Lance",
            flavorText: "Carried down the crest at the first full charge.",
            effect: .attackBonus(0.15)
        ),
        EquipmentItem(
            id: "c06-infantry-gate",
            cityNumber: 6,
            soldierType: .infantry,
            name: "Granite Ram",
            flavorText: "Pass-quarried weight that answers any gate.",
            effect: .specialistBonus(target: .gate, fraction: 0.40)
        ),
        EquipmentItem(
            id: "c07-cavalry-toughness",
            cityNumber: 7,
            soldierType: .cavalry,
            name: "Emberford Barding",
            flavorText: "Cured over forge coals until it stopped burning.",
            effect: .maxHPBonus(0.25)
        ),
        EquipmentItem(
            id: "c08-mage-attack",
            cityNumber: 8,
            soldierType: .mage,
            name: "Greywall Focus",
            flavorText: "A cold lens that straightens every spell line.",
            effect: .attackBonus(0.15)
        ),
        EquipmentItem(
            id: "c09-archer-toughness",
            cityNumber: 9,
            soldierType: .archer,
            name: "Runewatch Guard",
            flavorText: "Arrow-proof weave stitched with watch runes.",
            effect: .maxHPBonus(0.25)
        ),
        EquipmentItem(
            id: "c10-cavalry-barracks",
            cityNumber: 10,
            soldierType: .cavalry,
            name: "Ironthorn Hammer",
            flavorText: "Swung once at Ironthorn; barracks remember it.",
            effect: .specialistBonus(target: .barracks, fraction: 0.40)
        ),
        EquipmentItem(
            id: "c11-siege-attack",
            cityNumber: 11,
            soldierType: .siege,
            name: "Kingshield Ramhead",
            flavorText: "Cast for the keep that never expected a second try.",
            effect: .attackBonus(0.15)
        ),
        EquipmentItem(
            id: "c12-mage-barracks",
            cityNumber: 12,
            soldierType: .mage,
            name: "Ashbridge Cinders",
            flavorText: "Bridge-ash that finds the barracks beams.",
            effect: .specialistBonus(target: .barracks, fraction: 0.40)
        ),
        EquipmentItem(
            id: "c13-siege-toughness",
            cityNumber: 13,
            soldierType: .siege,
            name: "Starveil Plating",
            flavorText: "Night-quenched iron that outlasts the citadel's shadow.",
            effect: .maxHPBonus(0.25)
        ),
        EquipmentItem(
            id: "c14-mage-toughness",
            cityNumber: 14,
            soldierType: .mage,
            name: "Stonecrown Ward",
            flavorText: "Crowned stone that turns the tower's gaze aside.",
            effect: .maxHPBonus(0.25)
        ),
        EquipmentItem(
            id: "c15-siege-keep",
            cityNumber: 15,
            soldierType: .siege,
            name: "Crownspire Breaker",
            flavorText: "The last engine, aimed at the last wall.",
            effect: .specialistBonus(target: .keep, fraction: 0.40)
        )
    ]

    /// Country 1 city → its fixed drop. Cities outside 1–15 → nil.
    static func byCity(_ cityNumber: Int) -> EquipmentItem? {
        items.first { $0.cityNumber == cityNumber }
    }

    static func byID(_ id: String) -> EquipmentItem? {
        items.first { $0.id == id }
    }

    /// The Armory's stable per-type cycle order: the catalog table
    /// restricted to one soldier type, in city order (HPA-671).
    static func forType(_ soldierType: SoldierType) -> [EquipmentItem] {
        items.filter { $0.soldierType == soldierType }
    }
}

/// Explicit equip/unequip outcome (HPA-671). Callers save only on
/// `.success`; `.rejected` (unknown/unowned item, missing slot) and
/// `.unchanged` (no-op) never mutate state.
enum EquipmentMutationResult: Equatable {
    case success
    case rejected
    case unchanged
}
