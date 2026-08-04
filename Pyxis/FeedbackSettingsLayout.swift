import CoreGraphics

struct FeedbackSettingsSafeAreaInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat

    static let zero = FeedbackSettingsSafeAreaInsets(top: 0, left: 0, bottom: 0, right: 0)
}

struct FeedbackSettingsLayout: Equatable {
    private enum Metrics {
        static let safeHorizontalMargin: CGFloat = 16
        static let maximumPanelWidth: CGFloat = 320
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 20
        static let rowHeight: CGFloat = 52
        static let rowGap: CGFloat = 12
        static let closeGap: CGFloat = 18
        static let closeHeight: CGFloat = 48
        static let minimumInteractiveSize: CGFloat = 44

        static var panelHeight: CGFloat {
            verticalPadding * 2 + rowHeight * 2 + rowGap + closeGap + closeHeight
        }
    }

    let scrimFrame: CGRect
    let panelFrame: CGRect
    let soundRowFrame: CGRect
    let hapticsRowFrame: CGRect
    let closeFrame: CGRect

    static func compute(
        sceneSize: CGSize,
        safeAreaInsets: FeedbackSettingsSafeAreaInsets
    ) -> FeedbackSettingsLayout? {
        let values = [
            sceneSize.width,
            sceneSize.height,
            safeAreaInsets.top,
            safeAreaInsets.left,
            safeAreaInsets.bottom,
            safeAreaInsets.right
        ]
        guard values.allSatisfy(\.isFinite),
              sceneSize.width >= 0,
              sceneSize.height >= 0,
              safeAreaInsets.top >= 0,
              safeAreaInsets.left >= 0,
              safeAreaInsets.bottom >= 0,
              safeAreaInsets.right >= 0 else {
            return nil
        }

        let safeWidth = sceneSize.width - safeAreaInsets.left - safeAreaInsets.right
        let safeHeight = sceneSize.height - safeAreaInsets.top - safeAreaInsets.bottom
        guard safeWidth.isFinite,
              safeHeight.isFinite,
              safeWidth >= minimumSafeWidth,
              safeHeight >= Metrics.panelHeight else {
            return nil
        }

        let safeFrame = CGRect(
            x: safeAreaInsets.left,
            y: safeAreaInsets.bottom,
            width: safeWidth,
            height: safeHeight
        )
        let panelWidth = min(
            Metrics.maximumPanelWidth,
            safeFrame.width - Metrics.safeHorizontalMargin * 2
        )
        let controlWidth = panelWidth - Metrics.horizontalPadding * 2
        guard panelWidth >= minimumPanelWidth,
              controlWidth >= Metrics.minimumInteractiveSize else {
            return nil
        }

        let panelFrame = CGRect(
            x: safeFrame.midX - panelWidth / 2,
            y: safeFrame.midY - Metrics.panelHeight / 2,
            width: panelWidth,
            height: Metrics.panelHeight
        )
        let controlX = panelFrame.minX + Metrics.horizontalPadding
        let soundRowFrame = CGRect(
            x: controlX,
            y: panelFrame.maxY - Metrics.verticalPadding - Metrics.rowHeight,
            width: controlWidth,
            height: Metrics.rowHeight
        )
        let hapticsRowFrame = CGRect(
            x: controlX,
            y: soundRowFrame.minY - Metrics.rowGap - Metrics.rowHeight,
            width: controlWidth,
            height: Metrics.rowHeight
        )
        let closeFrame = CGRect(
            x: controlX,
            y: hapticsRowFrame.minY - Metrics.closeGap - Metrics.closeHeight,
            width: controlWidth,
            height: Metrics.closeHeight
        )

        guard safeFrame.contains(panelFrame),
              panelFrame.contains(soundRowFrame),
              panelFrame.contains(hapticsRowFrame),
              panelFrame.contains(closeFrame),
              soundRowFrame.height >= Metrics.minimumInteractiveSize,
              hapticsRowFrame.height >= Metrics.minimumInteractiveSize,
              closeFrame.height >= Metrics.minimumInteractiveSize,
              abs(closeFrame.minY - (panelFrame.minY + Metrics.verticalPadding)) < 0.0001 else {
            return nil
        }

        return FeedbackSettingsLayout(
            scrimFrame: CGRect(origin: .zero, size: sceneSize),
            panelFrame: panelFrame,
            soundRowFrame: soundRowFrame,
            hapticsRowFrame: hapticsRowFrame,
            closeFrame: closeFrame
        )
    }

    private static var minimumPanelWidth: CGFloat {
        Metrics.horizontalPadding * 2 + Metrics.minimumInteractiveSize
    }

    private static var minimumSafeWidth: CGFloat {
        Metrics.safeHorizontalMargin * 2 + minimumPanelWidth
    }
}
