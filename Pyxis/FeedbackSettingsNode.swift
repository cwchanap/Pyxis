import CoreGraphics
import SpriteKit

enum FeedbackSettingsAction: Equatable {
    case toggleSoundEffects
    case toggleHaptics
    case close
    case consumed
}

final class FeedbackSettingsNode: SKNode {
    private static let cornerRadius: CGFloat = 14

    private let scrim = SKShapeNode()
    private let panel = SKShapeNode()
    private let soundRow = SKShapeNode()
    private let hapticsRow = SKShapeNode()
    private let closeButton = SKShapeNode()
    private let soundEffectsLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let hapticsLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let soundEffectsStateLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let hapticsStateLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let closeLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)

    private var soundRowHitFrame: CGRect?
    private var hapticsRowHitFrame: CGRect?
    private var closeHitFrame: CGRect?

    override init() {
        super.init()
        configureTree()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(layout: FeedbackSettingsLayout, preferences: FeedbackPreferences) {
        renderScrim(layout.scrimFrame)
        renderPanel(layout.panelFrame)
        renderToggle(
            background: soundRow,
            title: soundEffectsLabel,
            state: soundEffectsStateLabel,
            frame: layout.soundRowFrame,
            text: "Sound Effects",
            isEnabled: preferences.soundEffectsEnabled
        )
        renderToggle(
            background: hapticsRow,
            title: hapticsLabel,
            state: hapticsStateLabel,
            frame: layout.hapticsRowFrame,
            text: "Haptics",
            isEnabled: preferences.hapticsEnabled
        )
        renderClose(layout.closeFrame)

        soundRowHitFrame = layout.soundRowFrame
        hapticsRowHitFrame = layout.hapticsRowFrame
        closeHitFrame = layout.closeFrame
        isHidden = false
    }

    func action(at scenePoint: CGPoint) -> FeedbackSettingsAction {
        if soundRowHitFrame?.contains(scenePoint) == true {
            return .toggleSoundEffects
        }
        if hapticsRowHitFrame?.contains(scenePoint) == true {
            return .toggleHaptics
        }
        if closeHitFrame?.contains(scenePoint) == true {
            return .close
        }
        return .consumed
    }

    private func configureTree() {
        zPosition = GameUITheme.Z.modal - 10

        scrim.fillColor = SKColor(white: 0, alpha: 0.58)
        scrim.strokeColor = .clear
        scrim.lineWidth = 0
        scrim.zPosition = 0
        addChild(scrim)

        panel.fillColor = GameUITheme.Color.panelFill
        panel.strokeColor = GameUITheme.Color.panelStroke
        panel.lineWidth = 1.5
        panel.zPosition = 1
        addChild(panel)

        configureRow(soundRow)
        configureRow(hapticsRow)
        configureLabel(soundEffectsLabel, alignment: .left)
        configureLabel(hapticsLabel, alignment: .left)
        configureLabel(soundEffectsStateLabel, alignment: .right)
        configureLabel(hapticsStateLabel, alignment: .right)

        closeButton.fillColor = GameUITheme.Color.spawn
        closeButton.strokeColor = GameUITheme.Color.panelStroke
        closeButton.lineWidth = 1.5
        closeButton.zPosition = 2
        addChild(closeButton)

        configureLabel(closeLabel, alignment: .center)
        closeLabel.fontColor = GameUITheme.Color.textPrimary

        isHidden = true
    }

    private func configureRow(_ row: SKShapeNode) {
        row.fillColor = GameUITheme.Color.hpBackground
        row.strokeColor = GameUITheme.Color.panelStroke
        row.lineWidth = 1
        row.zPosition = 2
        addChild(row)
    }

    private func configureLabel(
        _ label: SKLabelNode,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        label.fontColor = GameUITheme.Color.textPrimary
        label.fontSize = 15
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.zPosition = 3
        addChild(label)
    }

    private func renderScrim(_ frame: CGRect) {
        scrim.path = CGPath(rect: frame, transform: nil)
    }

    private func renderPanel(_ frame: CGRect) {
        panel.path = CGPath(
            roundedRect: frame,
            cornerWidth: Self.cornerRadius,
            cornerHeight: Self.cornerRadius,
            transform: nil
        )
    }

    private func renderToggle(
        background: SKShapeNode,
        title: SKLabelNode,
        state: SKLabelNode,
        frame: CGRect,
        text: String,
        isEnabled: Bool
    ) {
        background.path = CGPath(
            roundedRect: frame,
            cornerWidth: Self.cornerRadius,
            cornerHeight: Self.cornerRadius,
            transform: nil
        )
        title.text = text
        title.position = CGPoint(x: frame.minX + 12, y: frame.midY)
        state.text = isEnabled ? "On" : "Off"
        state.fontColor = isEnabled ? GameUITheme.Color.hpFill : GameUITheme.Color.textSecondary
        state.position = CGPoint(x: frame.maxX - 12, y: frame.midY)
    }

    private func renderClose(_ frame: CGRect) {
        closeButton.path = CGPath(
            roundedRect: frame,
            cornerWidth: Self.cornerRadius,
            cornerHeight: Self.cornerRadius,
            transform: nil
        )
        closeLabel.text = "Close"
        closeLabel.position = CGPoint(x: frame.midX, y: frame.midY)
    }
}

#if DEBUG
extension FeedbackSettingsNode {
    var soundEffectsLabelForTesting: String? { soundEffectsLabel.text }
    var hapticsLabelForTesting: String? { hapticsLabel.text }
    var closeLabelForTesting: String? { closeLabel.text }
    var soundEffectsStateForTesting: String? { soundEffectsStateLabel.text }
    var hapticsStateForTesting: String? { hapticsStateLabel.text }
    var soundRowHitFrameForTesting: CGRect? { soundRowHitFrame }
    var hapticsRowHitFrameForTesting: CGRect? { hapticsRowHitFrame }
    var closeHitFrameForTesting: CGRect? { closeHitFrame }
    var toggleControlCountForTesting: Int { 2 }
    var controlCountForTesting: Int { 3 }
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
