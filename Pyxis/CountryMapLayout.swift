import CoreGraphics

struct CountryMapSafeAreaInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat

    static let zero = CountryMapSafeAreaInsets(top: 0, left: 0, bottom: 0, right: 0)
}

enum CountryMapLayoutClass: Equatable {
    case phone
    case pad

    var informationRegionHeight: CGFloat {
        self == .phone ? 64 : 112
    }
}

struct CountryMapLayoutEnvironment: Equatable {
    let safeAreaInsets: CountryMapSafeAreaInsets
    let layoutClass: CountryMapLayoutClass
}

struct CountryMapLayoutConstraints: Equatable {
    let sceneSize: CGSize
    let environment: CountryMapLayoutEnvironment
    let definition: CountryMapLayoutDefinition
    let showsCurrentCityControl: Bool

    init(
        sceneSize: CGSize,
        environment: CountryMapLayoutEnvironment,
        definition: CountryMapLayoutDefinition,
        showsCurrentCityControl: Bool = false
    ) {
        self.sceneSize = sceneSize
        self.environment = environment
        self.definition = definition
        self.showsCurrentCityControl = showsCurrentCityControl
    }
}

struct CountryMapRouteLayout: Equatable {
    let start: CGPoint
    let end: CGPoint
    let lineWidth: CGFloat

    var strokeExpandedBounds: CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2)
    }
}

enum CountryMapLayoutFailureReason: Equatable {
    case unsupportedGeometry
    case invalidAuthoredData
}

enum CountryMapLayoutResult: Equatable {
    case supported(CountryMapLayout)
    case unsupported(CountryMapLayoutFailureReason)
}

struct CountryMapLayout: Equatable {
    private enum TitleControlMetrics {
        static let sideInset: CGFloat = 10
        static let gearHitSize: CGFloat = 44
        static let gearToTitleGap: CGFloat = 8
        static let titleToCurrentCityGap: CGFloat = 8
        static let currentCityWidth: CGFloat = 82
        static let minimumTitleTextWidth: CGFloat = 160
        static let minimumTitleFontSize: CGFloat = 16
    }

    static let minimumTitleTextWidth = TitleControlMetrics.minimumTitleTextWidth
    static let minimumTitleFontSize = TitleControlMetrics.minimumTitleFontSize

    let sceneFrame: CGRect
    let displayedBackdropFrame: CGRect
    let titleControlRegionFrame: CGRect
    let showsCurrentCityControl: Bool
    let settingsControlFrame: CGRect
    let currentCityControlFrame: CGRect?
    let titleTextFrame: CGRect
    let informationRegionFrame: CGRect
    let illustratedMapRegionFrame: CGRect
    let cityPositions: [Int: CGPoint]
    let routes: [CountryMapRouteLayout]

    static func compute(_ constraints: CountryMapLayoutConstraints) -> CountryMapLayoutResult {
        let sceneFrame = CGRect(origin: .zero, size: constraints.sceneSize)
        guard constraints.sceneSize.width >= 375,
              constraints.sceneSize.height >= 667,
              constraints.sceneSize.width.isFinite,
              constraints.sceneSize.height.isFinite,
              constraints.sceneSize.height > constraints.sceneSize.width
        else {
            return .unsupported(.unsupportedGeometry)
        }

        let definition = constraints.definition
        let source = definition.canonicalBackdropSize
        guard source.width.isFinite,
              source.height.isFinite,
              source.width > 0,
              source.height > 0,
              definition.cityAnchors.count == 15,
              definition.primaryRoutes.count == 14,
              definition.cityAnchors.allSatisfy({
                  $0.x.isFinite
                      && $0.y.isFinite
                      && (0...1).contains($0.x)
                      && (0...1).contains($0.y)
              }),
              definition.primaryRoutes.allSatisfy({
                  (1...15).contains($0.startCityNumber)
                      && (1...15).contains($0.endCityNumber)
                      && $0.lineWidth.isFinite
                      && $0.lineWidth > 0
              }),
              definition.branches.allSatisfy({
                  (1...15).contains($0.originCityNumber)
                      && $0.offset.dx.isFinite
                      && $0.offset.dy.isFinite
                      && $0.lineWidth.isFinite
                      && $0.lineWidth > 0
              })
        else {
            return .unsupported(.invalidAuthoredData)
        }

        let insets = constraints.environment.safeAreaInsets
        guard [insets.top, insets.left, insets.bottom, insets.right].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            return .unsupported(.unsupportedGeometry)
        }

        let scale = max(
            constraints.sceneSize.width / source.width,
            constraints.sceneSize.height / source.height
        )
        let backdropSize = CGSize(width: source.width * scale, height: source.height * scale)
        let displayedBackdropFrame = CGRect(
            x: (constraints.sceneSize.width - backdropSize.width) / 2,
            y: (constraints.sceneSize.height - backdropSize.height) / 2,
            width: backdropSize.width,
            height: backdropSize.height
        )

        let topMargin = max(34, insets.top + 10)
        let titleWidth = max(220, min(constraints.sceneSize.width - 40, 520))
        let titleControlRegionFrame = CGRect(
            x: (constraints.sceneSize.width - titleWidth) / 2,
            y: constraints.sceneSize.height - topMargin - 66,
            width: titleWidth,
            height: 66
        )
        let settingsControlFrame = CGRect(
            x: titleControlRegionFrame.minX + TitleControlMetrics.sideInset,
            y: titleControlRegionFrame.midY - TitleControlMetrics.gearHitSize / 2,
            width: TitleControlMetrics.gearHitSize,
            height: TitleControlMetrics.gearHitSize
        )
        let currentCityControlFrame = constraints.showsCurrentCityControl
            ? CGRect(
                x: titleControlRegionFrame.maxX
                    - TitleControlMetrics.sideInset
                    - TitleControlMetrics.currentCityWidth,
                y: titleControlRegionFrame.midY - TitleControlMetrics.gearHitSize / 2,
                width: TitleControlMetrics.currentCityWidth,
                height: TitleControlMetrics.gearHitSize
            )
            : nil
        let titleTextMaxX = (currentCityControlFrame?.minX
            ?? (titleControlRegionFrame.maxX - TitleControlMetrics.sideInset))
            - (currentCityControlFrame == nil ? 0 : TitleControlMetrics.titleToCurrentCityGap)
        let titleTextFrame = CGRect(
            x: settingsControlFrame.maxX + TitleControlMetrics.gearToTitleGap,
            y: titleControlRegionFrame.midY - TitleControlMetrics.gearHitSize / 2,
            width: titleTextMaxX
                - settingsControlFrame.maxX
                - TitleControlMetrics.gearToTitleGap,
            height: TitleControlMetrics.gearHitSize
        )

        let informationWidth = min(constraints.sceneSize.width - 32, 600)
        let informationRegionFrame = CGRect(
            x: (constraints.sceneSize.width - informationWidth) / 2,
            y: insets.bottom,
            width: informationWidth,
            height: constraints.environment.layoutClass.informationRegionHeight
        )
        let illustratedMapRegionFrame = CGRect(
            x: sceneFrame.minX,
            y: informationRegionFrame.maxY + 8,
            width: sceneFrame.width,
            height: titleControlRegionFrame.minY - informationRegionFrame.maxY - 16
        )

        guard sceneFrame.contains(titleControlRegionFrame),
              sceneFrame.contains(settingsControlFrame),
              titleControlRegionFrame.contains(settingsControlFrame),
              titleControlRegionFrame.contains(titleTextFrame),
              titleTextFrame.width >= TitleControlMetrics.minimumTitleTextWidth,
              (currentCityControlFrame.map {
                  sceneFrame.contains($0)
                      && titleControlRegionFrame.contains($0)
              } ?? true),
              sceneFrame.contains(informationRegionFrame),
              isFinite(displayedBackdropFrame),
              isFinite(illustratedMapRegionFrame),
              !illustratedMapRegionFrame.isNull,
              !illustratedMapRegionFrame.isEmpty
        else {
            return .unsupported(.unsupportedGeometry)
        }

        // The title, current-city control, and information region are centred
        // against the full scene width with fixed side margins. Horizontal
        // safe-area insets (e.g. Stage Manager or split-view side insets) can
        // therefore push that centred chrome into horizontally unsafe content
        // even when it still fits inside the scene frame. Require all three
        // chrome regions to stay within the horizontal safe-content rect so a
        // window with meaningful side insets fails closed instead of rendering
        // controls under system chrome.
        let safeContentMinX = sceneFrame.minX + insets.left
        let safeContentMaxX = sceneFrame.maxX - insets.right
        guard titleControlRegionFrame.minX >= safeContentMinX,
              titleControlRegionFrame.maxX <= safeContentMaxX,
              settingsControlFrame.minX >= safeContentMinX,
              settingsControlFrame.maxX <= safeContentMaxX,
              titleTextFrame.minX >= safeContentMinX,
              titleTextFrame.maxX <= safeContentMaxX,
              (currentCityControlFrame.map {
                  $0.minX >= safeContentMinX && $0.maxX <= safeContentMaxX
              } ?? true),
              informationRegionFrame.minX >= safeContentMinX,
              informationRegionFrame.maxX <= safeContentMaxX
        else {
            return .unsupported(.unsupportedGeometry)
        }

        var cityPositions: [Int: CGPoint] = [:]
        for (index, anchor) in definition.cityAnchors.enumerated() {
            cityPositions[index + 1] = CGPoint(
                x: displayedBackdropFrame.minX + anchor.x * displayedBackdropFrame.width,
                y: displayedBackdropFrame.minY + anchor.y * displayedBackdropFrame.height
            )
        }

        guard cityPositions.values.allSatisfy({ position in
            let cityFrame = CGRect(
                x: position.x - 22,
                y: position.y - 22,
                width: 44,
                height: 44
            )
            // City interaction frames must stay within the illustrated region
            // AND clear horizontal system chrome (side safe-area insets) so
            // interactive targets are not rendered under Stage Manager / split
            // view chrome. Vertical safe content is already enforced by the
            // illustrated region's title/information bounds.
            return illustratedMapRegionFrame.contains(cityFrame)
                && cityFrame.minX >= safeContentMinX
                && cityFrame.maxX <= safeContentMaxX
        }) else {
            return .unsupported(.unsupportedGeometry)
        }

        let primaryRoutes = definition.primaryRoutes.map { route in
            CountryMapRouteLayout(
                start: cityPositions[route.startCityNumber]!,
                end: cityPositions[route.endCityNumber]!,
                lineWidth: route.lineWidth
            )
        }
        let branchRoutes = definition.branches.map { branch in
            let start = cityPositions[branch.originCityNumber]!
            return CountryMapRouteLayout(
                start: start,
                end: CGPoint(x: start.x + branch.offset.dx, y: start.y + branch.offset.dy),
                lineWidth: branch.lineWidth
            )
        }
        let routes = primaryRoutes + branchRoutes

        guard routes.allSatisfy({ route in
            let bounds = route.strokeExpandedBounds
            // Route strokes follow the same horizontal safe-content rule as
            // city interaction frames so decorative routes do not render under
            // side system chrome.
            return illustratedMapRegionFrame.contains(bounds)
                && bounds.minX >= safeContentMinX
                && bounds.maxX <= safeContentMaxX
        }) else {
            return .unsupported(.unsupportedGeometry)
        }

        return .supported(CountryMapLayout(
            sceneFrame: sceneFrame,
            displayedBackdropFrame: displayedBackdropFrame,
            titleControlRegionFrame: titleControlRegionFrame,
            showsCurrentCityControl: constraints.showsCurrentCityControl,
            settingsControlFrame: settingsControlFrame,
            currentCityControlFrame: currentCityControlFrame,
            titleTextFrame: titleTextFrame,
            informationRegionFrame: informationRegionFrame,
            illustratedMapRegionFrame: illustratedMapRegionFrame,
            cityPositions: cityPositions,
            routes: routes
        ))
    }

    private static func isFinite(_ frame: CGRect) -> Bool {
        frame.minX.isFinite
            && frame.minY.isFinite
            && frame.width.isFinite
            && frame.height.isFinite
    }
}
