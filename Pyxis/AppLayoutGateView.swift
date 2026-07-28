import UIKit

enum AppLayoutGateReason: Equatable {
    case unsupportedGeometry
    case mapUnavailable

    var message: String {
        switch self {
        case .unsupportedGeometry:
            return "Pyxis needs a supported portrait window. Rotate or resize to continue."
        case .mapUnavailable:
            return "Map unavailable"
        }
    }
}

protocol LayoutGateLifecycleHandling: AnyObject {
    func layoutGateWillPause(at date: Date)
    func layoutGateWillResume(at date: Date)
}

/// Scenes whose layout depends on the live safe-area insets adopt this so
/// `GameViewController.viewSafeAreaInsetsDidChange()` can refresh every
/// mounted scene uniformly. An inset-only transition (e.g. rotating an iPad
/// between the two supported portrait orientations) can preserve scene
/// dimensions, so `didChangeSize` is not a reliable relayout path; this hook
/// guarantees the scene re-derives its layout from the current insets before
/// the controller updates or dismisses the layout gate.
protocol SceneLayoutRefreshable: AnyObject {
    func refreshLayoutForCurrentEnvironment()
}

final class AppLayoutGateView: UIView {
    let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.86)
        isUserInteractionEnabled = true
        accessibilityViewIsModal = true

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textColor = .white
        messageLabel.font = .preferredFont(forTextStyle: .headline)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(_ reason: AppLayoutGateReason) {
        messageLabel.text = reason.message
        accessibilityLabel = reason.message
    }
}
