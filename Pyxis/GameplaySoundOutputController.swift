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
        var scheduleGeneration: UInt64?

        var isAutomaticCombat: Bool {
            soundClass == .automaticCombat
        }
    }

    private enum InterruptionState {
        case none
        case active
        case awaitingNextForeground
    }

    private let backend: GameplayAudioBackend
    private let catalog: [GameplaySoundID: GameplaySoundResource]
    private let clock: MonotonicClock
    private let backendQueue = DispatchQueue(label: "com.pyxis.gameplay-audio-backend")
    private let outputQueue = DispatchQueue(label: "com.pyxis.gameplay-sound-output")

    // All mutable controller state is owned exclusively by `outputQueue`.
    // Every mutating `GameplayAudioBackend` call (graph rebuild, engine
    // start/stop, session activation, voice creation, sound preparation, and
    // lifecycle reset) is routed through the single serial `backendQueue` so
    // no two backend mutations can overlap — in particular a media-services
    // reset can never replace the engine/playerNodes/voices graph while a
    // background or interruption event on `outputQueue` calls stopEngine().
    private var preparationState: SoundPreparationState = .unprepared
    private var preparedSounds: [GameplaySoundID: GameplayPreparedSound] = [:]
    private var voiceSlots: [VoiceSlot] = []
    private var preparationGeneration: UInt64 = 0
    private var nextVoiceScheduleGeneration: UInt64 = 0
    private var isOutputActive = false
    private var nextActivationAttemptAt: TimeInterval?
    private var isAppInForeground = true
    private var interruptionState: InterruptionState = .none

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

    func handleAppDidEnterBackground() {
        outputQueue.async { [weak self] in
            guard let self else {
                return
            }

            isAppInForeground = false
            stopAllAndDeactivateOnOutputQueue()
        }
    }

    func handleAppWillEnterForeground() {
        outputQueue.async { [weak self] in
            guard let self else {
                return
            }

            isAppInForeground = true
            if case .awaitingNextForeground = interruptionState {
                interruptionState = .none
            }
            nextActivationAttemptAt = nil
            beginPreparationIfNeeded()
        }
    }

    func handleAudioInterruptionBegan() {
        outputQueue.async { [weak self] in
            guard let self else {
                return
            }

            interruptionState = .active
            stopAllAndDeactivateOnOutputQueue()
        }
    }

    func handleAudioInterruptionEnded(shouldResume: Bool) {
        outputQueue.async { [weak self] in
            guard let self else {
                return
            }

            if shouldResume {
                interruptionState = .none
                nextActivationAttemptAt = nil
                beginPreparationIfNeeded()
            } else if case .active = interruptionState {
                // A non-resumable interruption drops every current event. A
                // later app foreground is the explicit policy that releases
                // this block; preparation remains cached in the meantime.
                interruptionState = .awaitingNextForeground
            }
        }
    }

    func handleLifecycleRecovery() {
        outputQueue.async { [weak self] in
            guard let self else {
                return
            }

            isOutputActive = false
            nextActivationAttemptAt = nil

            preparationGeneration &+= 1

            if case .ready = preparationState {
                invalidateReadyOutputForLifecycleRecovery()
            }

            // Serialize the backend reset through the shared backendQueue so it
            // never overlaps any other backend mutation (stopEngine,
            // setSessionActive, startEngine, makeVoice, or an in-flight
            // prepareSound).  When recovery arrives during .preparing the reset
            // waits behind the stale preparation work; the generation bump
            // above already invalidates its stale completion.
            let backend = self.backend
            backendQueue.async { [weak self] in
                backend.resetForLifecycleRecovery()
                self?.outputQueue.async { [weak self] in
                    guard let self else { return }
                    preparationState = .unprepared
                    beginPreparationIfNeeded()
                }
            }
        }
    }

    private func beginPreparationIfNeeded() {
        switch preparationState {
        case .ready, .preparing:
            return
        case .unprepared, .failed:
            break
        }

        preparationGeneration &+= 1
        let generation = preparationGeneration
        preparationState = .preparing

        do {
            try backendQueue.sync {
                try backend.configureAmbientSession()
            }
        } catch {
            preparationState = .failed
            log("Gameplay sound session configuration failed: \(error)")
            return
        }

        let resources = catalog.values.sorted { lhs, rhs in
            lhs.id.rawValue < rhs.id.rawValue
        }

        backendQueue.async { [weak self, backend, resources] in
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
                    self?.finishPreparationFailure(message: message, generation: generation)
                }
                return
            }

            self?.outputQueue.async { [weak self, completedCatalog] in
                self?.finishPreparation(with: completedCatalog, generation: generation)
            }
        }
    }

    private func finishPreparation(
        with completedCatalog: [GameplaySoundID: GameplayPreparedSound],
        generation: UInt64
    ) {
        guard case .preparing = preparationState,
              generation == preparationGeneration
        else {
            return
        }

        // Create voices asynchronously on the backend queue so the output
        // queue is not blocked during voice creation.  A play request that
        // arrives in that window sees preparation still .preparing and is
        // dropped by playReadySound rather than queued for post-readiness
        // scheduling.  The generation is revalidated after creation completes
        // so a lifecycle recovery or retry that bumped it discards the stale
        // voices instead of publishing them.
        backendQueue.async { [weak self, backend, completedCatalog] in
            let voices: [GameplayAudioVoice] = (0..<Self.voiceCount).map { index in
                backend.makeVoice(index: index)
            }

            self?.outputQueue.async { [weak self, voices, completedCatalog, generation] in
                guard let self else { return }
                guard case .preparing = preparationState,
                      generation == preparationGeneration
                else {
                    return
                }

                let slots = voices.enumerated().map { index, voice in
                    VoiceSlot(
                        index: index,
                        voice: voice,
                        scheduledAt: nil,
                        soundClass: nil,
                        scheduleGeneration: nil
                    )
                }

                // The complete catalog is built off-queue and assigned only once all resources succeed.
                preparedSounds = completedCatalog
                voiceSlots = slots
                preparationState = .ready
            }
        }
    }

    private func finishPreparationFailure(message: String, generation: UInt64) {
        guard case .preparing = preparationState,
              generation == preparationGeneration
        else {
            return
        }

        preparedSounds = [:]
        voiceSlots = []
        preparationState = .failed
        log(message)
    }

    private func playReadySound(_ soundID: GameplaySoundID, soundClass: GameplaySoundClass) {
        guard isOutputEligible else {
            return
        }

        guard case .ready = preparationState,
              let preparedSound = preparedSounds[soundID]
        else {
            // The current event is intentionally dropped. A first-use retry may prepare a
            // previously failed/unprepared catalog, but never queues the dropped event.
            beginPreparationIfNeeded()
            return
        }

        let activationAttemptAt = clock.now
        if let nextActivationAttemptAt, activationAttemptAt < nextActivationAttemptAt {
            return
        }

        guard let voiceIndex = selectVoiceIndex(for: soundClass) else {
            return
        }

        guard activateOutputIfNeeded() else {
            return
        }

        let scheduledAt = clock.now
        nextVoiceScheduleGeneration &+= 1
        let scheduleGeneration = nextVoiceScheduleGeneration

        if voiceSlots[voiceIndex].scheduledAt != nil {
            voiceSlots[voiceIndex].voice.stop()
        }

        voiceSlots[voiceIndex].scheduledAt = scheduledAt
        voiceSlots[voiceIndex].soundClass = soundClass
        voiceSlots[voiceIndex].scheduleGeneration = scheduleGeneration
        voiceSlots[voiceIndex].voice.schedule(preparedSound) { [weak self] in
            self?.outputQueue.async { [weak self] in
                self?.markVoiceIdle(at: voiceIndex, generation: scheduleGeneration)
            }
        }
    }

    private func activateOutputIfNeeded() -> Bool {
        guard isOutputEligible else {
            return false
        }

        guard !isOutputActive else {
            return true
        }

        var sessionActivated = false
        do {
            try backendQueue.sync {
                try backend.setSessionActive(true, notifyOthers: false)
                sessionActivated = true
                try backend.startEngine()
            }
            isOutputActive = true
            nextActivationAttemptAt = nil
            return true
        } catch {
            if sessionActivated {
                do {
                    try backendQueue.sync {
                        try backend.setSessionActive(false, notifyOthers: true)
                    }
                } catch {
                    log("Gameplay sound session deactivation after start failure failed: \(error)")
                }
            }

            nextActivationAttemptAt = clock.now + 1.0
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

    private func markVoiceIdle(at index: Int, generation: UInt64) {
        guard voiceSlots.indices.contains(index),
              voiceSlots[index].scheduleGeneration == generation
        else {
            return
        }

        voiceSlots[index].scheduledAt = nil
        voiceSlots[index].soundClass = nil
        voiceSlots[index].scheduleGeneration = nil
    }

    private func invalidateReadyOutputForLifecycleRecovery() {
        for index in voiceSlots.indices where voiceSlots[index].scheduledAt != nil {
            voiceSlots[index].voice.stop()
        }

        backendQueue.sync {
            backend.stopEngine()
        }
        preparedSounds = [:]
        voiceSlots = []
    }

    private func stopAllAndDeactivateOnOutputQueue() {
        for index in voiceSlots.indices where voiceSlots[index].scheduledAt != nil {
            voiceSlots[index].voice.stop()
            voiceSlots[index].scheduledAt = nil
            voiceSlots[index].soundClass = nil
            voiceSlots[index].scheduleGeneration = nil
        }

        backendQueue.sync {
            backend.stopEngine()
        }
        isOutputActive = false
        nextActivationAttemptAt = nil

        do {
            try backendQueue.sync {
                try backend.setSessionActive(false, notifyOthers: true)
            }
        } catch {
            log("Gameplay sound deactivation failed: \(error)")
        }
    }

    private var isOutputEligible: Bool {
        guard isAppInForeground else {
            return false
        }

        if case .none = interruptionState {
            return true
        }
        return false
    }

    private func log(_ message: String) {
        NSLog("%@", message)
    }

    private enum PreparationError: Error {
        case mismatchedPreparedSoundID
    }
}

#if DEBUG
extension GameplaySoundOutputController {
    /// Creates a deterministic happens-before edge for tests that need every
    /// previously enqueued output operation to finish before inspecting state.
    /// Calling this from the output queue would deadlock, so reject that use.
    func drainOutputQueueForTesting() {
        dispatchPrecondition(condition: .notOnQueue(outputQueue))
        outputQueue.sync {}
    }
}
#endif
