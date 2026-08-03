import CoreGraphics
import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct FeedbackSettingsControllerTests {
    @Test func togglesImmediatelyUpdateObservedPreferencesAndKeepTheModalOpen() throws {
        let context = try makeControllerContext()

        #expect(context.controller.open())
        #expect(context.controller.isVisible)

        #expect(context.controller.handleTouch(at: context.layout.soundRowFrame.center) == .toggleSoundEffects)
        #expect(context.preferences.current == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        #expect(context.controller.modal.soundEffectsStateForTesting == "Off")
        #expect(accessibilityElements(in: context.containerView)[0].accessibilityValue == "Off")
        #expect(context.controller.isVisible)
        #expect(!context.controller.modal.isHidden)

        #expect(context.controller.handleTouch(at: context.layout.hapticsRowFrame.center) == .toggleHaptics)
        #expect(context.preferences.current == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        ))
        #expect(context.controller.modal.hapticsStateForTesting == "Off")
        #expect(accessibilityElements(in: context.containerView)[1].accessibilityValue == "Off")
        #expect(context.controller.isVisible)
    }

    @Test func outsideTouchIsConsumedAndCloseIsTheOnlyTouchDismissal() throws {
        let context = try makeControllerContext()
        #expect(context.controller.open())

        #expect(context.controller.handleTouch(at: CGPoint(x: 2, y: 2)) == .consumed)
        #expect(context.controller.isVisible)
        #expect(!context.controller.modal.isHidden)

        #expect(context.controller.handleTouch(at: context.layout.closeFrame.center) == .close)
        #expect(!context.controller.isVisible)
        #expect(context.controller.modal.isHidden)
        #expect(context.posts.last?.notification == .screenChanged)
        #expect(targetsSameObject(
            context.posts.last?.target,
            accessibilityElements(in: context.containerView).onlyElement
        ))
    }

    @Test func reapplyRefreshesExistingGearModalAndAccessibilityFramesWithoutDuplication() throws {
        let context = try makeControllerContext()
        #expect(context.controller.open())
        let initialGearNodeCount = context.controller.gear.nodeCountForTesting
        let initialModalNodeCount = context.controller.modal.nodeCountForTesting
        let initialElements = accessibilityElements(in: context.containerView)
        let resizedLayout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: CGSize(width: 834, height: 1194),
            safeAreaInsets: .init(top: 24, left: 50, bottom: 20, right: 50)
        ))
        let resizedGearFrame = CGRect(x: 744, y: 1110, width: 44, height: 44)

        context.controller.applyGearFrame(resizedGearFrame)
        context.controller.reapply(layout: resizedLayout)

        let elements = accessibilityElements(in: context.containerView)
        #expect(context.controller.gear.nodeCountForTesting == initialGearNodeCount)
        #expect(context.controller.modal.nodeCountForTesting == initialModalNodeCount)
        #expect(context.controller.modal.soundRowHitFrameForTesting == resizedLayout.soundRowFrame)
        #expect(context.controller.modal.hapticsRowHitFrameForTesting == resizedLayout.hapticsRowFrame)
        #expect(context.controller.modal.closeHitFrameForTesting == resizedLayout.closeFrame)
        #expect(elements.count == 3)
        #expect(elements[0].accessibilityFrame == converted(resizedLayout.soundRowFrame))
        #expect(elements[1].accessibilityFrame == converted(resizedLayout.hapticsRowFrame))
        #expect(elements[2].accessibilityFrame == converted(resizedLayout.closeFrame))
        #expect(elements[0] === initialElements[0])
        #expect(elements[1] === initialElements[1])
        #expect(elements[2] === initialElements[2])
    }

    @Test func gearAccessibilityUsesTheResolvedMinimumHitFrame() throws {
        let context = try makeControllerContext()
        let requestedFrame = CGRect(x: 20, y: 40, width: 40, height: 40)

        context.controller.applyGearFrame(requestedFrame)

        let gear = try #require(accessibilityElements(in: context.containerView).onlyElement)
        #expect(gear.accessibilityFrame == converted(
            CGRect(x: 18, y: 38, width: 44, height: 44)
        ))
    }

    @Test func outcomeFocusRemainsContainedWhenGearAndLayoutAreReapplied() throws {
        let context = try makeControllerContext()
        let outcome = UIAccessibilityElement(accessibilityContainer: context.containerView)
        outcome.accessibilityLabel = "Conquest complete"

        #expect(context.controller.open())
        context.controller.close(focusTarget: .outcome(outcome))
        let postsAfterClose = context.posts

        context.controller.applyGearFrame(CGRect(x: 300, y: 560, width: 44, height: 44))
        context.controller.reapply(layout: try refreshedLayout())

        let elements = accessibilityElements(in: context.containerView)
        #expect(!context.controller.isVisible)
        #expect(elements.count == 1)
        #expect(targetsSameObject(elements.onlyElement, outcome))
        #expect(context.posts.count == postsAfterClose.count)
        #expect(targetsSameObject(context.posts.last?.target, outcome))
    }

    @Test func systemDefaultFocusRemainsBlockedWhenGearAndLayoutAreReapplied() throws {
        let context = try makeControllerContext()

        #expect(context.controller.open())
        context.controller.close(focusTarget: .systemDefault)
        let postsAfterClose = context.posts

        context.controller.applyGearFrame(CGRect(x: 300, y: 560, width: 44, height: 44))
        context.controller.reapply(layout: try refreshedLayout())

        #expect(!context.controller.isVisible)
        #expect(accessibilityElements(in: context.containerView).isEmpty)
        #expect(context.posts.count == postsAfterClose.count)
        #expect(context.posts.last?.target == nil)
    }

    @Test func externallyObservedPreferenceChangesReapplyTheVisibleModal() throws {
        let context = try makeControllerContext()
        #expect(context.controller.open())

        _ = context.preferences.setSoundEffectsEnabled(false)
        _ = context.preferences.setHapticsEnabled(false)

        #expect(context.controller.modal.soundEffectsStateForTesting == "Off")
        #expect(context.controller.modal.hapticsStateForTesting == "Off")
        let elements = accessibilityElements(in: context.containerView)
        #expect(elements[0].accessibilityValue == "Off")
        #expect(elements[1].accessibilityValue == "Off")
        #expect(context.controller.isVisible)
    }

    @Test func controllerOnlyChangesPreferencesAndPostsAccessibilityFocusNotifications() throws {
        let context = try makeControllerContext()

        #expect(context.controller.open())
        _ = context.controller.handleTouch(at: context.layout.soundRowFrame.center)
        _ = context.controller.handleTouch(at: context.layout.closeFrame.center)

        #expect(context.preferences.current.soundEffectsEnabled == false)
        #expect(context.posts.allSatisfy { $0.notification == .screenChanged })
    }
}

@MainActor
private func makeControllerContext() throws -> FeedbackSettingsControllerTestContext {
    let preferences = RecordingFeedbackPreferencesManager()
    let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    var posts: [AccessibilityPost] = []
    let adapter = FeedbackSettingsAccessibilityAdapter(
        containerView: containerView,
        sceneToScreenFrame: converted,
        postNotification: { notification, target in
            posts.append(AccessibilityPost(notification: notification, target: target))
        }
    )
    let controller = FeedbackSettingsController(
        preferences: preferences,
        accessibilityAdapter: adapter
    )
    let layout = try layoutFixture()
    controller.applyGearFrame(CGRect(x: 16, y: 24, width: 44, height: 44))
    controller.reapply(layout: layout)

    return FeedbackSettingsControllerTestContext(
        controller: controller,
        preferences: preferences,
        containerView: containerView,
        layout: layout,
        posts: { posts }
    )
}

private func refreshedLayout() throws -> FeedbackSettingsLayout {
    try #require(FeedbackSettingsLayout.compute(
        sceneSize: CGSize(width: 834, height: 1194),
        safeAreaInsets: .init(top: 24, left: 50, bottom: 20, right: 50)
    ))
}

@MainActor
private final class FeedbackSettingsControllerTestContext {
    let controller: FeedbackSettingsController
    let preferences: RecordingFeedbackPreferencesManager
    let containerView: UIView
    let layout: FeedbackSettingsLayout
    private let recordedPosts: () -> [AccessibilityPost]

    init(
        controller: FeedbackSettingsController,
        preferences: RecordingFeedbackPreferencesManager,
        containerView: UIView,
        layout: FeedbackSettingsLayout,
        posts: @escaping () -> [AccessibilityPost]
    ) {
        self.controller = controller
        self.preferences = preferences
        self.containerView = containerView
        self.layout = layout
        recordedPosts = posts
    }

    var posts: [AccessibilityPost] {
        recordedPosts()
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
