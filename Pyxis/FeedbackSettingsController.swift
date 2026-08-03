import CoreGraphics
import SpriteKit

@MainActor
final class FeedbackSettingsController {
    private static let minimumGearHitSize = CGSize(width: 44, height: 44)

    let gear = SettingsGearNode()
    let modal = FeedbackSettingsNode()

    private let preferencesManager: FeedbackPreferencesManaging
    private let accessibilityAdapter: FeedbackSettingsAccessibilityAdapter
    private var preferences: FeedbackPreferences
    private var layout: FeedbackSettingsLayout?
    private var preferenceObservation: FeedbackPreferencesObservation?

    private(set) var isVisible = false

    init(
        preferences: FeedbackPreferencesManaging,
        accessibilityAdapter: FeedbackSettingsAccessibilityAdapter
    ) {
        preferencesManager = preferences
        self.accessibilityAdapter = accessibilityAdapter
        self.preferences = preferences.current

        accessibilityAdapter.configureActions(
            onGearActivate: { [weak self] in
                _ = self?.open()
            },
            onToggleSoundEffects: { [weak self] in
                self?.toggleSoundEffects()
            },
            onToggleHaptics: { [weak self] in
                self?.toggleHaptics()
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        preferenceObservation = preferences.observe { [weak self] snapshot in
            self?.applyObservedPreferences(snapshot)
        }
    }

    @discardableResult
    func open() -> Bool {
        guard let layout else { return false }

        isVisible = true
        modal.apply(layout: layout, preferences: preferences)
        accessibilityAdapter.present(layout: layout, preferences: preferences)
        return true
    }

    @discardableResult
    func handleTouch(at scenePoint: CGPoint) -> FeedbackSettingsAction? {
        guard isVisible else { return nil }

        let action = modal.action(at: scenePoint)
        switch action {
        case .toggleSoundEffects:
            toggleSoundEffects()
        case .toggleHaptics:
            toggleHaptics()
        case .close:
            close()
        case .consumed:
            break
        }
        return action
    }

    func applyGearFrame(_ frame: CGRect) {
        gear.apply(frame: frame)
        accessibilityAdapter.applyGear(frame: resolvedGearFrame(from: frame))
    }

    func reapply(layout: FeedbackSettingsLayout?) {
        guard let layout else { return }
        self.layout = layout
        reapplyVisibleModal()
    }

    func close(focusTarget: FeedbackSettingsFocusTarget = .openingGear) {
        guard isVisible else { return }

        isVisible = false
        modal.isHidden = true
        accessibilityAdapter.dismiss(focusTarget: focusTarget)
    }

    private func toggleSoundEffects() {
        let updated = preferencesManager.setSoundEffectsEnabled(!preferences.soundEffectsEnabled)
        applyObservedPreferences(updated)
    }

    private func toggleHaptics() {
        let updated = preferencesManager.setHapticsEnabled(!preferences.hapticsEnabled)
        applyObservedPreferences(updated)
    }

    private func applyObservedPreferences(_ updated: FeedbackPreferences) {
        guard preferences != updated else { return }
        preferences = updated
        reapplyVisibleModal()
    }

    private func reapplyVisibleModal() {
        guard isVisible, let layout else { return }
        modal.apply(layout: layout, preferences: preferences)
        accessibilityAdapter.reapplyModal(layout: layout, preferences: preferences)
    }

    private func resolvedGearFrame(from frame: CGRect) -> CGRect {
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.width.isFinite,
              frame.height.isFinite,
              frame.width > 0,
              frame.height > 0 else {
            return .zero
        }

        let size = CGSize(
            width: max(frame.width, Self.minimumGearHitSize.width),
            height: max(frame.height, Self.minimumGearHitSize.height)
        )
        return CGRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
