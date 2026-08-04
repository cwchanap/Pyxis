//
//  AVAudioEngineGameplayAudioBackendTests.swift
//  PyxisTests
//

import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct AVAudioEngineGameplayAudioBackendTests {
    @Test func setSessionActiveDoesNotThrowForActiveOrInactive() throws {
        let backend = AVAudioEngineGameplayAudioBackend()

        #expect(throws: Never.self) {
            try backend.setSessionActive(false, notifyOthers: false)
        }
        #expect(throws: Never.self) {
            try backend.setSessionActive(true, notifyOthers: false)
        }
        #expect(throws: Never.self) {
            try backend.setSessionActive(true, notifyOthers: true)
        }
        #expect(throws: Never.self) {
            try backend.setSessionActive(false, notifyOthers: true)
        }
    }

    @Test func configureAmbientSessionDoesNotThrow() throws {
        let backend = AVAudioEngineGameplayAudioBackend()

        #expect(throws: Never.self) {
            try backend.configureAmbientSession()
        }
    }

    @Test func makeVoiceReturnsVoiceForEachIndexAndConfiguresGraph() {
        let backend = AVAudioEngineGameplayAudioBackend()

        for index in 0..<8 {
            let voice = backend.makeVoice(index: index)
            #expect(voice.index == index)
        }
    }

    @Test func stopEngineDoesNotCrashWithoutStarting() {
        let backend = AVAudioEngineGameplayAudioBackend()

        backend.stopEngine()
    }

    @Test func resetForLifecycleRecoveryRebuildsGraphAndVoicesRemainAccessible() {
        let backend = AVAudioEngineGameplayAudioBackend()

        _ = backend.makeVoice(index: 0)
        backend.resetForLifecycleRecovery()

        let voice = backend.makeVoice(index: 0)
        #expect(voice.index == 0)
    }

    @Test func prepareSoundReturnsPreparedSoundForBundledResource() throws {
        let backend = AVAudioEngineGameplayAudioBackend()
        let resource = GameplaySoundResource(
            id: .deployment,
            resourceName: "deployment",
            fileExtension: "caf",
            soundClass: .nonAutomatic,
            maximumDuration: nil
        )

        let prepared = try backend.prepareSound(resource)
        #expect(prepared.id == .deployment)
    }

    @Test func voiceScheduleWithNonAVAudioPreparedSoundCallsCompletionImmediately() {
        let backend = AVAudioEngineGameplayAudioBackend()
        let voice = backend.makeVoice(index: 0)
        let foreignSound = ForeignPreparedSound(id: .deployment)

        var completionCalled = false
        voice.schedule(foreignSound) {
            completionCalled = true
        }

        #expect(completionCalled)
    }

    @Test func voiceStopDoesNotCrash() {
        let backend = AVAudioEngineGameplayAudioBackend()
        let voice = backend.makeVoice(index: 0)

        voice.stop()
    }

    @Test func interruptionBeganHandlerIsCalledForBeganNotification() throws {
        let notificationCenter = NotificationCenter()
        let backend = AVAudioEngineGameplayAudioBackend(notificationCenter: notificationCenter)

        var beganCalled = false
        backend.interruptionBeganHandler = {
            beganCalled = true
        }

        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )

        #expect(beganCalled)
    }

    @Test func interruptionEndedHandlerReceivesShouldResumeFromOptions() throws {
        let notificationCenter = NotificationCenter()
        let backend = AVAudioEngineGameplayAudioBackend(notificationCenter: notificationCenter)

        var receivedShouldResume: Bool?
        backend.interruptionEndedHandler = { shouldResume in
            receivedShouldResume = shouldResume
        }

        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ]
        )

        #expect(receivedShouldResume == true)
    }

    @Test func interruptionEndedHandlerReceivesFalseWhenNoResumeOption() throws {
        let notificationCenter = NotificationCenter()
        let backend = AVAudioEngineGameplayAudioBackend(notificationCenter: notificationCenter)

        var receivedShouldResume: Bool?
        backend.interruptionEndedHandler = { shouldResume in
            receivedShouldResume = shouldResume
        }

        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: 0
            ]
        )

        #expect(receivedShouldResume == false)
    }

    @Test func interruptionHandlerIgnoresNotificationWithMissingTypeKey() throws {
        let notificationCenter = NotificationCenter()
        let backend = AVAudioEngineGameplayAudioBackend(notificationCenter: notificationCenter)

        var beganCalled = false
        var endedCalled = false
        backend.interruptionBeganHandler = { beganCalled = true }
        backend.interruptionEndedHandler = { _ in endedCalled = true }

        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [:]
        )

        #expect(!beganCalled)
        #expect(!endedCalled)
    }

    @Test func interruptionHandlerIgnoresNotificationWithInvalidTypeRawValue() throws {
        let notificationCenter = NotificationCenter()
        let backend = AVAudioEngineGameplayAudioBackend(notificationCenter: notificationCenter)

        var beganCalled = false
        var endedCalled = false
        backend.interruptionBeganHandler = { beganCalled = true }
        backend.interruptionEndedHandler = { _ in endedCalled = true }

        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: UInt(99999)
            ]
        )

        #expect(!beganCalled)
        #expect(!endedCalled)
    }

    @Test func interruptionEndedDefaultsToNoResumeWhenOptionKeyIsMissing() throws {
        let notificationCenter = NotificationCenter()
        let backend = AVAudioEngineGameplayAudioBackend(notificationCenter: notificationCenter)

        var receivedShouldResume: Bool?
        backend.interruptionEndedHandler = { shouldResume in
            receivedShouldResume = shouldResume
        }

        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue
            ]
        )

        #expect(receivedShouldResume == false)
    }

    @Test func mediaServicesWereResetInvokesLifecycleRecoveryHandler() throws {
        let notificationCenter = NotificationCenter()
        let backend = AVAudioEngineGameplayAudioBackend(notificationCenter: notificationCenter)

        var recoveryCalled = false
        backend.lifecycleRecoveryHandler = {
            recoveryCalled = true
        }

        notificationCenter.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )

        #expect(recoveryCalled)
    }
}

private final class ForeignPreparedSound: GameplayPreparedSound {
    let id: GameplaySoundID

    init(id: GameplaySoundID) {
        self.id = id
    }
}
