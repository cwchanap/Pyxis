//
//  BattleSceneCoverageTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct BattleSceneCoverageTests {
    @Test func animationTestingAccessorsRejectUnknownActions() throws {
        let scene = try makeScene(initialState: stateWithBarracks())

        #expect(scene.animationFrameNamesForTesting(soldierType: .infantry, action: "idle").isEmpty)
        #expect(scene.cachedSoldierAnimationTexturesForTesting(soldierType: .infantry, action: "idle").isEmpty)
        #expect(scene.soldierAnimationFrameDurationsForTesting(action: "idle").isEmpty)
        #expect(scene.soldierAnimationDurationForTesting(action: "idle") == 0)
    }

    @Test func liveSoldierTestingAccessorsAreSafeBeforeSpawn() throws {
        let scene = try makeScene(initialState: stateWithBarracks())

        #expect(scene.firstLiveSoldierBodyFrameForTesting == nil)
        #expect(scene.firstLiveSoldierBodySpriteForTesting == nil)
        #expect(scene.firstLiveSoldierTowerShotTargetForTesting == nil)
        #expect(scene.firstLiveSoldierBodyNameForTesting == nil)
        #expect(scene.firstLiveSoldierHitAnimationRemainingForTesting == nil)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
        #expect(!scene.firstLiveSoldierVisualMatchesForTesting(.infantry))

        scene.triggerFirstLiveSoldierAnimationForTesting("attack")
        scene.triggerFirstLiveSoldierAnimationForTesting("idle")
        scene.completeFirstLiveSoldierTransientAnimationForTesting()

        #expect(scene.soldierAttackAnimationTriggerCountForTesting == 0)
        #expect(scene.soldierHitAnimationTriggerCountForTesting == 0)
    }

    @Test func compactSceneUsesCompactSoldierTargetHeight() throws {
        let sceneSize = CGSize(width: 390, height: 480)
        let scene = try makeScene(initialState: stateWithBarracks(), size: sceneSize)

        // This short fixture cannot fit the compact battlefield and is
        // deliberately routed to the unsupported-geometry gate.
        #expect(BattleChromeLayout.compute(.init(sceneSize: sceneSize)) == nil)
        #expect(scene.battleChromeLayoutForTesting == nil)
        #expect(scene.isBattleChromeFitFailedForTesting)
        #expect(scene.battlefieldLayoutCountForTesting == 0)
        #expect(scene.castleGatePointForTesting(lane: .center) == nil)
        #expect(abs(scene.soldierBaseTargetHeightForTesting - 50) < 0.001)
    }

    @Test func supportedCompactPhoneFitsReadableSoldiersOnTwoRails() throws {
        let scene = try makeScene(
            initialState: stateWithBarracks(), size: CGSize(width: 375, height: 667)
        )
        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(layout.isCompact)
        #expect(layout.battlefield.isVisible)
        #expect(!scene.isBattleChromeFitFailedForTesting)
        scene.spawnManualSoldiersDirectlyForTesting(3)
        let members = scene.soldierPresentationsForTesting
        #expect(members.count == 3)
        #expect(members.allSatisfy { $0.position == 0 })
        let visible = members.filter { !$0.isFolded }
        #expect(visible.count == 2)
        #expect(members.filter(\.isFolded).count == 1)
        let lane = try #require(visible.first?.lane)
        #expect(members.allSatisfy { $0.lane == lane })
        let badge = try #require(scene.childNode(withName: "//soldierOverflowBadge-\(lane.rawValue)"))
        let label = try #require(badge.childNode(withName: "count") as? SKLabelNode)
        #expect(label.text == "+1")

        let fittedHeight = scene.soldierTargetHeightForTesting
        #expect(abs(scene.soldierBaseTargetHeightForTesting - 54) < 0.001)
        #expect(fittedHeight >= 30)
        #expect(fittedHeight < scene.soldierBaseTargetHeightForTesting)
        var frames: [CGRect] = []
        for member in visible {
            let root = try #require(scene.soldierRootForTesting(member.id))
            #expect(root.parent?.isHidden == false)
            let sprite = try #require(root.children.first { $0.zPosition == 1 } as? SKSpriteNode)
            let bar = try #require(root.children.compactMap { $0 as? SKShapeNode }
                .first { $0.zPosition == 2 }?.path)
            func sceneFrame(_ bounds: CGRect) -> CGRect {
                let minPoint = root.convert(CGPoint(x: bounds.minX, y: bounds.minY), to: scene)
                let maxPoint = root.convert(CGPoint(x: bounds.maxX, y: bounds.maxY), to: scene)
                return CGRect(
                    x: minPoint.x, y: minPoint.y,
                    width: maxPoint.x - minPoint.x, height: maxPoint.y - minPoint.y
                )
            }
            let body = sceneFrame(
                SoldierAnimationGeometry(type: .infantry).logicalBodyFrame(frameSize: sprite.size)
            )
            let healthBar = sceneFrame(bar.boundingBox)
            #expect(abs(body.height - fittedHeight) < 0.01)
            #expect(body.height >= 30)
            #expect(healthBar.width >= 30)
            #expect(layout.battlefieldFrame.contains(body))
            #expect(layout.battlefieldFrame.contains(healthBar))
            frames.append(body.union(healthBar))
        }
        try #require(frames.count == 2)
        #expect(!frames[0].intersects(frames[1]))
    }

    @Test func zeroDeltaDoesNotConsumeAnActiveHitCountdown() throws {
        let scene = try makeScene(initialState: stateWithBarracks())
        scene.spawnSoldierForTesting()
        scene.triggerFirstLiveSoldierAnimationForTesting("hit")

        let initialRemaining = try #require(scene.firstLiveSoldierHitAnimationRemainingForTesting)
        scene.advanceCombatForTesting(deltaTime: 0)
        let remainingAfterZeroDelta = try #require(scene.firstLiveSoldierHitAnimationRemainingForTesting)

        #expect(abs(initialRemaining - remainingAfterZeroDelta) < 0.000_001)
    }

    @Test func guardTestingAccessorsAreSafeWithoutGuards() throws {
        let scene = try makeScene(initialState: stateWithBarracks())

        #expect(scene.livingGuardsForTesting.isEmpty)
        #expect(scene.guardNodeCountForTesting == 0)
        #expect(scene.firstLivingGuardRootNodeForTesting == nil)
        #expect(scene.firstLivingGuardVisualNodeForTesting == nil)
    }

    private func makeScene(
        initialState: KingdomGameState,
        size: CGSize = CGSize(width: 390, height: 844)
    ) throws -> BattleScene {
        let suiteName = "PyxisTests.BattleSceneCoverageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)

        let scene = BattleScene(size: size, store: store)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func stateWithBarracks() -> KingdomGameState {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        return KingdomGameState(
            gold: 100,
            cityBattleStates: [
                cityKey.storageKey: CityBattleState(
                    slots: [1: CityBuilding(type: .barracks)]
                )
            ]
        )
    }
}
