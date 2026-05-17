//
//  GameUITheme.swift
//  Pyxis
//

import CoreGraphics
import SpriteKit

enum GameUITheme {
    enum Font {
        static let bold = "AvenirNext-DemiBold"
        static let medium = "AvenirNext-Medium"
    }

    enum Color {
        static let panelFill = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 0.88)
        static let panelStroke = SKColor(red: 1.0, green: 0.91, blue: 0.55, alpha: 0.26)
        static let textPrimary = SKColor(red: 0.98, green: 0.94, blue: 0.84, alpha: 1.0)
        static let textSecondary = SKColor(red: 0.72, green: 0.82, blue: 0.86, alpha: 1.0)
        static let gold = SKColor(red: 1.0, green: 0.80, blue: 0.22, alpha: 1.0)
        static let hpFill = SKColor(red: 0.18, green: 0.78, blue: 0.42, alpha: 1.0)
        static let hpBackground = SKColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 0.94)
        static let spawn = SKColor(red: 0.10, green: 0.46, blue: 0.82, alpha: 1.0)
        static let upgradeAvailable = SKColor(red: 0.64, green: 0.36, blue: 0.86, alpha: 1.0)
        static let upgradeUnavailable = SKColor(red: 0.28, green: 0.25, blue: 0.34, alpha: 1.0)
        static let danger = SKColor(red: 0.91, green: 0.29, blue: 0.22, alpha: 1.0)
        static let locked = SKColor(red: 0.20, green: 0.28, blue: 0.34, alpha: 1.0)
    }

    enum Z {
        static let background: CGFloat = -20
        static let battlefield: CGFloat = 0
        static let hud: CGFloat = 100
        static let effects: CGFloat = 140
        static let modal: CGFloat = 200
    }

    static func clampedProgress(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    static func topUnsafeInset(sceneSize: CGSize, view: SKView?) -> CGFloat {
        let viewInset = view?.safeAreaInsets.top ?? 0
        let tallPhoneInset: CGFloat = isTallPhone(sceneSize) ? 58 : 0
        return max(viewInset, tallPhoneInset)
    }

    static func bottomUnsafeInset(sceneSize: CGSize, view: SKView?) -> CGFloat {
        let viewInset = view?.safeAreaInsets.bottom ?? 0
        let tallPhoneInset: CGFloat = isTallPhone(sceneSize) ? 26 : 0
        return max(viewInset, tallPhoneInset)
    }

    private static func isTallPhone(_ size: CGSize) -> Bool {
        let aspectRatio = size.height / max(size.width, 1)
        return size.width <= 430 && size.height >= 780 && aspectRatio >= 1.9
    }
}
