import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

private enum FeedbackSettingsNodeTestError: Error {
    case layoutUnavailable
}

private func nodeTestLayout(
    sceneSize: CGSize = .init(width: 375, height: 667),
    safeAreaInsets: FeedbackSettingsSafeAreaInsets = .zero
) throws -> FeedbackSettingsLayout {
    guard let layout = FeedbackSettingsLayout.compute(
        sceneSize: sceneSize,
        safeAreaInsets: safeAreaInsets
    ) else {
        throw FeedbackSettingsNodeTestError.layoutUnavailable
    }
    return layout
}

@MainActor
private func allNodes(in root: SKNode) -> [SKNode] {
    var nodes: [SKNode] = []

    func visit(_ node: SKNode) {
        nodes.append(node)
        for child in node.children {
            visit(child)
        }
    }

    visit(root)
    return nodes
}

@MainActor
private func renderedControlFrames(in node: FeedbackSettingsNode, panelFrame: CGRect) -> [CGRect] {
    allNodes(in: node).compactMap { child in
        guard let shape = child as? SKShapeNode else { return nil }
        guard [
            "feedbackSettingsSoundRow",
            "feedbackSettingsHapticsRow",
            "feedbackSettingsClose"
        ].contains(child.name) else { return nil }
        return shape.path?.boundingBox
    }.filter { frame in frame != panelFrame && panelFrame.contains(frame) }
}

@MainActor
private func renderedLabelTexts(in node: FeedbackSettingsNode) -> [String] {
    allNodes(in: node).compactMap { child in
        guard let label = child as? SKLabelNode,
              !label.isHidden,
              label.alpha > 0,
              let text = label.text,
              !text.isEmpty else {
            return nil
        }
        return text
    }
}

@MainActor
struct FeedbackSettingsNodeTests {
    @Test func modalUsesExactCopyAndRendersOnlyTwoTogglesAndClose() throws {
        let node = FeedbackSettingsNode()
        let layout = try nodeTestLayout()

        node.apply(
            layout: layout,
            preferences: .init(soundEffectsEnabled: true, hapticsEnabled: false)
        )

        #expect(renderedControlFrames(in: node, panelFrame: layout.panelFrame) == [
            layout.soundRowFrame,
            layout.hapticsRowFrame,
            layout.closeFrame
        ])
        #expect(renderedLabelTexts(in: node) == [
            "Sound Effects",
            "Haptics",
            "Done"
        ])
        #expect(node.iconSymbolNamesForTesting == [
            "speaker.wave.2.fill",
            "iphone.radiowaves.left.and.right"
        ])
        #expect(node.visibleToggleRowNamesForTesting == [
            "feedbackSettingsSoundRow",
            "feedbackSettingsHapticsRow"
        ])
        #expect(node.zPosition == GameUITheme.Z.modal - 10)
    }

    @Test func reapplyUpdatesResizedVisualAndHitFramesWithoutDuplicatingTree() throws {
        let node = FeedbackSettingsNode()
        let initialLayout = try nodeTestLayout()
        node.apply(
            layout: initialLayout,
            preferences: .init(soundEffectsEnabled: true, hapticsEnabled: true)
        )
        let originalNodeCount = allNodes(in: node).count
        let initialControlFrames = renderedControlFrames(in: node, panelFrame: initialLayout.panelFrame)
        let resizedLayout = try nodeTestLayout(
            sceneSize: .init(width: 834, height: 1194),
            safeAreaInsets: .init(top: 24, left: 50, bottom: 20, right: 50)
        )

        node.apply(
            layout: resizedLayout,
            preferences: .init(soundEffectsEnabled: false, hapticsEnabled: false)
        )

        #expect(node.soundEffectsStateForTesting == "Off")
        #expect(node.hapticsStateForTesting == "Off")
        #expect(allNodes(in: node).count == originalNodeCount)
        #expect(renderedControlFrames(in: node, panelFrame: resizedLayout.panelFrame) == [
            resizedLayout.soundRowFrame,
            resizedLayout.hapticsRowFrame,
            resizedLayout.closeFrame
        ])
        #expect(renderedControlFrames(in: node, panelFrame: resizedLayout.panelFrame) != initialControlFrames)
        #expect(node.soundRowHitFrameForTesting == resizedLayout.soundRowFrame)
        #expect(node.hapticsRowHitFrameForTesting == resizedLayout.hapticsRowFrame)
        #expect(node.closeHitFrameForTesting == resizedLayout.closeFrame)
        #expect(node.action(at: CGPoint(
            x: resizedLayout.soundRowFrame.midX,
            y: resizedLayout.soundRowFrame.midY
        )) == .toggleSoundEffects)
        #expect(node.action(at: CGPoint(
            x: resizedLayout.hapticsRowFrame.midX,
            y: resizedLayout.hapticsRowFrame.midY
        )) == .toggleHaptics)
        #expect(node.action(at: CGPoint(
            x: resizedLayout.closeFrame.midX,
            y: resizedLayout.closeFrame.midY
        )) == .close)
        #expect(node.action(at: CGPoint(
            x: initialLayout.soundRowFrame.minX + 1,
            y: initialLayout.soundRowFrame.midY
        )) == .consumed)
        #expect(node.action(at: CGPoint(
            x: initialLayout.hapticsRowFrame.minX + 1,
            y: initialLayout.hapticsRowFrame.midY
        )) == .consumed)
        #expect(node.action(at: CGPoint(
            x: initialLayout.closeFrame.minX + 1,
            y: initialLayout.closeFrame.midY
        )) == .consumed)
    }

    @Test func fullRowsResolveToTheirActionsAndEveryOtherPointIsConsumed() throws {
        let node = FeedbackSettingsNode()
        let layout = try nodeTestLayout()
        node.apply(layout: layout, preferences: .defaultValue)

        #expect(node.soundRowHitFrameForTesting == layout.soundRowFrame)
        #expect(node.hapticsRowHitFrameForTesting == layout.hapticsRowFrame)
        #expect(node.closeHitFrameForTesting == layout.closeFrame)
        #expect(node.action(at: CGPoint(
            x: layout.soundRowFrame.minX + 1,
            y: layout.soundRowFrame.midY
        )) == .toggleSoundEffects)
        #expect(node.action(at: CGPoint(
            x: layout.hapticsRowFrame.maxX - 1,
            y: layout.hapticsRowFrame.midY
        )) == .toggleHaptics)
        #expect(node.action(at: CGPoint(
            x: layout.closeFrame.midX,
            y: layout.closeFrame.midY
        )) == .close)
        #expect(node.action(at: CGPoint(
            x: layout.scrimFrame.minX + 1,
            y: layout.scrimFrame.minY + 1
        )) == .consumed)
        #expect(node.action(at: CGPoint(
            x: layout.panelFrame.minX + 1,
            y: layout.panelFrame.minY + 1
        )) == .consumed)
    }

    @Test func gearUsesTheNamedFortyFourPointTargetWithoutRebuilding() {
        let gear = SettingsGearNode()
        let initialNodeCount = gear.nodeCountForTesting
        let firstFrame = CGRect(x: 20, y: 40, width: 44, height: 44)
        gear.apply(frame: firstFrame)

        let scene = SKScene(size: .init(width: 200, height: 200))
        scene.addChild(gear)
        let firstNames = scene.nodes(at: CGPoint(x: firstFrame.midX, y: firstFrame.midY)).compactMap(\.name)

        #expect(gear.name == "feedbackSettingsGear")
        #expect(gear.hitShapeNameForTesting == "feedbackSettingsGear")
        #expect(firstNames.contains("feedbackSettingsGear"))
        #expect(gear.hitFrameForTesting == firstFrame)
        #expect(gear.contains(CGPoint(x: firstFrame.midX, y: firstFrame.midY)))
        #expect(!gear.contains(CGPoint(x: firstFrame.maxX + 1, y: firstFrame.midY)))
        #expect(gear.glyphSizeForTesting.width >= 20 && gear.glyphSizeForTesting.width <= 22)
        #expect(gear.glyphSizeForTesting.height >= 20 && gear.glyphSizeForTesting.height <= 22)
        #expect(gear.zPosition == GameUITheme.Z.hud + 2)

        let secondFrame = CGRect(x: 80, y: 100, width: 40, height: 40)
        gear.apply(frame: secondFrame)

        #expect(gear.nodeCountForTesting == initialNodeCount)
        #expect(gear.hitFrameForTesting == CGRect(x: 78, y: 98, width: 44, height: 44))
    }

    @Test func gearUsesItsHitFrameForADarkFramedRivetTile() throws {
        let gear = SettingsGearNode()
        let frame = CGRect(x: 20, y: 40, width: 44, height: 44)

        gear.apply(frame: frame)

        let tile = try #require(gear.childNode(withName: "settingsGearTile") as? PanelNode)
        #expect(tile.contentSizeForTesting == frame.size)
        #expect(tile.styleForTesting == .normal)
        #expect(tile.visibleRivetCountForTesting == 4)
        #expect(gear.hitFrameForTesting == frame)
    }

    @Test func forgedGearUsesA21PointOutlineVectorForDarkPanelContrast() {
        let gear = SettingsGearNode()

        gear.apply(
            frame: CGRect(x: 20, y: 40, width: 44, height: 44),
            appearance: .forged
        )

        #expect(gear.glyphIsVectorForTesting)
        #expect(gear.glyphFillAlphaForTesting == 0)
        #expect(gear.glyphSizeForTesting == CGSize(width: 21, height: 21))
        #expect(gear.glyphColorBlendFactorForTesting == 0)
    }

    @Test func testingHelpersExposeLabel_textsAndControlCounts() throws {
        let node = FeedbackSettingsNode()
        let layout = try nodeTestLayout()
        node.apply(
            layout: layout,
            preferences: .init(soundEffectsEnabled: true, hapticsEnabled: true)
        )

        #expect(node.soundEffectsLabelForTesting == "Sound Effects")
        #expect(node.hapticsLabelForTesting == "Haptics")
        #expect(node.closeLabelForTesting == "Done")
        #expect(node.toggleControlCountForTesting == 2)
        #expect(node.controlCountForTesting == 3)
    }

    @Test func gearContainsUsesHitFrameWhenNoParent() {
        let gear = SettingsGearNode()
        let frame = CGRect(x: 20, y: 40, width: 44, height: 44)
        gear.apply(frame: frame)

        // Without a parent, contains(_:) must fall back to hitFrame.contains.
        #expect(gear.contains(CGPoint(x: frame.midX, y: frame.midY)))
        #expect(!gear.contains(CGPoint(x: frame.maxX + 10, y: frame.midY)))
    }
}
