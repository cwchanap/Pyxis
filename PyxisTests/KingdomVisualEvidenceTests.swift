import SpriteKit
import UIKit
import XCTest
@testable import Pyxis

@MainActor
final class KingdomVisualEvidenceTests: XCTestCase {
    func testArmedAscensionAt320By568() throws {
        try captureArmedAscension(size: CGSize(width: 320, height: 568), name: "kingdom-armed-320x568")
    }

    func testArmedAscensionAt264By454() throws {
        try captureArmedAscension(size: CGSize(width: 264, height: 454), name: "kingdom-armed-264x454")
    }

    private func captureArmedAscension(size: CGSize, name: String) throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PyxisTests.\(UUID().uuidString)"))
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(KingdomGameState(
            gold: 500,
            completedCityCount: KingdomGameState.firstCountryCityCount,
            stageStatus: .countryComplete,
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"]
        ))
        let scene = KingdomScene(size: size, store: store, safeAreaInsetsOverride: .zero)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        let view = SKView(frame: window.bounds)
        window.addSubview(view)
        window.isHidden = false
        view.presentScene(scene)

        let selector = try XCTUnwrap(scene.ascendSelectorHitFrameForTesting())
        scene.handleTouchForTesting(at: CGPoint(x: selector.midX, y: selector.midY))
        let action = try XCTUnwrap(scene.ascendPrimaryActionHitFrameForTesting())
        scene.handleTouchForTesting(at: CGPoint(x: action.midX, y: action.midY))
        XCTAssertTrue(scene.isAscendConfirmationArmedForTesting)
        let texture = try XCTUnwrap(view.texture(from: scene, crop: CGRect(origin: .zero, size: size)))
        let attachment = XCTAttachment(image: UIImage(cgImage: texture.cgImage()))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
    }
}
