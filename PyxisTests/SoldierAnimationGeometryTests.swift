//
//  SoldierAnimationGeometryTests.swift
//  PyxisTests
//

import CoreGraphics
import Testing
@testable import Pyxis

struct SoldierAnimationGeometryTests {
    @Test func fullCanvasKeepsRequestedLogicalBodyHeightForEveryType() {
        for type in SoldierType.allCases {
            let geometry = SoldierAnimationGeometry(type: type)
            let frameSize = geometry.frameSize(forBodyHeight: 70)
            let bodyFrame = geometry.logicalBodyFrame(frameSize: frameSize)

            #expect(frameSize.width == frameSize.height)
            #expect(abs(bodyFrame.height - 70) < 0.001)
            #expect(abs(bodyFrame.minY) < 0.001)
        }
    }

    @Test func fullCanvasLeavesHorizontalRoomForWeapons() {
        let geometry = SoldierAnimationGeometry(type: .archer)
        let frameSize = geometry.frameSize(forBodyHeight: 70)
        let bodyFrame = geometry.logicalBodyFrame(frameSize: frameSize)

        #expect(frameSize.width > bodyFrame.width)
        #expect(bodyFrame.midX == 0)
    }
}
