//
//  KingdomSceneTests.swift
//  PyxisTests
//

import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct KingdomSceneTests {
    @Test func kingdomSceneShowsPersistedGold() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 123))
        let scene = makeScene(store: store)

        #expect(scene.titleTextForTesting == "Kingdom")
        #expect(scene.goldTextForTesting
            == "Gold " + CompactNumberFormatter.string(from: 123))
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }

    private func makeScene(store: KingdomGameStore) -> KingdomScene {
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }
}
