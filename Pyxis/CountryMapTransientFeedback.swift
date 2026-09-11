//
//  CountryMapTransientFeedback.swift
//  Pyxis
//

import CoreGraphics
import Foundation

struct CountryMapTransientFeedback: Equatable {
    enum Kind: Equatable {
        case locked
        case completed
        case status
        case recoverableError
        case flavor
        case idleSummary

        /// `false` only for `.flavor` and `.idleSummary`, which overlay the
        /// Scout card without blocking Attack or scout entry. All other kinds
        /// block both.
        var blocksScoutEntry: Bool {
            self != .flavor && self != .idleSummary
        }
    }

    let kind: Kind
    let text: String
    let totalDuration: TimeInterval
    let fadeDuration: TimeInterval
    private(set) var elapsed: TimeInterval = 0

    var alpha: CGFloat {
        let fadeStart = totalDuration - fadeDuration
        guard elapsed > fadeStart else { return 1 }
        return max(0, CGFloat((totalDuration - elapsed) / fadeDuration))
    }

    var isFinished: Bool {
        elapsed >= totalDuration
    }

    mutating func advance(by deltaTime: TimeInterval) {
        elapsed = min(totalDuration, elapsed + max(0, deltaTime))
    }

    static func locked(cityNumber: Int) -> Self {
        .init(
            kind: .locked,
            text: "\(Country1CityCatalog.definition(for: cityNumber).name) is locked",
            totalDuration: 1.5,
            fadeDuration: 0.3
        )
    }

    static func completed(cityNumber: Int) -> Self {
        .init(
            kind: .completed,
            text: "\(Country1CityCatalog.definition(for: cityNumber).name) complete",
            totalDuration: 1.5,
            fadeDuration: 0.3
        )
    }

    static func status(_ text: String) -> Self {
        .init(
            kind: .status,
            text: text,
            totalDuration: 2.5,
            fadeDuration: 0.3
        )
    }

    static func recoverableError(_ text: String) -> Self {
        .init(
            kind: .recoverableError,
            text: text,
            totalDuration: 2.5,
            fadeDuration: 0.3
        )
    }

    /// Non-blocking Scout card flavor text. Uses the same 2.5s timing as
    /// `status`/`recoverableError` but overlays only the informational area
    /// (via `nonBlockingOverlayFrame`), leaving the Attack target live.
    static func flavor(_ text: String) -> Self {
        .init(
            kind: .flavor,
            text: text,
            totalDuration: 2.5,
            fadeDuration: 0.3
        )
    }

    /// Compact non-blocking summary for a credited, non-conquest idle return
    /// with positive damage. Returns `nil` otherwise: conquest results render
    /// their own map copy, and zero-elapsed or zero-damage returns must stay
    /// silent (the scene clears stale feedback instead of showing a message).
    /// `state` is retained for call-site stability in this PR.
    static func idle(
        result: KingdomGameState.IdleProgressResult,
        state: KingdomGameState
    ) -> Self? {
        guard result.elapsedSeconds > 0,
              result.damageDealt > 0,
              result.conqueredCities == 0 else { return nil }

        return .init(
            kind: .idleSummary,
            text: "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage.",
            totalDuration: 2.5,
            fadeDuration: 0.3
        )
    }

    static func cannotEnterCityYet() -> Self {
        recoverableError("Cannot enter city yet.")
    }
}
