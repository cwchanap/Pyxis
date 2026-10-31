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

        #expect(node.visualCellCountForTesting == 4)
        #expect(node.hitFrameForTesting(for: .battle) == nil)
        #expect(node.hitFrameForTesting(for: .camp) == nil)
        #expect(node.hitFrameForTesting(for: .kingdom) == nil)

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
        // Four-tab cells (forged shell spans 361+32=393pt → 98.25pt cells)
        // shrink the selected tile from the 3-tab 96pt cap to 90.25pt; the
        // 44pt floor holds.
        #expect(selected.contentSizeForTesting == CGSize(width: 90.25, height: 52))
        #expect(node.hitFrameForTesting(for: .battle)?.width ?? 0 >= 44)
        #expect(node.hitFrameForTesting(for: .battle)?.height ?? 0 >= 44)
    }

    @Test func forgedTabsUseGradientShellMutedUnselectedTabsAndDarkSelectedTile() throws {
        let node = GameplayTabBarNode(appearance: .forged)
        node.apply(
            content: .init(
                selected: .battle,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: CGRect(x: 16, y: 0, width: 361, height: 82)
        )

        let shell = try #require(
            node.childNode(withName: "gameplayTabForgedBackdrop") as? SKShapeNode
        )
        let selected = try #require(
            node.childNode(withName: "//gameplayTabPanel-battle") as? PanelNode
        )
        let selectedPlate = try #require(
            selected.childNode(withName: "panelPlate") as? SKShapeNode
        )
        let campIcon = try #require(
            node.childNode(withName: "//gameplayTabIcon-camp") as? SKShapeNode
        )
        let campTitle = try #require(
            node.childNode(withName: "//gameplayTabTitle-camp") as? SKLabelNode
        )

        #expect(shell.fillTexture != nil)
        #expect(selectedPlate.fillTexture != nil)
        #expect(abs(campIcon.alpha - 0.45) < 0.001)
        #expect(abs(campTitle.alpha - 0.45) < 0.001)
        #expect(selectedPlate.strokeColor.cgColor.alpha < 0.8)
    }

    @Test func fourTabsEachKeepAtLeast44PointHitTargets() throws {
        let node = GameplayTabBarNode()
        let frame = CGRect(x: 0, y: 0, width: 300, height: 72)

        node.apply(
            content: .init(
                selected: .battle,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: frame
        )

        for tab in GameplayTab.allCases {
            let hitFrame = try #require(node.hitFrameForTesting(for: tab))
            #expect(hitFrame.width >= 44)
            #expect(hitFrame.height >= 44)
            #expect(node.tab(at: hitFrame.center) == tab)
        }
    }

    @Test func kingdomTabFallsBackToVectorCrownWhenAssetIsMissing() {
        let standard = GameplayTabBarNode()
        let forged = GameplayTabBarNode(appearance: .forged)

        // The real `tab-kingdom` asset has not shipped yet (HPA-673 is
        // asset-only), so the default catalog lookup misses and both
        // appearances render the shared vector crown placeholder.
        #expect(standard.iconIsVectorGlyphForTesting(for: .kingdom))
        #expect(forged.iconIsVectorGlyphForTesting(for: .kingdom))
        #expect(standard.iconSizeForTesting(for: .kingdom) == CGSize(width: 25, height: 25))
        #expect(forged.iconSizeForTesting(for: .kingdom) == CGSize(width: 18, height: 11))
    }

    @Test func kingdomTabUsesFixedSpriteSizeWhenAssetIsPresent() throws {
        let provider = GameplayTabBarNode.tabIconTextureProvider
        GameplayTabBarNode.tabIconTextureProvider = { _ in
            PanelNode.gradientTexture(top: .red, bottom: .blue)
        }
        defer {
            GameplayTabBarNode.tabIconTextureProvider = provider
        }

        let standard = GameplayTabBarNode()
        standard.apply(
            content: .init(
                selected: .map,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: CGRect(x: 0, y: 0, width: 300, height: 72)
        )
        let standardSprite = try #require(standard.iconNodeForTesting(for: .kingdom) as? SKSpriteNode)
        #expect(standardSprite.size == CGSize(width: 25, height: 25))
        #expect(standardSprite.colorBlendFactor == 0)

        let forged = GameplayTabBarNode(appearance: .forged)
        forged.apply(
            content: .init(
                selected: .kingdom,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: CGRect(x: 16, y: 0, width: 361, height: 82)
        )
        let selectedSprite = try #require(forged.iconNodeForTesting(for: .kingdom) as? SKSpriteNode)
        #expect(selectedSprite.size == CGSize(width: 18, height: 18))
        #expect(abs(selectedSprite.alpha - 1) < 0.001)
        #expect(selectedSprite.colorBlendFactor > 0)

        let forgedUnselected = GameplayTabBarNode(appearance: .forged)
        forgedUnselected.apply(
            content: .init(
                selected: .battle,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: CGRect(x: 16, y: 0, width: 361, height: 82)
        )
        let unselectedSprite = try #require(
            forgedUnselected.iconNodeForTesting(for: .kingdom) as? SKSpriteNode
        )
        #expect(unselectedSprite.size == CGSize(width: 18, height: 18))
        #expect(abs(unselectedSprite.alpha - 0.45) < 0.001)
        #expect(unselectedSprite.colorBlendFactor > 0)
    }

    @Test func spriteIconDoesNotRegressTabHitFrames() throws {
        let provider = GameplayTabBarNode.tabIconTextureProvider
        GameplayTabBarNode.tabIconTextureProvider = { _ in
            PanelNode.gradientTexture(top: .red, bottom: .blue)
        }
        defer {
            GameplayTabBarNode.tabIconTextureProvider = provider
        }

        let node = GameplayTabBarNode(appearance: .forged)
        node.apply(
            content: .init(
                selected: .kingdom,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: CGRect(x: 16, y: 0, width: 361, height: 82)
        )

        for tab in GameplayTab.allCases {
            let hitFrame = try #require(node.hitFrameForTesting(for: tab))
            #expect(hitFrame.width >= 44)
            #expect(hitFrame.height >= 44)
            #expect(node.tab(at: hitFrame.center) == tab)
        }
        #expect(node.iconNodeForTesting(for: .kingdom) is SKSpriteNode)
    }

    @Test func forgedTabsUseTheAuthoredSvgArtworkBoundsWithoutPerimeterOutlines() throws {
        let node = GameplayTabBarNode(appearance: .forged)
        node.apply(
            content: .init(
                selected: .battle,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: true
            ),
            frame: CGRect(x: 16, y: 0, width: 361, height: 82)
        )

        let shell = try #require(
            node.childNode(withName: "gameplayTabForgedBackdrop") as? SKShapeNode
        )
        let selected = try #require(
            node.childNode(withName: "//gameplayTabPanel-battle") as? PanelNode
        )
        let selectedPlate = try #require(
            selected.childNode(withName: "panelPlate") as? SKShapeNode
        )
        let selectedHighlight = try #require(
            selected.childNode(withName: "panelHighlight") as? SKShapeNode
        )

        #expect(node.iconSizeForTesting(for: .battle) == CGSize(width: 16, height: 16))
        #expect(node.iconSizeForTesting(for: .camp) == CGSize(width: 18, height: 14))
        #expect(node.iconSizeForTesting(for: .map) == CGSize(width: 18, height: 16))
        #expect(shell.strokeColor.cgColor.alpha < 0.05)
        #expect(selectedPlate.strokeColor.cgColor.alpha < 0.05)
        #expect(selectedHighlight.strokeColor.cgColor.alpha < 0.05)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
