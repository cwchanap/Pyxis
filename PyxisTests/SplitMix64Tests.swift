//
//  SplitMix64Tests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct SplitMix64Tests {
    @Test func sameSeedProducesSameSequence() {
        var first = SplitMix64(seed: 42)
        var second = SplitMix64(seed: 42)

        for _ in 0..<10 {
            #expect(first.next() == second.next())
        }
    }

    @Test func differentSeedsProduceDifferentSequences() {
        var first = SplitMix64(seed: 1)
        var second = SplitMix64(seed: 2)

        #expect(first.next() != second.next())
    }

    @Test func generatorsWithSameSeedAndAdvancementAreEqual() {
        var first = SplitMix64(seed: 7)
        var second = SplitMix64(seed: 7)

        #expect(first == second)

        _ = first.next()
        #expect(first != second)

        _ = second.next()
        #expect(first == second)
    }
}
