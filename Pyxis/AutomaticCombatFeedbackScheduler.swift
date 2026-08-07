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
    private static let attackOrder: [GameplaySoundID] = [
        .attackSiege,
        .attackRanged,
        .attackMelee
    ]

    private var lastGlobalOutputAt: TimeInterval?
    private var lastMeleeAttackAt: TimeInterval?
    private var lastRangedAttackAt: TimeInterval?
    private var lastSiegeAttackAt: TimeInterval?
    private var lastTowerFireAt: TimeInterval?
    private var lastHitDeathAt: TimeInterval?
    private var attackSkippedEligibleWindows = 0
    private var lastPlayedAttackSound: GameplaySoundID?

    mutating func selectSound(
        from result: BattleCombatState.TickResult,
        at now: TimeInterval
    ) -> GameplaySoundID? {
        guard isOpen(lastGlobalOutputAt, interval: Self.globalInterval, at: now) else {
            return nil
        }

        let eligibleSounds = candidates(from: result).filter { sound in
            guard let gate = gate(for: sound) else {
                return false
            }
            return isOpen(lastTimestamp(for: gate), interval: gate.interval, at: now)
        }
        let hasEligibleAttack = eligibleSounds.contains { attackSound(for: $0) != nil }

        guard !eligibleSounds.isEmpty else {
            attackSkippedEligibleWindows = 0
            return nil
        }

        let defaultSound = eligibleSounds[0]
        let shouldSelectRotatedAttack =
            attackSkippedEligibleWindows >= 2 || attackSound(for: defaultSound) != nil
        let selectedSound = shouldSelectRotatedAttack
            ? nextEligibleAttack(in: eligibleSounds) ?? defaultSound
            : defaultSound

        if let attackSound = attackSound(for: selectedSound) {
            attackSkippedEligibleWindows = 0
            lastPlayedAttackSound = attackSound
        } else if hasEligibleAttack {
            attackSkippedEligibleWindows += 1
        } else {
            attackSkippedEligibleWindows = 0
        }

        lastGlobalOutputAt = now
        recordSelection(selectedSound, at: now)
        return selectedSound
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

    private func gate(for sound: GameplaySoundID) -> Gate? {
        switch sound {
        case .attackMelee: .melee
        case .attackRanged: .ranged
        case .attackSiege: .siege
        case .towerFire:
            .tower
        case .soldierHit, .soldierDeath: .hitDeath
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

    private func attackSound(for sound: GameplaySoundID) -> GameplaySoundID? {
        guard Self.attackOrder.contains(sound) else {
            return nil
        }
        return sound
    }

    private func nextEligibleAttack(
        in eligibleSounds: [GameplaySoundID]
    ) -> GameplaySoundID? {
        let startIndex: Int
        if let lastPlayedAttackSound,
           let lastIndex = Self.attackOrder.firstIndex(of: lastPlayedAttackSound) {
            startIndex = (lastIndex + 1) % Self.attackOrder.count
        } else {
            startIndex = 0
        }

        for offset in Self.attackOrder.indices {
            let sound = Self.attackOrder[(startIndex + offset) % Self.attackOrder.count]
            if let eligibleSound = eligibleSounds.first(where: { attackSound(for: $0) == sound }) {
                return eligibleSound
            }
        }
        return nil
    }

    private mutating func recordSelection(_ sound: GameplaySoundID, at now: TimeInterval) {
        guard let gate = gate(for: sound) else {
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

    private func candidates(from result: BattleCombatState.TickResult) -> [GameplaySoundID] {
        let killed = Set(result.soldierLosses.map(\.soldierID))
        let hasNonfatalHit = result.damagedSoldierIDs.contains { !killed.contains($0) }
        let attacks = Set(result.soldierAttacks.map { attackSound(for: $0.type) })

        var sounds: [GameplaySoundID] = []
        if !result.soldierLosses.isEmpty { sounds.append(.soldierDeath) }
        if !result.towerShots.isEmpty { sounds.append(.towerFire) }
        if attacks.contains(.attackSiege) { sounds.append(.attackSiege) }
        if attacks.contains(.attackRanged) { sounds.append(.attackRanged) }
        if attacks.contains(.attackMelee) { sounds.append(.attackMelee) }
        if hasNonfatalHit { sounds.append(.soldierHit) }
        return sounds
    }

    private func attackSound(for type: SoldierType) -> GameplaySoundID {
        switch type {
        case .infantry, .cavalry:
            .attackMelee
        case .archer, .mage:
            .attackRanged
        case .siege:
            .attackSiege
        }
    }
}
