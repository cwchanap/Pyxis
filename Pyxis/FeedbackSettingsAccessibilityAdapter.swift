import CoreGraphics
import UIKit

enum FeedbackSettingsFocusTarget {
    case outcome(UIAccessibilityElement)
    case openingGear
    case systemDefault
}

@MainActor
final class ActionAccessibilityElement: UIAccessibilityElement {
    private var action: () -> Void

    init(
        accessibilityContainer: Any,
        action: @escaping () -> Void
    ) {
        self.action = action
        super.init(accessibilityContainer: accessibilityContainer)
    }

    func setAction(_ action: @escaping () -> Void) {
        self.action = action
    }

    override func accessibilityActivate() -> Bool {
        action()
        return true
    }
}

@MainActor
final class FeedbackSettingsAccessibilityAdapter {
    typealias FrameConverter = @MainActor (CGRect) -> CGRect
    typealias NotificationPoster = @MainActor (UIAccessibility.Notification, Any?) -> Void

    private weak var containerView: UIView?
    private let sceneToScreenFrame: FrameConverter
    private let postNotification: NotificationPoster
    private let gearElement: ActionAccessibilityElement
    private let soundEffectsElement: ActionAccessibilityElement
    private let hapticsElement: ActionAccessibilityElement
    private let closeElement: ActionAccessibilityElement

    private var isModalVisible = false
    private var isGearAccessible = false

    convenience init(
        containerView: UIView,
        postNotification: @escaping NotificationPoster = { notification, target in
            UIAccessibility.post(notification: notification, argument: target)
        }
    ) {
        self.init(
            containerView: containerView,
            sceneToScreenFrame: Self.defaultFrameConverter(for: containerView),
            postNotification: postNotification
        )
    }

    init(
        containerView: UIView,
        sceneToScreenFrame: @escaping FrameConverter,
        postNotification: @escaping NotificationPoster
    ) {
        self.containerView = containerView
        self.sceneToScreenFrame = sceneToScreenFrame
        self.postNotification = postNotification
        gearElement = ActionAccessibilityElement(
            accessibilityContainer: containerView,
            action: {}
        )
        soundEffectsElement = ActionAccessibilityElement(
            accessibilityContainer: containerView,
            action: {}
        )
        hapticsElement = ActionAccessibilityElement(
            accessibilityContainer: containerView,
            action: {}
        )
        closeElement = ActionAccessibilityElement(
            accessibilityContainer: containerView,
            action: {}
        )

        configureElementMetadata()
        expose([])
    }

    func configureActions(
        onGearActivate: @escaping () -> Void,
        onToggleSoundEffects: @escaping () -> Void,
        onToggleHaptics: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        gearElement.setAction(onGearActivate)
        soundEffectsElement.setAction(onToggleSoundEffects)
        hapticsElement.setAction(onToggleHaptics)
        closeElement.setAction(onClose)
    }

    func applyGear(frame: CGRect) {
        guard let accessibilityFrame = convertedFrame(from: frame) else {
            isGearAccessible = false
            gearElement.accessibilityFrame = .zero
            if !isModalVisible {
                expose([])
            }
            return
        }

        isGearAccessible = true
        gearElement.accessibilityFrame = accessibilityFrame
        if !isModalVisible {
            exposeGearIfAvailable()
        }
    }

    func present(layout: FeedbackSettingsLayout, preferences: FeedbackPreferences) {
        isModalVisible = true
        applyModal(layout: layout, preferences: preferences)
        expose([soundEffectsElement, hapticsElement, closeElement])
        postScreenChange(target: soundEffectsElement)
    }

    func reapplyModal(layout: FeedbackSettingsLayout, preferences: FeedbackPreferences) {
        guard isModalVisible else { return }
        applyModal(layout: layout, preferences: preferences)
        expose([soundEffectsElement, hapticsElement, closeElement])
    }

    func dismiss(focusTarget: FeedbackSettingsFocusTarget) {
        isModalVisible = false

        switch focusTarget {
        case .outcome(let outcome):
            expose([outcome])
            postScreenChange(target: outcome)

        case .openingGear:
            guard isGearAccessible else {
                expose([])
                postScreenChange(target: nil)
                return
            }
            expose([gearElement])
            postScreenChange(target: gearElement)

        case .systemDefault:
            expose([])
            postScreenChange(target: nil)
        }
    }

    private func configureElementMetadata() {
        gearElement.accessibilityLabel = "Settings"
        gearElement.accessibilityTraits = .button

        soundEffectsElement.accessibilityLabel = "Sound Effects"
        soundEffectsElement.accessibilityHint = "Double tap to toggle."
        soundEffectsElement.accessibilityTraits = .button

        hapticsElement.accessibilityLabel = "Haptics"
        hapticsElement.accessibilityHint = "Double tap to toggle."
        hapticsElement.accessibilityTraits = .button

        closeElement.accessibilityLabel = "Close"
        closeElement.accessibilityTraits = .button
    }

    private func applyModal(
        layout: FeedbackSettingsLayout,
        preferences: FeedbackPreferences
    ) {
        soundEffectsElement.accessibilityValue = preferences.soundEffectsEnabled ? "On" : "Off"
        hapticsElement.accessibilityValue = preferences.hapticsEnabled ? "On" : "Off"
        soundEffectsElement.accessibilityFrame = convertedFrame(from: layout.soundRowFrame) ?? .zero
        hapticsElement.accessibilityFrame = convertedFrame(from: layout.hapticsRowFrame) ?? .zero
        closeElement.accessibilityFrame = convertedFrame(from: layout.closeFrame) ?? .zero
    }

    private func exposeGearIfAvailable() {
        expose(isGearAccessible ? [gearElement] : [])
    }

    private func expose(_ elements: [UIAccessibilityElement]) {
        containerView?.accessibilityElements = elements
    }

    private func postScreenChange(target: Any?) {
        postNotification(.screenChanged, target)
    }

    private func convertedFrame(from sceneFrame: CGRect) -> CGRect? {
        guard sceneFrame.origin.x.isFinite,
              sceneFrame.origin.y.isFinite,
              sceneFrame.width.isFinite,
              sceneFrame.height.isFinite,
              sceneFrame.width > 0,
              sceneFrame.height > 0 else {
            return nil
        }

        let converted = sceneToScreenFrame(sceneFrame)
        guard converted.origin.x.isFinite,
              converted.origin.y.isFinite,
              converted.width.isFinite,
              converted.height.isFinite,
              converted.width > 0,
              converted.height > 0 else {
            assertionFailure("Failed to convert Feedback Settings accessibility frame")
            return nil
        }
        return converted
    }

    private static func defaultFrameConverter(for containerView: UIView) -> FrameConverter {
        { [weak containerView] sceneFrame in
            guard let containerView else { return .zero }
            let viewFrame = CGRect(
                x: sceneFrame.minX,
                y: containerView.bounds.height - sceneFrame.maxY,
                width: sceneFrame.width,
                height: sceneFrame.height
            )
            return containerView.convert(viewFrame, to: nil)
        }
    }
}
