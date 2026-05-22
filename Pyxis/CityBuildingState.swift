//
//  CityBuildingState.swift
//  Pyxis
//

import Foundation

struct CityKey: Equatable, Hashable {
    let countryNumber: Int
    let cityNumber: Int

    init(countryNumber: Int, cityNumber: Int) {
        self.countryNumber = max(1, countryNumber)
        self.cityNumber = min(max(1, cityNumber), KingdomGameState.firstCountryCityCount)
    }

    init?(storageKey: String) {
        let parts = storageKey.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let countryNumber = Int(parts[0]),
              let cityNumber = Int(parts[1]),
              countryNumber >= 1,
              (1...KingdomGameState.firstCountryCityCount).contains(cityNumber) else {
            return nil
        }

        let canonicalStorageKey = "\(countryNumber)-\(cityNumber)"
        guard storageKey == canonicalStorageKey else {
            return nil
        }

        self.countryNumber = countryNumber
        self.cityNumber = cityNumber
    }

    var storageKey: String {
        "\(countryNumber)-\(cityNumber)"
    }
}

enum BuildingType: String, Codable, CaseIterable, Equatable {
    case barracks
    case archeryRange

    var displayName: String {
        switch self {
        case .barracks:
            return "Barracks"
        case .archeryRange:
            return "Archery Range"
        }
    }

    var soldierType: SoldierType {
        switch self {
        case .barracks:
            return .infantry
        case .archeryRange:
            return .archer
        }
    }
}

struct CityBuilding: Codable, Equatable {
    let type: BuildingType
    var level: Int
    var spawnTimerElapsed: Double

    private enum CodingKeys: String, CodingKey {
        case type
        case level
        case spawnTimerElapsed
    }

    init(type: BuildingType, level: Int = 1, spawnTimerElapsed: Double = 0) {
        self.type = type
        self.level = max(1, level)
        self.spawnTimerElapsed = max(0, spawnTimerElapsed)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            type: try container.decode(BuildingType.self, forKey: .type),
            level: try container.decodeIfPresent(Int.self, forKey: .level) ?? 1,
            spawnTimerElapsed: try container.decodeIfPresent(Double.self, forKey: .spawnTimerElapsed) ?? 0
        )
    }

    func normalized() -> CityBuilding {
        CityBuilding(type: type, level: level, spawnTimerElapsed: spawnTimerElapsed)
    }
}

struct BuildingSpawn: Equatable {
    let soldierType: SoldierType
    let level: Int
    let sourceSlot: Int
}

struct CityBattleState: Codable, Equatable {
    static let slotRange = 1...25
    static let maxBuildingsPerType = 5

    var slots: [Int: CityBuilding]
    var lastBuildingProgressResolvedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case slots
        case lastBuildingProgressResolvedAt
    }

    private struct SlotCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = Int(stringValue)
        }

        init?(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    init(slots: [Int: CityBuilding] = [:], lastBuildingProgressResolvedAt: Date? = nil) {
        self.slots = slots
        self.lastBuildingProgressResolvedAt = lastBuildingProgressResolvedAt
        normalize()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lastResolvedAt = (try? container.decodeIfPresent(Date.self, forKey: .lastBuildingProgressResolvedAt)) ?? nil
        var decodedSlots: [Int: CityBuilding] = [:]

        if let slotsContainer = try? container.nestedContainer(keyedBy: SlotCodingKey.self, forKey: .slots) {
            for key in slotsContainer.allKeys {
                guard let slot = Int(key.stringValue), key.stringValue == String(slot),
                      let building = try? slotsContainer.decode(CityBuilding.self, forKey: key) else {
                    continue
                }

                decodedSlots[slot] = building
            }
        }

        self.init(slots: decodedSlots, lastBuildingProgressResolvedAt: lastResolvedAt)
    }

    var slotCount: Int {
        Self.slotRange.count
    }

    var occupiedSlotCount: Int {
        slots.count
    }

    func building(inSlot slot: Int) -> CityBuilding? {
        slots[slot]
    }

    func buildingCount(for type: BuildingType) -> Int {
        slots.values.filter { $0.type == type }.count
    }

    mutating func setBuilding(_ building: CityBuilding, inSlot slot: Int) {
        guard Self.slotRange.contains(slot) else {
            return
        }

        slots[slot] = building
        normalize()
    }

    mutating func removeAllBuildings() {
        slots.removeAll()
        lastBuildingProgressResolvedAt = nil
    }

    mutating func normalize() {
        var normalizedSlots: [Int: CityBuilding] = [:]
        var counts: [BuildingType: Int] = [:]

        for slot in slots.keys.sorted() where Self.slotRange.contains(slot) {
            guard let building = slots[slot]?.normalized() else {
                continue
            }

            let count = counts[building.type, default: 0]
            guard count < Self.maxBuildingsPerType else {
                continue
            }

            normalizedSlots[slot] = building
            counts[building.type] = count + 1
        }

        slots = normalizedSlots
    }
}
