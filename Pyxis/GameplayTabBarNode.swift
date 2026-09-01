//
//  GameplayTabBarNode.swift
//  Pyxis
//

import CoreGraphics
import SpriteKit

enum GameplayTab: CaseIterable, Hashable {
    case battle
    case camp
    case map
}

final class GameplayTabBarNode: SKNode {
    enum Appearance {
        case standard
        case forged
    }

    struct Content: Equatable {
        let selected: GameplayTab
        let enabledTabs: Set<GameplayTab>
        let showsCampAttention: Bool
    }

    private struct TabBundle {
        let root: SKNode
        let panel: PanelNode
        let icon: SKNode
        let title: SKLabelNode
        let attention: SKShapeNode

        init(for tab: GameplayTab, appearance: Appearance) {
            root = SKNode()
            panel = PanelNode(size: .zero)
            icon = GameplayTabBarNode.makeIcon(for: tab, appearance: appearance)
            title = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            attention = SKShapeNode(circleOfRadius: 4)

            root.name = "gameplayTab-\(tab.name)"
            panel.name = "gameplayTabPanel-\(tab.name)"
            icon.name = "gameplayTabIcon-\(tab.name)"
            title.name = "gameplayTabTitle-\(tab.name)"
            attention.name = "gameplayTabAttention-\(tab.name)"

            panel.zPosition = 0
            icon.zPosition = 1
            title.zPosition = 1
            attention.zPosition = 2

            title.text = tab.title
            title.fontSize = 11
            title.fontColor = GameUITheme.Color.textPrimary
            title.horizontalAlignmentMode = .center
            title.verticalAlignmentMode = .center

            attention.fillColor = GameUITheme.Color.gold
            attention.strokeColor = .clear
            attention.isHidden = true

            root.addChild(panel)
            root.addChild(icon)
            root.addChild(title)
            root.addChild(attention)
        }
    }

    private let tabBundles: [GameplayTab: TabBundle]
    private let appearance: Appearance
    private let forgedBackdrop = SKShapeNode()
    private static let forgedBackdropTexture = PanelNode.gradientTexture(
        top: SKColor(red: 34 / 255, green: 20 / 255, blue: 8 / 255, alpha: 0.60),
        bottom: SKColor(red: 16 / 255, green: 9 / 255, blue: 3 / 255, alpha: 0.98)
    )
    private var hitFrames = [GameplayTab: CGRect]()

    private static func makeIcon(for tab: GameplayTab, appearance: Appearance) -> SKNode {
        let path: CGPath
        switch tab {
        case .battle:
            let battlePath = CGMutablePath()
            battlePath.move(to: CGPoint(x: -8, y: 8))
            battlePath.addLine(to: CGPoint(x: -1, y: 1))
            battlePath.move(to: CGPoint(x: -6, y: -8))
            battlePath.addLine(to: CGPoint(x: 6, y: 4))
            battlePath.move(to: CGPoint(x: 6, y: -8))
            battlePath.addLine(to: CGPoint(x: -6, y: 4))
            battlePath.move(to: CGPoint(x: 2, y: -8))
            battlePath.addLine(to: CGPoint(x: 8, y: -8))
            battlePath.addLine(to: CGPoint(x: 8, y: -2))
            path = battlePath
        case .camp:
            let campPath = CGMutablePath()
            campPath.move(to: CGPoint(x: -9, y: 8))
            campPath.addLine(to: CGPoint(x: 9, y: 8))
            campPath.move(to: CGPoint(x: -7, y: 8))
            campPath.addLine(to: CGPoint(x: -7, y: -1))
            campPath.addLine(to: CGPoint(x: 0, y: -6))
            campPath.addLine(to: CGPoint(x: 7, y: -1))
            campPath.addLine(to: CGPoint(x: 7, y: 8))
            campPath.move(to: CGPoint(x: -2, y: 8))
            campPath.addLine(to: CGPoint(x: -2, y: 3))
            campPath.addLine(to: CGPoint(x: 2, y: 3))
            campPath.addLine(to: CGPoint(x: 2, y: 8))
            path = campPath
        case .map:
            let mapPath = CGMutablePath()
            mapPath.move(to: CGPoint(x: -3, y: -8))
            mapPath.addLine(to: CGPoint(x: -9, y: -6))
            mapPath.addLine(to: CGPoint(x: -9, y: 8))
            mapPath.addLine(to: CGPoint(x: -3, y: 6))
            mapPath.addLine(to: CGPoint(x: 3, y: 8))
            mapPath.addLine(to: CGPoint(x: 9, y: 6))
            mapPath.addLine(to: CGPoint(x: 9, y: -8))
            mapPath.addLine(to: CGPoint(x: 3, y: -6))
            mapPath.addLine(to: CGPoint(x: -3, y: -8))
            mapPath.closeSubpath()
            mapPath.move(to: CGPoint(x: -3, y: -8))
            mapPath.addLine(to: CGPoint(x: -3, y: 6))
            mapPath.move(to: CGPoint(x: 3, y: -6))
            mapPath.addLine(to: CGPoint(x: 3, y: 8))
            path = mapPath
        }

        let iconPath: CGPath
        if appearance == .standard {
            let size: CGSize
            switch tab {
            case .battle: size = CGSize(width: 14, height: 14)
            case .camp, .map: size = CGSize(width: 25, height: 25)
            }
            let bounds = path.boundingBox
            var transform = CGAffineTransform(
                scaleX: size.width / bounds.width,
                y: size.height / bounds.height
            )
            iconPath = path.copy(using: &transform) ?? path
        } else {
            iconPath = path
        }

        let glyph = SKShapeNode(path: iconPath)
        glyph.name = "gameplayTabGlyph-\(tab.name)"
        glyph.strokeColor = appearance == .forged
            ? SKColor(red: 1, green: 232 / 255, blue: 196 / 255, alpha: 1)
            : GameUITheme.Color.textPrimary
        glyph.fillColor = .clear
        glyph.lineWidth = tab == .battle ? 2 : 1.8
        glyph.lineCap = .round
        glyph.lineJoin = .round
        return glyph
    }

    init(appearance: Appearance = .standard) {
        self.appearance = appearance
        tabBundles = Dictionary(uniqueKeysWithValues: GameplayTab.allCases.map { tab in
            (tab, TabBundle(for: tab, appearance: appearance))
        })
        super.init()
        name = "gameplayTabBar"
        forgedBackdrop.name = "gameplayTabForgedBackdrop"
        forgedBackdrop.zPosition = -1
        forgedBackdrop.lineWidth = 1.5
        forgedBackdrop.isHidden = appearance == .standard
        addChild(forgedBackdrop)
        for tab in GameplayTab.allCases {
            addChild(tabBundles[tab]!.root)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next cyclomatic_complexity
    func apply(content: Content, frame: CGRect) {
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.width.isFinite,
              frame.height.isFinite,
              frame.width > 0,
              frame.height > 0 else {
            hitFrames.removeAll()
            isHidden = true
            return
        }

        isHidden = false
        hitFrames.removeAll(keepingCapacity: true)
        let visualFrame: CGRect
        if appearance == .forged, frame.minX >= BattleChromeLayout.sideMargin {
            visualFrame = frame.insetBy(dx: -BattleChromeLayout.sideMargin, dy: 0)
        } else {
            visualFrame = frame
        }
        let cellWidth = visualFrame.width / CGFloat(GameplayTab.allCases.count)
        if appearance == .forged {
            forgedBackdrop.path = CGPath(
                roundedRect: visualFrame,
                cornerWidth: 10,
                cornerHeight: 10,
                transform: nil
            )
            forgedBackdrop.fillColor = .white
            forgedBackdrop.fillTexture = Self.forgedBackdropTexture
            forgedBackdrop.strokeColor = .clear
        }

        for (index, tab) in GameplayTab.allCases.enumerated() {
            let cellFrame = CGRect(
                x: visualFrame.minX + cellWidth * CGFloat(index),
                y: visualFrame.minY,
                width: cellWidth,
                height: visualFrame.height
            )
            let bundle = tabBundles[tab]!
            let style: PanelNode.Style
            if tab == content.selected {
                style = .selected
            } else if content.enabledTabs.contains(tab) {
                style = .normal
            } else {
                style = .disabled
            }

            let panelSize: CGSize
            if appearance == .forged {
                panelSize = CGSize(
                    width: min(96, max(44, cellFrame.width - 8)),
                    height: min(52, max(44, cellFrame.height - 8))
                )
            } else {
                panelSize = cellFrame.size
            }
            let tileCenterY = appearance == .forged
                ? cellFrame.midY + 11
                : cellFrame.midY
            bundle.panel.apply(
                size: panelSize,
                style: style,
                showsRivets: false,
                appearance: appearance == .forged ? .forged : .standard,
                forgedTreatment: appearance == .forged && tab == content.selected
                    ? .selectedTab
                    : .standard
            )
            bundle.panel.alpha = appearance == .forged && tab != content.selected ? 0 : 1
            bundle.panel.position = CGPoint(x: cellFrame.midX, y: tileCenterY)
            bundle.icon.position = CGPoint(x: cellFrame.midX, y: tileCenterY + 10)
            bundle.title.position = CGPoint(x: cellFrame.midX, y: tileCenterY - 16)
            bundle.attention.position = CGPoint(x: cellFrame.maxX - 18, y: cellFrame.maxY - 15)
            bundle.attention.isHidden = !(tab == .camp && content.showsCampAttention)

            if appearance == .forged {
                let color = tab == content.selected
                    ? SKColor(red: 1, green: 232 / 255, blue: 196 / 255, alpha: 1)
                    : SKColor(red: 1, green: 225 / 255, blue: 180 / 255, alpha: 1)
                if let shape = bundle.icon as? SKShapeNode {
                    shape.strokeColor = color
                }
                bundle.title.fontColor = color
            }
            let iconAlpha: CGFloat
            if appearance == .forged {
                iconAlpha = tab == content.selected ? 1 : 0.45
            } else {
                iconAlpha = content.enabledTabs.contains(tab) || tab == content.selected ? 1 : 0.4
            }
            bundle.icon.alpha = iconAlpha
            bundle.title.alpha = iconAlpha

            guard content.enabledTabs.contains(tab) else {
                continue
            }
            let hitWidth = max(44, cellFrame.width - 8)
            let hitHeight = max(44, cellFrame.height - 8)
            hitFrames[tab] = CGRect(
                x: cellFrame.midX - hitWidth / 2,
                y: cellFrame.midY - hitHeight / 2,
                width: hitWidth,
                height: hitHeight
            )
        }
    }

    func apply(content: Content, frame: CGRect, hitFrames authoritativeHitFrames: [CGRect]) {
        apply(content: content, frame: frame)
        guard authoritativeHitFrames.count == GameplayTab.allCases.count else {
            return
        }

        for (index, tab) in GameplayTab.allCases.enumerated()
        where content.enabledTabs.contains(tab) {
            hitFrames[tab] = authoritativeHitFrames[index]
        }
    }

    func tab(at point: CGPoint) -> GameplayTab? {
        guard !isHidden else {
            return nil
        }
        return GameplayTab.allCases.first { hitFrames[$0]?.contains(point) == true }
    }
}

private extension GameplayTab {
    var name: String {
        switch self {
        case .battle: return "battle"
        case .camp: return "camp"
        case .map: return "map"
        }
    }

    var title: String {
        name.uppercased()
    }

}

#if DEBUG
extension GameplayTabBarNode {
    var visualCellCountForTesting: Int {
        tabBundles.values.filter { !$0.root.isHidden }.count
    }

    func iconIsVectorGlyphForTesting(for tab: GameplayTab) -> Bool {
        guard let icon = tabBundles[tab]?.icon as? SKShapeNode else {
            return false
        }
        return icon.path != nil
    }

    func hitFrameForTesting(for tab: GameplayTab) -> CGRect? {
        hitFrames[tab]
    }

    func iconSizeForTesting(for tab: GameplayTab) -> CGSize {
        (tabBundles[tab]?.icon as? SKShapeNode)?.path?.boundingBox.size ?? .zero
    }

}
#endif
