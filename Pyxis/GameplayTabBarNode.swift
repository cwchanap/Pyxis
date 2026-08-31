//
//  GameplayTabBarNode.swift
//  Pyxis
//

import CoreGraphics
import SpriteKit
import UIKit

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

            if let icon = icon as? SKSpriteNode {
                if appearance == .standard {
                    icon.color = GameUITheme.Color.textPrimary
                    icon.colorBlendFactor = 1
                }
                icon.size = CGSize(width: 20, height: 20)
            }

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
    private var hitFrames = [GameplayTab: CGRect]()

    private static func makeIcon(for tab: GameplayTab, appearance: Appearance) -> SKNode {
        if tab == .battle {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -7, y: -7))
            path.addLine(to: CGPoint(x: 7, y: 7))
            path.move(to: CGPoint(x: -4, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -4))
            path.move(to: CGPoint(x: 7, y: -7))
            path.addLine(to: CGPoint(x: -7, y: 7))
            path.move(to: CGPoint(x: 4, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -4))

            let glyph = SKShapeNode(path: path)
            glyph.name = "gameplayTabGlyph-battle"
            glyph.strokeColor = GameUITheme.Color.textPrimary
            glyph.fillColor = .clear
            glyph.lineWidth = 2
            glyph.lineCap = .round
            glyph.lineJoin = .round
            return glyph
        }

        let image: UIImage?
        switch appearance {
        case .standard:
            image = UIImage(systemName: tab.symbolName)
        case .forged:
            image = gameUISymbolImage(
                named: tab.symbolName,
                color: SKColor(red: 1, green: 232 / 255, blue: 196 / 255, alpha: 1)
            )
        }
        guard let image else { return SKNode() }
        return SKSpriteNode(texture: SKTexture(image: image))
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
            forgedBackdrop.fillColor = SKColor(
                red: 16 / 255,
                green: 9 / 255,
                blue: 3 / 255,
                alpha: 0.98
            )
            forgedBackdrop.strokeColor = SKColor(
                red: 255 / 255,
                green: 206 / 255,
                blue: 140 / 255,
                alpha: 0.34
            )
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
                appearance: appearance == .forged ? .forged : .standard
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
            let iconAlpha: CGFloat = content.enabledTabs.contains(tab) || tab == content.selected
                ? 1
                : (appearance == .forged ? 0.45 : 0.4)
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

    var symbolName: String {
        switch self {
        case .battle: return "crossed.swords"
        case .camp: return "house.fill"
        case .map: return "map.fill"
        }
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

    func iconColorBlendFactorForTesting(for tab: GameplayTab) -> CGFloat? {
        (tabBundles[tab]?.icon as? SKSpriteNode)?.colorBlendFactor
    }
}
#endif
