//
//  CampChromeLayoutTests.swift
//  PyxisTests
//

import CoreGraphics
import Testing
@testable import Pyxis

struct CampChromeLayoutTests {
    @Test func referencePhoneFitsBuilderAndInspectorGeometry() throws {
        let empty = try #require(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            selection: .emptyLot(slot: 1)
        )))
        let occupied = try #require(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            selection: .occupiedLot(slot: 1)
        )))

        #expect(empty.builderOptionFrames.count == BuildingType.allCases.count)
        #expect(empty.builderOptionFrames.values.allSatisfy { $0.width >= 44 && $0.height >= 44 })
        #expect(empty.builderOptionFrames.values.allSatisfy { empty.safeFrame.contains($0) })
        #expect(occupied.inspectorFrame != nil)
        #expect(occupied.inspectorFrame.map { occupied.safeFrame.contains($0) } == true)
        #expect(occupied.tabBarFrame == CGRect(x: 16, y: 0, width: 361, height: 82))
        #expect(occupied.inspectorFrame == CGRect(x: 16, y: 92, width: 361, height: 114))
        #expect(occupied.tabHitFrames.values.allSatisfy { $0.width >= 44 && $0.height >= 44 })
        #expect(occupied.tabHitFrames.values.allSatisfy { occupied.safeFrame.contains($0) })
    }

    @Test func edgeLotsKeepBuilderOptionsInsideSafeContentAndAwayFromTabs() throws {
        for slot in CityBattleState.slotRange {
            let layout = try #require(CampChromeLayout.compute(.init(
                sceneSize: CGSize(width: 393, height: 852),
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                selection: .emptyLot(slot: slot)
            )))

            #expect(layout.lotHitFrames[slot]?.width ?? 0 >= 44)
            #expect(layout.lotHitFrames[slot]?.height ?? 0 >= 44)
            for frame in layout.builderOptionFrames.values {
                #expect(layout.safeFrame.contains(frame))
                #expect(!frame.intersects(layout.tabBarFrame))
            }
        }
    }

    @Test func compactPhoneAndPadRemainSupported() {
        #expect(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 667),
            safeAreaInsets: .zero,
            selection: .emptyLot(slot: 25)
        )) != nil)
        #expect(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 834, height: 1194),
            safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0),
            selection: .occupiedLot(slot: 12)
        )) != nil)
    }

    @Test func selectionStatesReserveOne114PointBudgetAndKeepLotsFixed() throws {
        let insets = CampSafeAreaInsets(top: 59, left: 0, bottom: 34, right: 0)
        let size = CGSize(width: 393, height: 852)
        let none = try #require(CampChromeLayout.compute(.init(
            sceneSize: size,
            safeAreaInsets: insets,
            selection: .none
        )))
        let empty = try #require(CampChromeLayout.compute(.init(
            sceneSize: size,
            safeAreaInsets: insets,
            selection: .emptyLot(slot: 1)
        )))
        let occupied = try #require(CampChromeLayout.compute(.init(
            sceneSize: size,
            safeAreaInsets: insets,
            selection: .occupiedLot(slot: 1)
        )))

        #expect(none.builderFrame == nil)
        #expect(none.inspectorFrame == nil)
        #expect(empty.builderFrame == CGRect(x: 16, y: 92, width: 361, height: 114))
        #expect(occupied.inspectorFrame == CGRect(x: 16, y: 92, width: 361, height: 114))
        #expect(none.lotRegionFrame == CGRect(x: 0, y: 216, width: 393, height: 469))
        #expect(empty.lotRegionFrame == none.lotRegionFrame)
        #expect(occupied.lotRegionFrame == none.lotRegionFrame)
        #expect(empty.feedbackFrame == none.feedbackFrame)
        #expect(occupied.feedbackFrame == none.feedbackFrame)
        #expect(none.lotPositions.count == CityBattleState.slotRange.count)
        for slot in CityBattleState.slotRange {
            #expect(empty.lotPositions[slot] == none.lotPositions[slot])
            #expect(occupied.lotPositions[slot] == none.lotPositions[slot])
            #expect(empty.lotHitFrames[slot] == none.lotHitFrames[slot])
            #expect(occupied.lotHitFrames[slot] == none.lotHitFrames[slot])
        }
    }

    @Test func builderOptionCardsShareOneBaselineInsideThe114PointPanel() throws {
        let layout = try #require(CampChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            selection: .emptyLot(slot: 1)
        )))
        let builderFrame = try #require(layout.builderFrame)
        let optionFrames = try BuildingType.allCases.map { type in
            try #require(layout.builderOptionFrames[type])
        }

        #expect(builderFrame.height == 114)
        for frame in optionFrames {
            #expect(builderFrame.contains(frame))
            #expect(frame.minY == optionFrames[0].minY)
            #expect(frame.maxY == optionFrames[0].maxY)
            #expect(frame.width >= CampChromeLayout.minimumInteractiveSize)
            #expect(frame.height >= CampChromeLayout.minimumInteractiveSize)
        }
    }

    @Test func goldHeaderFramesStayInsideThePanelAndReserveATextBudget() throws {
        let cases: [(CGSize, CampSafeAreaInsets)] = [
            (CGSize(width: 393, height: 852), CampSafeAreaInsets(top: 59, left: 0, bottom: 34, right: 0)),
            (CGSize(width: 320, height: 568), .zero)
        ]
        for (size, insets) in cases {
            let layout = try #require(CampChromeLayout.compute(.init(
                sceneSize: size,
                safeAreaInsets: insets
            )))

            #expect(layout.goldFrame.contains(layout.goldIconFrame))
            #expect(layout.goldFrame.contains(layout.goldTextFrame))
            #expect(layout.goldIconFrame.width == layout.goldIconFrame.height)
            #expect(layout.goldIconFrame.width >= 16 && layout.goldIconFrame.width <= 28)
            #expect(layout.goldIconFrame.minX - layout.goldFrame.minX >= 4)
            #expect(layout.goldTextFrame.minX == layout.goldIconFrame.maxX + 3)
            #expect(layout.goldTextFrame.midY == layout.goldFrame.midY)
            #expect(layout.goldTextFrame.width > 0)
        }
    }

    @Test func smallestPhoneKeepsLotsAboveTheRegionFloorForEverySelection() throws {
        for selection in [
            CampChromeLayout.Selection.none,
            .emptyLot(slot: 1),
            .occupiedLot(slot: 1)
        ] {
            let layout = try #require(CampChromeLayout.compute(.init(
                sceneSize: CGSize(width: 320, height: 568),
                safeAreaInsets: .zero,
                selection: selection
            )))
            #expect(layout.lotRegionFrame.height >= 180)
            #expect(layout.lotRegionFrame.minY > layout.tabBarFrame.maxY)
        }
    }
}
