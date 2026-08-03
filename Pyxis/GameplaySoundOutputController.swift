//
//  GameplaySoundOutputController.swift
//  Pyxis
//

import Foundation

enum SoundPreparationState: Equatable {
    case unprepared
    case preparing
    case ready
    case failed
}

final class GameplaySoundOutputController: GameplaySoundOutput {
    private static let voiceCount = 8
    private static let automaticVoiceIndices = 0..<6
    private static let protectedVoiceIndices = 6..<8

    private struct VoiceSlot {
        let index: Int
        let voice: GameplayAudioVoice
        var scheduledAt: TimeInterval?
        var soundClass: GameplaySoundClass?

        var isAutomaticCombat: Bool {
            soundClass == .automaticCombat
        }
    }

    private let backend: GameplayAudioBackend
    private let catalog: [GameplaySoundID: GameplaySoundResource]
    private let clock: MonotonicClock
    private let preparationQueue = DispatchQueue(label: "com.pyxis.gameplay-sound-preparation")
    private let outputQueue = DispatchQueue(label: "com.pyxis.gameplay-sound-output")

    // All mutable controller state is owned exclusively by `outputQueue`.
    private var preparationState: SoundPreparationState = .unprepared
    private var preparedSounds: [GameplaySoundID: GameplayPreparedSound] = [:]
    private var voiceSlots: [VoiceSlot] = []
    private var isOutputActive = false
    private var nextActivationAttemptAt: TimeInterval?

    init(
        backend: GameplayAudioBackend,
        catalog: [GameplaySoundID: GameplaySoundResource],
        clock: MonotonicClock
    ) {
        self.backend = backend
        self.catalog = catalog
        self.clock = clock
    }

    func prepareIfNeeded() {
        outputQueue.async { [weak self] in
            self?.beginPreparationIfNeeded()
        }
    }

    func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass) {
        outputQueue.async { [weak self] in
            self?.playReadySound(sound, soundClass: soundClass)
        }
    }

    func stopAllAndDeactivate() {
        outputQueue.async { [weak self] in
            self?.stopAllAndDeactivateOnOutputQueue()
        }
    }

    func handleLifecycleRecovery() {
        outputQueue.async { [weak self] in
            guard let self else {
                return
            }

            // The lifecycle owner stopped the engine on background/interruption.
            // Do not activate here; the next ready, eligible sound owns that work.
            isOutputActive = false
            nextActivationAttemptAt = nil
            beginPreparationIfNeeded()
        }
    }

    private func beginPreparationIfNeeded() {
        guard preparationState != .ready, preparationState != .preparing else {
            return
        }

        preparationState = .preparing

        do {
            try backend.configureAmbientSession()
        } catch {
            preparationState = .failed
            log("Gameplay sound session configuration failed: \(error)")
            return
        }

        let resources = catalog.values.sorted { lhs, rhs in
            lhs.id.rawValue < rhs.id.rawValue
        }
        let backend = backend

        preparationQueue.async { [weak self, backend, resources] in
            var completedCatalog: [GameplaySoundID: GameplayPreparedSound] = [:]

            do {
                for resource in resources {
                    let preparedSound = try backend.prepareSound(resource)
                    guard preparedSound.id == resource.id else {
                        throw PreparationError.mismatchedPreparedSoundID
                    }
                    completedCatalog[resource.id] = preparedSound
                }
            } catch {
                let message = "Gameplay sound preparation failed: \(error)"
                self?.outputQueue.async { [weak self] in
                    self?.finishPreparationFailure(message: message)
                }
                return
            }

            self?.outputQueue.async { [weak self, completedCatalog] in
                self?.finishPreparation(with: completedCatalog)
            }
        }
    }

    private func finishPreparation(with completedCatalog: [GameplaySoundID: GameplayPreparedSound]) {
        guard preparationState == .preparing else {
            return
        }

        let slots = (0..<Self.voiceCount).map { index in
            VoiceSlot(
                index: index,
                voice: backend.makeVoice(index: index),
                scheduledAt: nil,
                soundClass: nil
            )
        }

        // The complete catalog is built off-queue and assigned only once all resources succeed.
        preparedSounds = completedCatalog
        voiceSlots = slots
        preparationState = .ready
    }

    private func finishPreparationFailure(message: String) {
        guard preparationState == .preparing else {
            return
        }

        preparedSounds = [:]
        voiceSlots = []
        preparationState = .failed
        log(message)
    }

    private func playReadySound(_ soundID: GameplaySoundID, soundClass: GameplaySoundClass) {
        guard preparationState == .ready,
              let preparedSound = preparedSounds[soundID]
        else {
            // The current event is intentionally dropped. A first-use retry may prepare a
            // previously failed/unprepared catalog, but never queues the dropped event.
            beginPreparationIfNeeded()
            return
        }

        let now = clock.now
        if let nextActivationAttemptAt, now < nextActivationAttemptAt {
            return
        }

        guard let voiceIndex = selectVoiceIndex(for: soundClass) else {
            return
        }

        guard activateOutputIfNeeded(at: now) else {
            return
        }

        if voiceSlots[voiceIndex].scheduledAt != nil {
            voiceSlots[voiceIndex].voice.stop()
        }

        voiceSlots[voiceIndex].voice.schedule(preparedSound)
        voiceSlots[voiceIndex].scheduledAt = now
        voiceSlots[voiceIndex].soundClass = soundClass
    }

    private func activateOutputIfNeeded(at now: TimeInterval) -> Bool {
        guard !isOutputActive else {
            return true
        }

        var sessionActivated = false
        do {
            try backend.setSessionActive(true, notifyOthers: false)
            sessionActivated = true
            try backend.startEngine()
            isOutputActive = true
            nextActivationAttemptAt = nil
            return true
        } catch {
            if sessionActivated {
                do {
                    try backend.setSessionActive(false, notifyOthers: true)
                } catch {
                    log("Gameplay sound session deactivation after start failure failed: \(error)")
                }
            }

            nextActivationAttemptAt = now + 1.0
            log("Gameplay sound activation failed: \(error)")
            return false
        }
    }

    private func selectVoiceIndex(for soundClass: GameplaySoundClass) -> Int? {
        switch soundClass {
        case .automaticCombat:
            return idleVoiceIndex(in: Self.automaticVoiceIndices)
                ?? oldestAutomaticVoiceIndex(in: Self.automaticVoiceIndices)

        case .nonAutomatic:
            return idleVoiceIndex(in: Self.protectedVoiceIndices)
                ?? idleVoiceIndex(in: 0..<Self.voiceCount)
                ?? oldestAutomaticVoiceIndex(in: 0..<Self.voiceCount)
        }
    }

    private func idleVoiceIndex(in indices: Range<Int>) -> Int? {
        for index in indices where voiceSlots[index].scheduledAt == nil {
            return index
        }
        return nil
    }

    private func oldestAutomaticVoiceIndex(in indices: Range<Int>) -> Int? {
        var selectedIndex: Int?

        for index in indices {
            let candidate = voiceSlots[index]
            guard candidate.isAutomaticCombat,
                  let candidateScheduledAt = candidate.scheduledAt
            else {
                continue
            }

            guard let existingIndex = selectedIndex,
                  let existingScheduledAt = voiceSlots[existingIndex].scheduledAt
            else {
                selectedIndex = index
                continue
            }

            if candidateScheduledAt < existingScheduledAt ||
                (candidateScheduledAt == existingScheduledAt && candidate.index < existingIndex) {
                selectedIndex = index
            }
        }

        return selectedIndex
    }

    private func stopAllAndDeactivateOnOutputQueue() {
        for index in voiceSlots.indices where voiceSlots[index].scheduledAt != nil {
            voiceSlots[index].voice.stop()
            voiceSlots[index].scheduledAt = nil
            voiceSlots[index].soundClass = nil
        }

        backend.stopEngine()
        isOutputActive = false
        nextActivationAttemptAt = nil

        do {
            try backend.setSessionActive(false, notifyOthers: true)
        } catch {
            log("Gameplay sound deactivation failed: \(error)")
        }
    }

    private func log(_ message: String) {
        NSLog("%@", message)
    }

    private enum PreparationError: Error {
        case mismatchedPreparedSoundID
    }
}
