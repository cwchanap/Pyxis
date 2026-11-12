import SpriteKit
import Testing
import UIKit
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

private enum RenderedPixelSamplingError: Error {
    case imageDrawFailed
    case emptySampleRegion
}

/// Draws the rendered scene image into an RGBA8 buffer and counts the pixels
/// matching `isMatch` inside `sceneRect`, a rect in bottom-left-origin scene
/// coordinates. Throws instead of returning a vacuous (0, 0) when the bitmap
/// cannot be drawn or the sampled region is empty, so a failed sample can
/// never satisfy the callers' thresholds.
private func renderedPixelStats(
    in image: CGImage,
    sceneRect: CGRect,
    sceneSize: CGSize,
    isMatch: (Int, Int, Int) -> Bool
) throws -> (matchingPixels: Int, totalPixels: Int) {
    guard image.width > 0, image.height > 0 else { throw RenderedPixelSamplingError.imageDrawFailed }
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    guard drawn else { throw RenderedPixelSamplingError.imageDrawFailed }

    let scaleX = CGFloat(image.width) / sceneSize.width
    let scaleY = CGFloat(image.height) / sceneSize.height
    // CGImage rows run top-down; scene Y runs bottom-up.
    let minX = max(0, Int((sceneRect.minX * scaleX).rounded(.down)))
    let maxX = min(image.width, Int((sceneRect.maxX * scaleX).rounded(.up)))
    let minY = max(0, Int(((sceneSize.height - sceneRect.maxY) * scaleY).rounded(.down)))
    let maxY = min(image.height, Int(((sceneSize.height - sceneRect.minY) * scaleY).rounded(.up)))
    guard minX < maxX, minY < maxY else { throw RenderedPixelSamplingError.emptySampleRegion }

    var matchingPixels = 0
    var totalPixels = 0
    for y in minY..<maxY {
        for x in minX..<maxX {
            let offset = (y * image.width + x) * 4
            totalPixels += 1
            if isMatch(
                Int(pixels[offset]),
                Int(pixels[offset + 1]),
                Int(pixels[offset + 2])
            ) {
                matchingPixels += 1
            }
        }
    }
    return (matchingPixels, totalPixels)
}

/// "Light" pixels — every channel above 150, the floor a readable light glyph
/// on the dark forged tiles clears (`textPrimary` renders ≈ 250/240/214 while
/// the tile fill and its top-light stay below ≈ 115).
private func renderedLightPixelStats(
    in image: CGImage,
    sceneRect: CGRect,
    sceneSize: CGSize
) throws -> (lightPixels: Int, totalPixels: Int) {
    let stats = try renderedPixelStats(in: image, sceneRect: sceneRect, sceneSize: sceneSize) {
        $0 > 150 && $1 > 150 && $2 > 150
    }
    return (stats.matchingPixels, stats.totalPixels)
}

/// Expected sRGB tint for a rendered-glyph pixel match.
private struct ExpectedGlyphColor {
    let red: Int
    let green: Int
    let blue: Int
}

/// Pixels close to an expected sRGB color (±80 per channel) — used to verify
/// a tinted glyph actually renders its configured color, not a generic
/// "bright" pixel, since the achievement chips tint green/gold rather than
/// `textPrimary`. The ±80 band accepts antialiased glyph edges while the
/// dark chip fill (≈ 16% tint over the panel) stays outside it.
private func renderedColorPixelStats(
    in image: CGImage,
    sceneRect: CGRect,
    sceneSize: CGSize,
    expected: ExpectedGlyphColor
) throws -> (matchingPixels: Int, totalPixels: Int) {
    try renderedPixelStats(in: image, sceneRect: sceneRect, sceneSize: sceneSize) { r, g, b in
        abs(r - expected.red) <= 80
            && abs(g - expected.green) <= 80
            && abs(b - expected.blue) <= 80
    }
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

    /// HPA-812 Task 1: the SIEGE (`timer`) and SENT/LOST (`person.3.fill`)
    /// icons are monochrome SF Symbol textures tinted `textPrimary` via
    /// `colorBlendFactor = 1`. On the dark forged tiles the rendered glyph
    /// must actually reach light pixels — the Forged mock shows light icons —
    /// so this samples the real rendered output rather than the configured
    /// `color`/`colorBlendFactor`.
    @Test @MainActor func symbolStatIconsRenderReadablePixelsOnDarkTiles() throws {
        let scene = SKScene(size: CGSize(width: 393, height: 852))
        scene.backgroundColor = SKColor(red: 0.10, green: 0.08, blue: 0.05, alpha: 1)
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        scene.addChild(node)
        let layout = try reportLayout(tiles: 3, chips: 2, sceneSize: scene.size)
        #expect(node.apply(
            content: fullContent(),
            layout: layout,
            isContinueEnabled: true,
            cityNumber: 3,
            cityName: "Falconridge"
        ) == .presented)

        let window = UIWindow(frame: CGRect(origin: .zero, size: scene.size))
        let view = SKView(frame: window.bounds)
        window.addSubview(view)
        window.isHidden = false
        view.presentScene(scene)
        defer { window.isHidden = true }

        let texture = try #require(view.texture(from: scene))
        let image = texture.cgImage()

        // fullContent tiles: [mvp(cavalry), battleTime("timer"), sentLost("person.3.fill")].
        for index in [1, 2] {
            let icon = try #require(
                node.childNode(withName: "//conquestStatTileIcon-\(index)") as? SKSpriteNode
            )
            let parent = try #require(icon.parent)
            let iconFrame = scene.convert(icon.frame, from: parent)
            let stats = try renderedLightPixelStats(
                in: image,
                sceneRect: iconFrame,
                sceneSize: scene.size
            )
            // A readable glyph paints a visible share of its sprite area in
            // light pixels; a glyph stuck dark contributes none.
            #expect(stats.lightPixels >= stats.totalPixels / 20)
        }
    }

    /// HPA-812 Task 1: the achievement chip icons (`checkmark.shield.fill`
    /// green, `shield.slash.fill` gold) are the same monochrome SF Symbol +
    /// `colorBlendFactor = 1` path as the stat icons — assert each chip's
    /// rendered pixels reach its configured tint color, not generic white.
    @Test @MainActor func achievementChipIconsRenderTheirTintedColors() throws {
        let scene = SKScene(size: CGSize(width: 393, height: 852))
        scene.backgroundColor = SKColor(red: 0.10, green: 0.08, blue: 0.05, alpha: 1)
        let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
        scene.addChild(node)
        let layout = try reportLayout(tiles: 3, chips: 2, sceneSize: scene.size)
        #expect(node.apply(
            content: fullContent(),
            layout: layout,
            isContinueEnabled: true,
            cityNumber: 3,
            cityName: "Falconridge"
        ) == .presented)

        let window = UIWindow(frame: CGRect(origin: .zero, size: scene.size))
        let view = SKView(frame: window.bounds)
        window.addSubview(view)
        window.isHidden = false
        view.presentScene(scene)
        defer { window.isHidden = true }

        let texture = try #require(view.texture(from: scene))
        let image = texture.cgImage()

        // fullContent achievements: [favorableUnit (61,204,97), exposedLane (gold 255,204,56)].
        let expected: [(index: Int, color: ExpectedGlyphColor)] = [
            (0, ExpectedGlyphColor(red: 61, green: 204, blue: 97)),
            (1, ExpectedGlyphColor(red: 255, green: 204, blue: 56))
        ]
        for chip in expected {
            let icon = try #require(
                node.childNode(withName: "//conquestAchievementChipIcon-\(chip.index)") as? SKSpriteNode
            )
            let parent = try #require(icon.parent)
            // Inset so the sample cannot clip the chip's same-colored border
            // ring, which passes within ~2pt of the 13pt icon at midY.
            let iconFrame = scene.convert(icon.frame, from: parent).insetBy(dx: 2, dy: 2)
            let stats = try renderedColorPixelStats(
                in: image,
                sceneRect: iconFrame,
                sceneSize: scene.size,
                expected: chip.color
            )
            #expect(stats.matchingPixels >= stats.totalPixels / 20)
        }
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
