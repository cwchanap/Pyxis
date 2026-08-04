import CoreGraphics
import SpriteKit
import UIKit

final class SettingsGearNode: SKNode {
    static let semanticName = "feedbackSettingsGear"

    private static let minimumHitSize = CGSize(width: 44, height: 44)
    private static let glyphSize = CGSize(width: 21, height: 21)

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

    func apply(frame: CGRect) {
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
        hitShape.path = CGPath(rect: localHitFrame, transform: nil)
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

    private func configureTree() {
        name = Self.semanticName
        zPosition = GameUITheme.Z.hud + 2

        hitShape.name = Self.semanticName
        hitShape.fillColor = .clear
        hitShape.strokeColor = .clear
        hitShape.lineWidth = 0
        hitShape.zPosition = 0
        addChild(hitShape)

        if let image = UIImage(systemName: "gearshape.fill") {
            glyph.texture = SKTexture(image: image)
        } else {
            assertionFailure("Missing SF Symbol: gearshape.fill")
        }
        glyph.color = GameUITheme.Color.textPrimary
        glyph.colorBlendFactor = 1
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
