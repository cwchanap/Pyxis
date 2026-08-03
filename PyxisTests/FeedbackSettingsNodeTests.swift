import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

private enum FeedbackSettingsNodeTestError: Error {
    case layoutUnavailable
}

private func nodeTestLayout() throws -> FeedbackSettingsLayout {
    guard let layout = FeedbackSettingsLayout.compute(
        sceneSize: .init(width: 375, height: 667),
        safeAreaInsets: .zero
    ) else {
        throw FeedbackSettingsNodeTestError.layoutUnavailable
    }
    return layout
}

@MainActor
struct FeedbackSettingsNodeTests {
    @Test func modalUsesExactCopyAndExpectedControlCount() throws {
        let node = FeedbackSettingsNode()
        let layout = try nodeTestLayout()

        node.apply(
            layout: layout,
            preferences: .init(soundEffectsEnabled: true, hapticsEnabled: false)
        )

        #expect(node.soundEffectsLabelForTesting == "Sound Effects")
        #expect(node.hapticsLabelForTesting == "Haptics")
        #expect(node.closeLabelForTesting == "Close")
        #expect(node.soundEffectsStateForTesting == "On")
        #expect(node.hapticsStateForTesting == "Off")
        #expect(node.toggleControlCountForTesting == 2)
        #expect(node.controlCountForTesting == 3)
        #expect(node.zPosition == GameUITheme.Z.modal - 10)
    }

    @Test func reapplyChangesOnlyStatesAndReusesTheExistingTree() throws {
        let node = FeedbackSettingsNode()
        let layout = try nodeTestLayout()
        node.apply(
            layout: layout,
            preferences: .init(soundEffectsEnabled: true, hapticsEnabled: true)
        )
        let originalNodeCount = node.nodeCountForTesting

        node.apply(
            layout: layout,
            preferences: .init(soundEffectsEnabled: false, hapticsEnabled: false)
        )

        #expect(node.soundEffectsStateForTesting == "Off")
        #expect(node.hapticsStateForTesting == "Off")
        #expect(node.nodeCountForTesting == originalNodeCount)
        #expect(node.toggleControlCountForTesting == 2)
        #expect(node.controlCountForTesting == 3)
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
}
