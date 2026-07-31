import SpriteKit
import Testing
@testable import Pyxis

private enum ConquestReportNodeTestError: Error { case layoutUnavailable }

private func reportLayout(
    rows: Int,
    achievements: Int,
    panelWidth: CGFloat = 319
) throws -> ConquestReportLayout {
    guard let layout = ConquestReportLayout.compute(.init(
        sceneSize: CGSize(width: 393, height: 499),
        safeAreaInsets: ConquestReportSafeAreaInsets(top: 20, left: 0, bottom: 20, right: 0),
        battleContentWidth: panelWidth,
        summaryRowCount: rows,
        achievementCount: achievements,
        compactHeight: true
    )) else {
        throw ConquestReportNodeTestError.layoutUnavailable
    }
    return layout
}

private func fullContent() -> ConquestReportContent {
    ConquestReportContent(
        title: "Country 1 - City 3 Conquered",
        summaryLines: ["Gold earned: +8", "Battle time: 1m", "MVP: Cavalry · 60%", "Deployed: 0 · Lost: 0"],
        achievements: [.favorableUnit, .exposedLane]
    )
}

struct ConquestReportNodeTests {

    @Test func reapplyReusesOneTree() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        let layout = try reportLayout(rows: 4, achievements: 2)
        #expect(node.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .presented)
        let counts = node.nodeCountsForTesting
        #expect(node.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .presented)
        #expect(node.nodeCountsForTesting == counts)
        #expect(node.continueControlCountForTesting == 1)
    }

    @Test func threeRowsHideUnusedLabelAndNoBadgesHideBothSprites() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        let content = ConquestReportContent(
            title: "Country 1 - City 3 Conquered",
            summaryLines: ["Gold earned: +8", "Battle time: 1m", "Deployed: 0 · Lost: 0"],
            achievements: []
        )
        let layout = try reportLayout(rows: 3, achievements: 0)
        #expect(node.apply(content: content, layout: layout, isContinueEnabled: true) == .presented)
        #expect(node.renderedSummaryLinesForTesting == content.summaryLines)
        #expect(node.renderedAchievementSymbolsForTesting == [])
    }

    @Test func badgeOrderAndGoldAnchorAreStable() throws {
        let scene = SKScene(size: .init(width: 393, height: 852))
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        scene.addChild(node)
        let layout = try reportLayout(rows: 4, achievements: 2)
        _ = node.apply(content: fullContent(), layout: layout, isContinueEnabled: true)
        #expect(node.renderedAchievementSymbolsForTesting == ["checkmark.shield.fill", "shield.slash.fill"])
        let firstRow = layout.summaryRowFrames[0]
        #expect(node.goldEffectAnchor(in: scene) == CGPoint(x: firstRow.midX, y: firstRow.midY))
    }

    @Test func disabledContinueAndFitFailureHaveNoHitTarget() throws {
        let layout = try reportLayout(rows: 4, achievements: 2)
        let disabled = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        _ = disabled.apply(content: fullContent(), layout: layout, isContinueEnabled: false)
        let continueCenter = CGPoint(x: layout.continueFrame.midX, y: layout.continueFrame.midY)
        #expect(!disabled.containsContinue(continueCenter))

        let failing = ConquestReportNode(textWidth: { text, _, _ in CGFloat(text.count) * 100 })
        let result = failing.apply(content: fullContent(), layout: layout, isContinueEnabled: true)
        #expect(result == .requiredContentDoesNotFit)
        #expect(failing.continueHitFrameForTesting == nil)
        #expect(failing.goldEffectAnchorForTesting == nil)
    }

    @Test func titleAndRowsOnlyShrinkToTheirMinimums() throws {
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size })
        let layout = try reportLayout(rows: 3, achievements: 0, panelWidth: 319)
        let content = ConquestReportContent(
            title: String(repeating: "T", count: 20),
            summaryLines: [
                String(repeating: "R", count: 20),
                "Battle time: 1m",
                "Deployed: 0 · Lost: 0"
            ],
            achievements: []
        )
        _ = node.apply(content: content, layout: layout, isContinueEnabled: true)
        #expect(node.titleFontSizeForTesting >= 14)
        #expect(node.summaryFontSizesForTesting.allSatisfy { $0 >= 12 })
        #expect(node.renderedSummaryLinesForTesting == content.summaryLines)
    }
}
