//
//  BattleChromeLayout.swift
//  Pyxis
//

import CoreGraphics

struct BattleChromeLayout: Equatable {
    static let minimumBattlefieldHeight: CGFloat = 416
    static let compactMinimumBattlefieldHeight: CGFloat = 340
    static let sideMargin: CGFloat = 16
    static let tabBarHeight: CGFloat = 72
    static let medallionVisualSize: CGFloat = 56

    struct SafeAreaInsets: Equatable {
        let top: CGFloat
        let left: CGFloat
        let bottom: CGFloat
        let right: CGFloat

        static let zero = SafeAreaInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    struct Input: Equatable {
        let sceneSize: CGSize
        let safeAreaInsets: SafeAreaInsets
        let isCompact: Bool?

        init(
            sceneSize: CGSize,
            safeAreaInsets: SafeAreaInsets = .zero,
            isCompact: Bool? = nil
        ) {
            self.sceneSize = sceneSize
            self.safeAreaInsets = safeAreaInsets
            self.isCompact = isCompact
        }
    }

    typealias Constraints = Input

    let sceneFrame: CGRect
    let safeFrame: CGRect
    let topBandFrame: CGRect
    let incomeFrame: CGRect
    let cityProgressFrame: CGRect
    let recommendationFrame: CGRect
    let feedbackFrame: CGRect
    let objectiveFrame: CGRect
    let statusFrame: CGRect
    let settingsFrame: CGRect
    let medallionFrames: [CGRect]
    let medallionHitFrames: [CGRect]
    let deployFrame: CGRect
    let manualCountFrame: CGRect
    let battlefieldFrame: CGRect
    let battlefield: BattlefieldLayout
    let laneChipFrames: [BattleLane: CGRect]
    let tabBarFrame: CGRect
    let tabHitFrames: [CGRect]
    let isCompact: Bool

    var fieldFrame: CGRect { battlefieldFrame }
    var tabFrame: CGRect { tabBarFrame }

    static func compute(_ input: Input) -> BattleChromeLayout? {
        let size = input.sceneSize
        let insets = input.safeAreaInsets
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0,
              [insets.top, insets.left, insets.bottom, insets.right]
                .allSatisfy({ $0.isFinite && $0 >= 0 })
        else {
            return nil
        }

        let sceneFrame = CGRect(origin: .zero, size: size)
        let safeWidth = size.width - insets.left - insets.right
        let safeHeight = size.height - insets.top - insets.bottom
        guard safeWidth > 0, safeHeight > 0 else { return nil }

        let safeFrame = CGRect(
            x: insets.left,
            y: insets.bottom,
            width: safeWidth,
            height: safeHeight
        )
        let compact = input.isCompact ?? (size.height < 780)
        let contentWidth = min(560, safeWidth - sideMargin * 2)
        guard contentWidth >= medallionVisualSize,
              contentWidth > 0 else { return nil }

        let contentX = safeFrame.midX - contentWidth / 2
        let tabBarFrame = CGRect(
            x: contentX,
            y: safeFrame.minY,
            width: contentWidth,
            height: tabBarHeight
        )
        let deployFrame = CGRect(
            x: contentX,
            y: tabBarFrame.maxY + 10,
            width: contentWidth,
            height: compact ? 56 : 58
        )
        let manualCountFrame = CGRect(
            x: deployFrame.maxX - 76,
            y: deployFrame.midY - 22,
            width: 68,
            height: 44
        )

        let medallionGap = (contentWidth - CGFloat(5) * medallionVisualSize) / 4
        guard medallionGap >= 0 else { return nil }
        let medallionY = deployFrame.maxY + 10
        let medallionFrames = (0..<5).map { index in
            CGRect(
                x: contentX + CGFloat(index) * (medallionVisualSize + medallionGap),
                y: medallionY,
                width: medallionVisualSize,
                height: medallionVisualSize
            )
        }
        let medallionHitFrames = medallionFrames.map { frame in
            let hitWidth = max(44, frame.width)
            let hitHeight = max(44, frame.height)
            return CGRect(
                x: frame.midX - hitWidth / 2,
                y: frame.midY - hitHeight / 2,
                width: hitWidth,
                height: hitHeight
            )
        }

        let fieldMinY = medallionFrames[0].maxY + 10
        let topBandGap: CGFloat = 12
        let minimumTopBandHeight: CGFloat = 76
        let minimumFieldHeight = compact
            ? compactMinimumBattlefieldHeight
            : minimumBattlefieldHeight
        let maximumFieldHeight = safeFrame.maxY
            - topBandGap
            - minimumTopBandHeight
            - fieldMinY
        guard maximumFieldHeight >= minimumFieldHeight else { return nil }

        let preferredFieldHeight: CGFloat = compact ? 342 : 432
        let fieldHeight = min(preferredFieldHeight, maximumFieldHeight)
        guard fieldHeight >= minimumFieldHeight else { return nil }
        let battlefieldFrame = CGRect(
            x: contentX,
            y: fieldMinY,
            width: contentWidth,
            height: fieldHeight
        )

        let battlefield = BattlefieldLayout.compute(constraints: .init(
            sceneSize: size,
            contentWidth: contentWidth,
            safeTopY: battlefieldFrame.maxY,
            safeBottomY: battlefieldFrame.minY,
            feedbackY: battlefieldFrame.minY,
            feedbackFontSize: 0
        ))
        guard battlefield.isVisible,
              nearlyEqual(battlefield.frame, battlefieldFrame) else {
            return nil
        }

        let topBandFrame = CGRect(
            x: contentX,
            y: battlefieldFrame.maxY + topBandGap,
            width: contentWidth,
            height: safeFrame.maxY - battlefieldFrame.maxY - topBandGap
        )
        // Keep the actual battlefield budget unchanged while splitting the
        // top chrome into three fixed visual bands. The compact row heights
        // are deliberately tight so the 340pt field floor remains available
        // on short phones.
        let topRowHeight: CGFloat = 44
        let preferredRecommendationHeight: CGFloat = compact ? 40 : 52
        let rowGap: CGFloat = compact ? 8 : 10
        let topRowY = topBandFrame.maxY - 4 - topRowHeight
        let recommendationHeight = min(
            preferredRecommendationHeight,
            max(32, topBandFrame.height - topRowHeight - rowGap - 8)
        )
        let recommendationFrame = CGRect(
            x: topBandFrame.minX,
            y: max(topBandFrame.minY + 4, topRowY - rowGap - recommendationHeight),
            width: topBandFrame.width,
            height: recommendationHeight
        )
        let settingsFrame = CGRect(
            x: topBandFrame.maxX - 44,
            y: topRowY,
            width: 44,
            height: topRowHeight
        )
        // The authored chrome gives the gold/income readout enough room for
        // its coin and two compact values. The city progress row remains
        // between this band and the 44pt settings hit target.
        let incomeWidth = min(160, max(112, topBandFrame.width * 0.42))
        let incomeFrame = CGRect(
            x: topBandFrame.minX,
            y: topRowY,
            width: incomeWidth,
            height: topRowHeight
        )
        let cityProgressFrame = CGRect(
            x: incomeFrame.maxX + 8,
            y: topRowY,
            width: settingsFrame.minX - incomeFrame.maxX - 16,
            height: topRowHeight
        )
        guard cityProgressFrame.width >= 44 else { return nil }

        // Legacy names remain aliases for callers that only need the city and
        // recommendation hit regions. They no longer describe one shared
        // panel, and each visual band has its own fixed frame above.
        let objectiveFrame = recommendationFrame
        let statusFrame = cityProgressFrame
        let feedbackFrame = CGRect(
            x: battlefieldFrame.minX + 8,
            y: battlefieldFrame.midY - 18,
            width: battlefieldFrame.width - 16,
            height: 36
        )

        let laneChipFrames = laneFrames(in: battlefieldFrame)
        let tabHitFrames = (0..<3).map { index in
            let width = tabBarFrame.width / 3
            let cell = CGRect(
                x: tabBarFrame.minX + CGFloat(index) * width,
                y: tabBarFrame.minY,
                width: width,
                height: tabBarFrame.height
            )
            return cell.insetBy(dx: 4, dy: 4)
        }

        let frames = [
            sceneFrame,
            safeFrame,
            topBandFrame,
            incomeFrame,
            cityProgressFrame,
            recommendationFrame,
            feedbackFrame,
            objectiveFrame,
            statusFrame,
            settingsFrame,
            deployFrame,
            manualCountFrame,
            battlefieldFrame,
            tabBarFrame
        ] + medallionFrames + medallionHitFrames + tabHitFrames
            + Array(laneChipFrames.values)
        guard frames.allSatisfy({
            $0.minX.isFinite
                && $0.minY.isFinite
                && $0.width.isFinite
                && $0.height.isFinite
                && $0.width > 0
                && $0.height > 0
        }),
              safeFrame.contains(topBandFrame),
              safeFrame.contains(deployFrame),
              safeFrame.contains(manualCountFrame),
              safeFrame.contains(battlefieldFrame),
              safeFrame.contains(tabBarFrame),
              safeFrame.contains(settingsFrame),
              topBandFrame.contains(incomeFrame),
              topBandFrame.contains(cityProgressFrame),
              topBandFrame.contains(recommendationFrame),
              topBandFrame.contains(objectiveFrame),
              topBandFrame.contains(statusFrame),
              topBandFrame.contains(settingsFrame),
              battlefieldFrame.contains(feedbackFrame),
              !incomeFrame.intersects(cityProgressFrame),
              !cityProgressFrame.intersects(settingsFrame),
              !recommendationFrame.intersects(incomeFrame),
              !recommendationFrame.intersects(cityProgressFrame),
              !recommendationFrame.intersects(settingsFrame),
              medallionFrames.allSatisfy({ safeFrame.contains($0) }),
              medallionHitFrames.allSatisfy({ safeFrame.contains($0) && $0.width >= 44 && $0.height >= 44 }),
              tabHitFrames.allSatisfy({ safeFrame.contains($0) && $0.width >= 44 && $0.height >= 44 }),
              laneChipFrames.values.allSatisfy({ battlefieldFrame.contains($0) })
        else {
            return nil
        }

        return BattleChromeLayout(
            sceneFrame: sceneFrame,
            safeFrame: safeFrame,
            topBandFrame: topBandFrame,
            incomeFrame: incomeFrame,
            cityProgressFrame: cityProgressFrame,
            recommendationFrame: recommendationFrame,
            feedbackFrame: feedbackFrame,
            objectiveFrame: objectiveFrame,
            statusFrame: statusFrame,
            settingsFrame: settingsFrame,
            medallionFrames: medallionFrames,
            medallionHitFrames: medallionHitFrames,
            deployFrame: deployFrame,
            manualCountFrame: manualCountFrame,
            battlefieldFrame: battlefieldFrame,
            battlefield: battlefield,
            laneChipFrames: laneChipFrames,
            tabBarFrame: tabBarFrame,
            tabHitFrames: tabHitFrames,
            isCompact: compact
        )
    }

    static func compute(constraints: Input) -> BattleChromeLayout? {
        compute(constraints)
    }

    private static func laneFrames(in frame: CGRect) -> [BattleLane: CGRect] {
        let laneWidth = frame.width / CGFloat(BattleLane.allCases.count)
        let chipWidth = min(90, max(56, laneWidth - 16))
        return Dictionary(uniqueKeysWithValues: BattleLane.allCases.enumerated().map { index, lane in
            let laneFrame = CGRect(
                x: frame.minX + CGFloat(index) * laneWidth,
                y: frame.minY,
                width: laneWidth,
                height: frame.height
            )
            return (
                lane,
                CGRect(
                    x: laneFrame.midX - chipWidth / 2,
                    y: frame.maxY - 32,
                    width: chipWidth,
                    height: 24
                )
            )
        })
    }

    private static func nearlyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 0.001
            && abs(lhs.minY - rhs.minY) < 0.001
            && abs(lhs.width - rhs.width) < 0.001
            && abs(lhs.height - rhs.height) < 0.001
    }

}
