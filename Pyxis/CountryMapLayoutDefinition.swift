import CoreGraphics

struct CountryMapPrimaryRouteDefinition: Equatable {
    let startCityNumber: Int
    let endCityNumber: Int
    let lineWidth: CGFloat
}

struct CountryMapBranchDefinition: Equatable {
    let originCityNumber: Int
    let offset: CGVector
    let lineWidth: CGFloat
}

struct CountryMapLayoutDefinition: Equatable {
    let canonicalBackdropSize: CGSize
    let cityAnchors: [CGPoint]
    let primaryRoutes: [CountryMapPrimaryRouteDefinition]
    let branches: [CountryMapBranchDefinition]

    static let country1 = CountryMapLayoutDefinition(
        canonicalBackdropSize: CGSize(width: 1024, height: 1536),
        cityAnchors: [
            CGPoint(x: 0.4000, y: 0.1696),
            CGPoint(x: 0.7528, y: 0.2020),
            CGPoint(x: 0.6846, y: 0.2874),
            CGPoint(x: 0.6904, y: 0.3721),
            CGPoint(x: 0.2776, y: 0.2517),
            CGPoint(x: 0.3518, y: 0.3386),
            CGPoint(x: 0.4171, y: 0.4171),
            CGPoint(x: 0.7078, y: 0.4598),
            CGPoint(x: 0.7200, y: 0.6160),
            CGPoint(x: 0.5894, y: 0.6473),
            CGPoint(x: 0.3468, y: 0.5793),
            CGPoint(x: 0.4225, y: 0.6725),
            CGPoint(x: 0.3452, y: 0.7280),
            CGPoint(x: 0.4865, y: 0.7651),
            CGPoint(x: 0.6807, y: 0.7931)
        ],
        primaryRoutes: (1...14).map {
            CountryMapPrimaryRouteDefinition(
                startCityNumber: $0,
                endCityNumber: $0 + 1,
                lineWidth: 6
            )
        },
        branches: [
            .init(originCityNumber: 3, offset: CGVector(dx: -44, dy: 34), lineWidth: 4),
            .init(originCityNumber: 6, offset: CGVector(dx: 44, dy: 34), lineWidth: 4),
            .init(originCityNumber: 9, offset: CGVector(dx: -44, dy: 34), lineWidth: 4),
            .init(originCityNumber: 12, offset: CGVector(dx: 44, dy: 34), lineWidth: 4)
        ]
    )
}
