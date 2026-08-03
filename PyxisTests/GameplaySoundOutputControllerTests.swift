//
//  GameplaySoundOutputControllerTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

@MainActor
struct GameplaySoundOutputControllerTests {
    @Test func preparationReturnsBeforeBlockedDecodingCompletes() async throws {
        let backend = RecordingAudioBackend(blockingPreparationCall: 1)
        let controller = makeController(backend: backend)

        let startedAt = ProcessInfo.processInfo.systemUptime
        controller.prepareIfNeeded()
        let returnedAt = ProcessInfo.processInfo.systemUptime

        #expect(returnedAt - startedAt < 0.050)
        #expect(backend.waitForBlockedPreparation())
        #expect(backend.createdVoiceIndices.isEmpty)

        backend.releaseBlockedPreparation()
        try await waitUntil { backend.createdVoiceIndices == Array(0...7) }
    }

    @Test func preReadinessEventsAreDroppedAndNeverReplayAfterPreparation() async throws {
        let backend = RecordingAudioBackend(blockingPreparationCall: 1)
        let controller = makeController(backend: backend)

        controller.prepareIfNeeded()
        controller.play(.deployment, soundClass: .nonAutomatic)

        #expect(backend.waitForBlockedPreparation())
        backend.releaseBlockedPreparation()
        try await waitUntil { backend.createdVoiceIndices == Array(0...7) }

        #expect(backend.scheduledSoundIDs.isEmpty)

        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs == [.deployment] }
    }

    @Test func preparationPublishesNoPartialCatalogBeforeEveryResourceSucceeds() async throws {
        let backend = RecordingAudioBackend(blockingPreparationCall: 2)
        let controller = makeController(backend: backend, catalog: partialCatalog)

        controller.prepareIfNeeded()
        controller.play(.deployment, soundClass: .nonAutomatic)

        #expect(backend.waitForBlockedPreparation())
        #expect(backend.preparedResourceIDs.count == 2)
        #expect(backend.createdVoiceIndices.isEmpty)
        #expect(backend.scheduledSoundIDs.isEmpty)

        backend.releaseBlockedPreparation()
        try await waitUntil { backend.createdVoiceIndices == Array(0...7) }

        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs == [.deployment] }
    }

    @Test func firstReadyPlaybackActivatesAndStartsOnlyOnce() async throws {
        let backend = RecordingAudioBackend()
        let controller = try await preparedController(backend: backend)

        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs == [.deployment] }

        controller.play(.attackMelee, soundClass: .automaticCombat)
        try await waitUntil { backend.scheduledSoundIDs == [.deployment, .attackMelee] }

        #expect(backend.activeSessionRequests == [.init(active: true, notifyOthers: false)])
        #expect(backend.engineStartCount == 1)
    }

    @Test func activationFailureDropsEventAndSuppressesRetriesForExactlyOneSecond() async throws {
        let backend = RecordingAudioBackend(activationFailuresRemaining: 1)
        let clock = MutableMonotonicClock(now: 10)
        let controller = try await preparedController(backend: backend, clock: clock)

        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.activeSessionRequests.count == 1 }
        #expect(backend.scheduledSoundIDs.isEmpty)

        clock.setNow(10.999)
        controller.play(.deployment, soundClass: .nonAutomatic)
        try await settleOutput()
        #expect(backend.activeSessionRequests.count == 1)
        #expect(backend.scheduledSoundIDs.isEmpty)

        clock.setNow(11)
        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs == [.deployment] }

        #expect(
            backend.activeSessionRequests == [
                .init(active: true, notifyOthers: false),
                .init(active: true, notifyOthers: false)
            ]
        )
    }

    @Test func lifecycleRecoveryClearsActivationCooldownForAnImmediateRetry() async throws {
        let backend = RecordingAudioBackend(activationFailuresRemaining: 1)
        let clock = MutableMonotonicClock(now: 20)
        let controller = try await preparedController(backend: backend, clock: clock)

        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.activeSessionRequests.count == 1 }

        clock.setNow(20.100)
        controller.handleLifecycleRecovery()
        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs == [.deployment] }

        #expect(
            backend.activeSessionRequests == [
                .init(active: true, notifyOthers: false),
                .init(active: true, notifyOthers: false)
            ]
        )
    }

    @Test func preparationCreatesExactlyEightFixedVoicesAndNeverAllocatesANinth() async throws {
        let backend = RecordingAudioBackend()
        let controller = try await preparedController(backend: backend)

        #expect(backend.createdVoiceIndices == Array(0...7))

        for _ in 0..<12 {
            controller.play(.attackMelee, soundClass: .automaticCombat)
        }
        try await waitUntil { backend.scheduledSoundIDs.count == 12 }

        #expect(backend.createdVoiceIndices == Array(0...7))
    }

    @Test func automaticCombatUsesOnlyAutomaticCapacityAndPreemptsItsOldestVoice() async throws {
        let backend = RecordingAudioBackend()
        let clock = MutableMonotonicClock(now: 0)
        let controller = try await preparedController(backend: backend, clock: clock)

        for time in 0...5 {
            clock.setNow(TimeInterval(time))
            controller.play(.attackMelee, soundClass: .automaticCombat)
            try await waitUntil { backend.scheduledSoundIDs.count == time + 1 }
        }

        clock.setNow(6)
        controller.play(.attackMelee, soundClass: .automaticCombat)
        try await waitUntil { backend.scheduledSoundIDs.count == 7 }

        #expect(backend.voiceOperations(for: 0) == [.schedule(.attackMelee), .stop, .schedule(.attackMelee)])
        #expect(backend.voiceOperations(for: 6).isEmpty)
        #expect(backend.voiceOperations(for: 7).isEmpty)
    }

    @Test func nonAutomaticEventsPreferProtectedVoicesBeforeAutomaticCapacity() async throws {
        let backend = RecordingAudioBackend()
        let controller = try await preparedController(backend: backend)

        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs.count == 1 }
        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs.count == 2 }

        #expect(backend.voiceOperations(for: 6) == [.schedule(.deployment)])
        #expect(backend.voiceOperations(for: 7) == [.schedule(.deployment)])
        for index in 0...5 {
            #expect(backend.voiceOperations(for: index).isEmpty)
        }
    }

    @Test func nonAutomaticEventPreemptsOldestAutomaticAndStopsItBeforeReuse() async throws {
        let backend = RecordingAudioBackend()
        let clock = MutableMonotonicClock(now: 0)
        let controller = try await preparedController(backend: backend, clock: clock)

        for time in 0...5 {
            clock.setNow(TimeInterval(time))
            controller.play(.attackMelee, soundClass: .automaticCombat)
            try await waitUntil { backend.scheduledSoundIDs.count == time + 1 }
        }
        for time in 6...7 {
            clock.setNow(TimeInterval(time))
            controller.play(.deployment, soundClass: .nonAutomatic)
            try await waitUntil { backend.scheduledSoundIDs.count == time + 1 }
        }

        clock.setNow(8)
        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs.count == 9 }

        #expect(backend.voiceOperations(for: 0) == [.schedule(.attackMelee), .stop, .schedule(.deployment)])
        #expect(backend.voiceOperations(for: 6) == [.schedule(.deployment)])
        #expect(backend.voiceOperations(for: 7) == [.schedule(.deployment)])
    }

    @Test func automaticCombatNeverPreemptsNonAutomaticSoundsAndFullNonAutomaticPoolDropsNewEvents() async throws {
        let backend = RecordingAudioBackend()
        let controller = try await preparedController(backend: backend)

        for expectedCount in 1...8 {
            controller.play(.deployment, soundClass: .nonAutomatic)
            try await waitUntil { backend.scheduledSoundIDs.count == expectedCount }
        }

        controller.play(.attackMelee, soundClass: .automaticCombat)
        controller.play(.deployment, soundClass: .nonAutomatic)
        try await settleOutput()

        #expect(backend.scheduledSoundIDs.count == 8)
        for index in 0...7 {
            #expect(backend.voiceOperations(for: index) == [.schedule(.deployment)])
        }
    }

    @Test func automaticPreemptionUsesTimestampThenLowerIndexAsTieBreak() async throws {
        let backend = RecordingAudioBackend()
        let clock = MutableMonotonicClock(now: 0)
        let controller = try await preparedController(backend: backend, clock: clock)

        clock.setNow(0)
        controller.play(.attackMelee, soundClass: .automaticCombat)
        try await waitUntil { backend.scheduledSoundIDs.count == 1 }

        clock.setNow(1)
        controller.play(.attackMelee, soundClass: .automaticCombat)
        controller.play(.attackMelee, soundClass: .automaticCombat)
        try await waitUntil { backend.scheduledSoundIDs.count == 3 }

        for time in 2...4 {
            clock.setNow(TimeInterval(time))
            controller.play(.attackMelee, soundClass: .automaticCombat)
            try await waitUntil { backend.scheduledSoundIDs.count == time + 2 }
        }

        clock.setNow(5)
        controller.play(.attackMelee, soundClass: .automaticCombat)
        try await waitUntil { backend.scheduledSoundIDs.count == 7 }
        #expect(backend.voiceOperations(for: 0) == [.schedule(.attackMelee), .stop, .schedule(.attackMelee)])

        clock.setNow(6)
        controller.play(.attackMelee, soundClass: .automaticCombat)
        try await waitUntil { backend.scheduledSoundIDs.count == 8 }

        #expect(backend.voiceOperations(for: 1) == [.schedule(.attackMelee), .stop, .schedule(.attackMelee)])
        #expect(backend.voiceOperations(for: 2) == [.schedule(.attackMelee)])
    }

    @Test func stopAllAndDeactivateStopsPlaybackBeforeDeactivatingTheSession() async throws {
        let backend = RecordingAudioBackend()
        let controller = try await preparedController(backend: backend)

        controller.play(.deployment, soundClass: .nonAutomatic)
        try await waitUntil { backend.scheduledSoundIDs == [.deployment] }

        controller.stopAllAndDeactivate()
        try await waitUntil { backend.activeSessionRequests.contains(where: { !$0.active }) }

        let calls = backend.calls
        let firstDeactivation = try #require(calls.firstIndex(of: .setSessionActive(false, true)))
        let engineStop = try #require(calls.firstIndex(of: .stopEngine))
        let scheduledVoiceStop = try #require(calls.firstIndex(of: .voiceStop(6)))

        #expect(scheduledVoiceStop < engineStop)
        #expect(engineStop < firstDeactivation)
    }

    private func makeController(
        backend: RecordingAudioBackend,
        catalog: [GameplaySoundID: GameplaySoundResource]? = nil,
        clock: MutableMonotonicClock = MutableMonotonicClock(now: 0)
    ) -> GameplaySoundOutputController {
        GameplaySoundOutputController(
            backend: backend,
            catalog: catalog ?? testCatalog,
            clock: clock
        )
    }

    private func preparedController(
        backend: RecordingAudioBackend,
        clock: MutableMonotonicClock = MutableMonotonicClock(now: 0)
    ) async throws -> GameplaySoundOutputController {
        let controller = makeController(backend: backend, clock: clock)
        controller.prepareIfNeeded()
        try await waitUntil { backend.createdVoiceIndices == Array(0...7) }
        return controller
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while !condition() && ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    private func settleOutput() async throws {
        try await Task.sleep(for: .milliseconds(50))
    }

    private var testCatalog: [GameplaySoundID: GameplaySoundResource] {
        [
            .deployment: GameplaySoundResource(
                id: .deployment,
                resourceName: "deployment",
                fileExtension: "caf",
                soundClass: .nonAutomatic,
                maximumDuration: nil
            ),
            .attackMelee: GameplaySoundResource(
                id: .attackMelee,
                resourceName: "attack-melee",
                fileExtension: "caf",
                soundClass: .automaticCombat,
                maximumDuration: 0.750
            )
        ]
    }

    private var partialCatalog: [GameplaySoundID: GameplaySoundResource] {
        [
            .deployment: GameplaySoundResource(
                id: .deployment,
                resourceName: "deployment",
                fileExtension: "caf",
                soundClass: .nonAutomatic,
                maximumDuration: nil
            ),
            .blocked: GameplaySoundResource(
                id: .blocked,
                resourceName: "blocked",
                fileExtension: "caf",
                soundClass: .nonAutomatic,
                maximumDuration: nil
            )
        ]
    }
}

private final class MutableMonotonicClock: MonotonicClock {
    private let lock = NSLock()
    private var value: TimeInterval

    init(now: TimeInterval) {
        value = now
    }

    var now: TimeInterval {
        withLock { value }
    }

    func setNow(_ now: TimeInterval) {
        withLock {
            value = now
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class RecordingPreparedSound: GameplayPreparedSound {
    let id: GameplaySoundID

    init(id: GameplaySoundID) {
        self.id = id
    }
}

private final class RecordingAudioBackend: GameplayAudioBackend {
    enum BackendError: Error {
        case activation
    }

    enum Call: Equatable {
        case configureAmbientSession
        case prepare(GameplaySoundID)
        case makeVoice(Int)
        case setSessionActive(Bool, Bool)
        case startEngine
        case stopEngine
        case voiceSchedule(Int, GameplaySoundID)
        case voiceStop(Int)
    }

    enum VoiceOperation: Equatable {
        case schedule(GameplaySoundID)
        case stop
    }

    struct SessionRequest: Equatable {
        let active: Bool
        let notifyOthers: Bool
    }

    private let lock = NSLock()
    private let blockingPreparationCall: Int?
    private let preparationDidBlock = DispatchSemaphore(value: 0)
    private let continuePreparation = DispatchSemaphore(value: 0)
    private var remainingActivationFailures: Int
    private var recordedCalls: [Call] = []
    private var recordedPreparedResourceIDs: [GameplaySoundID] = []
    private var recordedCreatedVoiceIndices: [Int] = []
    private var recordedVoiceOperations: [Int: [VoiceOperation]] = [:]

    init(blockingPreparationCall: Int? = nil, activationFailuresRemaining: Int = 0) {
        self.blockingPreparationCall = blockingPreparationCall
        remainingActivationFailures = activationFailuresRemaining
    }

    var calls: [Call] {
        withLock { recordedCalls }
    }

    var preparedResourceIDs: [GameplaySoundID] {
        withLock { recordedPreparedResourceIDs }
    }

    var createdVoiceIndices: [Int] {
        withLock { recordedCreatedVoiceIndices }
    }

    var scheduledSoundIDs: [GameplaySoundID] {
        withLock {
            recordedCalls.compactMap { call in
                guard case let .voiceSchedule(_, sound) = call else {
                    return nil
                }
                return sound
            }
        }
    }

    var activeSessionRequests: [SessionRequest] {
        withLock {
            recordedCalls.compactMap { call in
                guard case let .setSessionActive(active, notifyOthers) = call else {
                    return nil
                }
                return SessionRequest(active: active, notifyOthers: notifyOthers)
            }
        }
    }

    var engineStartCount: Int {
        withLock {
            recordedCalls.count { $0 == .startEngine }
        }
    }

    func voiceOperations(for index: Int) -> [VoiceOperation] {
        withLock { recordedVoiceOperations[index, default: []] }
    }

    func configureAmbientSession() throws {
        record(.configureAmbientSession)
    }

    func setSessionActive(_ active: Bool, notifyOthers: Bool) throws {
        let shouldFail = withLock { () -> Bool in
            recordedCalls.append(.setSessionActive(active, notifyOthers))
            guard active, remainingActivationFailures > 0 else {
                return false
            }
            remainingActivationFailures -= 1
            return true
        }

        if shouldFail {
            throw BackendError.activation
        }
    }

    func prepareSound(_ resource: GameplaySoundResource) throws -> GameplayPreparedSound {
        let shouldBlock = withLock { () -> Bool in
            recordedCalls.append(.prepare(resource.id))
            recordedPreparedResourceIDs.append(resource.id)
            return blockingPreparationCall == recordedPreparedResourceIDs.count
        }

        if shouldBlock {
            preparationDidBlock.signal()
            _ = continuePreparation.wait(timeout: .now() + .seconds(5))
        }

        return RecordingPreparedSound(id: resource.id)
    }

    func makeVoice(index: Int) -> GameplayAudioVoice {
        withLock {
            recordedCalls.append(.makeVoice(index))
            recordedCreatedVoiceIndices.append(index)
        }

        return RecordingAudioVoice(index: index) { [weak self] operation in
            self?.recordVoiceOperation(operation, at: index)
        }
    }

    func startEngine() throws {
        record(.startEngine)
    }

    func stopEngine() {
        record(.stopEngine)
    }

    func waitForBlockedPreparation() -> Bool {
        preparationDidBlock.wait(timeout: .now() + .seconds(1)) == .success
    }

    func releaseBlockedPreparation() {
        continuePreparation.signal()
    }

    private func record(_ call: Call) {
        withLock {
            recordedCalls.append(call)
        }
    }

    private func recordVoiceOperation(_ operation: VoiceOperation, at index: Int) {
        withLock {
            recordedVoiceOperations[index, default: []].append(operation)
            switch operation {
            case let .schedule(sound):
                recordedCalls.append(.voiceSchedule(index, sound))
            case .stop:
                recordedCalls.append(.voiceStop(index))
            }
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class RecordingAudioVoice: GameplayAudioVoice {
    let index: Int
    private let record: (RecordingAudioBackend.VoiceOperation) -> Void

    init(
        index: Int,
        record: @escaping (RecordingAudioBackend.VoiceOperation) -> Void
    ) {
        self.index = index
        self.record = record
    }

    func schedule(_ sound: GameplayPreparedSound) {
        record(.schedule(sound.id))
    }

    func stop() {
        record(.stop)
    }
}
