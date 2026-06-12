//
//  BattleLane.swift
//  Pyxis
//

import Foundation

/// One of the three vertical marching lanes on the battlefield.
/// Raw values are lane indices: left = 0, center = 1, right = 2.
enum BattleLane: Int, CaseIterable, Equatable {
    case left = 0
    case center = 1
    case right = 2
}
