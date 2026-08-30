//
//  GameplayTabBarNodeTests.swift
//  PyxisTests
//

import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct GameplayTabBarNodeTests {
    @Test func disabledTabsRemainVisibleButHaveNoHitFrames() {
        let node = GameplayTabBarNode()
        let frame = CGRect(x: 0, y: 0, width: 300, height: 72)

        node.apply(
            content: .init(
                selected: .map,
                enabledTabs: [.map],
                showsCampAttention: false
            ),
            frame: frame
        )

        #expect(node.visualCellCountForTesting == 3)
        #expect(node.hitFrameForTesting(for: .battle) == nil)
        #expect(node.hitFrameForTesting(for: .camp) == nil)

        let mapFrame = node.hitFrameForTesting(for: .map)
        #expect(mapFrame?.width ?? 0 >= 44)
        #expect(mapFrame?.height ?? 0 >= 44)
        #expect(node.tab(at: CGPoint(x: mapFrame?.midX ?? 0, y: mapFrame?.midY ?? 0)) == .map)
        #expect(node.tab(at: CGPoint(x: frame.minX + frame.width / 6, y: frame.midY)) == nil)
        #expect(node.tab(at: CGPoint(x: frame.minX + frame.width / 2, y: frame.midY)) == nil)
    }
}
