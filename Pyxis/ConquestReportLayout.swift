import CoreGraphics

struct ConquestReportSafeAreaInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat
}

struct ConquestReportLayout: Equatable {
    struct Input: Equatable {
        let sceneSize: CGSize
        let safeAreaInsets: ConquestReportSafeAreaInsets
        let battleContentWidth: CGFloat
        let tileCount: Int
        let chipCount: Int
        let compactHeight: Bool
        let includesCountryCompletion: Bool

        init(
            sceneSize: CGSize,
            safeAreaInsets: ConquestReportSafeAreaInsets,
            battleContentWidth: CGFloat,
            tileCount: Int,
            chipCount: Int,
            compactHeight: Bool,
            includesCountryCompletion: Bool = false
        ) {
            self.sceneSize = sceneSize
            self.safeAreaInsets = safeAreaInsets
            self.battleContentWidth = battleContentWidth
            self.tileCount = tileCount
            self.chipCount = chipCount
            self.compactHeight = compactHeight
            self.includesCountryCompletion = includesCountryCompletion
        }
    }

    private struct Metrics {
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let titleLine: CGFloat
        let titleRewardGap: CGFloat
        let rewardHeight: CGFloat
        let rewardTilesGap: CGFloat
        let tileHeight: CGFloat
        let tileGap: CGFloat
        let tileChipGap: CGFloat
        let chipWidth: CGFloat
        let chipHeight: CGFloat
        let chipGap: CGFloat
        let chipsContinueGap: CGFloat
        let continueInset: CGFloat
        let continueHeight: CGFloat
        let cornerRadius: CGFloat
        let titleStartingFontSize: CGFloat
        let titleMinimumFontSize: CGFloat
        let rewardStartingFontSize: CGFloat
        let rewardMinimumFontSize: CGFloat
        let tileValueStartingFontSize: CGFloat
        let tileValueMinimumFontSize: CGFloat
        let tileLabelStartingFontSize: CGFloat
        let tileLabelMinimumFontSize: CGFloat
        let chipStartingFontSize: CGFloat
        let chipMinimumFontSize: CGFloat
        let continueStartingFontSize: CGFloat
        let continueMinimumFontSize: CGFloat
        let countryCompletionLine: CGFloat
        let countryCompletionGap: CGFloat
        let takenMedallionDiameter: CGFloat
        let takenMedallionOverlap: CGFloat

        init(compactHeight: Bool) {
            let compact = compactHeight
            horizontalPadding = compact ? 18 : 22
            verticalPadding = compact ? 14 : 22
            titleLine = compact ? 24 : 44
            titleRewardGap = compact ? 6 : 12
            rewardHeight = compact ? 54 : 72
            rewardTilesGap = compact ? 8 : 16
            tileHeight = compact ? 76 : 108
            tileGap = 8
            tileChipGap = compact ? 10 : 18
            chipWidth = 104
            chipHeight = compact ? 28 : 30
            chipGap = 8
            chipsContinueGap = compact ? 12 : 21
            continueInset = 22
            continueHeight = compact ? 44 : 54
            cornerRadius = 14
            titleStartingFontSize = compact ? 19 : 22
            titleMinimumFontSize = 14
            rewardStartingFontSize = compact ? 34 : 40
            rewardMinimumFontSize = 20
            tileValueStartingFontSize = compact ? 18 : 20
            tileValueMinimumFontSize = 11
            tileLabelStartingFontSize = compact ? 9 : 10
            tileLabelMinimumFontSize = 8
            chipStartingFontSize = compact ? 10 : 11
            chipMinimumFontSize = 8
            continueStartingFontSize = compact ? 15 : 16
            continueMinimumFontSize = 15
            countryCompletionLine = compact ? 22 : 26
            countryCompletionGap = 8
            takenMedallionDiameter = compact ? 96 : 118
            takenMedallionOverlap = compact ? 28 : 39
        }
    }

    let safeFrame: CGRect
    let panelFrame: CGRect
    let takenMedallionFrame: CGRect?
    let titleFrame: CGRect
    let rewardFrame: CGRect
    let tileFrames: [CGRect]
    let chipStripFrame: CGRect?
    let chipFrames: [CGRect]
    let continueFrame: CGRect
    let countryCompleteFrame: CGRect?
    let panelCornerRadius: CGFloat
    let titleStartingFontSize: CGFloat
    let titleMinimumFontSize: CGFloat
    let rewardStartingFontSize: CGFloat
    let rewardMinimumFontSize: CGFloat
    let tileValueStartingFontSize: CGFloat
    let tileValueMinimumFontSize: CGFloat
    let tileLabelStartingFontSize: CGFloat
    let tileLabelMinimumFontSize: CGFloat
    let chipStartingFontSize: CGFloat
    let chipMinimumFontSize: CGFloat
    let continueStartingFontSize: CGFloat
    let continueMinimumFontSize: CGFloat

    static func compute(_ input: Input) -> ConquestReportLayout? {
        guard (2...3).contains(input.tileCount),
              (0...2).contains(input.chipCount) else { return nil }

        let safeWidth = input.sceneSize.width - input.safeAreaInsets.left - input.safeAreaInsets.right
        let safeHeight = input.sceneSize.height - input.safeAreaInsets.top - input.safeAreaInsets.bottom
        guard safeWidth.isFinite, safeHeight.isFinite, safeWidth > 0, safeHeight > 0 else {
            return nil
        }

        let safeFrame = CGRect(
            x: input.safeAreaInsets.left,
            y: input.safeAreaInsets.bottom,
            width: safeWidth,
            height: safeHeight
        )
        let metrics = Metrics(compactHeight: input.compactHeight)
        let panelWidth = min(input.battleContentWidth, safeWidth - 48, 345)
        let innerWidth = panelWidth - metrics.horizontalPadding * 2
        let continueWidth = panelWidth - metrics.continueInset * 2
        guard panelWidth > metrics.horizontalPadding * 2,
              innerWidth > 0,
              continueWidth >= 44 else { return nil }

        let tileWidth = (innerWidth - CGFloat(input.tileCount - 1) * metrics.tileGap)
            / CGFloat(input.tileCount)
        guard tileWidth >= 44 else { return nil }

        let chipStripWidth = input.chipCount > 0
            ? CGFloat(input.chipCount) * metrics.chipWidth
                + CGFloat(input.chipCount - 1) * metrics.chipGap
            : 0
        guard chipStripWidth <= innerWidth else { return nil }

        let chipReservation = input.chipCount > 0
            ? metrics.tileChipGap + metrics.chipHeight + metrics.chipsContinueGap
            : metrics.chipsContinueGap
        let panelHeight = metrics.verticalPadding * 2
            + metrics.titleLine
            + metrics.titleRewardGap
            + metrics.rewardHeight
            + metrics.rewardTilesGap
            + metrics.tileHeight
            + chipReservation
            + metrics.continueHeight
        let completionReservation = input.includesCountryCompletion
            ? metrics.countryCompletionGap + metrics.countryCompletionLine
            : 0
        let groupHeight = panelHeight + completionReservation
        guard groupHeight <= safeHeight else { return nil }

        let panelX = safeFrame.midX - panelWidth / 2
        let phoneForgedOffset: CGFloat = !input.compactHeight && input.sceneSize.width <= 440
            ? 19
            : 0
        let groupMinY = safeFrame.midY - groupHeight / 2 - phoneForgedOffset
        let panelFrame = CGRect(x: panelX, y: groupMinY, width: panelWidth, height: panelHeight)
        let countryCompleteFrame = input.includesCountryCompletion
            ? CGRect(
                x: panelX,
                y: panelFrame.maxY + metrics.countryCompletionGap,
                width: panelWidth,
                height: metrics.countryCompletionLine
            )
            : nil

        var takenMedallionCenterY = panelFrame.maxY + metrics.takenMedallionOverlap
        if let countryCompleteFrame {
            takenMedallionCenterY = min(
                takenMedallionCenterY,
                countryCompleteFrame.minY - metrics.takenMedallionDiameter / 2 - 4
            )
        }
        takenMedallionCenterY = min(
            takenMedallionCenterY,
            safeFrame.maxY - metrics.takenMedallionDiameter / 2
        )
        takenMedallionCenterY = max(
            takenMedallionCenterY,
            safeFrame.minY + metrics.takenMedallionDiameter / 2
        )
        let medallionCandidateFrame = CGRect(
            x: panelFrame.midX - metrics.takenMedallionDiameter / 2,
            y: takenMedallionCenterY - metrics.takenMedallionDiameter / 2,
            width: metrics.takenMedallionDiameter,
            height: metrics.takenMedallionDiameter
        )

        var cursorY = panelFrame.maxY - metrics.verticalPadding
        let titleFrame = CGRect(
            x: panelX + metrics.horizontalPadding,
            y: cursorY - metrics.titleLine,
            width: innerWidth,
            height: metrics.titleLine
        )
        cursorY -= metrics.titleLine + metrics.titleRewardGap

        let rewardWidth = min(innerWidth, 230)
        let rewardFrame = CGRect(
            x: panelFrame.midX - rewardWidth / 2,
            y: cursorY - metrics.rewardHeight,
            width: rewardWidth,
            height: metrics.rewardHeight
        )
        let avoidsCountryCompletion = countryCompleteFrame.map {
            !$0.intersects(medallionCandidateFrame)
        } ?? true
        let takenMedallionFrame: CGRect? = safeFrame.contains(medallionCandidateFrame)
            && !medallionCandidateFrame.intersects(titleFrame)
            && !medallionCandidateFrame.intersects(rewardFrame)
            && avoidsCountryCompletion
            ? medallionCandidateFrame
            : nil
        cursorY -= metrics.rewardHeight + metrics.rewardTilesGap

        let tileY = cursorY - metrics.tileHeight
        let tileFrames = (0..<input.tileCount).map { index in
            CGRect(
                x: panelX + metrics.horizontalPadding
                    + CGFloat(index) * (tileWidth + metrics.tileGap),
                y: tileY,
                width: tileWidth,
                height: metrics.tileHeight
            )
        }
        cursorY -= metrics.tileHeight

        let chipStripFrame: CGRect?
        let chipFrames: [CGRect]
        if input.chipCount > 0 {
            cursorY -= metrics.tileChipGap
            let stripY = cursorY - metrics.chipHeight
            let stripX = panelFrame.midX - chipStripWidth / 2
            chipStripFrame = CGRect(
                x: stripX,
                y: stripY,
                width: chipStripWidth,
                height: metrics.chipHeight
            )
            chipFrames = (0..<input.chipCount).map { index in
                CGRect(
                    x: stripX + CGFloat(index) * (metrics.chipWidth + metrics.chipGap),
                    y: stripY,
                    width: metrics.chipWidth,
                    height: metrics.chipHeight
                )
            }
            cursorY -= metrics.chipHeight
        } else {
            chipStripFrame = nil
            chipFrames = []
        }

        cursorY -= metrics.chipsContinueGap
        let continueFrame = CGRect(
            x: panelX + metrics.continueInset,
            y: cursorY - metrics.continueHeight,
            width: continueWidth,
            height: metrics.continueHeight
        )

        guard abs(continueFrame.minY - (panelFrame.minY + metrics.verticalPadding)) < 0.0001 else {
            return nil
        }
        let frames = ComputedFrames(
            safeFrame: safeFrame,
            panelFrame: panelFrame,
            takenMedallionFrame: takenMedallionFrame,
            titleFrame: titleFrame,
            rewardFrame: rewardFrame,
            tileFrames: tileFrames,
            chipStripFrame: chipStripFrame,
            chipFrames: chipFrames,
            continueFrame: continueFrame,
            countryCompleteFrame: countryCompleteFrame
        )
        guard framesAreContained(frames) else { return nil }

        return ConquestReportLayout(
            safeFrame: safeFrame,
            panelFrame: panelFrame,
            takenMedallionFrame: takenMedallionFrame,
            titleFrame: titleFrame,
            rewardFrame: rewardFrame,
            tileFrames: tileFrames,
            chipStripFrame: chipStripFrame,
            chipFrames: chipFrames,
            continueFrame: continueFrame,
            countryCompleteFrame: countryCompleteFrame,
            panelCornerRadius: metrics.cornerRadius,
            titleStartingFontSize: metrics.titleStartingFontSize,
            titleMinimumFontSize: metrics.titleMinimumFontSize,
            rewardStartingFontSize: metrics.rewardStartingFontSize,
            rewardMinimumFontSize: metrics.rewardMinimumFontSize,
            tileValueStartingFontSize: metrics.tileValueStartingFontSize,
            tileValueMinimumFontSize: metrics.tileValueMinimumFontSize,
            tileLabelStartingFontSize: metrics.tileLabelStartingFontSize,
            tileLabelMinimumFontSize: metrics.tileLabelMinimumFontSize,
            chipStartingFontSize: metrics.chipStartingFontSize,
            chipMinimumFontSize: metrics.chipMinimumFontSize,
            continueStartingFontSize: metrics.continueStartingFontSize,
            continueMinimumFontSize: metrics.continueMinimumFontSize
        )
    }

    private struct ComputedFrames {
        let safeFrame: CGRect
        let panelFrame: CGRect
        let takenMedallionFrame: CGRect?
        let titleFrame: CGRect
        let rewardFrame: CGRect
        let tileFrames: [CGRect]
        let chipStripFrame: CGRect?
        let chipFrames: [CGRect]
        let continueFrame: CGRect
        let countryCompleteFrame: CGRect?
    }

    private static func framesAreContained(_ frames: ComputedFrames) -> Bool {
        guard frames.safeFrame.contains(frames.panelFrame),
              frames.panelFrame.contains(frames.titleFrame),
              frames.panelFrame.contains(frames.rewardFrame),
              frames.tileFrames.allSatisfy({ frames.panelFrame.contains($0) }),
              frames.panelFrame.contains(frames.continueFrame) else {
            return false
        }
        if let strip = frames.chipStripFrame {
            guard frames.panelFrame.contains(strip),
                  frames.chipFrames.allSatisfy({ strip.contains($0) }) else { return false }
        } else if !frames.chipFrames.isEmpty {
            return false
        }
        if let takenMedallionFrame = frames.takenMedallionFrame {
            guard frames.safeFrame.contains(takenMedallionFrame),
                  !takenMedallionFrame.intersects(frames.titleFrame),
                  !takenMedallionFrame.intersects(frames.rewardFrame) else { return false }
        }
        if let countryCompleteFrame = frames.countryCompleteFrame {
            guard frames.safeFrame.contains(countryCompleteFrame),
                  !countryCompleteFrame.intersects(frames.panelFrame) else { return false }
            if let takenMedallionFrame = frames.takenMedallionFrame {
                guard !countryCompleteFrame.intersects(takenMedallionFrame) else { return false }
            }
        }
        return true
    }
}
