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

        init(for tab: GameplayTab) {
            root = SKNode()
            panel = PanelNode(size: .zero)
            icon = GameplayTabBarNode.makeIcon(for: tab)
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
                icon.color = GameUITheme.Color.textPrimary
                icon.colorBlendFactor = 1
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
    private var hitFrames = [GameplayTab: CGRect]()

    private static func makeIcon(for tab: GameplayTab) -> SKNode {
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

        guard let image = UIImage(systemName: tab.symbolName) else {
            return SKNode()
        }
        return SKSpriteNode(texture: SKTexture(image: image))
    }

    override init() {
        tabBundles = Dictionary(uniqueKeysWithValues: GameplayTab.allCases.map { tab in
            (tab, TabBundle(for: tab))
        })
        super.init()
        name = "gameplayTabBar"
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
        let cellWidth = frame.width / CGFloat(GameplayTab.allCases.count)

        for (index, tab) in GameplayTab.allCases.enumerated() {
            let cellFrame = CGRect(
                x: frame.minX + cellWidth * CGFloat(index),
                y: frame.minY,
                width: cellWidth,
                height: frame.height
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

            bundle.panel.apply(
                size: cellFrame.size,
                style: style,
                showsRivets: false
            )
            bundle.panel.position = CGPoint(x: cellFrame.midX, y: cellFrame.midY)
            bundle.icon.position = CGPoint(x: cellFrame.midX, y: cellFrame.midY + 10)
            bundle.title.position = CGPoint(x: cellFrame.midX, y: cellFrame.midY - 16)
            bundle.attention.position = CGPoint(x: cellFrame.maxX - 18, y: cellFrame.maxY - 15)
            bundle.attention.isHidden = !(tab == .camp && content.showsCampAttention)

            let iconAlpha: CGFloat = content.enabledTabs.contains(tab) || tab == content.selected ? 1 : 0.4
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
}
#endif
