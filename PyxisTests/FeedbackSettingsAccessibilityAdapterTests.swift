import CoreGraphics
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct FeedbackSettingsAccessibilityAdapterTests {
    @Test func actionElementRunsItsActionAndReportsActivation() {
        var activationCount = 0
        let element = ActionAccessibilityElement(accessibilityContainer: UIView()) {
            activationCount += 1
        }

        #expect(element.accessibilityActivate())
        #expect(activationCount == 1)
    }

    @Test func closedModalExposesOnlyTheSettingsGearWithConvertedFrame() throws {
        let context = makeAccessibilityContext()
        let underlying = UIAccessibilityElement(accessibilityContainer: context.containerView)
        context.containerView.accessibilityElements = [underlying]
        var gearActivationCount = 0
        context.adapter.configureActions(
            onGearActivate: { gearActivationCount += 1 },
            onToggleSoundEffects: {},
            onToggleHaptics: {},
            onClose: {}
        )
        let gearFrame = CGRect(x: 16, y: 24, width: 44, height: 44)

        context.adapter.applyGear(frame: gearFrame)

        let elements = accessibilityElements(in: context.containerView)
        let gear = try #require(elements.onlyElement)
        #expect(elements.count == 1)
        #expect(gear.accessibilityLabel == "Settings")
        #expect(gear.accessibilityValue == nil)
        #expect(gear.accessibilityHint == nil)
        #expect(gear.accessibilityTraits == .button)
        #expect(gear.accessibilityFrame == converted(gearFrame))
        #expect(gear.accessibilityActivate())
        #expect(gearActivationCount == 1)
        #expect(elements.first !== underlying)
    }

    @Test func openingModalExposesOnlyOrderedControlsWithConvertedFramesAndFocusesSoundEffects() throws {
        let context = makeAccessibilityContext()
        let layout = try layoutFixture()
        context.adapter.configureActions(
            onGearActivate: {},
            onToggleSoundEffects: {},
            onToggleHaptics: {},
            onClose: {}
        )
        context.adapter.applyGear(frame: CGRect(x: 16, y: 24, width: 44, height: 44))

        context.adapter.present(
            layout: layout,
            preferences: FeedbackPreferences(
                soundEffectsEnabled: false,
                hapticsEnabled: true
            )
        )

        let elements = accessibilityElements(in: context.containerView)
        #expect(elements.count == 3)
        #expect(elements.map(\.accessibilityLabel) == [
            "Sound Effects",
            "Haptics",
            "Close"
        ])
        #expect(elements.map(\.accessibilityValue) == ["Off", "On", nil])
        #expect(elements.map(\.accessibilityHint) == [
            "Double tap to toggle.",
            "Double tap to toggle.",
            nil
        ])
        #expect(elements.map(\.accessibilityTraits) == [.button, .button, .button])
        #expect(elements.map(\.accessibilityFrame) == [
            converted(layout.soundRowFrame),
            converted(layout.hapticsRowFrame),
            converted(layout.closeFrame)
        ])
        #expect(context.posts.count == 1)
        #expect(context.posts[0].notification == .screenChanged)
        #expect(targetsSameObject(context.posts[0].target, elements[0]))
    }

    @Test func modalElementActivationUsesTheConfiguredActions() throws {
        let context = makeAccessibilityContext()
        let layout = try layoutFixture()
        var soundActivations = 0
        var hapticsActivations = 0
        var closeActivations = 0
        context.adapter.configureActions(
            onGearActivate: {},
            onToggleSoundEffects: { soundActivations += 1 },
            onToggleHaptics: { hapticsActivations += 1 },
            onClose: { closeActivations += 1 }
        )

        context.adapter.present(layout: layout, preferences: .defaultValue)
        let elements = accessibilityElements(in: context.containerView)

        #expect(elements[0].accessibilityActivate())
        #expect(elements[1].accessibilityActivate())
        #expect(elements[2].accessibilityActivate())
        #expect(soundActivations == 1)
        #expect(hapticsActivations == 1)
        #expect(closeActivations == 1)
    }

    @Test func closingFocusesAnAccessibleOutcomeThenTheGearAfterOutcomeDismissal() throws {
        let context = makeAccessibilityContext()
        let layout = try layoutFixture()
        context.adapter.configureActions(
            onGearActivate: {},
            onToggleSoundEffects: {},
            onToggleHaptics: {},
            onClose: {}
        )
        context.adapter.applyGear(frame: CGRect(x: 16, y: 24, width: 44, height: 44))
        let gear = try #require(accessibilityElements(in: context.containerView).onlyElement)

        context.adapter.present(layout: layout, preferences: .defaultValue)
        let outcome = UIAccessibilityElement(accessibilityContainer: context.containerView)
        outcome.accessibilityLabel = "Conquest complete"
        context.adapter.dismiss(focusTarget: .outcome(outcome))

        #expect(context.posts.last?.notification == .screenChanged)
        #expect(targetsSameObject(context.posts.last?.target, outcome))
        #expect(targetsSameObject(
            accessibilityElements(in: context.containerView).onlyElement,
            outcome
        ))

        context.adapter.setSceneGearActionable(true)
        context.adapter.present(layout: layout, preferences: .defaultValue)
        context.adapter.dismiss(focusTarget: .openingGear)

        #expect(context.posts.last?.notification == .screenChanged)
        #expect(targetsSameObject(context.posts.last?.target, gear))
        #expect(targetsSameObject(
            accessibilityElements(in: context.containerView).onlyElement,
            gear
        ))
    }

    @Test func blockedOrInaccessibleOutcomePostsSystemDefaultWithoutTheGear() throws {
        let context = makeAccessibilityContext()
        let layout = try layoutFixture()
        context.adapter.configureActions(
            onGearActivate: {},
            onToggleSoundEffects: {},
            onToggleHaptics: {},
            onClose: {}
        )
        context.adapter.applyGear(frame: CGRect(x: 16, y: 24, width: 44, height: 44))
        let gear = try #require(accessibilityElements(in: context.containerView).onlyElement)

        context.adapter.present(layout: layout, preferences: .defaultValue)
        context.adapter.setSceneGearActionable(false)
        context.adapter.dismiss(focusTarget: .systemDefault)

        #expect(context.posts.last?.notification == .screenChanged)
        #expect(context.posts.last?.target == nil)
        #expect(accessibilityElements(in: context.containerView).isEmpty)
        #expect(!targetsSameObject(context.posts.last?.target, gear))

        context.adapter.present(layout: layout, preferences: .defaultValue)
        #expect(accessibilityElements(in: context.containerView).isEmpty)
    }
}

@MainActor
private func makeAccessibilityContext() -> AccessibilityAdapterTestContext {
    let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    var posts: [AccessibilityPost] = []
    let adapter = FeedbackSettingsAccessibilityAdapter(
        containerView: containerView,
        sceneToScreenFrame: converted,
        postNotification: { notification, target in
            posts.append(AccessibilityPost(notification: notification, target: target))
        }
    )
    return AccessibilityAdapterTestContext(
        containerView: containerView,
        adapter: adapter,
        posts: { posts }
    )
}

@MainActor
func accessibilityElements(in containerView: UIView) -> [UIAccessibilityElement] {
    (containerView.accessibilityElements as? [UIAccessibilityElement]) ?? []
}

func converted(_ frame: CGRect) -> CGRect {
    frame.offsetBy(dx: 100, dy: 200)
}

func layoutFixture() throws -> FeedbackSettingsLayout {
    try #require(FeedbackSettingsLayout.compute(
        sceneSize: CGSize(width: 375, height: 667),
        safeAreaInsets: .zero
    ))
}

func targetsSameObject(_ target: Any?, _ expected: AnyObject?) -> Bool {
    (target as AnyObject?) === expected
}

@MainActor
private final class AccessibilityAdapterTestContext {
    let containerView: UIView
    let adapter: FeedbackSettingsAccessibilityAdapter
    private let recordedPosts: () -> [AccessibilityPost]

    init(
        containerView: UIView,
        adapter: FeedbackSettingsAccessibilityAdapter,
        posts: @escaping () -> [AccessibilityPost]
    ) {
        self.containerView = containerView
        self.adapter = adapter
        recordedPosts = posts
    }

    var posts: [AccessibilityPost] {
        recordedPosts()
    }
}

struct AccessibilityPost {
    let notification: UIAccessibility.Notification
    let target: Any?
}

extension Array where Element == UIAccessibilityElement {
    var onlyElement: UIAccessibilityElement? {
        count == 1 ? first : nil
    }
}
