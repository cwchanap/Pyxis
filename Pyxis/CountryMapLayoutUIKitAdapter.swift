import SpriteKit
import UIKit

enum CountryMapLayoutUIKitAdapter {
    static func environment(
        safeAreaInsets: UIEdgeInsets,
        idiom: UIUserInterfaceIdiom
    ) -> CountryMapLayoutEnvironment? {
        let layoutClass: CountryMapLayoutClass
        switch idiom {
        case .phone:
            layoutClass = .phone
        case .pad:
            layoutClass = .pad
        default:
            return nil
        }

        return CountryMapLayoutEnvironment(
            safeAreaInsets: CountryMapSafeAreaInsets(
                top: safeAreaInsets.top,
                left: safeAreaInsets.left,
                bottom: safeAreaInsets.bottom,
                right: safeAreaInsets.right
            ),
            layoutClass: layoutClass
        )
    }

    static func environment(for view: SKView) -> CountryMapLayoutEnvironment? {
        environment(
            safeAreaInsets: view.safeAreaInsets,
            idiom: view.traitCollection.userInterfaceIdiom
        )
    }
}
