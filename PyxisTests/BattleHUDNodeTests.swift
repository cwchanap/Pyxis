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
    @Test func referenceHierarchySeparatesCityIdentityAndKeepsMedallionsPortraitLed() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let state = KingdomGameState(
            cityLevel: 3,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: 3).storageKey: CityBattleState(
                    slots: [1: CityBuilding(type: .barracks, level: 2)]
                )
            ]
        )
        let node = BattleHUDNode()

        #expect(node.apply(content: .project(from: state, manualCount: 0), layout: layout) == .presented)

        let progress = try #require(node.childNode(withName: "battleCityProgressLabel") as? SKLabelNode)
        let title = try #require(node.childNode(withName: "battleCityTitleLabel") as? SKLabelNode)
        let hp = try #require(node.childNode(withName: "battleCityHPLabel") as? SKLabelNode)
        let bar = try #require(node.childNode(withName: "battleCityProgressBar") as? ProgressBarNode)
        let detail = try #require(
            node.childNode(withName: "battleRecommendationDetailLabel") as? SKLabelNode
        )
        let typeLabel = try #require(
            node.childNode(withName: "//battleMedallionType-infantry") as? SKLabelNode
        )
        let status = try #require(
            node.childNode(withName: "//battleMedallionStatus-infantry") as? SKLabelNode
        )
        let multiplier = try #require(
            node.childNode(withName: "//battleMedallionMultiplier-infantry") as? SKLabelNode
        )
        let pill = try #require(node.childNode(withName: "//battleMedallionPill-infantry"))

        #expect(progress.text == "3 / 15")
        #expect(progress.fontSize == 11)
        #expect(title.text == "FALCONRIDGE")
        #expect(title.fontSize == 21)
        #expect(hp.isHidden)
        #expect(bar.children.compactMap { $0 as? SKShapeNode }.first?.path?.boundingBox.height == 14)
        #expect(detail.text?.contains("Lv2→3") == true)
        #expect(typeLabel.isHidden)
        #expect(status.isHidden)
        #expect(multiplier.text == "1.25")
        #expect(pill.isHidden == false)
    }

    @Test func battleChromeUsesForgedMaterialAndHexCutUnitPlates() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let node = BattleHUDNode()
        let content = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4),
            manualCount: 0
        )

        #expect(node.apply(content: content, layout: layout) == .presented)

        let incomePanel = try #require(
            node.childNode(withName: "battleIncomePanel") as? PanelNode
        )
        let incomePlate = try #require(
            incomePanel.childNode(withName: "panelPlate") as? SKShapeNode
        )
        #expect(rgba(incomePlate.fillColor) == [25, 17, 8, 255])
        #expect(rgba(incomePlate.strokeColor) == [198, 150, 80, 153])

        let deployPanel = try #require(
            node.childNode(withName: "battleDeployPanel") as? PanelNode
        )
        let deployPlate = try #require(
            deployPanel.childNode(withName: "panelPlate") as? SKShapeNode
        )
        #expect(rgba(deployPlate.fillColor) == [51, 31, 8, 255])
        #expect(rgba(deployPlate.strokeColor) == [255, 180, 60, 191])

        let infantryPanel = try #require(
            node.childNode(withName: "//battleMedallionPanel-infantry") as? PanelNode
        )
        let infantryPlate = try #require(
            infantryPanel.childNode(withName: "panelPlate") as? SKShapeNode
        )
        #expect(lineSegmentCount(infantryPlate.path) == 6)

        let deployIcon = try #require(
            node.childNode(withName: "battleDeployIcon") as? SKSpriteNode
        )
        #expect(deployIcon.size == CGSize(width: 46, height: 46))

        let tabBackdrop = try #require(
            node.childNode(withName: "//gameplayTabForgedBackdrop") as? SKShapeNode
        )
        #expect(rgba(tabBackdrop.fillColor) == [16, 9, 3, 250])

        let cityProgressBar = try #require(
            node.childNode(withName: "battleCityProgressBar") as? ProgressBarNode
        )
        let progressBackground = try #require(
            cityProgressBar.children.compactMap { $0 as? SKShapeNode }.first
        )
        #expect(progressBackground.path?.boundingBox.height == 14)
        #expect(rgba(progressBackground.strokeColor) == [198, 150, 80, 166])
        #expect(cityProgressBar.children.filter {
            $0.name?.hasPrefix("progressTick-") == true
        }.count == 9)
    }

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
        #expect(cityHPLabel.isHidden)
        #expect(recommendationLabel.text?.hasPrefix("NEXT") == true)
    }

    @Test func applyMountsTheAuthoredCityTitleNode() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))
        let node = BattleHUDNode()

        _ = node.apply(
            content: .project(from: KingdomGameState(), manualCount: 0),
            layout: layout
        )

        let title = try #require(node.childNode(withName: "battleCityTitleLabel") as? SKLabelNode)
        #expect(title.text == "WILLOWFORD")
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

private func rgba(_ color: SKColor) -> [Int] {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
}

private func lineSegmentCount(_ path: CGPath?) -> Int {
    var count = 0
    path?.applyWithBlock { element in
        if element.pointee.type == .addLineToPoint {
            count += 1
        }
    }
    return count
}
