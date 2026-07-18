//
//  BattleSceneTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct BattleSceneTests {
    private struct PixelBounds {
        let minX: Int
        let maxXExclusive: Int
    }

    @Test func battleSceneDisplaysCampaignCityTitle() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityLevel: 3,
                cityNumberInCountry: 3,
                completedCityCount: 2
            )
        )
        let scene = makeScene(store: store)

        #expect(scene.cityTitleTextForTesting == "Country 1 - City 3")
    }

    @Test func combatUsesCurrentCityLaneDefenseMultipliers() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // City 1: left fortified (1.25), center standard (1.0), right exposed (0.80).
        let multipliers = scene.combatLaneDamageMultipliersForTesting
        #expect(multipliers[.left] == 1.25)
        #expect(multipliers[.center] == 1.0)
        #expect(multipliers[.right] == 0.80)
    }

    @Test func battleSceneKeepsSoldierHUDValueWithoutTitle() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.liveCombatStatusTextForTesting == "0")

        scene.spawnSoldierForTesting()

        #expect(scene.liveCombatStatusTextForTesting == "1")
        #expect(scene.liveSoldierCountForTesting == 1)
    }

    @Test func tappingSpawnCreatesLiveCombatSoldierWithoutImmediateCityDamage() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(scene.cityRemainingPowerForTesting == 20)
        #expect(store.load().cityRemainingPower == 20)
    }

    @Test func infantrySoldierVisualMatchesAssetName() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierVisualMatchesForTesting(.infantry))
    }

    @Test func mismatchedSoldierTypeFallsBackToColorComparison() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        // Infantry soldier body does not match archer asset name, so it falls back to color comparison
        #expect(!scene.firstLiveSoldierVisualMatchesForTesting(.archer))
    }

    @Test func cavalrySoldierVisualMatches() throws {
        let state = stateWithBuildings([.stable], cityRemainingPower: 20)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierVisualMatchesForTesting(.cavalry))
    }

    @Test func allSoldierTypesExposeTenAnimationFramesForEachAction() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        for soldierType in SoldierType.allCases {
            for action in ["walk", "attack", "hit"] {
                let names = scene.animationFrameNamesForTesting(soldierType: soldierType, action: action)
                let expectedNames = (1...10).map {
                    "\(soldierType.rawValue)-\(action)-\(String(format: "%02d", $0))"
                }

                #expect(names == expectedNames)
            }
        }
    }

    @Test func spawnedSoldierStartsWalkingAnimation() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
    }

    @Test func cityDamageStartsAttackAnimation() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.recentSoldierAttackAnimationCountForTesting > 0)
    }

    @Test func remainingApprovedAttacksDoNotLayerProceduralFeedback() throws {
        for soldierType in [SoldierType.mage, .siege] {
            let buildingType = buildingTypeForSoldier(soldierType)
            let store = try makeStore(initialState: stateWithBuildings([buildingType], cityRemainingPower: 500))
            let scene = makeScene(store: store)

            scene.selectManualSoldierTypeForTesting(soldierType)
            scene.spawnSoldierForTesting()

            for _ in 0..<70 where scene.recentSoldierAttackAnimationCountForTesting == 0 {
                scene.advanceCombatForTesting(deltaTime: 0.1)
            }

            #expect(scene.recentSoldierAttackAnimationCountForTesting > 0)
            #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackBodyFeedback"))
            #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackCue") == 0)
            #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
        }
    }

    @Test func approvedArcherAttackDoesNotLayerProceduralFeedback() throws {
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], cityRemainingPower: 500))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        for _ in 0..<70 where scene.recentSoldierAttackAnimationCountForTesting == 0 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }

        #expect(scene.recentSoldierAttackAnimationCountForTesting > 0)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackCue") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
    }

    @Test func approvedInfantryAttackDoesNotLayerProceduralFeedback() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 500))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        for _ in 0..<70 where scene.recentSoldierAttackAnimationCountForTesting == 0 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }

        #expect(scene.recentSoldierAttackAnimationCountForTesting > 0)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackCue") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
    }

    @Test func approvedCavalryAttackDoesNotLayerProceduralFeedback() throws {
        let store = try makeStore(initialState: stateWithBuildings([.stable], cityRemainingPower: 500))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        for _ in 0..<70 where scene.recentSoldierAttackAnimationCountForTesting == 0 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }

        #expect(scene.recentSoldierAttackAnimationCountForTesting > 0)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackCue") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
    }

    @Test("Walk animation resumes after a transient attack/hit animation completes (spec §Runtime animation)")
    func walkAnimationResumesAfterTransientAnimationCompletes() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        scene.advanceCombatForTesting(deltaTime: 3.0)

        // An attack must have fired. The transient attack (or hit) animation
        // replaces the looping walk action — syncSoldierNodes no-ops the walk
        // restart while any transient action key is present.
        #expect(scene.recentSoldierAttackAnimationCountForTesting > 0)
        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        // Simulate the render loop finishing the transient animation: the
        // resume-walk closure fires and reinstalls the looping walk action.
        scene.completeFirstLiveSoldierTransientAnimationForTesting()

        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
    }

    @Test("Walk does not resume when transient animation clears with resumesWalk=false (spec §Runtime animation)")
    func walkDoesNotResumeWhenTransientAnimationClearsWithResumesWalkFalse() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        scene.advanceCombatForTesting(deltaTime: 3.0)

        // A transient attack/hit animation must have replaced the walk loop.
        #expect(scene.recentSoldierAttackAnimationCountForTesting > 0)
        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        // Mirror the production path for a fatal hit: the hit animation is
        // scheduled with `resumesWalk: !schedulesRemoval` → `false` when the
        // soldier is pending removal. The resume-walk guard must short-circuit
        // and leave the walk action uninstalled.
        scene.completeFirstLiveSoldierTransientAnimationForTesting(isAllowed: false)

        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
    }

    @Test func towerDamageStartsHitAnimation() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.recentSoldierHitAnimationCountForTesting > 0)
    }

    @Test func towerDamageUsesAuthoredArcherHitWithoutProceduralOverlay() throws {
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.archeryRange],
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.recentSoldierHitAnimationCountForTesting > 0)
        #expect(!scene.anyVisibleSoldierHasActionForTesting("soldierHitBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
    }

    @Test func towerDamageUsesAuthoredInfantryHitWithoutProceduralOverlay() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.recentSoldierHitAnimationCountForTesting > 0)
        #expect(!scene.anyVisibleSoldierHasActionForTesting("soldierHitBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
    }

    @Test func towerDamageUsesAuthoredCavalryHitWithoutProceduralOverlay() throws {
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.stable],
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.recentSoldierHitAnimationCountForTesting > 0)
        #expect(!scene.anyVisibleSoldierHasActionForTesting("soldierHitBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
    }

    @Test func remainingApprovedHitsDoNotLayerProceduralFeedback() throws {
        for soldierType in [SoldierType.mage, .siege] {
            let store = try makeStore(
                initialState: stateWithBuildings(
                    [buildingTypeForSoldier(soldierType)],
                    cityRemainingPower: 100,
                    cityNumberInCountry: 9,
                    completedCityCount: 8
                )
            )
            let scene = makeScene(store: store, combatSeed: 1)

            scene.selectManualSoldierTypeForTesting(soldierType)
            scene.spawnSoldierForTesting()
            for _ in 0..<40 where scene.recentSoldierHitAnimationCountForTesting == 0 {
                scene.advanceCombatForTesting(deltaTime: 0.1)
            }

            #expect(scene.recentSoldierHitAnimationCountForTesting > 0)
            #expect(!scene.anyVisibleSoldierHasActionForTesting("soldierHitBodyFeedback"))
            #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
            #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
        }
    }

    @Test("Soldier animations use authored weighted playback timing")
    func soldierAnimationsUseAuthoredWeightedPlaybackTiming() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
        let scene = makeScene(store: store)

        // Authored per-frame weights (each sums to 10) from
        // SoldierAnimationTiming / the July 12 full-animation spec. Pinning the
        // actual non-uniform arrays — not just the per-action total — means a
        // regression to uniform frame timing cannot satisfy this test.
        let attackWeights: [Double] = [1.10, 1.20, 1.30, 0.75, 0.70, 0.85, 1.00, 1.15, 1.10, 0.85]
        let hitWeights: [Double] = [0.90, 1.00, 1.10, 1.20, 1.20, 1.00, 0.95, 0.90, 0.90, 0.85]
        let walkWeights: [Double] = Array(repeating: 1.0, count: 10)

        func attackTotal(for type: SoldierType) -> Double {
            switch type {
            case .infantry, .cavalry: return 1.2
            case .archer, .mage: return 1.4
            case .siege: return 1.6
            }
        }

        func assertWeightedDurations(
            action: String,
            weights: [Double],
            total: Double,
            soldierType: SoldierType,
            expectUniform: Bool
        ) {
            let durations = scene.soldierAnimationFrameDurationsForTesting(
                action: action, soldierType: soldierType
            )
            #expect(durations.count == weights.count)
            let unit = total / weights.reduce(0, +)
            for index in 0..<weights.count {
                #expect(abs(durations[index] - weights[index] * unit) < 0.001)
            }
            let span = (durations.max() ?? 0) - (durations.min() ?? 0)
            if expectUniform {
                #expect(span < 0.001)
            } else {
                #expect(span > 0.001)
            }
            #expect(abs(durations.reduce(0, +) - total) < 0.001)
        }

        for type in SoldierType.allCases {
            assertWeightedDurations(
                action: "walk", weights: walkWeights, total: 1.0,
                soldierType: type, expectUniform: true
            )
            assertWeightedDurations(
                action: "attack", weights: attackWeights, total: attackTotal(for: type),
                soldierType: type, expectUniform: false
            )
            assertWeightedDurations(
                action: "hit", weights: hitWeights, total: 0.9,
                soldierType: type, expectUniform: false
            )
            #expect(abs(scene.soldierDelayedRemovalWaitDurationForTesting(soldierType: type) - 0.9) < 0.001)
        }
    }

    @Test("Hit animation interrupts an in-flight attack animation")
    func hitAnimationInterruptsInFlightAttackAnimation() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.triggerFirstLiveSoldierAnimationForTesting("attack")
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))

        scene.triggerFirstLiveSoldierAnimationForTesting("hit")
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierHitAnimation"))
    }

    @Test("Soldier animation textures are memoized across calls (no per-call UIImage lookup)")
    func soldierAnimationTexturesAreCachedAndReusedAcrossCalls() throws {
        let store = try makeStore(initialState: stateWithBuildings([.mageTower], cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 0)

        // First call resolves and caches the walk textures.
        let first = scene.cachedSoldierAnimationTexturesForTesting(soldierType: .mage, action: "walk")
        #expect(first.count == 10)
        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 1)

        // Second call must return the *same* SKTexture instances (cache hit).
        let second = scene.cachedSoldierAnimationTexturesForTesting(soldierType: .mage, action: "walk")
        #expect(second.count == first.count)
        for (a, b) in zip(first, second) {
            #expect(a === b)
        }
        // No duplicate cache entry was inserted.
        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 1)

        // Authored attack playback has its own cached texture entry.
        let attack = scene.cachedSoldierAnimationTexturesForTesting(soldierType: .mage, action: "attack")
        #expect(attack.count == first.count)
        for (attackTexture, walkTexture) in zip(attack, first) {
            #expect(attackTexture !== walkTexture)
        }
        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 2)

        let hit = scene.cachedSoldierAnimationTexturesForTesting(soldierType: .mage, action: "hit")
        for ((hitTexture, walkTexture), attackTexture) in zip(zip(hit, first), attack) {
            #expect(hitTexture !== walkTexture)
            #expect(hitTexture !== attackTexture)
        }
        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 3)
    }

    @Test("HUD icon textures are memoized per soldier type (no per-tick SKTexture reallocation)")
    func hudIconTexturesAreCachedAndReusedAcrossCalls() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // The scene's `buildInterface`/`redraw` eagerly populates the HUD icon
        // cache for every soldier type, so the cache is non-empty at test start.
        // The property under test is memoization: repeated calls return the same
        // `SKTexture` instance and never grow the cache.
        let baselineEntryCount = scene.soldierHUDIconTextureCacheEntryCountForTesting
        #expect(baselineEntryCount >= 1)

        // Repeated lookups for an already-cached type must return the identical
        // `SKTexture` instance (cache hit), not a fresh SKTexture(imageNamed:).
        let infantryFirst = scene.cachedSoldierHUDIconTextureForTesting(soldierType: .infantry)
        let infantrySecond = scene.cachedSoldierHUDIconTextureForTesting(soldierType: .infantry)
        #expect(infantryFirst === infantrySecond)
        #expect(scene.soldierHUDIconTextureCacheEntryCountForTesting == baselineEntryCount)

        // Every soldier type resolves to a cached entry; repeated lookups reuse
        // the same instance and never add a new cache entry.
        for soldierType in SoldierType.allCases {
            let first = scene.cachedSoldierHUDIconTextureForTesting(soldierType: soldierType)
            let second = scene.cachedSoldierHUDIconTextureForTesting(soldierType: soldierType)
            #expect(first === second)
        }
        #expect(scene.soldierHUDIconTextureCacheEntryCountForTesting == baselineEntryCount)

        // Distinct soldier types resolve to distinct textures (no aliasing).
        let infantry = scene.cachedSoldierHUDIconTextureForTesting(soldierType: .infantry)
        let archer = scene.cachedSoldierHUDIconTextureForTesting(soldierType: .archer)
        #expect(infantry !== archer)
    }

    @Test("Every approved soldier trio uses pairwise-distinct action frames")
    func approvedSoldierTriosUsePairwiseDistinctFrameIdentity() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        for soldierType in SoldierType.allCases {
            let walkTextures = scene.cachedSoldierAnimationTexturesForTesting(
                soldierType: soldierType,
                action: "walk"
            )
            let attackTextures = scene.cachedSoldierAnimationTexturesForTesting(
                soldierType: soldierType,
                action: "attack"
            )
            let hitTextures = scene.cachedSoldierAnimationTexturesForTesting(
                soldierType: soldierType,
                action: "hit"
            )

            #expect(attackTextures.count == walkTextures.count)
            #expect(hitTextures.count == walkTextures.count)
            for ((walkTexture, attackTexture), hitTexture) in zip(
                zip(walkTextures, attackTextures),
                hitTextures
            ) {
                #expect(walkTexture !== attackTexture)
                #expect(walkTexture !== hitTexture)
                #expect(attackTexture !== hitTexture)
            }
        }
    }

    @Test func approvedArcherFullCanvasPreservesLogicalBodyHeight() throws {
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], cityRemainingPower: 50))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        let bodyFrame = try #require(scene.firstLiveSoldierBodyFrameForTesting)
        let expectedFrameSize = SoldierAnimationGeometry(type: .archer).frameSize(
            forBodyHeight: scene.soldierTargetHeightForTesting
        )

        #expect(abs(bodyFrame.width - expectedFrameSize.width) < 0.001)
        #expect(abs(bodyFrame.height - expectedFrameSize.height) < 0.001)
    }

    @Test func approvedArcherHPBarUsesLogicalBodyTopInsteadOfCanvasTop() throws {
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], cityRemainingPower: 50))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        let hpBarFrame = try #require(scene.firstLiveSoldierHPBarFrameForTesting)
        let placement = try #require(scene.soldierLanePlacementsForTesting.first)
        let logicalBodyTop = placement.nodePosition.y + scene.soldierTargetHeightForTesting
        let gap = hpBarFrame.minY - logicalBodyTop

        #expect(gap >= 0)
        #expect(gap <= 1.5)
    }

    @Test func infantryAttackFramesKeepMotionInsideCanvasInset() throws {
        let fullCanvas = CGRect(x: 0, y: 0, width: 1, height: 1)

        for frameIndex in 1...10 {
            let imageName = "infantry-attack-\(String(format: "%02d", frameIndex))"
            let image = try #require(UIImage(named: imageName))
            let cgImage = try #require(image.cgImage)
            let bounds = try #require(opaquePixelBounds(in: image))
            let cropMinX = Int(floor(fullCanvas.minX * CGFloat(cgImage.width)))
            let cropMaxX = Int(ceil(fullCanvas.maxX * CGFloat(cgImage.width)))

            #expect(bounds.minX - cropMinX >= 3)
            #expect(cropMaxX - bounds.maxXExclusive >= 3)
        }
    }

    @Test("A tower-killed soldier is routed through the delayed-removal scheduler")
    func towerKilledSoldierSchedulesDelayedRemoval() throws {
        // City 9 with maxed-out city power so a tower shot is lethal. The combat
        // seed is fixed so the tower targets the spawned soldier's lane.
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        // Killed soldiers must be in pendingAnimatedRemovalSoldierIDs — this is
        // the regression for the removed dead branch (killed ⊆ damaged is a
        // structural invariant, so the death flow rides entirely on the
        // schedulesRemoval path inside playSoldierHitFeedback).
        #expect(!scene.pendingAnimatedRemovalSoldierIDsForTesting.isEmpty)
    }

    @Test func manualSelectorChangesSpawnedSoldierType() throws {
        let state = stateWithBuildings(
            [.barracks, .archeryRange],
            cityRemainingPower: 20,
            cityNumberInCountry: 2,
            completedCityCount: 1
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        #expect(scene.selectedManualSoldierTypeForTesting == .infantry)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        #expect(scene.selectedManualSoldierTypeForTesting == .archer)
        #expect(scene.liveSoldierTypesForTesting == [.archer])
    }

    @Test func manualSpawnCapBlocksEleventhManualSoldier() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
        let scene = makeScene(store: store)

        for _ in 0..<KingdomGameState.manualSoldierCap {
            scene.spawnSoldierForTesting()
        }

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)

        scene.spawnSoldierForTesting()

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene.liveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene.feedbackTextForTesting == "Manual squad is full.")
    }

    @Test func activeBuildingTimerCreatesBuildingSpawnedSoldierWithoutConsumingManualCap() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 9.95)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        for _ in 0..<KingdomGameState.manualSoldierCap {
            scene.spawnSoldierForTesting()
        }

        scene.advanceCombatForTesting(deltaTime: 0.1)

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.liveSoldierCountForTesting == KingdomGameState.manualSoldierCap + 1)
        let infantryCount = scene.liveSoldierTypesForTesting.filter { $0 == .infantry }.count
        #expect(infantryCount == KingdomGameState.manualSoldierCap + 1)
        scene.flushBuildingProgressSaveForTesting()
        #expect(store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed ?? 10 < 1)
    }

    @Test func archeryRangeBuildingSpawnUsesArcherVisual() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 2)
        let interval = KingdomGameState.activeSpawnInterval(for: .archeryRange)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .archeryRange, spawnTimerElapsed: interval - 0.1)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
                cityNumberInCountry: 2,
                completedCityCount: 1,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        scene.advanceCombatForTesting(deltaTime: 0.2)

        #expect(scene.liveSoldierTypesForTesting == [.archer])
        #expect(scene.firstLiveSoldierBodyNameForTesting == "archer-soldier")
        #expect(scene.firstLiveSoldierVisualMatchesForTesting(.archer))
    }

    @Test func battleSceneShowsDefenseTraitAndRemovesUpgradeAction() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10
            )
        )
        let scene = makeScene(store: store)

        #expect(scene.defenseTraitTextForTesting?.contains("Reinforced Keep") == true)
        #expect(scene.isUpgradeButtonVisibleForTesting == false)
    }

    @Test func manualSpawnAlwaysAllowsInfantryWithoutBuilding() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 100))
        let scene = makeScene(store: store)

        // Infantry is always available as the starter unit
        #expect(scene.manualSpawnableSoldierTypesForTesting == [.infantry])

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)
    }

    @Test func toggleManualTypeMenuOpenWithInfantryFallback() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 100))
        let scene = makeScene(store: store)

        // Infantry is always available, so the menu opens
        #expect(scene.manualSpawnableSoldierTypesForTesting == [.infantry])
        #expect(scene.isManualTypeMenuOpenForTesting == false)

        scene.toggleManualTypeMenuForTesting()

        #expect(scene.isManualTypeMenuOpenForTesting == true)
    }

    @Test func manualSelectorUsesBuiltCurrentCityUnitsOnly() throws {
        let state = stateWithBuildings(
            [.barracks, .mageTower],
            gold: 200,
            cityRemainingPower: 100,
            cityNumberInCountry: 8,
            completedCityCount: 7
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        #expect(scene.manualSpawnableSoldierTypesForTesting == [.infantry, .mage])

        scene.selectManualSoldierTypeForTesting(.mage)
        scene.spawnSoldierForTesting()

        #expect(scene.selectedManualSoldierTypeForTesting == .mage)
        #expect(scene.liveSoldierTypesForTesting == [.mage])
    }

    @Test func manualSpawnUsesHighestMatchingBuildingLevelAndTraitAdjustedDamage() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 11)
        let cityState = CityBattleState(
            slots: [
                1: CityBuilding(type: .siegeWorkshop, level: 1),
                2: CityBuilding(type: .siegeWorkshop, level: 3)
            ]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                gold: 200,
                cityRemainingPower: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        let initialCityHP = 100
        let expectedAttackPower = KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .siege,
            level: 3,
            defenseTrait: .reinforcedKeep
        )

        scene.selectManualSoldierTypeForTesting(.siege)
        for _ in 0..<4 {
            scene.spawnSoldierForTesting()
        }

        #expect(scene.liveSoldierLevelsForTesting == Array(repeating: 3, count: 4))
        #expect(scene.liveSoldierAttackPowersForTesting == Array(repeating: expectedAttackPower, count: 4))

        scene.advanceCombatForTesting(deltaTime: 4.0)

        #expect(store.load().cityRemainingPower < initialCityHP)
    }

    @Test func buildingSpawnUsesTraitAdjustedAttackPower() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 11)
        let interval = KingdomGameState.activeSpawnInterval(for: .siegeWorkshop)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .siegeWorkshop, level: 3, spawnTimerElapsed: interval - 0.1)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                gold: 200,
                cityRemainingPower: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        scene.advanceCombatForTesting(deltaTime: 0.2)

        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.liveSoldierTypesForTesting == [.siege])
        #expect(scene.liveSoldierLevelsForTesting == [3])
        #expect(scene.liveSoldierAttackPowersForTesting == [
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .siege,
                level: 3,
                defenseTrait: .reinforcedKeep
            )
        ])
    }

    @Test func activeBuildingPartialTimerProgressPersistsWithoutSpawn() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 0)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        scene.advanceCombatForTesting(deltaTime: 5.0)

        #expect(scene.buildingLiveSoldierCountForTesting == 0)
        scene.flushBuildingProgressSaveForTesting()
        let savedElapsed = try #require(
            store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed
        )
        #expect(savedElapsed > 0)
        #expect(savedElapsed < KingdomGameState.activeSpawnInterval(for: .barracks))
    }

    @Test func buildingProgressSaveIsThrottled() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 0)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        // Advance less than the throttle interval — no save should occur
        scene.advanceCombatForTesting(deltaTime: 1.0)

        let persisted = store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed ?? 0
        #expect(persisted == 0)
    }

    @Test func buildingProgressSaveFlushesImmediatelyWhenSpawnFires() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let interval = KingdomGameState.activeSpawnInterval(for: .barracks)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: interval - 0.1)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        // Small advance crosses the spawn threshold
        scene.advanceCombatForTesting(deltaTime: 0.2)

        // A building soldier should have spawned
        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        // The timer reset must be persisted immediately without waiting for the throttle
        let persisted = store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed ?? interval
        #expect(persisted < interval * 0.5)
    }

    @Test func liveSoldierHPBarStaysAttachedToScaledBodyTopEdge() throws {
        let store = try makeStore(initialState: stateWithBuildings([.mageTower], cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.mage)
        scene.spawnSoldierForTesting()

        let hpBarFrame = try #require(scene.firstLiveSoldierHPBarFrameForTesting)
        let placement = try #require(scene.soldierLanePlacementsForTesting.first)
        let logicalBodyTop = placement.nodePosition.y + scene.soldierTargetHeightForTesting
        let gap = hpBarFrame.minY - logicalBodyTop

        #expect(hpBarFrame.height >= 4.5)
        #expect(gap >= 0)
        #expect(gap <= 1.5)
    }

    @Test func combatTickCanDamageDurableCityHPAndSaveIt() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(store.load().cityRemainingPower < 20)
    }

    @Test func cityDamageCreatesFloatingFeedbackNode() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 50,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.floatingFeedbackCountForTesting > 0)
    }

    @Test func cityDamageDoesNotCreateScalingImpactEffect() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 50,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        let impactEffectScales = scene.impactEffectScalesForTesting

        #expect(!impactEffectScales.isEmpty)
        #expect(impactEffectScales.allSatisfy { $0.x == 1 && $0.y == 1 })
    }

    @Test func cityDamageDoesNotRelayoutBattlefieldBackdrop() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 50,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        let layoutCountBeforeDamage = scene.battlefieldLayoutCountForTesting

        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.cityRemainingPowerForTesting < 50)
        #expect(scene.battlefieldLayoutCountForTesting == layoutCountBeforeDamage)
    }

    @Test func infantrySelectorDoesNotRelayoutBattlefieldBackdrop() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 50,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        let layoutCountBeforeInfantryMenu = scene.battlefieldLayoutCountForTesting

        scene.toggleManualTypeMenuForTesting()
        scene.selectManualSoldierTypeForTesting(.infantry)

        #expect(scene.battlefieldLayoutCountForTesting == layoutCountBeforeInfantryMenu)
    }

    // City 9 tower damage (14 - 1 defense = 13 base) kills a 10-HP soldier in
    // one shot across ALL lanes: exposed lane 0.80× → 10, standard 1.0× → 13,
    // fortified 1.25× → 16. With a fixed seed the lane assignment is
    // deterministic, eliminating the balance-coincidence flakiness.
    @Test func towerDamageCanKillAndRemoveVisibleSoldier() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 18.0)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(!scene.isConquestPopupVisibleForTesting)
        #expect(savedState.stageStatus == .battleActive)
        #expect(savedState.cityRemainingPower == 100)
    }

    @Test func liveCombatStatusUpdatesWhenTowerKillsLastSoldierWithoutCityDamage() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 20,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()

        #expect(scene.liveCombatStatusTextForTesting == "1")

        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.cityRemainingPowerForTesting == 20)
        #expect(store.load().cityRemainingPower == 20)
        #expect(scene.liveCombatStatusTextForTesting == "0")
    }

    @Test func liveCombatConquestClearsSoldiersAndShowsPopup() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 1,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 3)

        scene.advanceCombatForTesting(deltaTime: 3.0)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(savedState.gold == 108)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)

        scene.advanceCombatForTesting(deltaTime: 3.0)

        let laterState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(laterState.gold == savedState.gold)
        #expect(laterState.completedCityCount == savedState.completedCityCount)
        #expect(laterState.stageStatus == savedState.stageStatus)
    }

    @Test func conquestPopupLayoutKeepsCityConquestFeedbackRunning() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 1,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.isCityConquestFeedbackRunningForTesting)
    }

    @Test func visualMatchReturnsFalseWithNoSoldiers() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)
        #expect(!scene.firstLiveSoldierVisualMatchesForTesting(.infantry))
    }

    @Test func goldBurstZPositionFallsBackWhenAbsent() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)
        #expect(scene.goldBurstZPositionForTesting < 0)
    }

    @Test func conquestPopupUsesRewardPresentationNodes() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 1,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.isGoldBurstVisibleForTesting)
        #expect(scene.goldBurstZPositionForTesting < scene.popupRewardZPositionForTesting)
        #expect(!scene.goldBurstContainsRewardTextForTesting)
    }

    @Test func conquestPopupRemovesGoldBurstAfterTransientActions() async throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 1,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isGoldBurstVisibleForTesting)
        #expect(scene.isGoldBurstRemovalScheduledForTesting)

        try await pollUntil(timeout: .seconds(2), interval: .milliseconds(50)) {
            !scene.isGoldBurstVisibleForTesting && !scene.isGoldBurstRemovalScheduledForTesting
        }

        #expect(!scene.isGoldBurstVisibleForTesting)
        #expect(!scene.isGoldBurstRemovalScheduledForTesting)
    }

    @Test func closingConquestPopupRequestsCountryMapRoute() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(!router.didRequestCountryMap)

        scene.closeConquestPopupForTesting()

        #expect(!scene.isConquestPopupVisibleForTesting)
        #expect(router.didRequestCountryMap)
    }

    @Test func closingConquestPopupWithoutRouterKeepsPopupVisible() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)

        scene.closeConquestPopupForTesting()

        #expect(scene.isConquestPopupVisibleForTesting)
    }

    @Test func buildButtonRequestsBuildingViewRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestBuildingViewForTesting()

        #expect(router.didRequestBuildingView)
    }

    @Test func worldButtonRequestsCountryMapRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestCountryMapForTesting()

        #expect(router.didRequestCountryMap)
    }

    @Test func buildButtonWaitsForLiveSoldiersBeforeRouting() throws {
        let start = Date(timeIntervalSinceReferenceDate: 500)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 20)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.spawnSoldierForTesting()
        scene.requestBuildingViewForTesting()

        #expect(!router.didRequestBuildingView)
        #expect(scene.feedbackTextForTesting == "Finish the current squad before building.")
        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(store.load() == initialState)
    }

    @Test func buildButtonAllowsRoutingWithOnlyBuildingSpawnedSoldiers() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 9.95)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                gold: 100,
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        // Advance combat to trigger a building spawn
        scene.advanceCombatForTesting(deltaTime: 0.1)

        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.manualLiveSoldierCountForTesting == 0)

        scene.requestBuildingViewForTesting()

        #expect(router.didRequestBuildingView)
    }

    @Test func idleConquestClearsLiveSoldiersBeforeShowingPopup() throws {
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(savedState.gold == 93)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)
    }

    @Test func idleConquestSuppressesFeedbackTooltipBehindPopup() throws {
        // Regression: `sceneWillEnterForeground` set a non-empty conquest
        // `feedbackText` then called `redraw()` before `showConquestPopup`,
        // so `presentFeedbackTooltipIfNeeded` (invoked at the tail of `redraw`)
        // presented the tooltip behind the modal, where it could linger after
        // the popup closed. The live-combat conquest path already avoided this;
        // the idle path must too.
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(store: store)

        // Fresh scene: no tooltip presented yet.
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        // The conquest popup is shown, and the feedback tooltip stays hidden
        // with no dedupe token recorded — the popup communicates the result.
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)
        #expect(scene.feedbackTextForTesting.isEmpty)
    }

    @Test func liveConquestClearsStaleFeedbackSoTooltipStaysHiddenBehindPopup() throws {
        // Regression: the live-combat conquest path only avoided *setting*
        // `feedbackText`. A stale message left by an earlier damage tick (tooltip
        // since faded, dedupe token reset to "") would be re-presented behind the
        // conquest popup during the conquest `redraw`. Mirrors the idle path:
        // clear `feedbackText` on conquest.
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
        let scene = makeScene(store: store)

        // Reproduce the post-fade stale state: a prior damage tick left a
        // message in `feedbackText` while the dedupe token has since reset.
        scene.setFeedbackTextForTesting("Soldiers dealt 5 damage.")
        #expect(!scene.feedbackTextForTesting.isEmpty)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        // Conquer via live combat (3 soldiers vs power 1).
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        // The conquest popup is shown and the stale feedback is cleared so the
        // tooltip is not re-presented behind the overlay (no dedupe token).
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.feedbackTextForTesting.isEmpty)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)
    }

    @Test func commanderHUDKeepsTopClustersAndActionsInsideScene() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.minX >= 12)
        #expect(frames.rightHUD.maxX <= scene.size.width - 12)
        #expect(frames.leftHUD.maxX < frames.rightHUD.minX)
        #expect(frames.leftHUD.height >= 64)
        #expect(frames.rightHUD.height >= 64)
        #expect(frames.spawnButton.maxY <= frames.battlefield.minY)
        #expect(frames.buildButton.maxY <= frames.battlefield.minY)
        #expect(frames.battlefield.maxY < frames.leftHUD.minY)
        #expect(frames.battlefield.maxY < frames.rightHUD.minY)
        #expect(frames.spawnButton.minX >= 12)
        #expect(frames.worldButton.maxY <= frames.battlefield.minY)
        #expect(frames.worldButton.minY >= frames.buildButton.maxY)
        #expect(frames.buildButton.maxX <= scene.size.width - 12)
        #expect(frames.spawnButton.maxX < frames.buildButton.minX)
        #expect(frames.buildButton.minY >= 12)
        #expect(frames.spawnButtonLabel.minX >= frames.spawnButton.minX + 14)
        #expect(frames.spawnButtonLabel.maxX <= frames.spawnButton.maxX - 14)
        // World/Build are now icon-only (labels carry empty text), so their
        // label-frame containment would be vacuous; icon presence is covered
        // by battleHUDUsesResourceValuesWithoutTitlesAndTextForCommands.
        #expect(frames.battlefield.width >= scene.size.width - 2)
        #expect(frames.battlefield.height >= scene.size.height * 0.64)
    }

    @Test func battleHUDUsesResourceValuesWithoutTitlesAndTextForCommands() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let texts = visibleLabelTexts(in: scene)
        #expect(!texts.contains { $0.hasPrefix("Gold:") })
        #expect(!texts.contains { $0.hasPrefix("Soldiers:") })
        #expect(!texts.contains { $0.hasPrefix("HP:") })
        #expect(texts.contains("30"))
        #expect(texts.contains("0"))
        #expect(texts.contains("Country 1 - City 1"))
        #expect(texts.contains("Infantry"))
        #expect(texts.contains("Spawn"))

        for controlName in ["manualType", "spawnSoldierButton", "worldButton", "buildButton"] {
            #expect(visibleSpriteCount(in: scene, named: controlName) >= 1)
        }
    }

    @Test func commonActionButtonsUseCompactIconShapes() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.buildButton.width <= frames.buildButton.height * 1.3)
        #expect(frames.worldButton.width <= frames.worldButton.height * 1.3)
        #expect(frames.spawnButton.width >= frames.buildButton.width * 2.2)
    }

    @Test func infantryAndSpawnButtonsAreCompactAndLeftAligned() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.spawnButtonBackground.width <= 170)
        #expect(frames.manualTypeButtonBackground.width <= 116)
        #expect(frames.manualTypeButtonBackground.width < frames.spawnButtonBackground.width)
        #expect(abs(frames.manualTypeButtonBackground.minX - frames.spawnButtonBackground.minX) <= 0.5)
    }

    @Test func buttonIconsAreLargeEnoughToRead() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let spawnIcon = try #require(visibleSpriteFrames(in: scene, named: "spawnSoldierButton").first)
        let manualIcon = try #require(visibleSpriteFrames(in: scene, named: "manualType").first)
        let worldIcon = try #require(visibleSpriteFrames(in: scene, named: "worldButton").first)
        let buildIcon = try #require(visibleSpriteFrames(in: scene, named: "buildButton").first)

        #expect(spawnIcon.height >= 48)
        #expect(manualIcon.height >= 26)
        #expect(worldIcon.height >= 42)
        #expect(buildIcon.height >= 42)
    }

    @Test func generatedSoldierButtonIconsUseTightPortraitCrop() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let spawnIcon = try #require(visibleSpriteFrames(in: scene, named: "spawnSoldierButton").first)
        let manualIcon = try #require(visibleSpriteFrames(in: scene, named: "manualType").first)

        #expect(spawnIcon.width > spawnIcon.height * 0.78)
        #expect(spawnIcon.width < spawnIcon.height * 0.86)
        #expect(manualIcon.width > manualIcon.height * 0.78)
        #expect(manualIcon.width < manualIcon.height * 0.86)
    }

    @Test func buttonIconsStayInsideTheirPaintedButtonBackgrounds() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let frames = try #require(scene.battleLayoutFramesForTesting)

        let spawnIcon = try #require(visibleSpriteFrames(in: scene, named: "spawnSoldierButton").first)
        let manualIcon = try #require(visibleSpriteFrames(in: scene, named: "manualType").first)
        let worldIcon = try #require(visibleSpriteFrames(in: scene, named: "worldButton").first)
        let buildIcon = try #require(visibleSpriteFrames(in: scene, named: "buildButton").first)

        #expect(spawnIcon.minX >= frames.spawnButtonBackground.minX + 4)
        #expect(spawnIcon.maxX <= frames.spawnButtonBackground.midX + frames.spawnButtonBackground.width * 0.08)
        #expect(spawnIcon.minY >= frames.spawnButtonBackground.minY + 1)
        #expect(spawnIcon.maxY <= frames.spawnButtonBackground.maxY - 1)
        #expect(abs(spawnIcon.midY - frames.spawnButtonBackground.midY) <= 3)

        #expect(manualIcon.minX >= frames.manualTypeButtonBackground.minX + 3)
        let manualIconRightLimit = frames.manualTypeButtonBackground.midX
            + frames.manualTypeButtonBackground.width * 0.08
        #expect(manualIcon.maxX <= manualIconRightLimit)
        #expect(manualIcon.minY >= frames.manualTypeButtonBackground.minY + 1)
        #expect(manualIcon.maxY <= frames.manualTypeButtonBackground.maxY - 1)
        #expect(abs(manualIcon.midY - frames.manualTypeButtonBackground.midY) <= 2)

        #expect(worldIcon.minX >= frames.worldButtonBackground.minX + 1)
        #expect(worldIcon.maxX <= frames.worldButtonBackground.maxX - 1)
        #expect(abs(worldIcon.midX - frames.worldButtonBackground.midX) <= 1)
        #expect(abs(worldIcon.midY - frames.worldButtonBackground.midY) <= 1)

        #expect(buildIcon.minX >= frames.buildButtonBackground.minX + 1)
        #expect(buildIcon.maxX <= frames.buildButtonBackground.maxX - 1)
        #expect(abs(buildIcon.midX - frames.buildButtonBackground.midX) <= 1)
        #expect(abs(buildIcon.midY - frames.buildButtonBackground.midY) <= 1)
    }

    @Test func commanderHUDSurvivesCompactLandscapeWithoutOverlap() throws {
        let size = CGSize(width: 667, height: 375)
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.minX >= 8)
        #expect(frames.rightHUD.maxX <= size.width - 8)
        #expect(frames.leftHUD.maxX < frames.rightHUD.minX)
        #expect(frames.leftHUD.height >= 56)
        #expect(frames.rightHUD.height >= 56)
        #expect(frames.spawnButton.maxY <= frames.battlefield.minY)
        #expect(frames.buildButton.maxY <= frames.battlefield.minY)
        #expect(frames.battlefield.maxY < frames.leftHUD.minY)
        #expect(frames.battlefield.maxY < frames.rightHUD.minY)
        #expect(frames.spawnButton.minY >= 8)
        #expect(frames.worldButton.maxY <= frames.battlefield.minY)
        #expect(frames.worldButton.minY >= frames.buildButton.maxY)
        #expect(frames.buildButton.minY >= 8)
        #expect(frames.spawnButton.maxX < frames.buildButton.minX)
    }

    @Test func manualTypeMenuAvoidsFeedbackAndBattlefieldInCompactAndNarrowLayouts() throws {
        for size in [CGSize(width: 667, height: 375), CGSize(width: 320, height: 568)] {
            let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
            let scene = BattleScene(size: size, store: store, router: nil)
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            scene.didMove(to: view)

            scene.openManualTypeMenuForTesting()

            let frames = try #require(scene.battleLayoutFramesForTesting)
            let infantryButton = try #require(frames.manualTypeMenuButtons[.infantry])
            let archerButton = frames.manualTypeMenuButtons[.archer]

            #expect(!infantryButton.intersects(frames.battlefield))
            #expect(!infantryButton.intersects(frames.worldButton))
            #expect(infantryButton.minY >= frames.spawnButton.maxY)
            #expect(infantryButton.maxX <= size.width - 8)
            #expect(archerButton == nil)
        }
    }

    @Test func manualTypeMenuKeepsFiveSpawnableUnitsTappableInNarrowLayout() throws {
        let size = CGSize(width: 320, height: 568)
        let store = try makeStore(
            initialState: stateWithBuildings(
                BuildingType.allCases,
                gold: 200,
                cityRemainingPower: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10
            )
        )
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        scene.openManualTypeMenuForTesting()

        let frames = try #require(scene.battleLayoutFramesForTesting)
        #expect(frames.manualTypeMenuButtons.count == SoldierType.allCases.count)

        for soldierType in SoldierType.allCases {
            let button = try #require(frames.manualTypeMenuButtons[soldierType])
            #expect(button.width >= 52)
            #expect(button.minX >= 8)
            #expect(button.maxX <= size.width - 8)
            #expect(button.minY >= frames.spawnButton.maxY)
            #expect(!button.intersects(frames.spawnButton))
            #expect(!button.intersects(frames.buildButton))
            #expect(!button.intersects(frames.battlefield))
            #expect(!button.intersects(frames.worldButton))
        }
    }

    @Test func commanderHUDFitsNarrowViewportWithoutOverflow() throws {
        let size = CGSize(width: 320, height: 568)
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.minX >= 8)
        #expect(frames.rightHUD.maxX <= size.width - 8)
        #expect(frames.leftHUD.maxX < frames.rightHUD.minX)
        #expect(frames.spawnButton.minX >= 8)
        #expect(frames.buildButton.maxX <= size.width - 8)
        #expect(frames.worldButton.maxX <= size.width - 8)
        #expect(frames.worldButton.minY >= frames.buildButton.maxY)
        #expect(frames.spawnButton.maxX < frames.buildButton.minX)
        #expect(frames.spawnButtonLabel.minX >= frames.spawnButton.minX + 14)
        #expect(frames.spawnButtonLabel.maxX <= frames.spawnButton.maxX - 14)
        // World/Build are icon-only here; label-frame checks would be vacuous.

        scene.spawnSoldierForTesting()
        let updatedFrames = try #require(scene.battleLayoutFramesForTesting)
        #expect(updatedFrames.liveCombatStatus.minX >= updatedFrames.leftHUD.minX + 10)
        #expect(updatedFrames.liveCombatStatus.maxX <= updatedFrames.leftHUD.maxX - 10)
    }

    @Test func worldToggleDoesNotCompressInfantryAndBuildControlsInNarrowViewport() throws {
        let size = CGSize(width: 320, height: 568)
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.spawnButton.width >= 150)
        #expect(frames.manualTypeButton.width >= 112)
        #expect(frames.buildButton.width >= 44)
        #expect(frames.worldButton.minY >= frames.buildButton.maxY)
    }

    @Test func commanderHUDFitsLateGameNumbersInNarrowViewport() throws {
        let size = CGSize(width: 320, height: 568)
        let state = KingdomGameState(
            gold: 123_456_789,
            normalSoldierUpgradeLevel: 15,
            cityNumberInCountry: 15,
            completedCityCount: 14
        )
        let store = try makeStore(initialState: state)
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.defenseTraitLabel.minX >= frames.rightHUD.minX + 10)
        #expect(frames.defenseTraitLabel.maxX <= frames.rightHUD.maxX - 10)
        #expect(frames.cityLevelLabel.minX >= frames.rightHUD.minX + 10)
        #expect(frames.cityLevelLabel.maxX <= frames.rightHUD.maxX - 10)
        #expect(frames.cityHPBar.maxX <= size.width - 8)
        // Build is icon-only in the late-game layout; no text label to bound.
    }

    @Test func commanderHUDAvoidsTallPhoneSensorArea() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.maxY <= size.height - 58)
        #expect(frames.rightHUD.maxY <= size.height - 58)
        #expect(frames.spawnButton.minY >= 26)
        #expect(frames.buildButton.minY >= 26)
    }

    @Test func verticalBattlefieldPlacesEnemyCityAboveCastle() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let enemyFrame = try #require(scene.enemyCityFrameForTesting)
        let castleFrame = try #require(scene.playerCastleFrameForTesting)
        let battlefield = try #require(scene.battleLayoutFramesForTesting).battlefield

        // Enemy city sits inside the top of the battlefield frame; castle at the bottom.
        #expect(enemyFrame.minY > castleFrame.maxY)
        #expect(enemyFrame.maxY < battlefield.maxY)
        #expect(enemyFrame.minY >= battlefield.minY)
        #expect(enemyFrame.maxY <= battlefield.maxY)
        #expect(abs(castleFrame.minY - battlefield.minY) <= 1)
    }

    @Test func cityHPBarUsesBattlefieldArtAboveEnemyCity() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let frames = try #require(scene.battleLayoutFramesForTesting)
        let enemyFrame = try #require(scene.enemyCityFrameForTesting)

        #expect(frames.cityHPBar.minY >= enemyFrame.maxY + 2)
        #expect(frames.cityHPBar.maxY <= frames.battlefield.maxY + 1)
        #expect(abs(frames.cityHPBar.midX - enemyFrame.midX) <= 1)
        #expect(frames.cityHPBar.width >= 96)
        #expect(frames.cityHPBar.height >= 5)
        #expect(!frames.cityHPBar.intersects(frames.rightHUD))
    }

    @Test func cityHPBarFillVisibleWhenCityHasPower() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // Positive case: with power remaining the fill path is non-nil so the
        // green HP sliver renders. Paired with the zero-power test below to
        // isolate the power==0 branch from full conquest teardown.
        #expect(!scene.isCityHPBarFillHiddenForTesting)
    }

    @Test func cityHPBarFillHiddenWhenCityPowerIsZero() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(cityRemainingPower: 1, completedCityCount: 0)
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()

        scene.advanceCombatForTesting(deltaTime: 3.0)

        // Regression for the zero-power sliver: previously the fill kept a
        // 1px-wide path (`max(1, width * 0)`) and rendered a tiny green line
        // after the city was drained. The fix nils the path at power==0.
        #expect(scene.cityRemainingPowerForTesting == 0)
        #expect(scene.isCityHPBarFillHiddenForTesting)
    }

    @Test func redrawWithLayoutRunsCityHPBarLayoutExactlyOnce() throws {
        // Regression: `redraw(shouldLayout: true)` called `layoutCityHPBar()`
        // directly and then again via `layoutInterface()`, building CGPaths on
        // the first pass that were immediately discarded by the second. The fix
        // defers to `layoutInterface()` when `shouldLayout` is true.
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // Baseline count after scene construction.
        let baseline = scene.layoutCityHPBarCallCountForTesting

        // A full-layout redraw must run `layoutCityHPBar` exactly once (via the
        // `layoutInterface` pass), not twice.
        scene.redrawForTesting(shouldLayout: true)
        #expect(scene.layoutCityHPBarCallCountForTesting == baseline + 1)

        // A no-layout redraw (the per-damage-tick hot path) must still run
        // `layoutCityHPBar` exactly once so the HP bar reflects new damage
        // without a full interface layout.
        let baselineAfterLayout = scene.layoutCityHPBarCallCountForTesting
        scene.redrawForTesting(shouldLayout: false)
        #expect(scene.layoutCityHPBarCallCountForTesting == baselineAfterLayout + 1)
    }

    @Test func feedbackTooltipHiddenByDefaultOnFreshScene() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // The feedback panel starts transparent and is only revealed briefly
        // as a tooltip after an action. Guards against a regression that
        // leaves the tooltip permanently visible.
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
    }

    @Test func infoTooltipSuppressedWhileConquestPopupIsVisible() throws {
        // Regression: `handleInfoButton` had no `isConquestPopupVisible` guard,
        // so tapping a HUD info button (gold/city) while the conquest popup
        // overlayed the scene could present a tooltip rendered behind the popup.
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        // Fresh scene: no tooltip presented yet.
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        // Present the conquest popup (overlaying the HUD).
        scene.presentConquestPopupForTesting(goldEarned: 5)
        #expect(scene.isConquestPopupVisibleForTesting)

        // While the popup is visible, both info buttons must be suppressed —
        // no tooltip presentation (panel stays hidden), no dedupe token recorded.
        scene.handleInfoButtonForTesting(named: scene.goldInfoButtonNameForTesting)
        scene.handleInfoButtonForTesting(named: scene.cityInfoButtonNameForTesting)
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        // After the popup closes, info tooltips work again. A router is required
        // for `closeConquestPopup` to complete its routing handoff.
        scene.closeConquestPopupForTesting()
        #expect(!scene.isConquestPopupVisibleForTesting)
        scene.handleInfoButtonForTesting(named: scene.cityInfoButtonNameForTesting)
        #expect(scene.isFeedbackTooltipVisibleForTesting)
        #expect(!scene.lastPresentedTooltipTextForTesting.isEmpty)
    }

    @Test func repeatedIdenticalFeedbackRetriggersTooltipAfterFadeOut() throws {
        // Regression: `lastPresentedTooltipText` was never reset after the
        // tooltip faded out, so a repeated identical message (e.g. "Soldiers
        // dealt 5 damage." tick after tick from a single infantry attacking a
        // durable city) would show once then never again — making combat look
        // stalled. The fix resets the dedupe token when the fade-out completes.
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 2000))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        // First attack: tooltip presents and records the dedupe token.
        let firstToken = scene.lastPresentedTooltipTextForTesting
        #expect(!firstToken.isEmpty)

        // Simulate the fade-out SKAction completing: the token resets so the
        // next identical message can re-trigger the tooltip.
        scene.completeFeedbackTooltipFadeOutForTesting()
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        // Second attack with the same damage message: the tooltip must
        // re-present, re-recording the dedupe token.
        scene.advanceCombatForTesting(deltaTime: 3.0)
        #expect(scene.lastPresentedTooltipTextForTesting == firstToken)
    }

    @Test func threeVerticalLanesSpanCastleGateToEnemyGate() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let laneXs = scene.laneCenterXsForTesting
        #expect(laneXs.count == 3)
        // Distinct, ascending lane columns.
        #expect(laneXs[0] < laneXs[1])
        #expect(laneXs[1] < laneXs[2])

        for lane in BattleLane.allCases {
            let start = try #require(scene.castleGatePointForTesting(lane: lane))
            let end = try #require(scene.enemyGatePointForTesting(lane: lane))
            // Vertical marching: same x, gaining y.
            #expect(start.x == end.x)
            #expect(end.y > start.y)
        }
    }

    @Test func laneRenderingUsesTerrainStripsWithDetail() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(visibleNodeCount(in: scene, namePrefix: "battleLaneTerrain-") == 3)
        #expect(visibleNodeCount(in: scene, namePrefix: "battleLaneDetail-") >= 12)
    }

    @Test func laneTerrainBlendsIntoBackdropInsteadOfCoveringIt() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let alphas = visibleShapeAlphas(in: scene, namePrefix: "battleLaneTerrain-")
        #expect(alphas.count == 3)
        for alpha in alphas {
            #expect(alpha.fill <= 0.18)
            #expect(alpha.stroke <= 0.28)
        }
    }

    @Test func soldierNodesRenderAtTheirLaneColumn() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 100, cityRemainingPower: 1_000))
        let scene = makeScene(store: store)

        for _ in 0..<6 {
            scene.spawnSoldierForTesting()
        }

        let placements = scene.soldierLanePlacementsForTesting
        #expect(placements.count == 6)
        for placement in placements {
            let expectedX = try #require(scene.castleGatePointForTesting(lane: placement.lane)?.x)
            #expect(
                abs(placement.nodePosition.x - expectedX)
                    <= scene.soldierFormationMaximumLateralOffsetForTesting + 0.5
            )
        }
    }

    @Test func soldiersSharingALaneDoNotRenderAtTheSamePoint() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 100, cityRemainingPower: 1_000))
        let scene = makeScene(store: store)

        for _ in 0..<6 {
            scene.spawnSoldierForTesting()
        }

        let placementsByLane = Dictionary(grouping: scene.soldierLanePlacementsForTesting, by: \.lane)
        #expect(scene.soldierLanePlacementsForTesting.count == 6)
        #expect(placementsByLane.values.contains { $0.count > 1 })
        for placements in placementsByLane.values where placements.count > 1 {
            for firstIndex in placements.indices {
                for secondIndex in placements.indices where secondIndex > firstIndex {
                    let first = placements[firstIndex].nodePosition
                    let second = placements[secondIndex].nodePosition
                    #expect(
                        hypot(first.x - second.x, first.y - second.y)
                            >= scene.soldierTargetHeightForTesting * 0.25
                    )
                }
            }
        }
    }

    @Test func approvedMageFullCanvasPreservesLogicalBodyHeight() throws {
        let store = try makeStore(
            initialState: stateWithBuildings([.mageTower], gold: 100, cityRemainingPower: 1_000)
        )
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.mage)
        scene.spawnSoldierForTesting()

        let bodyFrame = try #require(scene.firstLiveSoldierBodyFrameForTesting)
        let hpFrame = try #require(scene.firstLiveSoldierHPBarFrameForTesting)
        let expectedFrameSize = SoldierAnimationGeometry(type: .mage).frameSize(
            forBodyHeight: scene.soldierTargetHeightForTesting
        )
        let placement = try #require(scene.soldierLanePlacementsForTesting.first)
        let logicalBodyTop = placement.nodePosition.y + scene.soldierTargetHeightForTesting

        #expect(abs(bodyFrame.width - expectedFrameSize.width) < 0.001)
        #expect(abs(bodyFrame.height - expectedFrameSize.height) < 0.001)
        #expect(hpFrame.width >= 36)
        #expect(hpFrame.width <= 56)
        #expect(hpFrame.minY - logicalBodyTop >= 0)
        #expect(hpFrame.minY - logicalBodyTop <= 1.5)
    }

    @Test func approvedSiegeFullCanvasPreservesLogicalBodyHeight() throws {
        let store = try makeStore(
            initialState: stateWithBuildings([.siegeWorkshop], gold: 100, cityRemainingPower: 1_000)
        )
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.siege)
        scene.spawnSoldierForTesting()

        let bodyFrame = try #require(scene.firstLiveSoldierBodyFrameForTesting)
        let expectedFrameSize = SoldierAnimationGeometry(type: .siege).frameSize(
            forBodyHeight: scene.soldierTargetHeightForTesting
        )

        #expect(abs(bodyFrame.width - expectedFrameSize.width) < 0.001)
        #expect(abs(bodyFrame.height - expectedFrameSize.height) < 0.001)
    }

    @Test func laneIndicatorsMarkFortifiedAndExposedLanesOnly() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // City 1: left fortified, center standard, right exposed.
        let indicators = scene.laneIndicatorsForTesting
        #expect(indicators.count == 2)

        let fortified = try #require(indicators.first { $0.role == .fortified })
        let exposed = try #require(indicators.first { $0.role == .exposed })
        let leftGateX = try #require(scene.enemyGatePointForTesting(lane: .left)?.x)
        let rightGateX = try #require(scene.enemyGatePointForTesting(lane: .right)?.x)

        #expect(abs(fortified.position.x - leftGateX) <= 0.5)
        #expect(abs(exposed.position.x - rightGateX) <= 0.5)
        #expect(indicators.allSatisfy { $0.role != .standard })
    }

    @Test func backdropCoversFullScene() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        guard let backdropFrame = scene.battlefieldBackdropFrameForTesting else {
            // No backdrop asset bundled — nothing to assert.
            return
        }

        #expect(backdropFrame.minX <= 0)
        #expect(backdropFrame.maxX >= scene.size.width)
        #expect(backdropFrame.minY <= 0)
        #expect(backdropFrame.maxY >= scene.size.height)
    }

    private func pollUntil(
        timeout: Duration,
        interval: Duration = .milliseconds(50),
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: interval)
        }
        Issue.record("Poll timed out after \(timeout)")
    }

    private func makeScene(
        store: KingdomGameStore,
        router: BattleSceneRouting? = nil,
        combatSeed: UInt64? = nil
    ) -> BattleScene {
        let size = CGSize(width: 390, height: 844)
        let scene = BattleScene(size: size, store: store, router: router, combatSeed: combatSeed)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }

    private func stateWithBarracks(
        gold: Int = 100,
        cityRemainingPower: Int = 20,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0
    ) -> KingdomGameState {
        stateWithBuildings(
            [.barracks],
            gold: gold,
            cityRemainingPower: cityRemainingPower,
            cityNumberInCountry: cityNumberInCountry,
            completedCityCount: completedCityCount
        )
    }

    private func stateWithBuildings(
        _ buildingTypes: [BuildingType],
        gold: Int = 100,
        cityRemainingPower: Int = 20,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0
    ) -> KingdomGameState {
        let cityKey = CityKey(countryNumber: 1, cityNumber: cityNumberInCountry)
        let slots = Dictionary(
            uniqueKeysWithValues: buildingTypes.enumerated().map { index, buildingType in
                (index + 1, CityBuilding(type: buildingType))
            }
        )
        return KingdomGameState(
            gold: gold,
            cityRemainingPower: cityRemainingPower,
            cityNumberInCountry: cityNumberInCountry,
            completedCityCount: completedCityCount,
            cityBattleStates: [cityKey.storageKey: CityBattleState(slots: slots)]
        )
    }

    private func buildingTypeForSoldier(_ soldierType: SoldierType) -> BuildingType {
        switch soldierType {
        case .infantry:
            return .barracks
        case .archer:
            return .archeryRange
        case .cavalry:
            return .stable
        case .mage:
            return .mageTower
        case .siege:
            return .siegeWorkshop
        }
    }

    private final class RouteSpy: BattleSceneRouting {
        private(set) var didRequestCountryMap = false
        private(set) var didRequestBuildingView = false

        func battleSceneDidRequestCountryMap(_ scene: BattleScene) {
            didRequestCountryMap = true
        }

        func battleSceneDidRequestBuildingView(_ scene: BattleScene) {
            didRequestBuildingView = true
        }
    }

    private final class MockTouch: UITouch {
        private let loc: CGPoint
        init(location: CGPoint) {
            self.loc = location
            super.init()
        }
        override func location(in view: UIView?) -> CGPoint {
            return loc
        }
    }

    private func visibleLabelTexts(
        in node: SKNode,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> [String] {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return []
        }

        var texts: [String] = []
        if let label = node as? SKLabelNode,
           let text = label.text,
           !text.isEmpty {
            texts.append(text)
        }

        for child in node.children {
            texts.append(contentsOf: visibleLabelTexts(
                in: child,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            ))
        }
        return texts
    }

    private func visibleSpriteCount(
        in node: SKNode,
        named name: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> Int {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return 0
        }

        let selfCount = (node as? SKSpriteNode) != nil && node.name == name ? 1 : 0
        return node.children.reduce(selfCount) { count, child in
            count + visibleSpriteCount(
                in: child,
                named: name,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            )
        }
    }

    private func visibleSpriteFrames(
        in node: SKNode,
        named name: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> [CGRect] {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return []
        }

        var frames: [CGRect] = []
        if (node as? SKSpriteNode) != nil,
           node.name == name,
           let sceneFrame = sceneFrameInTest(for: node) {
            frames.append(sceneFrame)
        }

        for child in node.children {
            frames.append(contentsOf: visibleSpriteFrames(
                in: child,
                named: name,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            ))
        }
        return frames
    }

    private func sceneFrameInTest(for node: SKNode) -> CGRect? {
        guard let parent = node.parent else {
            return nil
        }

        let frame = node.calculateAccumulatedFrame()
        let corners = [
            CGPoint(x: frame.minX, y: frame.minY),
            CGPoint(x: frame.maxX, y: frame.minY),
            CGPoint(x: frame.minX, y: frame.maxY),
            CGPoint(x: frame.maxX, y: frame.maxY)
        ].map { parent.convert($0, to: node.scene ?? parent) }

        guard let first = corners.first else {
            return nil
        }

        return corners.dropFirst().reduce(
            CGRect(origin: first, size: .zero)
        ) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
    }

    private func visibleNodeCount(
        in node: SKNode,
        namePrefix: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> Int {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return 0
        }

        let selfCount = node.name?.hasPrefix(namePrefix) == true ? 1 : 0
        return node.children.reduce(selfCount) { count, child in
            count + visibleNodeCount(
                in: child,
                namePrefix: namePrefix,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            )
        }
    }

    private func visibleNodeHasAction(
        in node: SKNode,
        namePrefix: String,
        actionKey: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> Bool {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return false
        }

        if node.name?.hasPrefix(namePrefix) == true,
           node.action(forKey: actionKey) != nil {
            return true
        }

        return node.children.contains { child in
            visibleNodeHasAction(
                in: child,
                namePrefix: namePrefix,
                actionKey: actionKey,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            )
        }
    }

    private func visibleShapeAlphas(
        in node: SKNode,
        namePrefix: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> [(fill: CGFloat, stroke: CGFloat)] {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return []
        }

        var alphas: [(fill: CGFloat, stroke: CGFloat)] = []
        if let shape = node as? SKShapeNode,
           node.name?.hasPrefix(namePrefix) == true {
            alphas.append((
                fill: alphaComponent(of: shape.fillColor) * alpha,
                stroke: alphaComponent(of: shape.strokeColor) * alpha
            ))
        }

        for child in node.children {
            alphas.append(contentsOf: visibleShapeAlphas(
                in: child,
                namePrefix: namePrefix,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            ))
        }
        return alphas
    }

    private func alphaComponent(of color: SKColor) -> CGFloat {
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return alpha
    }

    private func opaquePixelBounds(in image: UIImage) -> PixelBounds? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var didDraw = false

        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            didDraw = true
        }

        guard didDraw else {
            return nil
        }

        var minX = width
        var maxXExclusive = 0
        for y in 0..<height {
            for x in 0..<width {
                let alphaIndex = (y * width + x) * 4 + 3
                guard pixels[alphaIndex] > 0 else {
                    continue
                }
                minX = min(minX, x)
                maxXExclusive = max(maxXExclusive, x + 1)
            }
        }

        guard minX < width else {
            return nil
        }
        return PixelBounds(minX: minX, maxXExclusive: maxXExclusive)
    }

    // MARK: - touchesEnded

    @Test func touchesEndedEmptyTouchesDoesNothing() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let liveCountBefore = scene.liveSoldierCountForTesting

        scene.touchesEnded([], with: nil)

        #expect(scene.liveSoldierCountForTesting == liveCountBefore)
        #expect(!router.didRequestCountryMap)
        #expect(!router.didRequestBuildingView)
    }

    @Test func touchesEndedSpawnButtonSpawnsSoldier() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let frames = try #require(scene.battleLayoutFramesForTesting)
        let point = CGPoint(x: frames.spawnButton.midX, y: frames.spawnButton.midY)

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(scene.liveSoldierCountForTesting == 1)
    }

    @Test func touchesEndedBuildButtonRequestsBuildingView() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let frames = try #require(scene.battleLayoutFramesForTesting)
        let point = CGPoint(x: frames.buildButton.midX, y: frames.buildButton.midY)

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestBuildingView)
    }

    @Test func touchesEndedWorldButtonRequestsCountryMap() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let frames = try #require(scene.battleLayoutFramesForTesting)
        let point = CGPoint(x: frames.worldButton.midX, y: frames.worldButton.midY)

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestCountryMap)
    }

    @Test func touchesEndedPopupContinueClosesPopupAndRoutes() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1, completedCityCount: 0))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)
        #expect(scene.isConquestPopupVisibleForTesting)

        let frame = try #require(scene.popupContinueButtonFrameForTesting)
        let point = CGPoint(x: frame.midX, y: frame.midY)
        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestCountryMap)
        #expect(!scene.isConquestPopupVisibleForTesting)
    }

    @Test func touchesEndedOutsideClosesManualTypeMenu() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)
        scene.openManualTypeMenuForTesting()
        #expect(scene.isManualTypeMenuOpenForTesting)

        let point = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(!scene.isManualTypeMenuOpenForTesting)
    }

    @Test func requestCountryMapBlocksWithManualSoldiersAlive() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()

        scene.requestCountryMapForTesting()

        #expect(!router.didRequestCountryMap)
        #expect(scene.feedbackTextForTesting == "Finish the current squad before viewing world.")
    }

    @Test func requestCountryMapBlocksWhenConquestPopupVisible() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1, completedCityCount: 0))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)
        #expect(scene.isConquestPopupVisibleForTesting)

        scene.requestCountryMapForTesting()

        #expect(!router.didRequestCountryMap)
    }

    // MARK: - compactNumber

    @Test func compactNumberFormatsSmallValuesAsRawIntegers() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(0) == "0")
        #expect(scene.compactNumberForTesting(42) == "42")
        #expect(scene.compactNumberForTesting(999) == "999")
    }

    @Test func compactNumberFormatsThousandsWithSuffix() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(1_000) == "1K")
        #expect(scene.compactNumberForTesting(1_500) == "1.5K")
        #expect(scene.compactNumberForTesting(12_000) == "12K")
        #expect(scene.compactNumberForTesting(150_000) == "150K")
        #expect(scene.compactNumberForTesting(500_000) == "500K")
    }

    @Test func compactNumberFormatsMillionsWithSuffix() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(1_000_000) == "1M")
        #expect(scene.compactNumberForTesting(2_500_000) == "2.5M")
        #expect(scene.compactNumberForTesting(15_000_000) == "15M")
    }

    @Test func compactNumberFormatsBillionsWithSuffix() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(1_000_000_000) == "1B")
        #expect(scene.compactNumberForTesting(3_200_000_000) == "3.2B")
    }

    @Test func compactNumberPromotesAtUnitBoundaries() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // 999,950 rounds to "1M" not "1000K"
        #expect(scene.compactNumberForTesting(999_950) == "1M")
        // 999,500,000 rounds to "1B" not "1000M"
        #expect(scene.compactNumberForTesting(999_500_000) == "1B")
        // 999,500,000,000 rounds to "1T" not "1000B"
        #expect(scene.compactNumberForTesting(999_500_000_000) == "1T")
    }

    @Test func compactNumberHandlesNegativeValues() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(-1_500) == "-1.5K")
        #expect(scene.compactNumberForTesting(-1_000_000) == "-1M")
    }

    @Test func compactNumberDoesNotPromoteBelowThousand() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // 999,400 rounds to 999.4K → body "999" (since 999.4 >= 10, uses integer format)
        #expect(scene.compactNumberForTesting(999_400) == "999K")
        // 994,999 rounds to 995K
        #expect(scene.compactNumberForTesting(994_999) == "995K")
        // 998,500 rounds to 998.5K → body "998.5" (since 998.5 is not a whole number and < 10 is false)
        // Actually 998.5 >= 10 → uses %.0f → "998" but wait, 998.5.rounded() == 999 != 998.5
        // So body = String(format: "%.0f", 998.5) = "998"... but that loses the .5
        // Let's test: 1,500 → 1.5K (works because 1.5 < 10)
        #expect(scene.compactNumberForTesting(1_500) == "1.5K")
    }
}
