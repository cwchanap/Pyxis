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

    @Test func progressBarPreservesRatioWhenResized() {
        let bar = ProgressBarNode(size: CGSize(width: 100, height: 14))

        bar.update(progress: 0.5)
        #expect(bar.fillWidthForTesting == 50)

        bar.update(size: CGSize(width: 200, height: 20))

        #expect(bar.fillWidthForTesting == 100)
    }

    @Test func progressBarPreservesRatioAfterZeroWidthResize() {
        let bar = ProgressBarNode(size: CGSize(width: 0, height: 14))

        bar.update(progress: 0.5)
        #expect(bar.fillWidthForTesting == 0)

        bar.update(size: CGSize(width: 200, height: 20))

        #expect(bar.fillWidthForTesting == 100)
    }

    @Test func panelNodeStoresStableContentSize() {
        let panel = PanelNode(size: CGSize(width: 180, height: 72))

        #expect(panel.contentSizeForTesting == CGSize(width: 180, height: 72))

        panel.update(size: CGSize(width: 200, height: 80))

        #expect(panel.contentSizeForTesting == CGSize(width: 200, height: 80))
    }

    @Test func primaryActionKeepsPanelTreeAndStyleWhenReappliedAndResized() {
        let panel = PanelNode(size: CGSize(width: 180, height: 58))

        panel.apply(size: CGSize(width: 180, height: 58), style: .primaryAction, showsRivets: true)
        let childCount = panel.children.count

        panel.apply(size: CGSize(width: 180, height: 58), style: .primaryAction, showsRivets: true)

        #expect(panel.children.count == childCount)
        #expect(panel.visibleRivetCountForTesting == 4)
        #expect(panel.styleForTesting == .primaryAction)

        panel.update(size: CGSize(width: 220, height: 64))

        #expect(panel.styleForTesting == .primaryAction)
    }

    @Test func panelShadowDoesNotExpandLayoutAboveContentBounds() {
        let panel = PanelNode(size: CGSize(width: 180, height: 58))

        let frame = panel.calculateAccumulatedFrame()

        let semanticBoundsPadding: CGFloat = 2
        #expect(frame.minY >= -panel.contentSizeForTesting.height / 2 - semanticBoundsPadding)
    }

    @Test func forgedPanelUsesFixedProgressiveSurfaceLayersWithoutAnimatedSheen() throws {
        let panel = PanelNode(size: CGSize(width: 180, height: 58))
        panel.apply(
            size: CGSize(width: 180, height: 58),
            style: .normal,
            showsRivets: true,
            appearance: .forged
        )

        let plate = try #require(panel.childNode(withName: "panelPlate") as? SKShapeNode)
        let topLight = try #require(panel.childNode(withName: "panelTopLight") as? SKShapeNode)
        let floorShade = try #require(panel.childNode(withName: "panelFloorShade") as? SKShapeNode)
        #expect(plate.fillTexture != nil)
        #expect(topLight.fillTexture != nil)
        #expect(floorShade.fillTexture != nil)
        #expect(!topLight.isHidden)
        #expect(!floorShade.isHidden)
        #expect(panel.childNode(withName: "panelSheen") == nil)
    }

    @Test func standardPanelHidesForgedSurfaceLayers() throws {
        let panel = PanelNode(size: CGSize(width: 180, height: 58))

        let topLight = try #require(panel.childNode(withName: "panelTopLight") as? SKShapeNode)
        let floorShade = try #require(panel.childNode(withName: "panelFloorShade") as? SKShapeNode)
        #expect(topLight.isHidden)
        #expect(floorShade.isHidden)
    }

    @Test func forgedPanelReusesItsFixedGradientTextureAcrossReapply() throws {
        let panel = PanelNode(size: CGSize(width: 180, height: 58))
        panel.apply(
            size: CGSize(width: 180, height: 58),
            style: .normal,
            showsRivets: true,
            appearance: .forged
        )
        let firstTexture = try #require(
            (panel.childNode(withName: "panelPlate") as? SKShapeNode)?.fillTexture
        )

        panel.apply(
            size: CGSize(width: 220, height: 64),
            style: .normal,
            showsRivets: true,
            appearance: .forged
        )
        let secondTexture = try #require(
            (panel.childNode(withName: "panelPlate") as? SKShapeNode)?.fillTexture
        )

        #expect(firstTexture === secondTexture)
    }

    @Test func forgedTexturedPanelsUseWhiteTintAndKeepMaterialReadbacks() throws {
        for style in [PanelNode.Style.selected, .primaryAction] {
            let expectedStrokeAlpha: CGFloat = style == .selected ? 0.96 : 0.75
            let expectedGlowWidth: CGFloat = style == .selected ? 8 : 7
            let expectedGlowAlpha: CGFloat = style == .selected ? 0.52 : 0.38
            let panel = PanelNode(size: CGSize(width: 96, height: 52))
            panel.apply(
                size: CGSize(width: 96, height: 52),
                style: style,
                showsRivets: false,
                appearance: .forged
            )

            let plate = try #require(panel.childNode(withName: "panelPlate") as? SKShapeNode)
            let shadow = try #require(panel.childNode(withName: "panelShadow") as? SKShapeNode)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            plate.fillColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            #expect(plate.fillTexture != nil)
            #expect(red > 0.99)
            #expect(green > 0.99)
            #expect(blue > 0.99)
            #expect(alpha > 0.99)
            #expect(abs(plate.strokeColor.cgColor.alpha - expectedStrokeAlpha) < 0.001)
            #expect(shadow.lineWidth == expectedGlowWidth)
            #expect(abs(shadow.strokeColor.cgColor.alpha - expectedGlowAlpha) < 0.001)
        }
    }

    @Test func forgedProgressFillUsesAReferenceGradientTexture() throws {
        let bar = ProgressBarNode(size: CGSize(width: 288, height: 14), appearance: .forged)
        bar.update(progress: 0.71)

        let fill = try #require(bar.children[1] as? SKShapeNode)

        #expect(fill.fillTexture != nil)
        #expect(rgba(fill.fillColor) == [255, 255, 255, 255])
    }
}

private func rgba(_ color: SKColor) -> [Int] {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
}
