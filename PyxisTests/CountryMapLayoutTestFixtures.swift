import CoreGraphics
@testable import Pyxis

struct CountryMapLayoutTestFixture: Sendable {
    let name: String
    let size: CGSize
    let insets: CountryMapSafeAreaInsets
    let layoutClass: CountryMapLayoutClass
}

enum CountryMapLayoutTestFixtures {
    static let supported: [CountryMapLayoutTestFixture] = [
        .init(name: "small phone", size: .init(width: 375, height: 667),
              insets: .zero, layoutClass: .phone),
        .init(name: "iPhone 12/13 mini", size: .init(width: 375, height: 812),
              insets: .init(top: 50, left: 0, bottom: 34, right: 0), layoutClass: .phone),
        .init(name: "modern phone", size: .init(width: 393, height: 852),
              insets: .init(top: 59, left: 0, bottom: 34, right: 0), layoutClass: .phone),
        .init(name: "large phone", size: .init(width: 440, height: 956),
              insets: .init(top: 62, left: 0, bottom: 34, right: 0), layoutClass: .phone),
        .init(name: "iPad mini", size: .init(width: 744, height: 1133),
              insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "11-inch iPad", size: .init(width: 834, height: 1194),
              insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "13-inch iPad", size: .init(width: 1032, height: 1376),
              insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "Stage Manager", size: .init(width: 600, height: 1008),
              insets: .init(top: 28, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "narrow iPad", size: .init(width: 480, height: 1194),
              insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "iPad with side insets", size: .init(width: 834, height: 1194),
              insets: .init(top: 24, left: 50, bottom: 20, right: 50), layoutClass: .pad)
    ]
}
