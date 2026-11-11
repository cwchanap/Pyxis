import SpriteKit
import UIKit
import XCTest
@testable import Pyxis

@MainActor
final class BattleFormationVisualEvidenceTests: XCTestCase {
    func testDenseGateAtCompactPortrait() throws {
        try capture(size: CGSize(width: 393, height: 700), name: "dense-gate-393x700")
    }

    func testDenseGateAtReferencePortrait() throws {
        try capture(size: CGSize(width: 393, height: 852), name: "dense-gate-393x852")
    }

    private func capture(size: CGSize, name: String) throws {
        var state = KingdomGameState(cityNumberInCountry: 15, completedCityCount: 14)
        state.siegeProgress.selectedLane = .right
        state.siegeProgress.captain = VanguardCaptainProgress(
            lane: .left,
            remainingHP: 0,
            recoveryRemainingSeconds: VanguardCaptainRules.recoverySeconds,
            rallyConsumed: false
        )
        let layout = state.currentSiegeLayout
        let tower = try XCTUnwrap(layout.objectives.first { $0.kind == .arrowTower })
        let gate = try XCTUnwrap(layout.objectives.first { $0.kind == .gate && $0.visualLane == .right })
        let maximums = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)
        state.siegeProgress.damageByObjectiveID[tower.id] = maximums[tower.id]
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PyxisTests.\(UUID().uuidString)"))
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(state)
        let scene = BattleScene(size: size, store: store, router: nil, combatSeed: 1)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        let view = SKView(frame: window.bounds)
        window.addSubview(view)
        window.isHidden = false
        view.presentScene(scene)
        scene.dismissMilestoneArrivalForTesting()
        scene.spawnManualSoldiersDirectlyForTesting(9)
        scene.advanceCombatForTesting(deltaTime: 3)
        XCTAssertEqual(scene.soldierLanePlacementsForTesting.count, 9)
        XCTAssertGreaterThan(scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gate.id, default: 0], 0)
        let texture = try XCTUnwrap(view.texture(from: scene, crop: CGRect(origin: .zero, size: size)))
        let attachment = XCTAttachment(image: UIImage(cgImage: texture.cgImage()))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
    }
}
