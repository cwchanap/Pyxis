import CoreGraphics
import SpriteKit

enum FeedbackSettingsAction: Equatable {
    case toggleSoundEffects
    case toggleHaptics
    case close
    case consumed
}

final class FeedbackSettingsNode: SKNode {
    private struct ToggleNodes {
        let background = SKShapeNode()
        let iconTile = SKShapeNode()
        let icon = SKShapeNode()
        let switchTrack = SKShapeNode()
        let switchKnob = SKShapeNode()
        let title = SKLabelNode(fontNamed: GameUITheme.Font.medium)
        let state = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    }

    private static let cornerRadius: CGFloat = 14
    private static let iconTileSize = CGSize(width: 40, height: 40)
    private static let switchSize = CGSize(width: 51, height: 31)
    private static let switchKnobSize = CGSize(width: 27, height: 27)

    private static let scrimColor = SKColor(red: 0.12, green: 0.055, blue: 0.018, alpha: 0.68)
    private static let sheetFillColor = SKColor(red: 0.075, green: 0.047, blue: 0.024, alpha: 0.98)
    private static let sheetStrokeColor = SKColor(red: 1.0, green: 0.81, blue: 0.55, alpha: 0.45)
    private static let iconTileColor = SKColor(red: 1.0, green: 0.75, blue: 0.43, alpha: 0.10)
    private static let dividerColor = SKColor(red: 0.78, green: 0.59, blue: 0.31, alpha: 0.24)
    private static let doneFillColor = SKColor(red: 0.14, green: 0.075, blue: 0.022, alpha: 1.0)
    private static let switchOffColor = SKColor(red: 0.23, green: 0.19, blue: 0.14, alpha: 1.0)
    private static let switchOnColor = GameUITheme.Color.hpFill
    private static let switchKnobColor = SKColor(white: 0.98, alpha: 1.0)

    /// Typed artwork discriminator for the toggle icons. Every supported
    /// artwork maps explicitly; unrelated SF Symbol strings can never fall
    /// through to the wrong drawing path.
    private enum IconKind {
        case soundEffects
        case haptics

        var accessibilitySymbolName: String {
            switch self {
            case .soundEffects: return "speaker.wave.2.fill"
            case .haptics: return "iphone.radiowaves.left.and.right"
            }
        }
    }

    private let scrim = SKShapeNode()
    private let panel = SKShapeNode()
    private let handle = SKShapeNode()
    private let divider = SKShapeNode()
    private let soundToggle = ToggleNodes()
    private let hapticsToggle = ToggleNodes()
    private let closeButton = SKShapeNode()
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
        renderHandle(layout.handleFrame)
        renderDivider(
            at: layout.hapticsRowFrame.maxY,
            width: layout.hapticsRowFrame.width,
            x: layout.hapticsRowFrame.minX
        )
        renderToggle(
            soundToggle,
            frame: layout.soundRowFrame,
            text: "Sound Effects",
            iconKind: .soundEffects,
            isEnabled: preferences.soundEffectsEnabled
        )
        renderToggle(
            hapticsToggle,
            frame: layout.hapticsRowFrame,
            text: "Haptics",
            iconKind: .haptics,
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
        name = "feedbackSettingsModal"

        scrim.name = "feedbackSettingsScrim"
        scrim.fillColor = Self.scrimColor
        scrim.strokeColor = .clear
        scrim.lineWidth = 0
        scrim.zPosition = 0
        addChild(scrim)

        panel.name = "feedbackSettingsPanel"
        panel.fillColor = Self.sheetFillColor
        panel.strokeColor = Self.sheetStrokeColor
        panel.lineWidth = 1.5
        panel.glowWidth = 8
        panel.zPosition = 1
        addChild(panel)

        handle.name = "feedbackSettingsHandle"
        handle.fillColor = Self.sheetStrokeColor
        handle.strokeColor = .clear
        handle.lineWidth = 0
        handle.zPosition = 2
        addChild(handle)

        divider.name = "feedbackSettingsDivider"
        divider.fillColor = Self.dividerColor
        divider.strokeColor = .clear
        divider.lineWidth = 0
        divider.zPosition = 2
        addChild(divider)

        configureRow(soundToggle.background, name: "feedbackSettingsSoundRow")
        configureRow(hapticsToggle.background, name: "feedbackSettingsHapticsRow")
        configureIconTile(soundToggle.iconTile, name: "feedbackSettingsSoundIconTile")
        configureIconTile(hapticsToggle.iconTile, name: "feedbackSettingsHapticsIconTile")
        configureIcon(soundToggle.icon, name: "feedbackSettingsSoundIcon")
        configureIcon(hapticsToggle.icon, name: "feedbackSettingsHapticsIcon")
        configureSwitchTrack(soundToggle.switchTrack, name: "feedbackSettingsSoundSwitch")
        configureSwitchTrack(hapticsToggle.switchTrack, name: "feedbackSettingsHapticsSwitch")
        configureSwitchKnob(soundToggle.switchKnob, name: "feedbackSettingsSoundSwitchKnob")
        configureSwitchKnob(hapticsToggle.switchKnob, name: "feedbackSettingsHapticsSwitchKnob")

        configureLabel(soundToggle.title, alignment: .left)
        configureLabel(hapticsToggle.title, alignment: .left)
        configureLabel(soundToggle.state, alignment: .right)
        configureLabel(hapticsToggle.state, alignment: .right)
        soundToggle.state.isHidden = true
        hapticsToggle.state.isHidden = true

        closeButton.name = "feedbackSettingsClose"
        closeButton.fillColor = Self.doneFillColor
        closeButton.strokeColor = Self.sheetStrokeColor
        closeButton.lineWidth = 1.5
        closeButton.zPosition = 2
        addChild(closeButton)

        configureLabel(closeLabel, alignment: .center)
        closeLabel.fontColor = GameUITheme.Color.textPrimary

        isHidden = true
    }

    private func configureRow(_ row: SKShapeNode, name: String) {
        row.name = name
        row.fillColor = .clear
        row.strokeColor = .clear
        row.lineWidth = 0
        row.zPosition = 2
        addChild(row)
    }

    private func configureIconTile(_ tile: SKShapeNode, name: String) {
        tile.name = name
        tile.fillColor = Self.iconTileColor
        tile.strokeColor = .clear
        tile.lineWidth = 0
        tile.zPosition = 3
        addChild(tile)
    }

    private func configureIcon(_ icon: SKShapeNode, name: String) {
        icon.name = name
        icon.fillColor = GameUITheme.Color.textPrimary
        icon.strokeColor = GameUITheme.Color.textPrimary
        icon.lineWidth = 2
        icon.lineCap = .round
        icon.lineJoin = .round
        icon.zPosition = 4
        addChild(icon)
    }

    private func configureSwitchTrack(_ track: SKShapeNode, name: String) {
        track.name = name
        track.fillColor = Self.switchOffColor
        track.strokeColor = .clear
        track.lineWidth = 0
        track.zPosition = 3
        addChild(track)
    }

    private func configureSwitchKnob(_ knob: SKShapeNode, name: String) {
        knob.name = name
        knob.fillColor = Self.switchKnobColor
        knob.strokeColor = .clear
        knob.lineWidth = 0
        knob.zPosition = 4
        addChild(knob)
    }

    private func configureLabel(
        _ label: SKLabelNode,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        label.fontColor = GameUITheme.Color.textPrimary
        label.fontSize = 16
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.zPosition = 4
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

    private func renderHandle(_ frame: CGRect) {
        handle.path = CGPath(
            roundedRect: frame,
            cornerWidth: frame.height / 2,
            cornerHeight: frame.height / 2,
            transform: nil
        )
    }

    private func renderDivider(at y: CGFloat, width: CGFloat, x: CGFloat) {
        divider.path = CGPath(
            rect: CGRect(x: x, y: y, width: width, height: 1),
            transform: nil
        )
    }

    private func renderToggle(
        _ toggle: ToggleNodes,
        frame: CGRect,
        text: String,
        iconKind: IconKind,
        isEnabled: Bool
    ) {
        toggle.background.path = CGPath(rect: frame, transform: nil)

        let iconTileFrame = CGRect(
            x: frame.minX,
            y: frame.midY - Self.iconTileSize.height / 2,
            width: Self.iconTileSize.width,
            height: Self.iconTileSize.height
        )
        toggle.iconTile.path = CGPath(
            roundedRect: iconTileFrame,
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )
        renderIcon(
            toggle.icon,
            kind: iconKind,
            center: CGPoint(x: iconTileFrame.midX, y: iconTileFrame.midY)
        )

        toggle.title.text = text
        toggle.title.position = CGPoint(x: iconTileFrame.maxX + 13, y: frame.midY)

        let switchFrame = CGRect(
            x: frame.maxX - Self.switchSize.width,
            y: frame.midY - Self.switchSize.height / 2,
            width: Self.switchSize.width,
            height: Self.switchSize.height
        )
        toggle.switchTrack.path = CGPath(
            roundedRect: switchFrame,
            cornerWidth: switchFrame.height / 2,
            cornerHeight: switchFrame.height / 2,
            transform: nil
        )
        toggle.switchTrack.fillColor = isEnabled ? Self.switchOnColor : Self.switchOffColor

        let knobFrame = CGRect(
            x: isEnabled
                ? switchFrame.maxX - Self.switchKnobSize.width - 2
                : switchFrame.minX + 2,
            y: switchFrame.midY - Self.switchKnobSize.height / 2,
            width: Self.switchKnobSize.width,
            height: Self.switchKnobSize.height
        )
        toggle.switchKnob.path = CGPath(
            roundedRect: knobFrame,
            cornerWidth: knobFrame.height / 2,
            cornerHeight: knobFrame.height / 2,
            transform: nil
        )

        toggle.state.text = isEnabled ? "On" : "Off"
        toggle.state.fontColor = isEnabled ? GameUITheme.Color.hpFill : GameUITheme.Color.textSecondary
    }

    private func renderIcon(_ icon: SKShapeNode, kind: IconKind, center: CGPoint) {
        let path = CGMutablePath()
        if kind == .soundEffects {
            path.move(to: CGPoint(x: center.x - 8, y: center.y - 4))
            path.addLine(to: CGPoint(x: center.x - 3, y: center.y - 4))
            path.addLine(to: CGPoint(x: center.x + 3, y: center.y - 9))
            path.addLine(to: CGPoint(x: center.x + 3, y: center.y + 9))
            path.addLine(to: CGPoint(x: center.x - 3, y: center.y + 4))
            path.addLine(to: CGPoint(x: center.x - 8, y: center.y + 4))
            path.closeSubpath()
            path.addArc(
                center: CGPoint(x: center.x + 1, y: center.y),
                radius: 7,
                startAngle: -0.7,
                endAngle: 0.7,
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: center.x + 1, y: center.y),
                radius: 11,
                startAngle: -0.7,
                endAngle: 0.7,
                clockwise: false
            )
        } else {
            path.addRoundedRect(
                in: CGRect(x: center.x - 4, y: center.y - 9, width: 8, height: 18),
                cornerWidth: 2,
                cornerHeight: 2
            )
            path.move(to: CGPoint(x: center.x - 9, y: center.y - 5))
            path.addCurve(
                to: CGPoint(x: center.x - 9, y: center.y + 5),
                control1: CGPoint(x: center.x - 13, y: center.y - 3),
                control2: CGPoint(x: center.x - 13, y: center.y + 3)
            )
            path.move(to: CGPoint(x: center.x + 9, y: center.y - 5))
            path.addCurve(
                to: CGPoint(x: center.x + 9, y: center.y + 5),
                control1: CGPoint(x: center.x + 13, y: center.y - 3),
                control2: CGPoint(x: center.x + 13, y: center.y + 3)
            )
        }
        icon.path = path
    }

    private func renderClose(_ frame: CGRect) {
        closeButton.path = CGPath(
            roundedRect: frame,
            cornerWidth: Self.cornerRadius,
            cornerHeight: Self.cornerRadius,
            transform: nil
        )
        closeLabel.text = "Done"
        closeLabel.position = CGPoint(x: frame.midX, y: frame.midY)
    }
}

#if DEBUG
extension FeedbackSettingsNode {
    var soundEffectsLabelForTesting: String? { soundToggle.title.text }
    var hapticsLabelForTesting: String? { hapticsToggle.title.text }
    var closeLabelForTesting: String? { closeLabel.text }
    var soundEffectsStateForTesting: String? { soundToggle.state.text }
    var hapticsStateForTesting: String? { hapticsToggle.state.text }
    var soundRowHitFrameForTesting: CGRect? { soundRowHitFrame }
    var hapticsRowHitFrameForTesting: CGRect? { hapticsRowHitFrame }
    var closeHitFrameForTesting: CGRect? { closeHitFrame }
    var iconSymbolNamesForTesting: [String] {
        [IconKind.soundEffects.accessibilitySymbolName, IconKind.haptics.accessibilitySymbolName]
    }
    var visibleToggleRowNamesForTesting: [String] {
        [soundToggle.background.name, hapticsToggle.background.name].compactMap { $0 }
    }
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
