//
//  AutomaticCombatFeedbackScheduler.swift
//  Pyxis
//

import Foundation

struct AutomaticCombatFeedbackScheduler {
    private enum Gate {
        case melee
        case ranged
        case siege
        case tower
        case hitDeath

        var interval: TimeInterval {
            switch self {
            case .melee, .ranged, .siege:
                0.200
            case .tower:
                0.250
            case .hitDeath:
                0.300
            }
        }
    }

    private static let globalInterval: TimeInterval = 0.150
    private static let attackOrder: [SoldierAttackSoundCategory] = [.siege, .ranged, .melee]

    private var lastGlobalOutputAt: TimeInterval?
    private var lastMeleeAttackAt: TimeInterval?
    private var lastRangedAttackAt: TimeInterval?
    private var lastSiegeAttackAt: TimeInterval?
    private var lastTowerFireAt: TimeInterval?
    private var lastHitDeathAt: TimeInterval?
    private var attackSkippedEligibleWindows = 0
    private var lastPlayedAttackCategory: SoldierAttackSoundCategory?

    mutating func select(
        from orderedEvents: [GameplayFeedbackEvent],
        at now: TimeInterval
    ) -> GameplayFeedbackEvent? {
        guard isOpen(lastGlobalOutputAt, interval: Self.globalInterval, at: now) else {
            return nil
        }

        let eligibleEvents = orderedEvents.filter { event in
            guard let gate = gate(for: event) else {
                return false
            }
            return isOpen(lastTimestamp(for: gate), interval: gate.interval, at: now)
        }
        let hasEligibleAttack = eligibleEvents.contains { attackCategory(for: $0) != nil }

        guard !eligibleEvents.isEmpty else {
            attackSkippedEligibleWindows = 0
            return nil
        }

        let defaultEvent = eligibleEvents[0]
        let shouldSelectRotatedAttack =
            attackSkippedEligibleWindows >= 2 || attackCategory(for: defaultEvent) != nil
        let selectedEvent = shouldSelectRotatedAttack
            ? nextEligibleAttack(in: eligibleEvents) ?? defaultEvent
            : defaultEvent

        if let attackCategory = attackCategory(for: selectedEvent) {
            attackSkippedEligibleWindows = 0
            lastPlayedAttackCategory = attackCategory
        } else if hasEligibleAttack {
            attackSkippedEligibleWindows += 1
        } else {
            attackSkippedEligibleWindows = 0
        }

        lastGlobalOutputAt = now
        recordSelection(selectedEvent, at: now)
        return selectedEvent
    }

    private func isOpen(
        _ lastOutputAt: TimeInterval?,
        interval: TimeInterval,
        at now: TimeInterval
    ) -> Bool {
        guard let lastOutputAt else {
            return true
        }
        return now >= lastOutputAt + interval
    }

    private func gate(for event: GameplayFeedbackEvent) -> Gate? {
        switch event {
        case .soldierAttack(.melee):
            .melee
        case .soldierAttack(.ranged):
            .ranged
        case .soldierAttack(.siege):
            .siege
        case .towerFire:
            .tower
        case .soldierDamage:
            .hitDeath
        default:
            nil
        }
    }

    private func lastTimestamp(for gate: Gate) -> TimeInterval? {
        switch gate {
        case .melee:
            lastMeleeAttackAt
        case .ranged:
            lastRangedAttackAt
        case .siege:
            lastSiegeAttackAt
        case .tower:
            lastTowerFireAt
        case .hitDeath:
            lastHitDeathAt
        }
    }

    private func attackCategory(for event: GameplayFeedbackEvent) -> SoldierAttackSoundCategory? {
        guard case let .soldierAttack(category) = event else {
            return nil
        }
        return category
    }

    private func nextEligibleAttack(
        in eligibleEvents: [GameplayFeedbackEvent]
    ) -> GameplayFeedbackEvent? {
        let startIndex: Int
        if let lastPlayedAttackCategory,
           let lastIndex = Self.attackOrder.firstIndex(of: lastPlayedAttackCategory) {
            startIndex = (lastIndex + 1) % Self.attackOrder.count
        } else {
            startIndex = 0
        }

        for offset in Self.attackOrder.indices {
            let category = Self.attackOrder[(startIndex + offset) % Self.attackOrder.count]
            if let event = eligibleEvents.first(where: { attackCategory(for: $0) == category }) {
                return event
            }
        }
        return nil
    }

    private mutating func recordSelection(_ event: GameplayFeedbackEvent, at now: TimeInterval) {
        guard let gate = gate(for: event) else {
            return
        }

        switch gate {
        case .melee:
            lastMeleeAttackAt = now
        case .ranged:
            lastRangedAttackAt = now
        case .siege:
            lastSiegeAttackAt = now
        case .tower:
            lastTowerFireAt = now
        case .hitDeath:
            lastHitDeathAt = now
        }
    }
}
