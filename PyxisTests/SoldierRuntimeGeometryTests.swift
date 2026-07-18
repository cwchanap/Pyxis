import SpriteKit
import Testing
import UIKit

@testable import Pyxis

@MainActor
struct SoldierRuntimeGeometryTests {
    @Test func infantryBodySizeRemainsFixedDuringRenderedWalkAndAttack() async throws {
        let suiteName = "PyxisRuntimeGeometryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(slots: [1: CityBuilding(type: .barracks)])
        let state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 10_000,
            cityBattleStates: [cityKey.storageKey: cityState]
        )
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(state)

        let size = CGSize(width: 390, height: 844)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let controller = UIViewController()
        controller.view = view
        let windowScene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let previousKeyWindow = windowScene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            view.presentScene(nil)
            window.isHidden = true
            previousKeyWindow?.makeKeyAndVisible()
        }

        let scene = BattleScene(size: size, store: store, combatSeed: 1)
        view.presentScene(scene)
        try await Task.sleep(for: .milliseconds(100))
        scene.selectManualSoldierTypeForTesting(.infantry)
        scene.spawnSoldierForTesting()
        try await Task.sleep(for: .milliseconds(100))

        // The walk animation must actually be playing before we sample the walk
        // geometry, otherwise a silent no-op in the spawn path would leave the
        // static sprite under test and the size-invariance check would pass
        // without exercising walk rendering.
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        let body = try #require(scene.firstLiveSoldierBodySpriteForTesting)
        var sampledSizes = try await collectSizes(of: body, count: 30)

        scene.triggerFirstLiveSoldierAnimationForTesting("attack")
        // Likewise, confirm the attack transient installed before sampling its
        // geometry, so the attack half of the size-invariance check cannot be
        // satisfied by the still-walking (or static) sprite.
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))
        sampledSizes += try await collectSizes(of: body, count: 45)

        let widths = sampledSizes.map(\.width)
        let heights = sampledSizes.map(\.height)
        #expect((widths.max() ?? 0) - (widths.min() ?? 0) < 0.001)
        #expect((heights.max() ?? 0) - (heights.min() ?? 0) < 0.001)
    }

    private func collectSizes(of sprite: SKSpriteNode, count: Int) async throws -> [CGSize] {
        var sizes: [CGSize] = []
        for _ in 0..<count {
            sizes.append(sprite.size)
            try await Task.sleep(for: .milliseconds(20))
        }
        return sizes
    }
}
