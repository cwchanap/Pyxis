//
//  CampChromeLayout.swift
//  Pyxis
//

import CoreGraphics

struct CampSafeAreaInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat

    static let zero = CampSafeAreaInsets(top: 0, left: 0, bottom: 0, right: 0)
}

struct CampChromeLayout: Equatable {
    typealias SafeAreaInsets = CampSafeAreaInsets

    private struct LotAnchor {
        let slot: Int
        let x: CGFloat
        let y: CGFloat
        let scale: CGFloat
    }

    private static let scenicLotAnchors: [LotAnchor] = [
        LotAnchor(slot: 1, x: 0.18, y: 0.78, scale: 0.96),
        LotAnchor(slot: 2, x: 0.34, y: 0.82, scale: 0.90),
        LotAnchor(slot: 3, x: 0.52, y: 0.78, scale: 0.98),
        LotAnchor(slot: 4, x: 0.70, y: 0.82, scale: 0.90),
        LotAnchor(slot: 5, x: 0.84, y: 0.72, scale: 0.88),
        LotAnchor(slot: 6, x: 0.24, y: 0.64, scale: 1.02),
        LotAnchor(slot: 7, x: 0.43, y: 0.66, scale: 0.94),
        LotAnchor(slot: 8, x: 0.62, y: 0.62, scale: 1.02),
        LotAnchor(slot: 9, x: 0.78, y: 0.56, scale: 0.92),
        LotAnchor(slot: 10, x: 0.13, y: 0.49, scale: 0.86),
        LotAnchor(slot: 11, x: 0.31, y: 0.50, scale: 1.02),
        LotAnchor(slot: 12, x: 0.51, y: 0.48, scale: 1.10),
        LotAnchor(slot: 13, x: 0.68, y: 0.43, scale: 0.98),
        LotAnchor(slot: 14, x: 0.87, y: 0.42, scale: 0.86),
        LotAnchor(slot: 15, x: 0.20, y: 0.34, scale: 0.94),
        LotAnchor(slot: 16, x: 0.39, y: 0.32, scale: 1.06),
        LotAnchor(slot: 17, x: 0.58, y: 0.31, scale: 0.96),
        LotAnchor(slot: 18, x: 0.76, y: 0.27, scale: 0.94),
        LotAnchor(slot: 19, x: 0.10, y: 0.19, scale: 0.82),
        LotAnchor(slot: 20, x: 0.28, y: 0.17, scale: 0.94),
        LotAnchor(slot: 21, x: 0.46, y: 0.15, scale: 1.02),
        LotAnchor(slot: 22, x: 0.64, y: 0.13, scale: 0.94),
        LotAnchor(slot: 23, x: 0.82, y: 0.14, scale: 0.84),
        LotAnchor(slot: 24, x: 0.56, y: 0.88, scale: 0.86),
        LotAnchor(slot: 25, x: 0.90, y: 0.62, scale: 0.80)
    ]

    enum Selection: Equatable {
        case none
        case emptyLot(slot: Int)
        case occupiedLot(slot: Int)
    }

    struct Input: Equatable {
        let sceneSize: CGSize
        let safeAreaInsets: CampSafeAreaInsets
        let selection: Selection

        init(
            sceneSize: CGSize,
            safeAreaInsets: CampSafeAreaInsets,
            selection: Selection = .none
        ) {
            self.sceneSize = sceneSize
            self.safeAreaInsets = safeAreaInsets
            self.selection = selection
        }
    }

    typealias Constraints = Input

    static let tabBarHeight: CGFloat = 72
    static let minimumInteractiveSize: CGFloat = 44
    static let lotTargetSize: CGFloat = 44

    let sceneFrame: CGRect
    let safeFrame: CGRect
    let headerFrame: CGRect
    let goldFrame: CGRect
    let titleFrame: CGRect
    let progressFrame: CGRect
    let settingsFrame: CGRect
    let lotRegionFrame: CGRect
    let lotPositions: [Int: CGPoint]
    let lotVisualScales: [Int: CGFloat]
    let lotHitFrames: [Int: CGRect]
    let builderFrame: CGRect?
    let builderOptionFrames: [BuildingType: CGRect]
    let inspectorFrame: CGRect?
    let inspectorActionFrame: CGRect?
    let tabBarFrame: CGRect
    let tabHitFrames: [GameplayTab: CGRect]
    let selection: Selection

    /// The currently selected panel, when the Camp scene is showing a lot
    /// selection. This is a convenience for scene layout and tests; the lot
    /// positions remain valid when no lot is selected.
    var selectionFrame: CGRect? {
        builderFrame ?? inspectorFrame
    }

    var selectionPanelFrame: CGRect? { selectionFrame }

    static func compute(_ input: Input) -> CampChromeLayout? {
        let size = input.sceneSize
        let insets = input.safeAreaInsets
        let values = [
            size.width, size.height,
            insets.top, insets.left, insets.bottom, insets.right
        ]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }),
              size.width >= 320,
              size.height >= 480,
              size.height > size.width else {
            return nil
        }

        let sceneFrame = CGRect(origin: .zero, size: size)
        let safeFrame = CGRect(
            x: insets.left,
            y: insets.bottom,
            width: size.width - insets.left - insets.right,
            height: size.height - insets.top - insets.bottom
        )
        guard safeFrame.width >= 280,
              safeFrame.height >= tabBarHeight + 180 else {
            return nil
        }

        let horizontalMargin = min(22, max(16, safeFrame.width * 0.04))
        let contentWidth = min(560, safeFrame.width - horizontalMargin * 2)
        guard contentWidth >= 280 else {
            return nil
        }

        let tabBarFrame = CGRect(
            x: safeFrame.midX - contentWidth / 2,
            y: safeFrame.minY,
            width: contentWidth,
            height: tabBarHeight
        )
        let tabCellWidth = tabBarFrame.width / CGFloat(GameplayTab.allCases.count)
        let tabHitFrames = Dictionary(uniqueKeysWithValues: GameplayTab.allCases.enumerated().map { index, tab in
            let cell = CGRect(
                x: tabBarFrame.minX + CGFloat(index) * tabCellWidth,
                y: tabBarFrame.minY,
                width: tabCellWidth,
                height: tabBarFrame.height
            )
            let hitWidth = max(minimumInteractiveSize, cell.width - 8)
            let hitHeight = max(minimumInteractiveSize, cell.height - 8)
            return (
                tab,
                CGRect(
                    x: cell.midX - hitWidth / 2,
                    y: cell.midY - hitHeight / 2,
                    width: hitWidth,
                    height: hitHeight
                )
            )
        })

        let selectionHeight: CGFloat
        switch input.selection {
        case .none:
            selectionHeight = 0
        case .emptyLot:
            selectionHeight = 174
        case .occupiedLot:
            selectionHeight = 114
        }
        let selectionFrame = selectionHeight > 0
            ? CGRect(
                x: safeFrame.midX - contentWidth / 2,
                y: tabBarFrame.maxY + 10,
                width: contentWidth,
                height: selectionHeight
            )
            : nil

        let headerFrame = CGRect(
            x: safeFrame.midX - contentWidth / 2,
            y: safeFrame.maxY - 112,
            width: contentWidth,
            height: 104
        )
        let goldFrame = CGRect(
            x: headerFrame.minX,
            y: headerFrame.maxY - 52,
            width: min(106, contentWidth * 0.30),
            height: 48
        )
        let settingsFrame = CGRect(
            x: headerFrame.maxX - 44,
            y: headerFrame.maxY - 52,
            width: 44,
            height: 44
        )
        let titleFrame = CGRect(
            x: headerFrame.minX,
            y: headerFrame.minY + 4,
            width: min(64, contentWidth - 100),
            height: 30
        )
        let progressFrame = CGRect(
            x: titleFrame.maxX + 10,
            y: titleFrame.midY - 3,
            width: max(60, settingsFrame.minX - titleFrame.maxX - 20),
            height: 6
        )
        guard headerFrame.minX >= safeFrame.minX,
              headerFrame.maxX <= safeFrame.maxX,
              headerFrame.contains(goldFrame),
              headerFrame.contains(settingsFrame),
              headerFrame.contains(titleFrame),
              headerFrame.contains(progressFrame) else {
            return nil
        }

        let lotRegionMinY = (selectionFrame?.maxY ?? tabBarFrame.maxY) + 10
        let lotRegionMaxY = progressFrame.minY - 12
        let lotRegionFrame = CGRect(
            x: safeFrame.minX,
            y: lotRegionMinY,
            width: safeFrame.width,
            height: lotRegionMaxY - lotRegionMinY
        )
        guard lotRegionFrame.width >= lotTargetSize,
              lotRegionFrame.height >= 180 else {
            return nil
        }

        let lotPositions = Dictionary(uniqueKeysWithValues: scenicLotAnchors.map { anchor in
            (
                anchor.slot,
                CGPoint(
                    x: lotRegionFrame.minX + lotRegionFrame.width * anchor.x,
                    y: lotRegionFrame.minY + lotRegionFrame.height * anchor.y
                )
            )
        })
        let lotVisualScales = Dictionary(uniqueKeysWithValues: scenicLotAnchors.map {
            ($0.slot, $0.scale)
        })
        let lotHitFrames = Dictionary(uniqueKeysWithValues: lotPositions.map { slot, center in
            (
                slot,
                CGRect(
                    x: center.x - lotTargetSize / 2,
                    y: center.y - lotTargetSize / 2,
                    width: lotTargetSize,
                    height: lotTargetSize
                )
            )
        })
        guard lotHitFrames.count == CityBattleState.slotRange.count,
              lotHitFrames.values.allSatisfy({ safeFrame.contains($0) && lotRegionFrame.contains($0) }) else {
            return nil
        }

        var builderFrame: CGRect?
        var inspectorFrame: CGRect?
        var inspectorActionFrame: CGRect?
        var builderOptionFrames: [BuildingType: CGRect] = [:]

        if let selectionFrame {
            switch input.selection {
            case .emptyLot:
                builderFrame = selectionFrame
                let gap: CGFloat = 6
                let optionWidth = min(62, (selectionFrame.width - gap * 4 - 20) / 5)
                let optionHeight = min(64, selectionFrame.height - 38)
                let totalWidth = optionWidth * 5 + gap * 4
                let startX = selectionFrame.midX - totalWidth / 2 + optionWidth / 2
                let yOffsets: [CGFloat] = [0, 8, 12, 8, 0]
                for (index, type) in BuildingType.allCases.enumerated() {
                    let center = CGPoint(
                        x: startX + CGFloat(index) * (optionWidth + gap),
                        y: selectionFrame.midY - 4 + yOffsets[index]
                    )
                    builderOptionFrames[type] = CGRect(
                        x: center.x - optionWidth / 2,
                        y: center.y - optionHeight / 2,
                        width: optionWidth,
                        height: optionHeight
                    )
                }
            case .occupiedLot:
                inspectorFrame = selectionFrame
                let actionWidth: CGFloat = min(92, max(80, selectionFrame.width * 0.25))
                let actionHeight: CGFloat = max(minimumInteractiveSize, selectionFrame.height - 28)
                inspectorActionFrame = CGRect(
                    x: selectionFrame.maxX - actionWidth - 12,
                    y: selectionFrame.midY - actionHeight / 2,
                    width: actionWidth,
                    height: actionHeight
                )
            case .none:
                break
            }
        }

        let allInteractiveFrames = Array(tabHitFrames.values)
            + Array(lotHitFrames.values)
            + Array(builderOptionFrames.values)
            + (inspectorActionFrame.map { [$0] } ?? [])
        guard allInteractiveFrames.allSatisfy({
            safeFrame.contains($0)
                && $0.width >= minimumInteractiveSize
                && $0.height >= minimumInteractiveSize
        }),
        builderOptionFrames.values.allSatisfy({ frame in
            builderFrame?.contains(frame) == true && !frame.intersects(tabBarFrame)
        }),
        (inspectorActionFrame.map { inspectorFrame?.contains($0) == true } ?? true) else {
            return nil
        }

        return CampChromeLayout(
            sceneFrame: sceneFrame,
            safeFrame: safeFrame,
            headerFrame: headerFrame,
            goldFrame: goldFrame,
            titleFrame: titleFrame,
            progressFrame: progressFrame,
            settingsFrame: settingsFrame,
            lotRegionFrame: lotRegionFrame,
            lotPositions: lotPositions,
            lotVisualScales: lotVisualScales,
            lotHitFrames: lotHitFrames,
            builderFrame: builderFrame,
            builderOptionFrames: builderOptionFrames,
            inspectorFrame: inspectorFrame,
            inspectorActionFrame: inspectorActionFrame,
            tabBarFrame: tabBarFrame,
            tabHitFrames: tabHitFrames,
            selection: input.selection
        )
    }

    static func compute(
        sceneSize: CGSize,
        safeAreaInsets: CampSafeAreaInsets = .zero,
        selection: Selection = .none
    ) -> CampChromeLayout? {
        compute(Input(
            sceneSize: sceneSize,
            safeAreaInsets: safeAreaInsets,
            selection: selection
        ))
    }
}
