//
//  KingdomGameStore.swift
//  Pyxis
//

import Foundation

final class KingdomGameStore {
    static let shared = KingdomGameStore()

    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "pyxis.kingdomGameState") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> KingdomGameState {
        guard let data = defaults.data(forKey: key) else {
            return KingdomGameState()
        }

        do {
            return try decoder.decode(KingdomGameState.self, from: data)
        } catch {
            return KingdomGameState()
        }
    }

    func save(_ state: KingdomGameState) {
        guard let data = try? encoder.encode(state) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
