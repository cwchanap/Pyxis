//
//  BattleChromeLayout.swift
//  Pyxis
//

import CoreGraphics

struct BattleChromeLayout: Equatable {
    static let minimumBattlefieldHeight: CGFloat = 416
    static let compactMinimumBattlefieldHeight: CGFloat = 340
    static let sideMargin: CGFloat = 16
    static let tabBarHeight: CGFloat = 82
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

    // swiftlint:disable:next cyclomatic_complexity
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
        let canonicalFieldHeight = size.height - 426
        let compact = input.isCompact ?? (
            size.height < 780 || canonicalFieldHeight < minimumBattlefieldHeight
        )
        let contentWidth = min(560, safeWidth - sideMargin * 2)
        guard contentWidth >= medallionVisualSize,
              contentWidth > 0 else { return nil }

        let contentX = safeFrame.midX - contentWidth / 2
        let medallionGap = (contentWidth - CGFloat(5) * medallionVisualSize) / 4
        guard medallionGap >= 0 else { return nil }

        let tabBarFrame: CGRect
        let deployFrame: CGRect
        let manualCountFrame: CGRect
        let medallionFrames: [CGRect]
        let battlefieldFrame: CGRect
        let topBandFrame: CGRect
        let incomeFrame: CGRect
        let cityProgressFrame: CGRect
        let recommendationFrame: CGRect
        let settingsFrame: CGRect
        let feedbackFrame: CGRect
        let tabHitFrames: [CGRect]

        if compact {
            // Short phones keep the existing adaptive stack, with the forged
            // shell reserving its full 82pt authored height.
            tabBarFrame = CGRect(
                x: contentX,
                y: safeFrame.minY,
                width: contentWidth,
                height: tabBarHeight
            )
            deployFrame = CGRect(
                x: contentX,
                y: tabBarFrame.maxY + 10,
                width: contentWidth,
                height: 56
            )
            manualCountFrame = CGRect(
                x: deployFrame.maxX - 76,
                y: deployFrame.midY - 22,
                width: 68,
                height: 44
            )
            let medallionY = deployFrame.maxY + 10
            medallionFrames = (0..<5).map { index in
                CGRect(
                    x: contentX + CGFloat(index) * (medallionVisualSize + medallionGap),
                    y: medallionY,
                    width: medallionVisualSize,
                    height: medallionVisualSize
                )
            }

            let fieldMinY = medallionFrames[0].maxY + 10
            let topBandGap: CGFloat = 12
            let minimumTopBandHeight: CGFloat = 76
            let maximumFieldHeight = safeFrame.maxY
                - topBandGap
                - minimumTopBandHeight
                - fieldMinY
            guard maximumFieldHeight >= compactMinimumBattlefieldHeight else { return nil }
            let fieldHeight = min(342, maximumFieldHeight)
            guard fieldHeight >= compactMinimumBattlefieldHeight else { return nil }
            battlefieldFrame = CGRect(
                x: contentX,
                y: fieldMinY,
                width: contentWidth,
                height: fieldHeight
            )
            topBandFrame = CGRect(
                x: contentX,
                y: battlefieldFrame.maxY + topBandGap,
                width: contentWidth,
                height: safeFrame.maxY - battlefieldFrame.maxY - topBandGap
            )
            let topRowHeight: CGFloat = 44
            let rowGap: CGFloat = 8
            let topRowY = topBandFrame.maxY - 4 - topRowHeight
            let recommendationHeight = min(
                40,
                max(32, topBandFrame.height - topRowHeight - rowGap - 8)
            )
            recommendationFrame = CGRect(
                x: topBandFrame.minX,
                y: max(topBandFrame.minY + 4, topRowY - rowGap - recommendationHeight),
                width: topBandFrame.width,
                height: recommendationHeight
            )
            settingsFrame = CGRect(
                x: topBandFrame.maxX - 44,
                y: topRowY,
                width: 44,
                height: topRowHeight
            )
            incomeFrame = CGRect(
                x: topBandFrame.minX,
                y: topRowY,
                width: min(160, max(112, topBandFrame.width * 0.42)),
                height: topRowHeight
            )
            cityProgressFrame = CGRect(
                x: incomeFrame.maxX + 8,
                y: topRowY,
                width: settingsFrame.minX - incomeFrame.maxX - 16,
                height: topRowHeight
            )
            guard cityProgressFrame.width >= 44 else { return nil }
            feedbackFrame = CGRect(
                x: battlefieldFrame.minX + 8,
                y: battlefieldFrame.midY - 18,
                width: battlefieldFrame.width - 16,
                height: 36
            )
            tabHitFrames = tabHitFramesInSafeArea(
               for: tabBarFrame,
                safeFrame: safeFrame
            )
        } else {
            // The reference phone is authored in scene coordinates. The
            // visible chrome may kiss the safe-area edges, while every
            // gameplay hit target remains at least 44pt and is clamped to the
            // safe frame below.
            tabBarFrame = CGRect(
                x: contentX,
                y: 0,
                width: contentWidth,
                height: tabBarHeight
            )
            deployFrame = CGRect(
                x: contentX,
                y: 90,
                width: contentWidth,
                height: 58
            )
            manualCountFrame = CGRect(
                x: deployFrame.maxX - 76,
                y: deployFrame.midY - 22,
                width: 68,
                height: 44
            )
            let medallionY: CGFloat = 154
            medallionFrames = (0..<5).map { index in
                CGRect(
                    x: contentX + CGFloat(index) * (medallionVisualSize + medallionGap),
                    y: medallionY,
                    width: medallionVisualSize,
                    height: medallionVisualSize
                )
            }
            let fieldMinY: CGFloat = 210
            let fieldTopY = size.height - 216
            let fieldHeight = fieldTopY - fieldMinY
            guard fieldHeight >= minimumBattlefieldHeight else { return nil }
            battlefieldFrame = CGRect(
                x: contentX,
                y: fieldMinY,
                width: contentWidth,
                height: fieldHeight
            )
            topBandFrame = CGRect(
                x: contentX,
                y: battlefieldFrame.maxY,
                width: contentWidth,
                height: sceneFrame.maxY - battlefieldFrame.maxY
            )
            incomeFrame = CGRect(
                x: contentX,
                y: size.height - 102,
                width: min(160, contentWidth),
                height: 46
            )
            settingsFrame = CGRect(
                x: contentX + contentWidth - 46,
                y: size.height - 102,
                width: 46,
                height: 46
            )
            cityProgressFrame = CGRect(
                x: contentX,
                y: size.height - 160,
                width: contentWidth,
                height: 48
            )
            recommendationFrame = CGRect(
                x: contentX,
                y: battlefieldFrame.maxY,
                width: contentWidth,
                height: 48
            )
            feedbackFrame = CGRect(
                x: battlefieldFrame.minX + 8,
                y: battlefieldFrame.midY - 18,
                width: battlefieldFrame.width - 16,
                height: 36
            )
            tabHitFrames = tabHitFramesInSafeArea(
                for: tabBarFrame,
                safeFrame: safeFrame
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

        let laneChipFrames = laneFrames(in: battlefieldFrame)

        let frames = [
            sceneFrame,
            safeFrame,
            topBandFrame,
            incomeFrame,
            cityProgressFrame,
            recommendationFrame,
            feedbackFrame,
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
              sceneFrame.contains(topBandFrame),
              safeFrame.contains(deployFrame),
              safeFrame.contains(manualCountFrame),
              safeFrame.contains(battlefieldFrame),
              sceneFrame.contains(tabBarFrame),
              sceneFrame.contains(settingsFrame),
              topBandFrame.contains(incomeFrame),
              topBandFrame.contains(cityProgressFrame),
              topBandFrame.contains(recommendationFrame),
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
                    y: frame.maxY - min(76, max(26, frame.height - 26)),
                    width: chipWidth,
                    height: 26
                )
            )
        })
    }

    private static func tabHitFramesInSafeArea(
        for frame: CGRect,
        safeFrame: CGRect
    ) -> [CGRect] {
        let width = frame.width / CGFloat(GameplayTab.allCases.count)
        let hitHeight = min(44, frame.height)
        let availableY = max(frame.minY, safeFrame.minY)
        let maxY = min(frame.maxY - hitHeight, safeFrame.maxY - hitHeight)
        let hitY = max(availableY, maxY)
        return (0..<GameplayTab.allCases.count).map { index in
            let cell = CGRect(
                x: frame.minX + CGFloat(index) * width,
                y: hitY,
                width: width,
                height: hitHeight
            )
            return cell.insetBy(dx: 4, dy: 0)
        }
    }

    private static func nearlyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 0.001
            && abs(lhs.minY - rhs.minY) < 0.001
            && abs(lhs.width - rhs.width) < 0.001
            && abs(lhs.height - rhs.height) < 0.001
    }

}
