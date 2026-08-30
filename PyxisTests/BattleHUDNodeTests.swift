//
//  BattleHUDNodeTests.swift
//  PyxisTests
//

import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct BattleHUDNodeTests {
    @Test func applyKeepsFixedTreeAndReturnsOnlyBattleActions() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let content = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4),
            manualCount: 0
        )
        let node = BattleHUDNode()
        let childCount = node.children.count

        #expect(node.apply(content: content, layout: layout) == .presented)
        node.apply(content: content, layout: layout)

        #expect(node.children.count == childCount)
        #expect(node.visualMedallionCountForTesting == 5)
        #expect(node.medallionVisualSizeForTesting == CGSize(width: 56, height: 56))
        #expect(node.action(at: CGPoint(x: layout.deployFrame.midX, y: layout.deployFrame.midY)) == .deploy)
    }

    @Test func applyProjectsGoldCityProgressAndNextRecommendationIntoSeparateBands() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let state = KingdomGameState(
            gold: 1_234,
            cityRemainingPower: 42,
            cityNumberInCountry: 5,
            completedCityCount: 4
        )
        let node = BattleHUDNode()
        _ = node.apply(content: .project(from: state, manualCount: 0), layout: layout)

        let incomePanel = try #require(node.childNode(withName: "battleIncomePanel") as? PanelNode)
        let cityPanel = try #require(node.childNode(withName: "battleCityProgressPanel") as? PanelNode)
        let recommendationPanel = try #require(
            node.childNode(withName: "battleRecommendationPanel") as? PanelNode
        )
        let goldLabel = try #require(node.childNode(withName: "battleGoldLabel") as? SKLabelNode)
        let cityLabel = try #require(node.childNode(withName: "battleCityProgressLabel") as? SKLabelNode)
        let cityHPLabel = try #require(node.childNode(withName: "battleCityHPLabel") as? SKLabelNode)
        let recommendationLabel = try #require(
            node.childNode(withName: "battleRecommendationLabel") as? SKLabelNode
        )

        #expect(incomePanel.styleForTesting == .normal)
        #expect(cityPanel.styleForTesting == .normal)
        #expect(recommendationPanel.styleForTesting == .normal)
        #expect(goldLabel.text?.contains("1.2K") == true)
        #expect(cityLabel.text?.contains("5 / 15") == true)
        #expect(cityHPLabel.text?.contains("42") == true)
        #expect(recommendationLabel.text?.hasPrefix("NEXT") == true)
    }

    @Test func medallionsUseAuthoredUnitFramesAsTheirPrimaryVisual() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let node = BattleHUDNode()
        let content = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4),
            manualCount: 0
        )
        _ = node.apply(content: content, layout: layout)

        for type in SoldierType.allCases {
            let icon = try #require(
                node.childNode(withName: "//battleMedallionIcon-\(type.rawValue)") as? SKSpriteNode
            )
            let assetName = try #require(icon.userData?["assetName"] as? String)
            #expect(assetName.hasPrefix("\(type.rawValue)-walk-") || assetName == "normal-soldier")
        }
    }

    @Test func availableAndUnavailableMedallionsReturnSelectOrRequirement() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let content = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4),
            manualCount: 0
        )
        let node = BattleHUDNode()
        _ = node.apply(content: content, layout: layout)

        let infantryPoint = CGPoint(
            x: layout.medallionHitFrames[0].midX,
            y: layout.medallionHitFrames[0].midY
        )
        let archerPoint = CGPoint(
            x: layout.medallionHitFrames[1].midX,
            y: layout.medallionHitFrames[1].midY
        )
        let magePoint = CGPoint(
            x: layout.medallionHitFrames[3].midX,
            y: layout.medallionHitFrames[3].midY
        )
        #expect(node.action(at: infantryPoint) == .select(.infantry))
        #expect(node.action(at: archerPoint) == .requirement(
            soldierType: .archer,
            unlocksAtCity: nil
        ))
        #expect(node.action(at: magePoint) == .requirement(
            soldierType: .mage,
            unlocksAtCity: 8
        ))
    }

    @Test func disabledTabHasNoActionAndEnabledTabReturnsTabAction() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let content = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4),
            manualCount: 1
        )
        let node = BattleHUDNode()
        _ = node.apply(content: content, layout: layout)

        let campFrame = layout.tabBarFrame.offsetBy(dx: layout.tabBarFrame.width / 3, dy: 0)
        let battleFrame = layout.tabBarFrame
            .insetBy(dx: 0, dy: 8)
        #expect(node.action(at: CGPoint(x: campFrame.midX, y: campFrame.midY)) == nil)
        #expect(node.action(at: CGPoint(
            x: battleFrame.minX + battleFrame.width / 6,
            y: battleFrame.midY
        )) == .tab(.battle))
    }

    @Test func rendersOnlyAuthoredNonStandardLaneChips() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        let content = BattleHUDContent.project(from: state, manualCount: 0)
        let node = BattleHUDNode()
        _ = node.apply(content: content, layout: layout)

        let leftChip = try #require(node.childNode(withName: "battleLaneChip-0"))
        let exposedLabel = try #require(
            node.childNode(withName: "battleLaneChipLabel-1") as? SKLabelNode
        )
        let fortifiedLabel = try #require(
            node.childNode(withName: "battleLaneChipLabel-2") as? SKLabelNode
        )

        #expect(leftChip.isHidden)
        #expect(exposedLabel.isHidden == false)
        #expect(exposedLabel.text == "OPEN")
        #expect(fortifiedLabel.isHidden == false)
        #expect(fortifiedLabel.text == "HELD")
    }
}
