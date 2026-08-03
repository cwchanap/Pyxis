//
//  AVAudioEngineGameplayAudioBackend.swift
//  Pyxis
//

import AVFoundation
import Foundation

final class AVAudioPreparedSound: GameplayPreparedSound {
    let id: GameplaySoundID
    fileprivate let buffer: AVAudioPCMBuffer

    init(id: GameplaySoundID, buffer: AVAudioPCMBuffer) {
        self.id = id
        self.buffer = buffer
    }
}

final class AVAudioEngineGameplayAudioBackend: GameplayAudioBackend {
    private static let voiceCount = 8

    private let audioSession: AVAudioSession
    private let bundle: Bundle
    private var engine: AVAudioEngine
    private var playerNodes: [AVAudioPlayerNode]
    private var voices: [AVAudioEngineGameplayAudioVoice]
    private let notificationCenter: NotificationCenter
    private var notificationObservers: [NSObjectProtocol] = []
    private var isGraphConfigured = false

    /// Task 13 supplies these controller callbacks at the composition boundary.
    var interruptionBeganHandler: (() -> Void)?
    var interruptionEndedHandler: ((Bool) -> Void)?
    var lifecycleRecoveryHandler: (() -> Void)?

    init(
        audioSession: AVAudioSession = AVAudioSession.sharedInstance(),
        bundle: Bundle = .main,
        notificationCenter: NotificationCenter = .default
    ) {
        self.audioSession = audioSession
        self.bundle = bundle
        self.notificationCenter = notificationCenter

        let engine = AVAudioEngine()
        self.engine = engine

        let playerNodes = Self.makePlayerNodes()
        self.playerNodes = playerNodes
        voices = Self.makeVoices(from: playerNodes)

        registerForAudioSessionLifecycleNotifications()
    }

    deinit {
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
    }

    func configureAmbientSession() throws {
        try audioSession.setCategory(.ambient, mode: .default, options: [])
    }

    func setSessionActive(_ active: Bool, notifyOthers: Bool) throws {
        let options: AVAudioSession.SetActiveOptions = notifyOthers
            ? [.notifyOthersOnDeactivation]
            : []
        try audioSession.setActive(active, options: options)
    }

    func prepareSound(_ resource: GameplaySoundResource) throws -> GameplayPreparedSound {
        guard let resourceURL = bundle.url(
            forResource: resource.resourceName,
            withExtension: resource.fileExtension
        ) else {
            throw PreparationError.missingResource(resource.resourceName)
        }

        let audioFile = try AVAudioFile(forReading: resourceURL)
        guard audioFile.length > 0,
              audioFile.length <= AVAudioFramePosition(UInt32.max),
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: audioFile.processingFormat,
                  frameCapacity: AVAudioFrameCount(audioFile.length)
              )
        else {
            throw PreparationError.invalidFrameCount(resource.resourceName)
        }

        try audioFile.read(into: buffer)
        return AVAudioPreparedSound(id: resource.id, buffer: buffer)
    }

    func makeVoice(index: Int) -> GameplayAudioVoice {
        precondition(voices.indices.contains(index), "Gameplay audio voice index is out of range")
        configureGraphIfNeeded()
        return voices[index]
    }

    func startEngine() throws {
        guard !engine.isRunning else {
            return
        }

        try engine.start()
    }

    func stopEngine() {
        for playerNode in playerNodes {
            playerNode.stop()
        }
        engine.stop()
    }

    func resetForLifecycleRecovery() {
        stopEngine()
        engine.reset()

        // Media-services reset invalidates the old audio objects. This method is called only
        // from Task 6's serialized output boundary, so clearing the old references before
        // installing this fully configured replacement graph cannot expose a mixed graph.
        voices = []
        playerNodes = []
        engine = AVAudioEngine()

        let replacementNodes = Self.makePlayerNodes()
        playerNodes = replacementNodes
        voices = Self.makeVoices(from: replacementNodes)
        isGraphConfigured = false
        configureGraphIfNeeded()
    }

    private func registerForAudioSessionLifecycleNotifications() {
        notificationObservers = [
            notificationCenter.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: audioSession,
                queue: nil
            ) { [weak self] notification in
                self?.handleInterruption(notification)
            },
            notificationCenter.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: audioSession,
                queue: nil
            ) { [weak self] _ in
                self?.lifecycleRecoveryHandler?()
            }
        ]
    }

    private func configureGraphIfNeeded() {
        guard !isGraphConfigured else {
            return
        }

        for playerNode in playerNodes {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        }

        isGraphConfigured = true
    }

    private static func makePlayerNodes() -> [AVAudioPlayerNode] {
        (0..<voiceCount).map { _ in
            AVAudioPlayerNode()
        }
    }

    private static func makeVoices(
        from playerNodes: [AVAudioPlayerNode]
    ) -> [AVAudioEngineGameplayAudioVoice] {
        playerNodes.enumerated().map { index, playerNode in
            AVAudioEngineGameplayAudioVoice(index: index, playerNode: playerNode)
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return
        }

        switch interruptionType {
        case .began:
            interruptionBeganHandler?()

        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            interruptionEndedHandler?(options.contains(.shouldResume))

        @unknown default:
            break
        }
    }

    private enum PreparationError: Error {
        case missingResource(String)
        case invalidFrameCount(String)
    }
}

private final class AVAudioEngineGameplayAudioVoice: GameplayAudioVoice {
    let index: Int
    private let playerNode: AVAudioPlayerNode

    init(index: Int, playerNode: AVAudioPlayerNode) {
        self.index = index
        self.playerNode = playerNode
    }

    func schedule(_ sound: GameplayPreparedSound, completion: @escaping () -> Void) {
        guard let preparedSound = sound as? AVAudioPreparedSound else {
            completion()
            return
        }

        playerNode.scheduleBuffer(
            preparedSound.buffer,
            at: nil,
            options: [],
            completionCallbackType: .dataPlayedBack
        ) { _ in
            completion()
        }
        playerNode.play()
    }

    func stop() {
        playerNode.stop()
    }
}
