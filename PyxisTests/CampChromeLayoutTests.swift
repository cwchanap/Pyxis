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
}
