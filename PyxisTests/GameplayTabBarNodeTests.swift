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
    @Test func battleTabUsesRenderableGlyph() {
        let node = GameplayTabBarNode()

        #expect(node.iconIsVectorGlyphForTesting(for: .battle))
        #expect(node.iconIsVectorGlyphForTesting(for: .camp))
        #expect(node.iconIsVectorGlyphForTesting(for: .map))
        #expect(node.iconSizeForTesting(for: .camp) == CGSize(width: 25, height: 25))
        #expect(node.iconSizeForTesting(for: .map) == CGSize(width: 25, height: 25))
    }

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

    @Test func forgedTabsUseOutlineGlyphsForDarkBackdropContrast() {
        let node = GameplayTabBarNode(appearance: .forged)

        node.apply(
            content: .init(
                selected: .battle,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: CGRect(x: 0, y: 0, width: 300, height: 72)
        )

        #expect(node.iconIsVectorGlyphForTesting(for: .battle))
        #expect(node.iconIsVectorGlyphForTesting(for: .camp))
        #expect(node.iconIsVectorGlyphForTesting(for: .map))
    }

    @Test func forgedSelectedTabUsesReferenceTileInsideTheEightyTwoPointShell() throws {
        let node = GameplayTabBarNode(appearance: .forged)
        node.apply(
            content: .init(
                selected: .battle,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: CGRect(x: 16, y: 0, width: 361, height: 82)
        )

        let selected = try #require(
            node.childNode(withName: "//gameplayTabPanel-battle") as? PanelNode
        )
        #expect(selected.contentSizeForTesting == CGSize(width: 96, height: 52))
        #expect(node.hitFrameForTesting(for: .battle)?.width ?? 0 >= 44)
        #expect(node.hitFrameForTesting(for: .battle)?.height ?? 0 >= 44)
    }
}
