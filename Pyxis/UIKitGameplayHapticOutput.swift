//
//  UIKitGameplayHapticOutput.swift
//  Pyxis
//

import CoreHaptics
import UIKit

protocol HapticCapabilityProviding {
    var supportsHaptics: Bool { get }
}

enum HapticImpactStyle: Equatable {
    case light
    case medium
}

enum HapticNotificationFeedback: Equatable {
    case warning
    case success
}

protocol HapticImpactGenerating: AnyObject {
    func prepare()
    func impactOccurred()
}

protocol HapticNotificationGenerating: AnyObject {
    func prepare()
    func notificationOccurred(_ feedback: HapticNotificationFeedback)
}

protocol HapticGeneratorFactory {
    func makeImpactGenerator(style: HapticImpactStyle) -> HapticImpactGenerating
    func makeNotificationGenerator() -> HapticNotificationGenerating
}

final class UIKitGameplayHapticOutput: GameplayHapticOutput {
    private let lightImpactGenerator: HapticImpactGenerating?
    private let mediumImpactGenerator: HapticImpactGenerating?
    private let notificationGenerator: HapticNotificationGenerating?

    init(
        capability: HapticCapabilityProviding = CoreHapticsCapabilityProvider(),
        generatorFactory: HapticGeneratorFactory = UIKitHapticGeneratorFactory()
    ) {
        guard capability.supportsHaptics else {
            lightImpactGenerator = nil
            mediumImpactGenerator = nil
            notificationGenerator = nil
            return
        }

        let lightImpactGenerator = generatorFactory.makeImpactGenerator(style: .light)
        let mediumImpactGenerator = generatorFactory.makeImpactGenerator(style: .medium)
        let notificationGenerator = generatorFactory.makeNotificationGenerator()

        self.lightImpactGenerator = lightImpactGenerator
        self.mediumImpactGenerator = mediumImpactGenerator
        self.notificationGenerator = notificationGenerator

        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        notificationGenerator.prepare()
    }

    func play(_ kind: GameplayHapticKind) {
        switch kind {
        case .lightImpact:
            lightImpactGenerator?.impactOccurred()
            lightImpactGenerator?.prepare()

        case .mediumImpact:
            mediumImpactGenerator?.impactOccurred()
            mediumImpactGenerator?.prepare()

        case .warning:
            notificationGenerator?.notificationOccurred(.warning)
            notificationGenerator?.prepare()

        case .strongSuccess:
            notificationGenerator?.notificationOccurred(.success)
            notificationGenerator?.prepare()
        }
    }
}

private final class CoreHapticsCapabilityProvider: HapticCapabilityProviding {
    var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
}

private final class UIKitHapticGeneratorFactory: HapticGeneratorFactory {
    func makeImpactGenerator(style: HapticImpactStyle) -> HapticImpactGenerating {
        UIKitImpactHapticGenerator(style: style)
    }

    func makeNotificationGenerator() -> HapticNotificationGenerating {
        UIKitNotificationHapticGenerator()
    }
}

private final class UIKitImpactHapticGenerator: HapticImpactGenerating {
    private let generator: UIImpactFeedbackGenerator

    init(style: HapticImpactStyle) {
        switch style {
        case .light:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .medium:
            generator = UIImpactFeedbackGenerator(style: .medium)
        }
    }

    func prepare() {
        generator.prepare()
    }

    func impactOccurred() {
        generator.impactOccurred()
    }
}

private final class UIKitNotificationHapticGenerator: HapticNotificationGenerating {
    private let generator = UINotificationFeedbackGenerator()

    func prepare() {
        generator.prepare()
    }

    func notificationOccurred(_ feedback: HapticNotificationFeedback) {
        switch feedback {
        case .warning:
            generator.notificationOccurred(.warning)
        case .success:
            generator.notificationOccurred(.success)
        }
    }
}
