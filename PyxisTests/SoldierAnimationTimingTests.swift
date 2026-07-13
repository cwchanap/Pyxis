import Foundation
import Testing
@testable import Pyxis

struct SoldierAnimationTimingTests {
    @Test func everyActionProvidesTenPositiveDurations() {
        for type in SoldierType.allCases {
            for action in SoldierAnimationAction.allCases {
                let durations = SoldierAnimationTiming.frameDurations(for: action, type: type)
                #expect(durations.count == 10)
                #expect(durations.allSatisfy { $0 > 0 })
            }
        }
    }

    @Test func totalsMatchApprovedPlaybackDurations() {
        let attacks: [SoldierType: TimeInterval] = [
            .infantry: 1.2, .archer: 1.4, .cavalry: 1.2, .mage: 1.4, .siege: 1.6
        ]
        for (type, expected) in attacks {
            #expect(abs(SoldierAnimationTiming.totalDuration(for: .attack, type: type) - expected) < 0.000_1)
        }
        for type in SoldierType.allCases {
            #expect(abs(SoldierAnimationTiming.totalDuration(for: .walk, type: type) - 1.0) < 0.000_1)
            #expect(abs(SoldierAnimationTiming.totalDuration(for: .hit, type: type) - 0.9) < 0.000_1)
        }
    }

    @Test func attackMovesFasterThroughContactThanAnticipation() {
        let durations = SoldierAnimationTiming.frameDurations(for: .attack, type: .archer)
        #expect(durations[2] > durations[4])
        #expect(durations[7] > durations[4])
    }

    @Test func hitHoldsPeakReactionLongerThanNeutral() {
        let durations = SoldierAnimationTiming.frameDurations(for: .hit, type: .infantry)
        #expect(durations[3] > durations[0])
        #expect(durations[4] > durations[9])
    }
}
