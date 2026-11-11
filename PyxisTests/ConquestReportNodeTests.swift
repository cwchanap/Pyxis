import SpriteKit
import Testing
@testable import Pyxis

private enum ConquestReportNodeTestError: Error { case layoutUnavailable }

private func reportLayout(
    tiles: Int,
    chips: Int,
    panelWidth: CGFloat = 319,
    sceneSize: CGSize = CGSize(width: 393, height: 499),
    includesGearLine: Bool = false
) throws -> ConquestReportLayout {
    guard let layout = ConquestReportLayout.compute(.init(
        sceneSize: sceneSize,
        safeAreaInsets: ConquestReportSafeAreaInsets(top: 20, left: 0, bottom: 20, right: 0),
        battleContentWidth: panelWidth,
        tileCount: tiles,
        chipCount: chips,
        compactHeight: sceneSize.height < 500,
        includesGearLine: includesGearLine
    )) else {
        throw ConquestReportNodeTestError.layoutUnavailable
    }
    return layout
}

private func fullContent(newGearLineText: String? = nil) -> ConquestReportContent {
    ConquestReportContent(
        title: "Falconridge Silenced",
        rewardText: "+8",
        newGearLineText: newGearLineText,
        tiles: [
            .mvp(soldierType: .cavalry, sharePercent: 60),
            .battleTime(seconds: 60),
            .sentLost(sent: 0, lost: 0)
        ],
        achievements: [.favorableUnit, .exposedLane]
    )
}

struct ConquestReportNodeTests {
    @Test func reapplyReusesOneTree() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        let layout = try reportLayout(tiles: 3, chips: 2)
        #expect(node.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .presented)
        let counts = node.nodeCountsForTesting
        #expect(node.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .presented)
        #expect(node.nodeCountsForTesting == counts)
        #expect(node.continueControlCountForTesting == 1)
    }

    @Test func takenCrestScalesWithCompactAndReferenceMedallions() throws {
        let node = ConquestReportNode()
        let compact = try reportLayout(tiles: 3, chips: 2, sceneSize: CGSize(width: 393, height: 499))
        #expect(compact.takenMedallionFrame == nil)
        let reference = try reportLayout(tiles: 3, chips: 2, sceneSize: CGSize(width: 393, height: 852))
        let compactFrame = CGRect(x: reference.safeFrame.midX - 48, y: reference.panelFrame.maxY, width: 96, height: 96)
        let compactPresentation = ConquestReportLayout(
            safeFrame: reference.safeFrame,
            panelFrame: reference.panelFrame,
            takenMedallionFrame: compactFrame,
            titleFrame: reference.titleFrame,
            rewardFrame: reference.rewardFrame,
            gearLabelFrame: reference.gearLabelFrame,
            tileFrames: reference.tileFrames,
            chipStripFrame: reference.chipStripFrame,
            chipFrames: reference.chipFrames,
            continueFrame: reference.continueFrame,
            countryCompleteFrame: reference.countryCompleteFrame,
            panelCornerRadius: reference.panelCornerRadius,
            titleStartingFontSize: reference.titleStartingFontSize,
            titleMinimumFontSize: reference.titleMinimumFontSize,
            rewardStartingFontSize: reference.rewardStartingFontSize,
            rewardMinimumFontSize: reference.rewardMinimumFontSize,
            tileValueStartingFontSize: reference.tileValueStartingFontSize,
            tileValueMinimumFontSize: reference.tileValueMinimumFontSize,
            tileLabelStartingFontSize: reference.tileLabelStartingFontSize,
            tileLabelMinimumFontSize: reference.tileLabelMinimumFontSize,
            chipStartingFontSize: reference.chipStartingFontSize,
            chipMinimumFontSize: reference.chipMinimumFontSize,
            continueStartingFontSize: reference.continueStartingFontSize,
            continueMinimumFontSize: reference.continueMinimumFontSize,
            gearStartingFontSize: reference.gearStartingFontSize,
            gearMinimumFontSize: reference.gearMinimumFontSize
        )
        for layout in [compactPresentation, reference] {
            let frame = try #require(layout.takenMedallionFrame)
            #expect(node.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .presented)
            let medallion = try #require(node.childNode(withName: "conquestTakenMedallion"))
            let icon = try #require(medallion.childNode(withName: "conquestTakenMedallionIcon") as? SKSpriteNode)
            let label = try #require(medallion.childNode(withName: "conquestTakenMedallionLabel") as? SKLabelNode)
            let outer = try #require(medallion.childNode(withName: "conquestTakenMedallionOuter") as? SKShapeNode)
            let inner = try #require(medallion.childNode(withName: "conquestTakenMedallionInner") as? SKShapeNode)
            #expect(!medallion.isHidden)
            #expect(icon.size.width >= frame.width * 0.45)
            #expect(icon.size.width <= frame.width * 0.50)
            #expect(icon.size.height == icon.size.width)
            #expect(!icon.frame.intersects(label.frame))
            #expect(try #require(inner.path).boundingBox.contains(icon.frame))
            #expect(try #require(outer.path).boundingBox.width == frame.width)
            #expect(label.text == "TAKEN")
            #expect(layout.safeFrame.contains(frame))
        }
    }

    @Test func twoTilesHideUnusedBundlesAndNoChipsHideBoth() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        let content = ConquestReportContent(
            title: "Falconridge Silenced",
            rewardText: "+8",
            tiles: [.battleTime(seconds: 60), .sentLost(sent: 0, lost: 0)],
            achievements: []
        )
        let layout = try reportLayout(tiles: 2, chips: 0)
        #expect(node.apply(content: content, layout: layout, isContinueEnabled: true) == .presented)
        #expect(node.renderedTilesForTesting == content.tiles)
        #expect(node.renderedChipSymbolsForTesting == [])
    }

    @Test func chipOrderAndGoldAnchorAreStable() throws {
        let scene = SKScene(size: .init(width: 393, height: 852))
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        scene.addChild(node)
        let content = fullContent()
        let layout = try reportLayout(tiles: 3, chips: 2)
        _ = node.apply(content: content, layout: layout, isContinueEnabled: true)
        #expect(node.renderedChipSymbolsForTesting == ["checkmark.shield.fill", "shield.slash.fill"])
        #expect(node.goldEffectAnchor(in: scene) == CGPoint(
            x: layout.rewardFrame.midX,
            y: layout.rewardFrame.midY
        ))
    }

    @Test func chipCentersHonorConfiguredGap() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        let layout = try reportLayout(tiles: 3, chips: 2)
        _ = node.apply(content: fullContent(), layout: layout, isContinueEnabled: true)
        let centers = node.renderedChipCentersForTesting
        #expect(centers.count == 2)
        #expect(centers[0].y == centers[1].y)
        #expect(centers[1].x - centers[0].x == 112)
        #expect(layout.chipFrames.map(\.midX) == centers.map(\.x))
    }

    @Test func disabledContinueAndFitFailureHaveNoHitTarget() throws {
        let layout = try reportLayout(tiles: 3, chips: 2)
        let disabled = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        _ = disabled.apply(content: fullContent(), layout: layout, isContinueEnabled: false)
        let continueCenter = CGPoint(x: layout.continueFrame.midX, y: layout.continueFrame.midY)
        #expect(!disabled.containsContinue(continueCenter))
        let enabled = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        _ = enabled.apply(content: fullContent(), layout: layout, isContinueEnabled: true)
        #expect(disabled.continueBackgroundAlphaForTesting < enabled.continueBackgroundAlphaForTesting)
        #expect(enabled.continueBackgroundAlphaForTesting == 1.0)

        let failing = ConquestReportNode(textWidth: { text, _, _ in CGFloat(text.count) * 100 })
        let result = failing.apply(content: fullContent(), layout: layout, isContinueEnabled: true)
        #expect(result == .requiredContentDoesNotFit)
        #expect(failing.continueHitFrameForTesting == nil)
        #expect(failing.goldEffectAnchorForTesting == nil)
    }

    @Test func titleRewardAndTileTextShrinkToTheirMinimums() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size })
        let layout = try reportLayout(tiles: 2, chips: 0, panelWidth: 319)
        let content = ConquestReportContent(
            title: String(repeating: "T", count: 20),
            rewardText: String(repeating: "R", count: 10),
            tiles: [.battleTime(seconds: 60), .sentLost(sent: 0, lost: 0)],
            achievements: []
        )
        let result = node.apply(content: content, layout: layout, isContinueEnabled: true)
        #expect(result == .presented)
        #expect(node.titleFontSizeForTesting >= 14)
        #expect(node.rewardFontSizeForTesting >= 20)
        #expect(node.tileValueFontSizesForTesting.allSatisfy { $0 >= 11 })
        #expect(node.renderedTilesForTesting == content.tiles)
        #expect(node.renderedContinueTextForTesting == "MARCH ON")
    }

    @Test func victoryReportUsesTakenCityHeaderAndForgedContinueTreatment() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        let layout = try reportLayout(tiles: 3, chips: 2, sceneSize: CGSize(width: 393, height: 852))

        #expect(node.apply(
            content: fullContent(),
            layout: layout,
            isContinueEnabled: true,
            cityNumber: 3,
            cityName: "Falconridge"
        ) == .presented)
        #expect(node.renderedTakenStatusTextForTesting == "TAKEN")
        #expect(node.takenMedallionUsesAuthoredIconForTesting)
        #expect(node.rewardUsesAuthoredCoinForTesting)
        #expect(node.tileIconColorBlendFactorsForTesting.first == 0)
        #expect(node.tileIconTextureRectsForTesting.first
            == SoldierAnimationGeometry(type: .cavalry).bodyRegion)
        #expect(node.renderedCityNumberTextForTesting == "CITY 3")
        #expect(node.renderedCityTitleForTesting == "Falconridge")
        #expect(node.continuePanelStyleForTesting == .primaryAction)
        #expect(node.continueUsesForgedAppearanceForTesting)
        #expect(node.statTilesUseForgedAppearanceForTesting)
    }

    @Test func gearLineRendersAndClearsOnNodeReuse() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        let layout = try reportLayout(
            tiles: 3,
            chips: 2,
            sceneSize: CGSize(width: 393, height: 852),
            includesGearLine: true
        )

        #expect(node.apply(
            content: fullContent(newGearLineText: "New gear: Willowford Blade · Lv 1"),
            layout: layout,
            isContinueEnabled: true
        ) == .presented)
        #expect(node.renderedGearLineTextForTesting == "New gear: Willowford Blade · Lv 1")

        // A subsequent report without a new reward reuses the same node and
        // must not keep a stale gear line (HPA-671 Task 5).
        #expect(node.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .presented)
        #expect(node.renderedGearLineTextForTesting == nil)
    }

    @Test func renderedGearLabelsKeepClearanceFromRequiredPanels() throws {
        let node = ConquestReportNode()
        let layout = try reportLayout(
            tiles: 3,
            chips: 2,
            sceneSize: CGSize(width: 393, height: 852),
            includesGearLine: true
        )

        for item in EquipmentCatalog.items {
            // The longest line an item can ever render: the upgrade wording
            // at the level cap (HPA-672 level-aware receipts).
            let result = node.apply(
                content: fullContent(newGearLineText: "Gear upgraded: \(item.name) · Lv 3"),
                layout: layout,
                isContinueEnabled: true
            )
            #expect(result == .presented)
            let label = try #require(node.childNode(withName: "conquestGearLineLabel") as? SKLabelNode)
            #expect(!label.isHidden)
            #expect(layout.rewardFrame.minY - label.frame.maxY >= 2)
            #expect(label.frame.minY - layout.tileFrames[0].maxY >= 2)
        }
    }

    @Test func gearLineHidesWithoutFailingCompactOrUnfittableReports() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        let compactLayout = try reportLayout(
            tiles: 3,
            chips: 2,
            sceneSize: CGSize(width: 393, height: 499),
            includesGearLine: true
        )
        #expect(compactLayout.gearLabelFrame == nil)
        #expect(node.apply(
            content: fullContent(newGearLineText: "New gear: Willowford Blade · Lv 1"),
            layout: compactLayout,
            isContinueEnabled: true
        ) == .presented)
        #expect(node.renderedGearLineTextForTesting == nil)
        #expect(node.containsContinue(CGPoint(
            x: compactLayout.continueFrame.midX,
            y: compactLayout.continueFrame.midY
        )))

        // Roomy frame but the gear text cannot fit even at the minimum font —
        // only the label is dropped; required content still presents.
        let unfittable = ConquestReportNode(textWidth: { text, _, size in
            text.hasPrefix("New gear:") || text.hasPrefix("Gear upgraded:")
                ? .greatestFiniteMagnitude
                : CGFloat(text.count) * size * 0.45
        })
        let roomyLayout = try reportLayout(
            tiles: 3,
            chips: 2,
            sceneSize: CGSize(width: 393, height: 852),
            includesGearLine: true
        )
        #expect(unfittable.apply(
            content: fullContent(newGearLineText: "Gear upgraded: Willowford Blade · Lv 2"),
            layout: roomyLayout,
            isContinueEnabled: true
        ) == .presented)
        #expect(unfittable.renderedGearLineTextForTesting == nil)
        #expect(unfittable.containsContinue(CGPoint(
            x: roomyLayout.continueFrame.midX,
            y: roomyLayout.continueFrame.midY
        )))
    }

    @Test("The smallest supported roomy viewport presents with the longest level-aware gear line")
    func minimumSizeRoomyLayoutPresentsWithLongestLevelAwareGearLine() throws {
        // 375×667 is the smallest supported roomy report fixture: the
        // longest possible line (upgrade wording, finale item, cap level)
        // must never fail the report — the label renders with clearance or
        // drops, and Continue stays hit-testable either way (HPA-672).
        let node = ConquestReportNode()
        let layout = try reportLayout(
            tiles: 3,
            chips: 2,
            sceneSize: CGSize(width: 375, height: 667),
            includesGearLine: true
        )

        #expect(node.apply(
            content: fullContent(newGearLineText: "Gear upgraded: Crownspire Breaker · Lv 3"),
            layout: layout,
            isContinueEnabled: true
        ) == .presented)
        #expect(node.containsContinue(CGPoint(
            x: layout.continueFrame.midX,
            y: layout.continueFrame.midY
        )))
        if node.renderedGearLineTextForTesting != nil {
            let label = try #require(
                node.childNode(withName: "conquestGearLineLabel") as? SKLabelNode
            )
            #expect(layout.rewardFrame.minY - label.frame.maxY >= 2)
            #expect(label.frame.minY - layout.tileFrames[0].maxY >= 2)
        }
    }
}
