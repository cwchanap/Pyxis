//
//  SplitMix64.swift
//  Pyxis
//

import Foundation

/// Seedable, Equatable PRNG so `BattleCombatState` stays a deterministic value type.
struct SplitMix64: RandomNumberGenerator, Equatable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
