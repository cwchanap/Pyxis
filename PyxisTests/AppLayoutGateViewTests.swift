//
//  AppLayoutGateViewTests.swift
//  PyxisTests
//

import Testing
import UIKit
@testable import Pyxis

@MainActor
struct AppLayoutGateViewTests {
    @Test func unsupportedGeometryMessageDescribesRequiredPortraitWindow() {
        #expect(AppLayoutGateReason.unsupportedGeometry.message
            == "Pyxis needs a supported portrait window. Rotate or resize to continue.")
    }

    @Test func mapUnavailableMessageIsShortAndDistinct() {
        #expect(AppLayoutGateReason.mapUnavailable.message == "Map unavailable")
        #expect(AppLayoutGateReason.mapUnavailable.message != AppLayoutGateReason.unsupportedGeometry.message)
    }

    @Test func reasonsAreEquatableByCaseOnly() {
        #expect(AppLayoutGateReason.unsupportedGeometry == .unsupportedGeometry)
        #expect(AppLayoutGateReason.mapUnavailable == .mapUnavailable)
        #expect(AppLayoutGateReason.unsupportedGeometry != .mapUnavailable)
    }

    @Test func initialAppearanceIsAnOpaqueModalOverlay() {
        let gate = AppLayoutGateView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        #expect(gate.isUserInteractionEnabled)
        #expect(gate.accessibilityViewIsModal)
        #expect(gate.backgroundColor == UIColor.black.withAlphaComponent(0.86))
    }

    @Test func messageLabelIsConfiguredForCenteredMultilineText() {
        let gate = AppLayoutGateView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        #expect(gate.messageLabel.superview === gate)
        #expect(gate.messageLabel.numberOfLines == 0)
        #expect(gate.messageLabel.textAlignment == .center)
        #expect(gate.messageLabel.textColor == .white)
        #expect(gate.messageLabel.font == .preferredFont(forTextStyle: .headline))
        #expect(!gate.messageLabel.translatesAutoresizingMaskIntoConstraints)
    }

    @Test func messageLabelIsConstrainedToViewCenter() {
        let gate = AppLayoutGateView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        gate.layoutIfNeeded()

        let centerXConstraints = gate.constraints.filter {
            $0.firstAttribute == .centerX || $0.secondAttribute == .centerX
        }
        let centerYConstraints = gate.constraints.filter {
            $0.firstAttribute == .centerY || $0.secondAttribute == .centerY
        }

        #expect(!centerXConstraints.isEmpty)
        #expect(!centerYConstraints.isEmpty)
        #expect(abs(gate.messageLabel.center.x - gate.bounds.midX) < 0.5)
        #expect(abs(gate.messageLabel.center.y - gate.bounds.midY) < 0.5)
    }

    @Test func applyUnsupportedGeometrySetsLabelTextAndAccessibilityLabel() {
        let gate = AppLayoutGateView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        gate.apply(.unsupportedGeometry)

        #expect(gate.messageLabel.text == AppLayoutGateReason.unsupportedGeometry.message)
        #expect(gate.accessibilityLabel == AppLayoutGateReason.unsupportedGeometry.message)
    }

    @Test func applyMapUnavailableSetsLabelTextAndAccessibilityLabel() {
        let gate = AppLayoutGateView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        gate.apply(.mapUnavailable)

        #expect(gate.messageLabel.text == AppLayoutGateReason.mapUnavailable.message)
        #expect(gate.accessibilityLabel == AppLayoutGateReason.mapUnavailable.message)
    }

    @Test func reapplyingADifferentReasonOverwritesThePreviousMessage() {
        let gate = AppLayoutGateView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        gate.apply(.unsupportedGeometry)
        #expect(gate.messageLabel.text == AppLayoutGateReason.unsupportedGeometry.message)

        gate.apply(.mapUnavailable)
        #expect(gate.messageLabel.text == AppLayoutGateReason.mapUnavailable.message)
        #expect(gate.accessibilityLabel == AppLayoutGateReason.mapUnavailable.message)

        gate.apply(.unsupportedGeometry)
        #expect(gate.messageLabel.text == AppLayoutGateReason.unsupportedGeometry.message)
        #expect(gate.accessibilityLabel == AppLayoutGateReason.unsupportedGeometry.message)
    }
}