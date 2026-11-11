//
//  CampSelectionNodeTests.swift
//  PyxisTests
//

import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
@Suite(.serialized)
struct CampSelectionNodeTests {
    @Test func nodeKeepsFixedTreeAndExposesBuilderAndInspectorActions() throws {
        let layout = try #require(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            selection: .emptyLot(slot: 1)
        )))
        let content = CampSelectionContent.project(
            from: KingdomGameState(gold: 100),
            selectedSlot: 1
        )
        let node = CampSelectionNode()
        let childCount = node.children.count

        #expect(node.apply(content: content, layout: layout) == .presented)
        node.apply(content: content, layout: layout)
        #expect(node.children.count == childCount)
        #expect(node.visualOptionCountForTesting == 5)
        #expect(node.builderPanelUsesForgedAppearanceForTesting)
        #expect(node.tabBarForTesting.usesForgedAppearanceForTesting)
        #expect(node.action(at: center(of: layout.builderOptionFrames[.barracks]!)) == .build(.barracks))
        #expect(node.action(at: center(of: layout.tabHitFrames[.map]!)) == .tab(.map))
        #expect(node.action(at: CGPoint(x: layout.tabBarFrame.midX, y: 10)) == nil)

        let occupiedLayout = try #require(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            selection: .occupiedLot(slot: 1)
        )))
        var occupiedState = KingdomGameState(gold: 100)
        _ = occupiedState.buildBuilding(.barracks, inSlot: 1)
        let occupiedContent = CampSelectionContent.project(from: occupiedState, selectedSlot: 1)
        #expect(node.apply(content: occupiedContent, layout: occupiedLayout) == .presented)
        #expect(node.inspectorPanelUsesForgedAppearanceForTesting)
        #expect(node.action(at: center(of: occupiedLayout.inspectorActionFrame!)) == .upgrade)
    }

    @Test func actionStyleMapsDisabledThenRecommendedThenActionableFallback() {
        #expect(CampSelectionNode.actionStyle(
            isRecommended: true,
            isActionable: false,
            actionableStyle: .normal
        ) == .disabled)
        #expect(CampSelectionNode.actionStyle(
            isRecommended: true,
            isActionable: false,
            actionableStyle: .primaryAction
        ) == .disabled)
        #expect(CampSelectionNode.actionStyle(
            isRecommended: false,
            isActionable: false,
            actionableStyle: .primaryAction
        ) == .disabled)
        #expect(CampSelectionNode.actionStyle(
            isRecommended: true,
            isActionable: true,
            actionableStyle: .normal
        ) == .selected)
        #expect(CampSelectionNode.actionStyle(
            isRecommended: true,
            isActionable: true,
            actionableStyle: .primaryAction
        ) == .selected)
        #expect(CampSelectionNode.actionStyle(
            isRecommended: false,
            isActionable: true,
            actionableStyle: .primaryAction
        ) == .primaryAction)
        #expect(CampSelectionNode.actionStyle(
            isRecommended: false,
            isActionable: true,
            actionableStyle: .normal
        ) == .normal)
    }

    @Test func builderCardsContainStatusTextAcrossStatesAndViewports() throws {
        struct Viewport {
            let size: CGSize
            let insets: CampSafeAreaInsets
        }
        let viewports = [
            Viewport(
                size: CGSize(width: 393, height: 852),
                insets: .init(top: 59, left: 0, bottom: 34, right: 0)
            ),
            Viewport(
                size: CGSize(width: 320, height: 568),
                insets: .init(top: 0, left: 0, bottom: 0, right: 0)
            )
        ]

        for viewport in viewports {
            let layout = try #require(CampChromeLayout.compute(.init(
                sceneSize: viewport.size,
                safeAreaInsets: viewport.insets,
                selection: .emptyLot(slot: 1)
            )))
            let builderFrame = try #require(layout.builderFrame)
            let content = CampSelectionContent(
                selectedSlot: 1,
                options: [
                    .init(
                        buildingType: .barracks,
                        state: .available(cost: 15),
                        isRecommended: true
                    ),
                    .init(
                        buildingType: .archeryRange,
                        state: .available(cost: 999_999_999),
                        isRecommended: false
                    ),
                    .init(
                        buildingType: .stable,
                        state: .unaffordable(cost: 999_999_999, currentGold: 0),
                        isRecommended: false
                    ),
                    .init(
                        buildingType: .mageTower,
                        state: .locked(unlocksAtCity: 8),
                        isRecommended: false
                    ),
                    .init(
                        buildingType: .siegeWorkshop,
                        state: .locked(unlocksAtCity: 11),
                        isRecommended: false
                    )
                ],
                inspector: nil,
                enabledTabs: Set(GameplayTab.allCases)
            )

            #expect(content.options.filter(\.isRecommended).count == 1)
            #expect(content.options.filter(\.state.isAvailable).count == 2)
            #expect(content.options.contains {
                if case .unaffordable = $0.state { return true }
                return false
            })
            #expect(content.options.filter {
                if case .locked = $0.state { return true }
                return false
            }.count == 2)

            let node = CampSelectionNode()
            #expect(node.apply(content: content, layout: layout) == .presented)

            for option in content.options {
                let frame = try #require(layout.builderOptionFrames[option.buildingType])
                #expect(builderFrame.contains(frame))
                #expect(frame.minY == layout.builderOptionFrames[.barracks]?.minY)
                #expect(frame.maxY == layout.builderOptionFrames[.barracks]?.maxY)
                let nameFrame = try #require(
                    node.optionNameLabelFrameForTesting(option.buildingType)
                )
                let statusFrame = try #require(
                    node.optionStatusLabelFrameForTesting(option.buildingType)
                )
                #expect(frame.contains(nameFrame))
                #expect(frame.contains(statusFrame))
                let expectedAction: CampSelectionNode.Action = option.state.isAvailable
                    ? .build(option.buildingType)
                    : .requirement(option.buildingType)
                #expect(node.action(at: center(of: frame)) == expectedAction)
            }
            #expect(node.optionPanelStyleForTesting(.barracks) == .selected)
            #expect(node.optionPanelStyleForTesting(.archeryRange) == .normal)
            #expect(node.optionPanelStyleForTesting(.stable) == .disabled)
            #expect(node.optionPanelStyleForTesting(.mageTower) == .disabled)
            #expect(node.optionPanelStyleForTesting(.siegeWorkshop) == .disabled)
            #expect(node.optionRecommendationMarkIsHiddenForTesting(.barracks) == false)
            #expect(node.optionRecommendationMarkIsHiddenForTesting(.stable) == true)
            let markFrame = try #require(
                node.optionRecommendationMarkFrameForTesting(.barracks)
            )
            #expect(layout.builderOptionFrames[.barracks]?.contains(markFrame) == true)
        }
    }

    @Test func inspectorUpgradeDisablesUnaffordableRecommendationAndKeepsMarker() throws {
        var state = KingdomGameState(gold: 100)
        _ = state.buildBuilding(.barracks, inSlot: 1)
        state.gold = 0
        let content = CampSelectionContent.project(from: state, selectedSlot: 1)
        let inspector = try #require(content.inspector)
        #expect(inspector.isRecommended)
        #expect(!inspector.canUpgrade)
        let layout = try #require(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            selection: .occupiedLot(slot: 1)
        )))
        let node = CampSelectionNode()

        #expect(node.apply(content: content, layout: layout) == .presented)

        #expect(node.inspectorActionPanelStyleForTesting == .disabled)
        #expect(!node.inspectorRecommendationMarkIsHiddenForTesting)
        #expect(
            layout.inspectorActionFrame?.contains(
                node.inspectorRecommendationMarkFrameForTesting
            ) == true
        )
        #expect(node.action(at: center(of: layout.inspectorActionFrame!)) == .upgrade)
    }

    @Test func inspectorUpgradeKeepsSelectedAndPrimaryEmphasis() throws {
        var recommendedState = KingdomGameState(gold: 100)
        _ = recommendedState.buildBuilding(.barracks, inSlot: 1)
        let recommendedContent = CampSelectionContent.project(
            from: recommendedState,
            selectedSlot: 1
        )
        #expect(recommendedContent.inspector?.isRecommended == true)
        #expect(recommendedContent.inspector?.canUpgrade == true)
        let layout = try #require(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            selection: .occupiedLot(slot: 1)
        )))
        let node = CampSelectionNode()

        #expect(node.apply(content: recommendedContent, layout: layout) == .presented)
        #expect(node.inspectorActionPanelStyleForTesting == .selected)
        #expect(!node.inspectorRecommendationMarkIsHiddenForTesting)

        var otherState = KingdomGameState(gold: 100)
        _ = otherState.buildBuilding(.barracks, inSlot: 1)
        _ = otherState.buildBuilding(.barracks, inSlot: 2)
        let otherContent = CampSelectionContent.project(from: otherState, selectedSlot: 2)
        #expect(otherContent.inspector?.isRecommended == false)
        #expect(otherContent.inspector?.canUpgrade == true)

        #expect(node.apply(content: otherContent, layout: layout) == .presented)
        #expect(node.inspectorActionPanelStyleForTesting == .primaryAction)
        #expect(node.inspectorRecommendationMarkIsHiddenForTesting)
    }

    private func center(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}
