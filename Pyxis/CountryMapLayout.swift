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
}

struct CountryMapLayoutEnvironment: Equatable {
    let safeAreaInsets: CountryMapSafeAreaInsets
    let layoutClass: CountryMapLayoutClass
}

struct CountryMapLayoutConstraints: Equatable {
    let sceneSize: CGSize
    let environment: CountryMapLayoutEnvironment
    let definition: CountryMapLayoutDefinition
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
        static let minimumTitleTextWidth: CGFloat = 160
        static let minimumTitleFontSize: CGFloat = 16
        static let resourceWidth: CGFloat = 106
        static let resourceHeight: CGFloat = 44
        static let progressHeight: CGFloat = 24
    }

    static let tabBarHeight: CGFloat = 72
    static let preferredPhoneInformationHeight: CGFloat = 164
    static let preferredPadInformationHeight: CGFloat = 140
    static let minimumCompactInformationHeight: CGFloat = 48
    static let minimumIllustratedMapHeight: CGFloat = 431
    static let minimumCityCenterDistance: CGFloat = 45

    static let minimumTitleTextWidth = TitleControlMetrics.minimumTitleTextWidth
    static let minimumTitleFontSize = TitleControlMetrics.minimumTitleFontSize

    let sceneFrame: CGRect
    let displayedBackdropFrame: CGRect
    let titleControlRegionFrame: CGRect
    let settingsControlFrame: CGRect
    let titleTextFrame: CGRect
    let resourceFrame: CGRect
    let progressFrame: CGRect
    let informationRegionFrame: CGRect
    let illustratedMapRegionFrame: CGRect
    let cityPositions: [Int: CGPoint]
    let routes: [CountryMapRouteLayout]

    // The map contract is deliberately fail-closed: all authored-data,
    // chrome-budget, transform, and interaction-envelope guards live in this
    // pure computation so callers cannot render a partial route.
    // swiftlint:disable:next cyclomatic_complexity
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
        guard [insets.top, insets.left, insets.bottom, insets.right].allSatisfy({
            $0.isFinite && $0 >= 0
        }) else {
            return .unsupported(.unsupportedGeometry)
        }

        let topMargin = max(34, insets.top + 10)
        let titleWidth = max(220, min(constraints.sceneSize.width - 40, 520))
        let titleControlRegionFrame = CGRect(
            x: (constraints.sceneSize.width - titleWidth) / 2,
            y: constraints.sceneSize.height - topMargin - 66,
            width: titleWidth,
            height: 66
        )
        let settingsControlFrame = CGRect(
            x: titleControlRegionFrame.maxX
                - TitleControlMetrics.sideInset
                - TitleControlMetrics.gearHitSize,
            y: titleControlRegionFrame.midY - TitleControlMetrics.gearHitSize / 2,
            width: TitleControlMetrics.gearHitSize,
            height: TitleControlMetrics.gearHitSize
        )
        let titleTextFrame = CGRect(
            x: titleControlRegionFrame.minX + TitleControlMetrics.sideInset,
            y: titleControlRegionFrame.midY - TitleControlMetrics.gearHitSize / 2,
            width: titleControlRegionFrame.maxX
                - titleControlRegionFrame.minX
                - TitleControlMetrics.sideInset * 2
                - TitleControlMetrics.gearHitSize
                - TitleControlMetrics.gearToTitleGap,
            height: TitleControlMetrics.gearHitSize
        )
        // Keep map-only chrome within the existing title treatment. The
        // resource tile rises slightly above the title plate, matching the
        // authored presentation without consuming map/card budget.
        let resourceFrame = CGRect(
            x: titleControlRegionFrame.minX + TitleControlMetrics.sideInset - 2,
            y: titleControlRegionFrame.maxY - TitleControlMetrics.resourceHeight + 10,
            width: min(TitleControlMetrics.resourceWidth, titleControlRegionFrame.width * 0.32),
            height: TitleControlMetrics.resourceHeight
        )
        let progressFrame = CGRect(
            x: titleControlRegionFrame.minX + 140,
            y: titleControlRegionFrame.minY + 5,
            width: settingsControlFrame.minX - 10 - (titleControlRegionFrame.minX + 140),
            height: TitleControlMetrics.progressHeight
        )

        let preferredInformationHeight: CGFloat = constraints.environment.layoutClass == .phone
            ? preferredPhoneInformationHeight
            : preferredPadInformationHeight
        let mapToTitleGap: CGFloat = 8
        let tabToCardGap: CGFloat = 8
        // Build the vertical stack from the bottom safe area upward: tabs,
        // scout card, then the illustrated map. Keep the tab reservation
        // independent of card layout so map hit targets cannot render beneath
        // the tabs on iPad.
        let reservedTabHeight = tabBarHeight
        let informationHeightBudget = titleControlRegionFrame.minY
            - mapToTitleGap
            - minimumIllustratedMapHeight
            - reservedTabHeight
            - tabToCardGap
            - insets.bottom
        guard informationHeightBudget >= minimumCompactInformationHeight else {
            return .unsupported(.unsupportedGeometry)
        }

        let informationWidth = min(constraints.sceneSize.width - 32, 600)
        var informationRegionFrame = CGRect(
            x: (constraints.sceneSize.width - informationWidth) / 2,
            y: insets.bottom + reservedTabHeight + tabToCardGap,
            width: informationWidth,
            height: min(preferredInformationHeight, informationHeightBudget)
        )
        var illustratedMapRegionFrame = CGRect(
            x: sceneFrame.minX,
            y: informationRegionFrame.maxY,
            width: sceneFrame.width,
            height: constraints.environment.layoutClass == .phone
                ? minimumIllustratedMapHeight
                : titleControlRegionFrame.minY
                    - mapToTitleGap
                    - informationRegionFrame.maxY
        )

        guard sceneFrame.contains(titleControlRegionFrame),
              sceneFrame.contains(settingsControlFrame),
              sceneFrame.contains(resourceFrame),
              sceneFrame.contains(progressFrame),
              titleControlRegionFrame.contains(settingsControlFrame),
              titleControlRegionFrame.contains(titleTextFrame),
              titleTextFrame.width >= TitleControlMetrics.minimumTitleTextWidth,
              sceneFrame.contains(informationRegionFrame),
              illustratedMapRegionFrame.height >= minimumIllustratedMapHeight,
              isFinite(illustratedMapRegionFrame)
        else {
            return .unsupported(.unsupportedGeometry)
        }

        // The title and information card are centred against the full scene
        // width. Keep the existing side-safe-content validation for chrome and
        // interaction targets.
        let safeContentMinX = sceneFrame.minX + insets.left
        let safeContentMaxX = sceneFrame.maxX - insets.right
        guard titleControlRegionFrame.minX >= safeContentMinX,
              titleControlRegionFrame.maxX <= safeContentMaxX,
              settingsControlFrame.minX >= safeContentMinX,
              settingsControlFrame.maxX <= safeContentMaxX,
              resourceFrame.minX >= safeContentMinX,
              resourceFrame.maxX <= safeContentMaxX,
              progressFrame.minX >= safeContentMinX,
              progressFrame.maxX <= safeContentMaxX,
              titleTextFrame.minX >= safeContentMinX,
              titleTextFrame.maxX <= safeContentMaxX,
              informationRegionFrame.minX >= safeContentMinX,
              informationRegionFrame.maxX <= safeContentMaxX
        else {
            return .unsupported(.unsupportedGeometry)
        }

        let sourceCityPoints = definition.cityAnchors.map {
            CGPoint(x: $0.x * source.width, y: $0.y * source.height)
        }
        var minimumAuthoredDistance = CGFloat.greatestFiniteMagnitude
        for index in sourceCityPoints.indices {
            for otherIndex in sourceCityPoints.indices.dropFirst(index + 1) {
                minimumAuthoredDistance = min(
                    minimumAuthoredDistance,
                    hypot(
                        sourceCityPoints[index].x - sourceCityPoints[otherIndex].x,
                        sourceCityPoints[index].y - sourceCityPoints[otherIndex].y
                    )
                )
            }
        }
        guard minimumAuthoredDistance.isFinite, minimumAuthoredDistance > 0 else {
            return .unsupported(.invalidAuthoredData)
        }

        let scale = max(
            sceneFrame.width / source.width,
            illustratedMapRegionFrame.height / source.height,
            minimumCityCenterDistance / minimumAuthoredDistance
        )
        guard scale.isFinite, scale > 0 else {
            return .unsupported(.unsupportedGeometry)
        }

        let backdropSize = CGSize(width: source.width * scale, height: source.height * scale)
        let horizontalOrigin = (sceneFrame.width - backdropSize.width) / 2
        let unshiftedCityPositions = sourceCityPoints.map {
            CGPoint(
                x: horizontalOrigin + $0.x * scale,
                y: $0.y * scale
            )
        }
        let unshiftedRoutes = makeRoutes(
            cityPositions: Dictionary(uniqueKeysWithValues: unshiftedCityPositions.enumerated().map {
                ($0.offset + 1, $0.element)
            }),
            definition: definition
        )

        var interactionEnvelope = CGRect.null
        for position in unshiftedCityPositions {
            interactionEnvelope = interactionEnvelope.union(
                CGRect(x: position.x - 22, y: position.y - 22, width: 44, height: 44)
            )
        }
        for route in unshiftedRoutes {
            interactionEnvelope = interactionEnvelope.union(route.strokeExpandedBounds)
        }
        guard !interactionEnvelope.isNull, isFinite(interactionEnvelope) else {
            return .unsupported(.unsupportedGeometry)
        }

        if constraints.environment.layoutClass == .phone {
            // Keep the authored interaction envelope inside the illustrated
            // region with an 8 pt target/route margin on each edge. The
            // reference 431 pt map already provides that margin; taller
            // width-filled maps need the same guard rather than letting the
            // envelope touch the crop boundary.
            let requiredMapHeight = max(minimumIllustratedMapHeight, interactionEnvelope.height + 16)
            let maximumMapHeight = titleControlRegionFrame.minY
                - mapToTitleGap
                - illustratedMapRegionFrame.minY
            if requiredMapHeight > maximumMapHeight {
                let cardReduction = requiredMapHeight - maximumMapHeight
                informationRegionFrame.size.height -= cardReduction
                guard informationRegionFrame.height >= minimumCompactInformationHeight else {
                    return .unsupported(.unsupportedGeometry)
                }
                illustratedMapRegionFrame.origin.y = informationRegionFrame.maxY
            }
            let finalMaximumMapHeight = titleControlRegionFrame.minY
                - mapToTitleGap
                - illustratedMapRegionFrame.minY
            guard finalMaximumMapHeight >= requiredMapHeight else {
                return .unsupported(.unsupportedGeometry)
            }
            illustratedMapRegionFrame.size.height = requiredMapHeight
        }
        guard illustratedMapRegionFrame.height >= minimumIllustratedMapHeight,
              isFinite(illustratedMapRegionFrame) else {
            return .unsupported(.unsupportedGeometry)
        }

        let verticalOrigin = illustratedMapRegionFrame.midY - interactionEnvelope.midY
        let displayedBackdropFrame = CGRect(
            x: horizontalOrigin,
            y: verticalOrigin,
            width: backdropSize.width,
            height: backdropSize.height
        )
        let cityPositions = Dictionary(uniqueKeysWithValues: unshiftedCityPositions.enumerated().map {
            (
                $0.offset + 1,
                CGPoint(x: $0.element.x, y: $0.element.y + verticalOrigin)
            )
        })
        let routes = makeRoutes(cityPositions: cityPositions, definition: definition)

        guard cityPositions.values.allSatisfy({ position in
            let cityFrame = CGRect(x: position.x - 22, y: position.y - 22, width: 44, height: 44)
            return illustratedMapRegionFrame.contains(cityFrame)
                && cityFrame.minX >= safeContentMinX
                && cityFrame.maxX <= safeContentMaxX
        }),
        routes.allSatisfy({ route in
            let bounds = route.strokeExpandedBounds
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
            settingsControlFrame: settingsControlFrame,
            titleTextFrame: titleTextFrame,
            resourceFrame: resourceFrame,
            progressFrame: progressFrame,
            informationRegionFrame: informationRegionFrame,
            illustratedMapRegionFrame: illustratedMapRegionFrame,
            cityPositions: cityPositions,
            routes: routes
        ))
    }

    private static func makeRoutes(
        cityPositions: [Int: CGPoint],
        definition: CountryMapLayoutDefinition
    ) -> [CountryMapRouteLayout] {
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
        return primaryRoutes + branchRoutes
    }

    private static func isFinite(_ frame: CGRect) -> Bool {
        frame.minX.isFinite
            && frame.minY.isFinite
            && frame.width.isFinite
            && frame.height.isFinite
    }
}
