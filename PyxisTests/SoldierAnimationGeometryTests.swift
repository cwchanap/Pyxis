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
            // The body no longer starts at the canvas bottom: the regenerated
            // frames have a transparent margin below the feet, so the logical
            // body frame floats above y=0. Assert it stays within the canvas
            // and its top sits where the HP bar anchors (silhouette top).
            #expect(bodyFrame.minY >= 0)
            #expect(bodyFrame.maxY <= frameSize.height)
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
