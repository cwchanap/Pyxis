//
//  GameplayTabBarNodeTests.swift
//  PyxisTests
//

import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

func brightestImageRGBSum(_ image: UIImage?) -> Int {
    guard let image = image?.cgImage,
          let data = image.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data) else {
        return 0
    }

    let bytesPerPixel = image.bitsPerPixel / 8
    guard bytesPerPixel >= 3 else { return 0 }
    var brightest = 0
    for yPosition in 0..<image.height {
        for xPosition in 0..<image.width {
            let offset = yPosition * image.bytesPerRow + xPosition * bytesPerPixel
            brightest = max(
                brightest,
                Int(bytes[offset]) + Int(bytes[offset + 1]) + Int(bytes[offset + 2])
            )
        }
    }
    return brightest
}

@MainActor
struct GameplayTabBarNodeTests {
    @Test func battleTabUsesRenderableGlyph() {
        let node = GameplayTabBarNode()

        #expect(node.iconIsVectorGlyphForTesting(for: .battle))
        #expect(!node.iconIsVectorGlyphForTesting(for: .camp))
        #expect(!node.iconIsVectorGlyphForTesting(for: .map))
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

    @Test func forgedSystemIconsUseSourceTintForDarkBackdropContrast() {
        let node = GameplayTabBarNode(appearance: .forged)

        node.apply(
            content: .init(
                selected: .battle,
                enabledTabs: Set(GameplayTab.allCases),
                showsCampAttention: false
            ),
            frame: CGRect(x: 0, y: 0, width: 300, height: 72)
        )

        #expect(node.iconColorBlendFactorForTesting(for: .camp) == 0)
        #expect(node.iconColorBlendFactorForTesting(for: .map) == 0)
        #expect(brightestImageRGBSum(gameUISymbolImage(
            named: "house.fill",
            color: SKColor(red: 1, green: 232 / 255, blue: 196 / 255, alpha: 1)
        )) > 600)
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
