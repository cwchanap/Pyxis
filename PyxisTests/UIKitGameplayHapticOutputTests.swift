//
//  UIKitGameplayHapticOutputTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

@MainActor
struct UIKitGameplayHapticOutputTests {
    @Test func lightImpactUsesItsCachedGenerator() {
        let capability = FixedHapticCapability(supportsHaptics: true)
        let generators = RecordingHapticGeneratorFactory()
        let output = UIKitGameplayHapticOutput(
            capability: capability,
            generatorFactory: generators
        )

        output.play(.lightImpact)
        output.play(.lightImpact)

        #expect(generators.createdImpactStyles == [.light, .medium])
        #expect(generators.createdNotificationGeneratorCount == 1)
        #expect(generators.lightImpact.impactCount == 2)
        #expect(generators.mediumImpact.impactCount == 0)
        #expect(generators.notification.feedbacks.isEmpty)
    }

    @Test func mediumImpactUsesItsCachedGenerator() {
        let generators = RecordingHapticGeneratorFactory()
        let output = UIKitGameplayHapticOutput(
            capability: FixedHapticCapability(supportsHaptics: true),
            generatorFactory: generators
        )

        output.play(.mediumImpact)

        #expect(generators.lightImpact.impactCount == 0)
        #expect(generators.mediumImpact.impactCount == 1)
        #expect(generators.notification.feedbacks.isEmpty)
    }

    @Test func warningUsesTheCachedNotificationGenerator() {
        let generators = RecordingHapticGeneratorFactory()
        let output = UIKitGameplayHapticOutput(
            capability: FixedHapticCapability(supportsHaptics: true),
            generatorFactory: generators
        )

        output.play(.warning)
        output.play(.warning)

        #expect(generators.createdNotificationGeneratorCount == 1)
        #expect(generators.notification.feedbacks == [.warning, .warning])
    }

    @Test func strongSuccessUsesTheNotificationSuccessFeedback() {
        let generators = RecordingHapticGeneratorFactory()
        let output = UIKitGameplayHapticOutput(
            capability: FixedHapticCapability(supportsHaptics: true),
            generatorFactory: generators
        )

        output.play(.strongSuccess)

        #expect(generators.notification.feedbacks == [.success])
    }

    @Test func unsupportedHardwareDoesNotAllocateOrPlayGenerators() {
        let generators = RecordingHapticGeneratorFactory()
        let output = UIKitGameplayHapticOutput(
            capability: FixedHapticCapability(supportsHaptics: false),
            generatorFactory: generators
        )

        output.play(.lightImpact)
        output.play(.mediumImpact)
        output.play(.warning)
        output.play(.strongSuccess)

        #expect(generators.createdImpactStyles.isEmpty)
        #expect(generators.createdNotificationGeneratorCount == 0)
        #expect(generators.lightImpact.impactCount == 0)
        #expect(generators.mediumImpact.impactCount == 0)
        #expect(generators.notification.feedbacks.isEmpty)
    }

    @Test func defaultInitDoesNotCrashAndPlaysAllKindsWithoutThrowing() {
        // The default init uses CoreHapticsCapabilityProvider which queries
        // CHHapticEngine.capabilitiesForHardware().supportsHaptics. On the
        // simulator this may return false, in which case generators are nil
        // and play() is a no-op. Either way, init and play must not crash.
        let output = UIKitGameplayHapticOutput()

        output.play(.lightImpact)
        output.play(.mediumImpact)
        output.play(.warning)
        output.play(.strongSuccess)
    }

    @Test func realGeneratorFactoryCreatesAndPlaysAllKindsWhenCapabilityIsTrue() {
        // Use the default UIKitHapticGeneratorFactory (private to the file)
        // by injecting only a capability that reports true. This exercises
        // UIKitHapticGeneratorFactory, UIKitImpactHapticGenerator, and
        // UIKitNotificationHapticGenerator on the simulator.
        let output = UIKitGameplayHapticOutput(
            capability: FixedHapticCapability(supportsHaptics: true)
        )

        output.play(.lightImpact)
        output.play(.mediumImpact)
        output.play(.warning)
        output.play(.strongSuccess)
    }
}

private final class FixedHapticCapability: HapticCapabilityProviding {
    let supportsHaptics: Bool

    init(supportsHaptics: Bool) {
        self.supportsHaptics = supportsHaptics
    }
}

private final class RecordingHapticGeneratorFactory: HapticGeneratorFactory {
    let lightImpact = RecordingImpactGenerator()
    let mediumImpact = RecordingImpactGenerator()
    let notification = RecordingNotificationGenerator()

    private(set) var createdImpactStyles: [HapticImpactStyle] = []
    private(set) var createdNotificationGeneratorCount = 0

    func makeImpactGenerator(style: HapticImpactStyle) -> HapticImpactGenerating {
        createdImpactStyles.append(style)

        switch style {
        case .light:
            return lightImpact
        case .medium:
            return mediumImpact
        }
    }

    func makeNotificationGenerator() -> HapticNotificationGenerating {
        createdNotificationGeneratorCount += 1
        return notification
    }
}

private final class RecordingImpactGenerator: HapticImpactGenerating {
    private(set) var impactCount = 0

    func prepare() {}

    func impactOccurred() {
        impactCount += 1
    }
}

private final class RecordingNotificationGenerator: HapticNotificationGenerating {
    private(set) var feedbacks: [HapticNotificationFeedback] = []

    func prepare() {}

    func notificationOccurred(_ feedback: HapticNotificationFeedback) {
        feedbacks.append(feedback)
    }
}
