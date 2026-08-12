//
//  GameplayAudioBackend.swift
//  Pyxis
//

protocol GameplayPreparedSound: AnyObject {
    var id: GameplaySoundID { get }
}

protocol GameplayAudioVoice: AnyObject {
    var index: Int { get }

    /// Calls `completion` when this scheduled sound no longer occupies the voice.
    func schedule(
        _ sound: GameplayPreparedSound,
        completion: @escaping () -> Void
    )
    func stop()
}

protocol GameplayAudioBackend: AnyObject {
    var isEngineRunning: Bool { get }

    func configureAmbientSession() throws
    func setSessionActive(_ active: Bool, notifyOthers: Bool) throws
    func prepareSound(_ resource: GameplaySoundResource) throws -> GameplayPreparedSound
    func makeVoice(index: Int) -> GameplayAudioVoice
    func startEngine() throws
    func stopEngine()

    /// Discards invalid lifecycle-recovery state without activating the session or playing sound.
    /// The controller reconfigures and prepares a fresh output graph afterward.
    func resetForLifecycleRecovery()
}
