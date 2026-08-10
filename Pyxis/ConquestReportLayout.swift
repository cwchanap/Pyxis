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
        let summaryRowCount: Int
        let achievementCount: Int
        let compactHeight: Bool
        let includesCountryCompletion: Bool

        init(
            sceneSize: CGSize,
            safeAreaInsets: ConquestReportSafeAreaInsets,
            battleContentWidth: CGFloat,
            summaryRowCount: Int,
            achievementCount: Int,
            compactHeight: Bool,
            includesCountryCompletion: Bool = false
        ) {
            self.sceneSize = sceneSize
            self.safeAreaInsets = safeAreaInsets
            self.battleContentWidth = battleContentWidth
            self.summaryRowCount = summaryRowCount
            self.achievementCount = achievementCount
            self.compactHeight = compactHeight
            self.includesCountryCompletion = includesCountryCompletion
        }
    }

    private struct Metrics {
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let titleLine: CGFloat
        let titleRowsGap: CGFloat
        let rowLine: CGFloat
        let rowGap: CGFloat
        let badgeSize: CGFloat
        let badgeGap: CGFloat
        let rowsBadgeGap: CGFloat
        let contentContinueGap: CGFloat
        let continueInset: CGFloat
        let continueHeight: CGFloat
        let cornerRadius: CGFloat
        let titleStartingFontSize: CGFloat
        let titleMinimumFontSize: CGFloat
        let summaryStartingFontSize: CGFloat
        let summaryMinimumFontSize: CGFloat
        let continueStartingFontSize: CGFloat
        let continueMinimumFontSize: CGFloat
        let countryCompletionLine: CGFloat
        let countryCompletionGap: CGFloat

        init(compactHeight: Bool) {
            let compact = compactHeight
            horizontalPadding = compact ? 18 : 24
            verticalPadding = compact ? 14 : 18
            titleLine = compact ? 24 : 30
            titleRowsGap = compact ? 8 : 10
            rowLine = compact ? 20 : 24
            rowGap = compact ? 2 : 4
            badgeSize = compact ? 20 : 24
            badgeGap = compact ? 6 : 8
            rowsBadgeGap = compact ? 8 : 10
            contentContinueGap = compact ? 12 : 16
            continueInset = 24
            continueHeight = compact ? 44 : 48
            cornerRadius = 14
            titleStartingFontSize = compact ? 19 : 22
            titleMinimumFontSize = 14
            summaryStartingFontSize = compact ? 14 : 17
            summaryMinimumFontSize = 12
            continueStartingFontSize = compact ? 15 : 16
            continueMinimumFontSize = 15
            countryCompletionLine = compact ? 22 : 26
            countryCompletionGap = 8
        }
    }

    let safeFrame: CGRect
    let panelFrame: CGRect
    let titleFrame: CGRect
    let summaryRowFrames: [CGRect]
    let achievementStripFrame: CGRect?
    let badgeFrames: [CGRect]
    let continueFrame: CGRect
    let countryCompleteFrame: CGRect?
    let panelCornerRadius: CGFloat
    let titleStartingFontSize: CGFloat
    let titleMinimumFontSize: CGFloat
    let summaryStartingFontSize: CGFloat
    let summaryMinimumFontSize: CGFloat
    let continueStartingFontSize: CGFloat
    let continueMinimumFontSize: CGFloat

    static func compute(_ input: Input) -> ConquestReportLayout? {
        guard (3...4).contains(input.summaryRowCount),
              (0...2).contains(input.achievementCount) else { return nil }

        let safeWidth = input.sceneSize.width - input.safeAreaInsets.left - input.safeAreaInsets.right
        let safeHeight = input.sceneSize.height - input.safeAreaInsets.top - input.safeAreaInsets.bottom
        guard safeWidth > 0, safeHeight > 0 else { return nil }

        let safeFrame = CGRect(
            x: input.safeAreaInsets.left,
            y: input.safeAreaInsets.bottom,
            width: safeWidth,
            height: safeHeight
        )

        let metrics = Metrics(compactHeight: input.compactHeight)

        let panelWidth = min(input.battleContentWidth, safeWidth - 56)
        let continueWidth = panelWidth - metrics.continueInset * 2
        guard panelWidth > metrics.horizontalPadding * 2, continueWidth >= 44 else { return nil }

        let reportPanelHeight = panelHeight(
            metrics: metrics,
            summaryRowCount: input.summaryRowCount,
            achievementCount: input.achievementCount
        )
        let completionReservation = input.includesCountryCompletion
            ? metrics.countryCompletionGap + metrics.countryCompletionLine
            : 0
        let groupHeight = reportPanelHeight + completionReservation
        guard groupHeight <= safeHeight else { return nil }

        let panelX = safeFrame.midX - panelWidth / 2
        let groupMinY = safeFrame.midY - groupHeight / 2
        let panelFrame = CGRect(
            x: panelX,
            y: groupMinY,
            width: panelWidth,
            height: reportPanelHeight
        )
        let countryCompleteFrame = input.includesCountryCompletion
            ? CGRect(
                x: panelX,
                y: panelFrame.maxY + metrics.countryCompletionGap,
                width: panelWidth,
                height: metrics.countryCompletionLine
            )
            : nil

        var cursorY = panelFrame.maxY - metrics.verticalPadding

        let titleFrame = CGRect(
            x: panelX + metrics.horizontalPadding,
            y: cursorY - metrics.titleLine,
            width: panelWidth - metrics.horizontalPadding * 2,
            height: metrics.titleLine
        )
        cursorY -= metrics.titleLine + metrics.titleRowsGap

        var summaryRowFrames: [CGRect] = []
        summaryRowFrames.reserveCapacity(input.summaryRowCount)
        for index in 0..<input.summaryRowCount {
            if index > 0 { cursorY -= metrics.rowGap }
            let rowFrame = CGRect(
                x: panelX + metrics.horizontalPadding,
                y: cursorY - metrics.rowLine,
                width: panelWidth - metrics.horizontalPadding * 2,
                height: metrics.rowLine
            )
            summaryRowFrames.append(rowFrame)
            cursorY -= metrics.rowLine
        }

        let achievementStripFrame: CGRect?
        let badgeFrames: [CGRect]
        if input.achievementCount > 0 {
            cursorY -= metrics.rowsBadgeGap
            let stripWidth = CGFloat(input.achievementCount) * metrics.badgeSize
                + CGFloat(input.achievementCount - 1) * metrics.badgeGap
            let stripX = panelFrame.midX - stripWidth / 2
            let stripY = cursorY - metrics.badgeSize
            achievementStripFrame = CGRect(
                x: stripX,
                y: stripY,
                width: stripWidth,
                height: metrics.badgeSize
            )
            // Per-badge frames step by badgeSize + badgeGap so the rendered
            // edge-to-edge gap matches the configured gap (evenly spacing
            // centers across the whole strip would halve it).
            badgeFrames = (0..<input.achievementCount).map { index in
                CGRect(
                    x: stripX + CGFloat(index) * (metrics.badgeSize + metrics.badgeGap),
                    y: stripY,
                    width: metrics.badgeSize,
                    height: metrics.badgeSize
                )
            }
            cursorY -= metrics.badgeSize
        } else {
            achievementStripFrame = nil
            badgeFrames = []
        }

        cursorY -= metrics.contentContinueGap
        let continueFrame = CGRect(
            x: panelX + metrics.continueInset,
            y: cursorY - metrics.continueHeight,
            width: continueWidth,
            height: metrics.continueHeight
        )
        cursorY -= metrics.continueHeight

        guard abs(cursorY - (panelFrame.minY + metrics.verticalPadding)) < 0.0001 else { return nil }
        let frames = ComputedFrames(
            safeFrame: safeFrame,
            panelFrame: panelFrame,
            titleFrame: titleFrame,
            summaryRowFrames: summaryRowFrames,
            achievementStripFrame: achievementStripFrame,
            badgeFrames: badgeFrames,
            continueFrame: continueFrame,
            countryCompleteFrame: countryCompleteFrame
        )
        guard framesAreContained(frames) else { return nil }

        return ConquestReportLayout(
            safeFrame: safeFrame,
            panelFrame: panelFrame,
            titleFrame: titleFrame,
            summaryRowFrames: summaryRowFrames,
            achievementStripFrame: achievementStripFrame,
            badgeFrames: badgeFrames,
            continueFrame: continueFrame,
            countryCompleteFrame: countryCompleteFrame,
            panelCornerRadius: metrics.cornerRadius,
            titleStartingFontSize: metrics.titleStartingFontSize,
            titleMinimumFontSize: metrics.titleMinimumFontSize,
            summaryStartingFontSize: metrics.summaryStartingFontSize,
            summaryMinimumFontSize: metrics.summaryMinimumFontSize,
            continueStartingFontSize: metrics.continueStartingFontSize,
            continueMinimumFontSize: metrics.continueMinimumFontSize
        )
    }

    private static func panelHeight(
        metrics: Metrics,
        summaryRowCount: Int,
        achievementCount: Int
    ) -> CGFloat {
        metrics.verticalPadding * 2
            + metrics.titleLine + metrics.titleRowsGap
            + CGFloat(summaryRowCount) * metrics.rowLine
            + CGFloat(summaryRowCount - 1) * metrics.rowGap
            + (achievementCount > 0 ? metrics.rowsBadgeGap + metrics.badgeSize : 0)
            + metrics.contentContinueGap + metrics.continueHeight
    }

    private struct ComputedFrames {
        let safeFrame: CGRect
        let panelFrame: CGRect
        let titleFrame: CGRect
        let summaryRowFrames: [CGRect]
        let achievementStripFrame: CGRect?
        let badgeFrames: [CGRect]
        let continueFrame: CGRect
        let countryCompleteFrame: CGRect?
    }

    private static func framesAreContained(_ frames: ComputedFrames) -> Bool {
        guard frames.safeFrame.contains(frames.panelFrame),
              frames.panelFrame.contains(frames.titleFrame),
              frames.summaryRowFrames.allSatisfy({ frames.panelFrame.contains($0) }),
              frames.panelFrame.contains(frames.continueFrame) else { return false }
        if let countryCompleteFrame = frames.countryCompleteFrame {
            guard frames.safeFrame.contains(countryCompleteFrame),
                  !countryCompleteFrame.intersects(frames.panelFrame),
                  !countryCompleteFrame.intersects(frames.continueFrame) else {
                return false
            }
        }
        if let achievementStripFrame = frames.achievementStripFrame {
            guard frames.panelFrame.contains(achievementStripFrame) else { return false }
            // Badge frames step by badgeSize + badgeGap inside the strip, so
            // every frame is a height-square fully contained by the strip.
            guard frames.badgeFrames.allSatisfy({
                $0.size == CGSize(width: achievementStripFrame.height, height: achievementStripFrame.height)
                    && achievementStripFrame.contains($0)
            }) else { return false }
        }
        return true
    }
}
