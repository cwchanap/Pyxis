import CoreGraphics
import SpriteKit
import UIKit

final class SettingsGearNode: SKNode {
    static let semanticName = "feedbackSettingsGear"

    private static let minimumHitSize = CGSize(width: 44, height: 44)
    private static let glyphSize = CGSize(width: 21, height: 21)

    private let tile = PanelNode(size: .zero)
    private let hitShape = SKShapeNode()
    private let glyph = SKSpriteNode()
    private var hitFrame = CGRect.zero
    private var localHitFrame = CGRect.zero

    override init() {
        super.init()
        configureTree()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(frame: CGRect, appearance: PanelNode.Appearance = .standard) {
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.width.isFinite,
              frame.height.isFinite,
              frame.width > 0,
              frame.height > 0 else {
            hitFrame = .zero
            localHitFrame = .zero
            isHidden = true
            return
        }

        let size = CGSize(
            width: max(frame.width, Self.minimumHitSize.width),
            height: max(frame.height, Self.minimumHitSize.height)
        )
        let resolvedFrame = CGRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        hitFrame = resolvedFrame
        position = CGPoint(x: resolvedFrame.midX, y: resolvedFrame.midY)
        localHitFrame = CGRect(
            x: -resolvedFrame.width / 2,
            y: -resolvedFrame.height / 2,
            width: resolvedFrame.width,
            height: resolvedFrame.height
        )
        tile.apply(
            size: resolvedFrame.size,
            style: .normal,
            showsRivets: true,
            appearance: appearance
        )
        tile.position = .zero
        hitShape.path = CGPath(rect: localHitFrame, transform: nil)
        applyGlyphAppearance(appearance)
        glyph.size = Self.glyphSize
        glyph.position = .zero
        isHidden = false
    }

    override func contains(_ point: CGPoint) -> Bool {
        guard !isHidden else { return false }
        guard let parent else { return hitFrame.contains(point) }
        return localHitFrame.contains(convert(point, from: parent))
    }

    func contains(_ point: CGPoint, in coordinateNode: SKNode) -> Bool {
        guard !isHidden else { return false }
        return localHitFrame.contains(convert(point, from: coordinateNode))
    }

    var resolvedHitFrame: CGRect { hitFrame }

    private func applyGlyphAppearance(_ appearance: PanelNode.Appearance) {
        guard let symbol = UIImage(systemName: "gearshape.fill") else {
            assertionFailure("Missing SF Symbol: gearshape.fill")
            return
        }

        switch appearance {
        case .standard:
            glyph.texture = SKTexture(image: symbol)
            glyph.color = GameUITheme.Color.textPrimary
            glyph.colorBlendFactor = 1
        case .forged:
            guard let tinted = gameUISymbolImage(
                named: "gearshape.fill",
                color: SKColor(red: 1, green: 232 / 255, blue: 196 / 255, alpha: 1)
            ) else { return }
            glyph.texture = SKTexture(image: tinted)
            glyph.colorBlendFactor = 0
        }
    }

    private func configureTree() {
        name = Self.semanticName
        zPosition = GameUITheme.Z.hud + 2

        tile.name = "settingsGearTile"
        tile.zPosition = -1
        addChild(tile)

        hitShape.name = Self.semanticName
        hitShape.fillColor = .clear
        hitShape.strokeColor = .clear
        hitShape.lineWidth = 0
        hitShape.zPosition = 0
        addChild(hitShape)

        applyGlyphAppearance(.standard)
        glyph.zPosition = 1
        addChild(glyph)

        isHidden = true
    }
}

#if DEBUG
extension SettingsGearNode {
    var hitShapeNameForTesting: String? { hitShape.name }
    var hitFrameForTesting: CGRect { hitFrame }
    var glyphSizeForTesting: CGSize { glyph.size }
    var glyphColorBlendFactorForTesting: CGFloat { glyph.colorBlendFactor }
    var nodeCountForTesting: Int {
        var count = 0
        var stack: [SKNode] = [self]
        while let node = stack.popLast() {
            count += 1
            stack.append(contentsOf: node.children)
        }
        return count
    }
}
#endif
