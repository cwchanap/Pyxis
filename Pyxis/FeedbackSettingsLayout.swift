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
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 12
        static let handleWidth: CGFloat = 44
        static let handleHeight: CGFloat = 4
        static let handleGap: CGFloat = 16
        static let rowHeight: CGFloat = 60
        static let dividerHeight: CGFloat = 1
        static let closeGap: CGFloat = 14
        static let closeHeight: CGFloat = 52
        static let minimumBottomPadding: CGFloat = 20
        static let minimumInteractiveSize: CGFloat = 44

        static func panelHeight(bottomPadding: CGFloat) -> CGFloat {
            topPadding
                + handleHeight
                + handleGap
                + rowHeight * 2
                + dividerHeight
                + closeGap
                + closeHeight
                + bottomPadding
        }
    }

    let scrimFrame: CGRect
    let panelFrame: CGRect
    let handleFrame: CGRect
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
        let bottomPadding = max(Metrics.minimumBottomPadding, safeAreaInsets.bottom)
        let panelHeight = Metrics.panelHeight(bottomPadding: bottomPadding)
        guard safeWidth.isFinite,
              safeWidth >= Metrics.horizontalPadding * 2 + Metrics.minimumInteractiveSize,
              sceneSize.height >= panelHeight else {
            return nil
        }

        let panelFrame = CGRect(
            x: 0,
            y: 0,
            width: sceneSize.width,
            height: panelHeight
        )
        let controlX = safeAreaInsets.left + Metrics.horizontalPadding
        let controlWidth = safeWidth - Metrics.horizontalPadding * 2
        let closeFrame = CGRect(
            x: controlX,
            y: panelFrame.minY + bottomPadding,
            width: controlWidth,
            height: Metrics.closeHeight
        )
        let hapticsRowFrame = CGRect(
            x: controlX,
            y: closeFrame.maxY + Metrics.closeGap,
            width: controlWidth,
            height: Metrics.rowHeight
        )
        let soundRowFrame = CGRect(
            x: controlX,
            y: hapticsRowFrame.maxY + Metrics.dividerHeight,
            width: controlWidth,
            height: Metrics.rowHeight
        )
        let handleFrame = CGRect(
            x: panelFrame.midX - Metrics.handleWidth / 2,
            y: soundRowFrame.maxY + Metrics.handleGap,
            width: Metrics.handleWidth,
            height: Metrics.handleHeight
        )

        guard panelFrame.minY >= 0,
              panelFrame.maxY <= sceneSize.height,
              panelFrame.contains(handleFrame),
              panelFrame.contains(soundRowFrame),
              panelFrame.contains(hapticsRowFrame),
              panelFrame.contains(closeFrame),
              soundRowFrame.height >= Metrics.minimumInteractiveSize,
              hapticsRowFrame.height >= Metrics.minimumInteractiveSize,
              closeFrame.height >= Metrics.minimumInteractiveSize,
              handleFrame.maxY + Metrics.topPadding == panelFrame.maxY else {
            return nil
        }

        return FeedbackSettingsLayout(
            scrimFrame: CGRect(origin: .zero, size: sceneSize),
            panelFrame: panelFrame,
            handleFrame: handleFrame,
            soundRowFrame: soundRowFrame,
            hapticsRowFrame: hapticsRowFrame,
            closeFrame: closeFrame
        )
    }
}
