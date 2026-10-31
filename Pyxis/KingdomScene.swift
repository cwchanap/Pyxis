//
//  KingdomScene.swift
//  Pyxis
//

import SpriteKit

protocol KingdomSceneRouting: AnyObject {
    /// Requests a switch to another gameplay tab; returns false when declined.
    @discardableResult
    func kingdomSceneDidRequestGameplayTab(_ scene: KingdomScene, tab: GameplayTab) -> Bool
}

/// HPA-670 Kingdom shell: persisted title and gold, sufficient for the
/// controller's four-tab routing tests. Task 4 expands this scene into the
/// full Treasury layout; every exit still routes through the controller's
/// pending-first gate.
final class KingdomScene: SKScene {
    private let store: KingdomGameStore
    private weak var router: (any KingdomSceneRouting)?

    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let goldLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)

    init(size: CGSize, store: KingdomGameStore, router: (any KingdomSceneRouting)?) {
        self.store = store
        self.router = router
        super.init(size: size)
        backgroundColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1.0)

        titleLabel.name = "kingdomTitleLabel"
        titleLabel.text = "Kingdom"
        titleLabel.fontSize = 28
        titleLabel.fontColor = GameUITheme.Color.textPrimary
        addChild(titleLabel)

        goldLabel.name = "kingdomGoldLabel"
        goldLabel.fontSize = 18
        goldLabel.fontColor = GameUITheme.Color.gold
        addChild(goldLabel)
    }

    required init?(coder: NSCoder) {
        self.store = .shared
        self.router = nil
        super.init(coder: coder)
    }

    override func didMove(to view: SKView) {
        goldLabel.text = "Gold " + CompactNumberFormatter.string(from: store.load().gold)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        goldLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72 - 40)
    }
}

#if DEBUG
extension KingdomScene {
    var titleTextForTesting: String? { titleLabel.text }

    var goldTextForTesting: String? { goldLabel.text }

    func requestGameplayTabForTesting(_ tab: GameplayTab) {
        router?.kingdomSceneDidRequestGameplayTab(self, tab: tab)
    }
}
#endif
