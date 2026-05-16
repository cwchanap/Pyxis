//
//  GameUIComponentsTests.swift
//  PyxisTests
//

import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct GameUIComponentsTests {
    @Test func progressBarClampsFillWidthWithinBounds() {
        let bar = ProgressBarNode(size: CGSize(width: 120, height: 14))

        bar.update(progress: 1.7)
        #expect(bar.fillWidthForTesting == 120)

        bar.update(progress: -0.4)
        #expect(bar.fillWidthForTesting == 0)

        bar.update(progress: 0.25)
        #expect(bar.fillWidthForTesting == 30)
    }

    @Test func panelNodeStoresStableContentSize() {
        let panel = PanelNode(size: CGSize(width: 180, height: 72))

        #expect(panel.contentSizeForTesting == CGSize(width: 180, height: 72))

        panel.update(size: CGSize(width: 200, height: 80))

        #expect(panel.contentSizeForTesting == CGSize(width: 200, height: 80))
    }
}
