//
//  CampSelectionNodeTests.swift
//  PyxisTests
//

import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
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

    private func center(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}
