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
        static let progressHeight: CGFloat = 22
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
    static func compute(_ constraints: CountryMapLayoutConstraints) -> CountryMapLayoutResult {
        let sceneFrame = CGRect(origin: .zero, size: constraints.sceneSize)
        guard isValidSceneSize(constraints.sceneSize) else {
            return .unsupported(.unsupportedGeometry)
        }

        let definition = constraints.definition
        let source = definition.canonicalBackdropSize
        guard hasValidAuthoredDefinition(definition, source: source) else {
            return .unsupported(.invalidAuthoredData)
        }

        let insets = constraints.environment.safeAreaInsets
        guard [insets.top, insets.left, insets.bottom, insets.right].allSatisfy({
            $0.isFinite && $0 >= 0
        }) else {
            return .unsupported(.unsupportedGeometry)
        }

        // The title and information card are centred against the full scene
        // width. Side-safe-content validation still applies to every chrome
        // and interaction target.
        let safeContentMinX = sceneFrame.minX + insets.left
        let safeContentMaxX = sceneFrame.maxX - insets.right

        guard let header = makeHeaderFrames(
            sceneSize: constraints.sceneSize,
            insets: insets
        ),
        isHeaderSupported(header, sceneFrame: sceneFrame, minX: safeContentMinX, maxX: safeContentMaxX),
        let stack = makeVerticalStack(
            sceneFrame: sceneFrame,
            headerRegionMinY: header.region.minY,
            sceneWidth: constraints.sceneSize.width,
            insets: insets,
            layoutClass: constraints.environment.layoutClass
        ),
        isStackSupported(stack, sceneFrame: sceneFrame, minX: safeContentMinX, maxX: safeContentMaxX)
        else {
            return .unsupported(.unsupportedGeometry)
        }

        guard let minimumAuthoredDistance = minimumAuthoredDistance(
            definition: definition,
            source: source
        ) else {
            return .unsupported(.invalidAuthoredData)
        }

        guard let fitted = fitInteractionEnvelope(EnvelopeInput(
            definition: definition,
            source: source,
            sceneFrame: sceneFrame,
            headerRegionMinY: header.region.minY,
            stack: stack,
            layoutClass: constraints.environment.layoutClass,
            minimumAuthoredDistance: minimumAuthoredDistance,
            minX: safeContentMinX,
            maxX: safeContentMaxX
        )) else {
            return .unsupported(.unsupportedGeometry)
        }

        return .supported(CountryMapLayout(
            sceneFrame: sceneFrame,
            displayedBackdropFrame: fitted.displayedBackdropFrame,
            titleControlRegionFrame: header.region,
            settingsControlFrame: header.settings,
            titleTextFrame: header.titleText,
            resourceFrame: header.resource,
            progressFrame: header.progress,
            informationRegionFrame: fitted.stack.informationRegion,
            illustratedMapRegionFrame: fitted.stack.illustratedMap,
            cityPositions: fitted.cityPositions,
            routes: fitted.routes
        ))
    }

    // MARK: - Validation phases

    private static func isValidSceneSize(_ size: CGSize) -> Bool {
        size.width >= 375
            && size.height >= 667
            && size.width.isFinite
            && size.height.isFinite
            && size.height > size.width
    }

    private static func hasValidAuthoredDefinition(
        _ definition: CountryMapLayoutDefinition,
        source: CGSize
    ) -> Bool {
        source.width.isFinite
            && source.height.isFinite
            && source.width > 0
            && source.height > 0
            && definition.cityAnchors.count == 15
            && definition.primaryRoutes.count == 14
            && definition.cityAnchors.allSatisfy({
                $0.x.isFinite
                    && $0.y.isFinite
                    && (0...1).contains($0.x)
                    && (0...1).contains($0.y)
            })
            && definition.primaryRoutes.allSatisfy({
                (1...15).contains($0.startCityNumber)
                    && (1...15).contains($0.endCityNumber)
                    && $0.lineWidth.isFinite
                    && $0.lineWidth > 0
            })
            && definition.branches.allSatisfy({
                (1...15).contains($0.originCityNumber)
                    && $0.offset.dx.isFinite
                    && $0.offset.dy.isFinite
                    && $0.lineWidth.isFinite
                    && $0.lineWidth > 0
            })
    }

    private static func minimumAuthoredDistance(
        definition: CountryMapLayoutDefinition,
        source: CGSize
    ) -> CGFloat? {
        let sourceCityPoints = definition.cityAnchors.map {
            CGPoint(x: $0.x * source.width, y: $0.y * source.height)
        }
        var minimumDistance = CGFloat.greatestFiniteMagnitude
        for index in sourceCityPoints.indices {
            for otherIndex in sourceCityPoints.indices.dropFirst(index + 1) {
                minimumDistance = min(
                    minimumDistance,
                    hypot(
                        sourceCityPoints[index].x - sourceCityPoints[otherIndex].x,
                        sourceCityPoints[index].y - sourceCityPoints[otherIndex].y
                    )
                )
            }
        }
        return minimumDistance.isFinite && minimumDistance > 0 ? minimumDistance : nil
    }

    // MARK: - Header geometry

    private struct HeaderFrames {
        let region: CGRect
        let settings: CGRect
        let titleText: CGRect
        let resource: CGRect
        let progress: CGRect
    }

    private static func makeHeaderFrames(
        sceneSize: CGSize,
        insets: CountryMapSafeAreaInsets
    ) -> HeaderFrames? {
        let topMargin = max(34, insets.top + 10)
        let titleWidth = max(220, min(sceneSize.width - 40, 520))
        let region = CGRect(
            x: (sceneSize.width - titleWidth) / 2,
            y: sceneSize.height - topMargin - 66,
            width: titleWidth,
            height: 66
        )
        let settings = CGRect(
            x: region.maxX - TitleControlMetrics.sideInset - TitleControlMetrics.gearHitSize,
            y: region.maxY - TitleControlMetrics.gearHitSize,
            width: TitleControlMetrics.gearHitSize,
            height: TitleControlMetrics.gearHitSize
        )
        let progressStartX = region.minX + 140
        let titleTextX = region.minX + TitleControlMetrics.sideInset
        let unclampedTitleTextWidth = region.width
            - TitleControlMetrics.sideInset * 2
            - TitleControlMetrics.gearHitSize
            - TitleControlMetrics.gearToTitleGap
        // The title shares the lower header row with the progress segments:
        // end it before they start, but never below the authored minimum
        // title width (which wins when space does not permit both).
        let titleText = CGRect(
            x: titleTextX,
            y: region.minY,
            width: max(
                TitleControlMetrics.minimumTitleTextWidth,
                min(unclampedTitleTextWidth, progressStartX - titleTextX)
            ),
            height: TitleControlMetrics.progressHeight
        )
        // Reserve the lower row for the Country title/progress treatment and
        // the upper row for the resource tile and Settings gear. This keeps
        // every header target inside the existing title allocation without
        // changing the card/map budget below it.
        let resource = CGRect(
            x: region.minX + TitleControlMetrics.sideInset - 2,
            y: region.maxY - TitleControlMetrics.resourceHeight,
            width: min(TitleControlMetrics.resourceWidth, region.width * 0.32),
            height: TitleControlMetrics.resourceHeight
        )
        let progress = CGRect(
            x: progressStartX,
            y: region.minY,
            width: settings.minX - 10 - progressStartX,
            height: TitleControlMetrics.progressHeight
        )
        return HeaderFrames(
            region: region,
            settings: settings,
            titleText: titleText,
            resource: resource,
            progress: progress
        )
    }

    private static func isHeaderSupported(
        _ header: HeaderFrames,
        sceneFrame: CGRect,
        minX: CGFloat,
        maxX: CGFloat
    ) -> Bool {
        let frames = [header.region, header.settings, header.titleText, header.resource, header.progress]
        return frames.allSatisfy { sceneFrame.contains($0) }
            && header.region.contains(header.settings)
            && header.region.contains(header.titleText)
            && header.titleText.width >= TitleControlMetrics.minimumTitleTextWidth
            && frames.allSatisfy { $0.minX >= minX && $0.maxX <= maxX }
    }

    // MARK: - Vertical budget

    private struct VerticalStack {
        var informationRegion: CGRect
        var illustratedMap: CGRect
    }

    private static func makeVerticalStack(
        sceneFrame: CGRect,
        headerRegionMinY: CGFloat,
        sceneWidth: CGFloat,
        insets: CountryMapSafeAreaInsets,
        layoutClass: CountryMapLayoutClass
    ) -> VerticalStack? {
        let preferredInformationHeight: CGFloat = layoutClass == .phone
            ? preferredPhoneInformationHeight
            : preferredPadInformationHeight
        let mapToTitleGap: CGFloat = 8
        let tabToCardGap: CGFloat = 8
        // Build the vertical stack from the bottom safe area upward: tabs,
        // scout card, then the illustrated map. Keep the tab reservation
        // independent of card layout so map hit targets cannot render beneath
        // the tabs on iPad.
        let reservedTabHeight = tabBarHeight
        let informationHeightBudget = headerRegionMinY
            - mapToTitleGap
            - minimumIllustratedMapHeight
            - reservedTabHeight
            - tabToCardGap
            - insets.bottom
        guard informationHeightBudget >= minimumCompactInformationHeight else {
            return nil
        }

        let informationWidth = min(sceneWidth - 32, 600)
        let informationRegion = CGRect(
            x: (sceneWidth - informationWidth) / 2,
            y: insets.bottom + reservedTabHeight + tabToCardGap,
            width: informationWidth,
            height: min(preferredInformationHeight, informationHeightBudget)
        )
        let illustratedMap = CGRect(
            x: sceneFrame.minX,
            y: informationRegion.maxY,
            width: sceneFrame.width,
            height: layoutClass == .phone
                ? minimumIllustratedMapHeight
                : headerRegionMinY - mapToTitleGap - informationRegion.maxY
        )
        return VerticalStack(informationRegion: informationRegion, illustratedMap: illustratedMap)
    }

    private static func isStackSupported(
        _ stack: VerticalStack,
        sceneFrame: CGRect,
        minX: CGFloat,
        maxX: CGFloat
    ) -> Bool {
        sceneFrame.contains(stack.informationRegion)
            && stack.illustratedMap.height >= minimumIllustratedMapHeight
            && isFinite(stack.illustratedMap)
            && stack.informationRegion.minX >= minX
            && stack.informationRegion.maxX <= maxX
    }

    // MARK: - Envelope fitting

    private struct FittedMap {
        let stack: VerticalStack
        let displayedBackdropFrame: CGRect
        let cityPositions: [Int: CGPoint]
        let routes: [CountryMapRouteLayout]
    }

    private struct EnvelopeInput {
        let definition: CountryMapLayoutDefinition
        let source: CGSize
        let sceneFrame: CGRect
        let headerRegionMinY: CGFloat
        let stack: VerticalStack
        let layoutClass: CountryMapLayoutClass
        let minimumAuthoredDistance: CGFloat
        let minX: CGFloat
        let maxX: CGFloat
    }

    private static func fitInteractionEnvelope(_ input: EnvelopeInput) -> FittedMap? {
        let definition = input.definition
        let source = input.source
        let sceneFrame = input.sceneFrame
        let minX = input.minX
        let maxX = input.maxX
        var stack = input.stack
        let mapToTitleGap: CGFloat = 8
        let sourceCityPoints = definition.cityAnchors.map {
            CGPoint(x: $0.x * source.width, y: $0.y * source.height)
        }

        let scale = max(
            sceneFrame.width / source.width,
            stack.illustratedMap.height / source.height,
            minimumCityCenterDistance / input.minimumAuthoredDistance
        )
        guard scale.isFinite, scale > 0 else {
            return nil
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
            return nil
        }

        if input.layoutClass == .phone {
            // Keep the authored interaction envelope inside the illustrated
            // region with an 8 pt target/route margin on each edge. The
            // reference 431 pt map already provides that margin; taller
            // width-filled maps need the same guard rather than letting the
            // envelope touch the crop boundary.
            let requiredMapHeight = max(minimumIllustratedMapHeight, interactionEnvelope.height + 16)
            let maximumMapHeight = input.headerRegionMinY - mapToTitleGap - stack.illustratedMap.minY
            if requiredMapHeight > maximumMapHeight {
                let cardReduction = requiredMapHeight - maximumMapHeight
                stack.informationRegion.size.height -= cardReduction
                guard stack.informationRegion.height >= minimumCompactInformationHeight else {
                    return nil
                }
                stack.illustratedMap.origin.y = stack.informationRegion.maxY
            }
            let finalMaximumMapHeight = input.headerRegionMinY - mapToTitleGap - stack.illustratedMap.minY
            guard finalMaximumMapHeight >= requiredMapHeight else {
                return nil
            }
            stack.illustratedMap.size.height = requiredMapHeight
        }
        guard stack.illustratedMap.height >= minimumIllustratedMapHeight,
              isFinite(stack.illustratedMap) else {
            return nil
        }

        let verticalOrigin = stack.illustratedMap.midY - interactionEnvelope.midY
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
            return stack.illustratedMap.contains(cityFrame)
                && cityFrame.minX >= minX
                && cityFrame.maxX <= maxX
        }),
        routes.allSatisfy({ route in
            let bounds = route.strokeExpandedBounds
            return stack.illustratedMap.contains(bounds)
                && bounds.minX >= minX
                && bounds.maxX <= maxX
        }) else {
            return nil
        }

        return FittedMap(
            stack: stack,
            displayedBackdropFrame: displayedBackdropFrame,
            cityPositions: cityPositions,
            routes: routes
        )
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
