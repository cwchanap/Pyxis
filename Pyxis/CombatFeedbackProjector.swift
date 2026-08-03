//
//  CombatFeedbackProjector.swift
//  Pyxis
//

enum CombatFeedbackProjector {
    static func events(from result: BattleCombatState.TickResult) -> [GameplayFeedbackEvent] {
        let killed = Set(result.soldierLosses.map(\.soldierID))
        let hasNonfatalHit = result.damagedSoldierIDs.contains { !killed.contains($0) }
        let categories = Set(result.soldierAttacks.map { category(for: $0.type) })

        var events: [GameplayFeedbackEvent] = []

        if !result.soldierLosses.isEmpty {
            events.append(.soldierDamage(.death))
        }
        if !result.towerShots.isEmpty {
            events.append(.towerFire)
        }
        if categories.contains(.siege) {
            events.append(.soldierAttack(.siege))
        }
        if categories.contains(.ranged) {
            events.append(.soldierAttack(.ranged))
        }
        if categories.contains(.melee) {
            events.append(.soldierAttack(.melee))
        }
        if hasNonfatalHit {
            events.append(.soldierDamage(.hit))
        }

        return events
    }

    private static func category(for type: SoldierType) -> SoldierAttackSoundCategory {
        switch type {
        case .infantry, .cavalry:
            .melee
        case .archer, .mage:
            .ranged
        case .siege:
            .siege
        }
    }
}
