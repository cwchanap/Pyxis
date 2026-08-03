//
//  GameplayAudioBackend.swift
//  Pyxis
//

protocol GameplayPreparedSound: AnyObject {
    var id: GameplaySoundID { get }
}

protocol GameplayAudioVoice: AnyObject {
    var index: Int { get }

    func schedule(_ sound: GameplayPreparedSound)
    func stop()
}

protocol GameplayAudioBackend: AnyObject {
    func configureAmbientSession() throws
    func setSessionActive(_ active: Bool, notifyOthers: Bool) throws
    func prepareSound(_ resource: GameplaySoundResource) throws -> GameplayPreparedSound
    func makeVoice(index: Int) -> GameplayAudioVoice
    func startEngine() throws
    func stopEngine()
}
