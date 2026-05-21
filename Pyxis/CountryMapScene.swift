//
//  CountryMapScene.swift
//  Pyxis
//

import Foundation
import SpriteKit
import UIKit

protocol CountryMapSceneRouting: AnyObject {
    func countryMapSceneDidRequestBattle(_ scene: CountryMapScene)
}

enum CountryMapCityVisualState: Equatable {
    case completed
    case unlocked
    case locked
}

#if DEBUG
struct CountryMapLayoutFrames {
    let sceneFrame: CGRect
    let titlePanelFrame: CGRect
    let illustratedRegionFrame: CGRect
    let feedbackPanelFrame: CGRect
}
#endif

final class CountryMapScene: SKScene {
    private enum NodeName {
        static let cityPrefix = "countryMapCity-"
    }

    private enum MapAssetName {
        static let countryMapBackdrop = "country-map-backdrop"
        static let conqueredMarker = "conquered-marker"
    }

    private enum ActionKey {
        static let unlockedPulse = "countryMapUnlockedPulse"
    }

    private let store: KingdomGameStore
    private weak var router: CountryMapSceneRouting?
    private var state: KingdomGameState
    private var didBuildInterface = false

    private let backdropLayer = SKNode()
    private let routeLayer = SKNode()
    private let cityLayer = SKNode()
    private let titlePanel = PanelNode(size: CGSize(width: 320, height: 68))
    private let feedbackPanel = PanelNode(size: CGSize(width: 320, height: 56))
    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let feedbackLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private var backdropNode: SKSpriteNode?
    private var cityNodes: [Int: SKShapeNode] = [:]
    private var cityLabels: [Int: SKLabelNode] = [:]
    private var conqueredMarkers: [Int: SKSpriteNode] = [:]
    private var cityVisualStates: [Int: CountryMapCityVisualState] = [:]
    private var cityBaseScales: [Int: CGFloat] = [:]
    private var layoutFrames = (
        scene: CGRect.zero,
        titlePanel: CGRect.zero,
        illustratedRegion: CGRect.zero,
        feedbackPanel: CGRect.zero
    )
    private var feedbackText = "Select the unlocked city."

    init(size: CGSize, store: KingdomGameStore = .shared, router: CountryMapSceneRouting? = nil) {
        self.store = store
        self.router = router
        self.state = store.load()
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.store = .shared
        self.router = nil
        self.state = KingdomGameStore.shared.load()
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.12, blue: 0.14, alpha: 1.0)
        state = store.load()
        feedbackText = defaultFeedbackText(for: state)

        if !didBuildInterface {
            buildInterface()
            didBuildInterface = true
        }

        layoutInterface()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutInterface()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }

        guard let cityNumber = cityNumber(at: touch.location(in: self)) else {
            return
        }

        enterCity(cityNumber)
    }

    private func buildInterface() {
        backdropLayer.zPosition = -20
        routeLayer.zPosition = 0
        cityLayer.zPosition = 10
        titlePanel.zPosition = GameUITheme.Z.hud
        feedbackPanel.zPosition = GameUITheme.Z.hud
        addChild(backdropLayer)
        addChild(routeLayer)
        addChild(cityLayer)
        addChild(titlePanel)
        addChild(feedbackPanel)

        if UIImage(named: MapAssetName.countryMapBackdrop) != nil {
            let backdrop = SKSpriteNode(imageNamed: MapAssetName.countryMapBackdrop)
            backdrop.name = MapAssetName.countryMapBackdrop
            backdrop.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            backdrop.zPosition = 0
            backdropLayer.addChild(backdrop)
            backdropNode = backdrop
        }

        configureLabel(titleLabel, fontSize: 30, color: GameUITheme.Color.textPrimary)
        configureLabel(feedbackLabel, fontSize: 16, color: GameUITheme.Color.gold)
        titlePanel.addChild(titleLabel)
        feedbackPanel.addChild(feedbackLabel)

        let hasConqueredMarkerAsset = UIImage(named: MapAssetName.conqueredMarker) != nil

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let cityNode = SKShapeNode(circleOfRadius: 18)
            cityNode.name = "\(NodeName.cityPrefix)\(cityNumber)"
            cityNode.lineWidth = 3
            cityLayer.addChild(cityNode)
            cityNodes[cityNumber] = cityNode

            let cityLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            configureLabel(cityLabel, fontSize: 13, color: .white)
            cityLabel.text = "\(cityNumber)"
            cityLabel.name = cityNode.name
            cityLayer.addChild(cityLabel)
            cityLabels[cityNumber] = cityLabel

            if hasConqueredMarkerAsset {
                let marker = SKSpriteNode(imageNamed: MapAssetName.conqueredMarker)
                marker.name = cityNode.name
                marker.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                marker.zPosition = 2
                marker.isHidden = true
                cityLayer.addChild(marker)
                conqueredMarkers[cityNumber] = marker
            }
        }
    }

    private func configureLabel(_ label: SKLabelNode, fontSize: CGFloat, color: SKColor) {
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
    }

    private func layoutInterface() {
        guard didBuildInterface else {
            return
        }

        let isCompactHeight = size.height < 500
        let horizontalMargin: CGFloat = isCompactHeight ? 14 : 20
        let topInset = max(
            isCompactHeight ? 10 : 42,
            GameUITheme.topUnsafeInset(sceneSize: size, view: view) + (isCompactHeight ? 8 : 10)
        )
        let bottomInset = max(
            isCompactHeight ? 10 : 24,
            GameUITheme.bottomUnsafeInset(sceneSize: size, view: view) + (isCompactHeight ? 8 : 12)
        )
        let nodeRadius: CGFloat = isCompactHeight ? 8 : 15
        let labelFontSize: CGFloat = isCompactHeight ? 9 : 12
        let panelWidth = max(220, min(size.width - horizontalMargin * 2, 520))
        let titlePanelSize = CGSize(width: panelWidth, height: isCompactHeight ? 46 : 66)
        let feedbackPanelSize = CGSize(width: panelWidth, height: isCompactHeight ? 42 : 56)

        titlePanel.update(size: titlePanelSize)
        feedbackPanel.update(size: feedbackPanelSize)
        titlePanel.position = CGPoint(x: size.width / 2, y: size.height - topInset - titlePanelSize.height / 2)
        feedbackPanel.position = CGPoint(x: size.width / 2, y: bottomInset + feedbackPanelSize.height / 2)

        titleLabel.position = .zero
        feedbackLabel.position = .zero
        titleLabel.fontSize = isCompactHeight ? 21 : 28
        feedbackLabel.fontSize = isCompactHeight ? 12 : 15

        let illustratedTop = titlePanel.position.y - titlePanelSize.height / 2 - (isCompactHeight ? 8 : 18)
        let illustratedBottom = feedbackPanel.position.y + feedbackPanelSize.height / 2 + (isCompactHeight ? 8 : 18)
        let illustratedRegionFrame = CGRect(
            x: horizontalMargin,
            y: illustratedBottom,
            width: max(1, size.width - horizontalMargin * 2),
            height: max(1, illustratedTop - illustratedBottom)
        )

        layoutFrames = (
            scene: CGRect(origin: .zero, size: size),
            titlePanel: frame(centeredAt: titlePanel.position, size: titlePanelSize),
            illustratedRegion: illustratedRegionFrame,
            feedbackPanel: frame(centeredAt: feedbackPanel.position, size: feedbackPanelSize)
        )

        if let backdropNode {
            backdropNode.position = CGPoint(x: illustratedRegionFrame.midX, y: illustratedRegionFrame.midY)
            let scale = min(
                illustratedRegionFrame.width / max(1, backdropNode.size.width),
                illustratedRegionFrame.height / max(1, backdropNode.size.height)
            )
            backdropNode.setScale(scale)
        }

        let positions = cityPositions(in: illustratedRegionFrame, nodeRadius: nodeRadius)
        drawRoutes(positions: positions)

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            guard let position = positions[cityNumber] else {
                continue
            }

            let baseScale = nodeRadius / 18
            cityBaseScales[cityNumber] = baseScale
            cityNodes[cityNumber]?.setScale(baseScale)
            cityNodes[cityNumber]?.lineWidth = isCompactHeight ? 2 : 3
            cityNodes[cityNumber]?.position = position
            cityLabels[cityNumber]?.fontSize = labelFontSize
            cityLabels[cityNumber]?.position = position
            conqueredMarkers[cityNumber]?.position = CGPoint(x: position.x + nodeRadius * 0.74, y: position.y + nodeRadius * 0.62)
            conqueredMarkers[cityNumber]?.size = CGSize(width: nodeRadius * 1.35, height: nodeRadius * 1.35)
        }

        redraw()
    }

    private func frame(centeredAt center: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    private func cityPositions(in regionFrame: CGRect, nodeRadius: CGFloat) -> [Int: CGPoint] {
        let insetX = max(nodeRadius + 4, regionFrame.width * 0.08)
        let insetY = max(nodeRadius + 4, regionFrame.height * 0.05)
        let drawable = regionFrame.insetBy(dx: insetX, dy: insetY)
        let normalizedCoordinates = [
            CGPoint(x: 0.17, y: 0.07),
            CGPoint(x: 0.36, y: 0.14),
            CGPoint(x: 0.61, y: 0.10),
            CGPoint(x: 0.78, y: 0.21),
            CGPoint(x: 0.58, y: 0.29),
            CGPoint(x: 0.30, y: 0.27),
            CGPoint(x: 0.16, y: 0.40),
            CGPoint(x: 0.39, y: 0.47),
            CGPoint(x: 0.66, y: 0.42),
            CGPoint(x: 0.82, y: 0.55),
            CGPoint(x: 0.60, y: 0.62),
            CGPoint(x: 0.33, y: 0.59),
            CGPoint(x: 0.19, y: 0.73),
            CGPoint(x: 0.47, y: 0.80),
            CGPoint(x: 0.76, y: 0.90),
        ]
        var positions: [Int: CGPoint] = [:]
        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let normalized = normalizedCoordinates[cityNumber - 1]
            positions[cityNumber] = CGPoint(
                x: drawable.minX + normalized.x * drawable.width,
                y: drawable.minY + normalized.y * drawable.height
            )
        }

        return positions
    }

    private func drawRoutes(positions: [Int: CGPoint]) {
        routeLayer.removeAllChildren()

        for cityNumber in 1..<KingdomGameState.firstCountryCityCount {
            guard let start = positions[cityNumber], let end = positions[cityNumber + 1] else {
                continue
            }

            routeLayer.addChild(routeLine(from: start, to: end, alpha: 0.9, width: 6))
        }

        for cityNumber in [3, 6, 9, 12] {
            guard let origin = positions[cityNumber] else {
                continue
            }

            let branchEnd = CGPoint(
                x: origin.x + (cityNumber.isMultiple(of: 2) ? 44 : -44),
                y: origin.y + 34
            )
            routeLayer.addChild(routeLine(from: origin, to: branchEnd, alpha: 0.38, width: 4))
        }
    }

    private func routeLine(from start: CGPoint, to end: CGPoint, alpha: CGFloat, width: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let line = SKShapeNode(path: path)
        line.strokeColor = SKColor(red: 0.72, green: 0.56, blue: 0.28, alpha: alpha)
        line.lineWidth = width
        line.lineCap = .round
        return line
    }

    private func redraw() {
        titleLabel.text = "Country \(state.countryNumber)"
        feedbackLabel.text = feedbackText

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            applyVisualState(visualState(for: cityNumber), to: cityNumber)
        }
    }

    private func visualState(for cityNumber: Int) -> CountryMapCityVisualState {
        switch state.mapStatus(for: cityNumber) {
        case .completed:
            return .completed
        case .unlocked:
            return .unlocked
        case .locked:
            return .locked
        }
    }

    private func applyVisualState(_ visualState: CountryMapCityVisualState, to cityNumber: Int) {
        cityVisualStates[cityNumber] = visualState
        let cityNode = cityNodes[cityNumber]
        let cityLabel = cityLabels[cityNumber]
        let conqueredMarker = conqueredMarkers[cityNumber]

        cityNode?.removeAction(forKey: ActionKey.unlockedPulse)
        cityNode?.alpha = 1
        cityNode?.setScale(cityBaseScales[cityNumber] ?? cityNode?.xScale ?? 1)
        conqueredMarker?.isHidden = true

        switch visualState {
        case .completed:
            cityNode?.fillColor = GameUITheme.Color.gold
            cityNode?.strokeColor = SKColor(red: 1.0, green: 0.96, blue: 0.72, alpha: 1.0)
            cityNode?.lineWidth = max(2, cityNode?.lineWidth ?? 2)
            cityLabel?.fontColor = SKColor(red: 0.13, green: 0.10, blue: 0.04, alpha: 1.0)
            conqueredMarker?.isHidden = false
        case .unlocked:
            cityNode?.fillColor = GameUITheme.Color.hpFill
            cityNode?.strokeColor = SKColor.white
            cityNode?.lineWidth = max(3, cityNode?.lineWidth ?? 3)
            cityLabel?.fontColor = .white
            startUnlockedPulse(for: cityNode)
        case .locked:
            cityNode?.fillColor = GameUITheme.Color.locked
            cityNode?.strokeColor = SKColor(white: 1.0, alpha: 0.24)
            cityNode?.lineWidth = max(2, cityNode?.lineWidth ?? 2)
            cityNode?.alpha = 0.78
            cityLabel?.fontColor = SKColor(white: 1.0, alpha: 0.52)
        }
    }

    private func startUnlockedPulse(for cityNode: SKShapeNode?) {
        guard let cityNode else {
            return
        }

        let pulseUp = SKAction.group([
            SKAction.scale(to: cityNode.xScale * 1.08, duration: 0.8),
            SKAction.fadeAlpha(to: 0.86, duration: 0.8),
        ])
        let pulseDown = SKAction.group([
            SKAction.scale(to: cityNode.xScale, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8),
        ])
        cityNode.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])), withKey: ActionKey.unlockedPulse)
    }

    private func defaultFeedbackText(for state: KingdomGameState) -> String {
        if state.stageStatus == .countryComplete {
            return "Country \(state.countryNumber) conquered."
        }

        return "Select the unlocked city."
    }

    private func cityNumber(at point: CGPoint) -> Int? {
        for node in nodes(at: point) {
            guard let name = node.name, name.hasPrefix(NodeName.cityPrefix) else {
                continue
            }

            return Int(name.dropFirst(NodeName.cityPrefix.count))
        }

        return nil
    }

    private func enterCity(_ cityNumber: Int) {
        var latestState = store.load()

        switch latestState.startCityFromMap(cityNumber) {
        case .entered:
            guard let router else {
                state = store.load()
                feedbackText = "Cannot enter city yet."
                redraw()
                return
            }

            state = latestState
            store.save(state)
            router.countryMapSceneDidRequestBattle(self)
        case .locked:
            state = latestState
            feedbackText = "City \(cityNumber) is locked."
            redraw()
        case .alreadyCompleted:
            state = latestState
            feedbackText = "City \(cityNumber) is complete."
            redraw()
        case .countryComplete:
            state = latestState
            feedbackText = "Country \(state.countryNumber) conquered."
            redraw()
        }
    }
}

#if DEBUG
extension CountryMapScene {
    var mapLayoutFramesForTesting: CountryMapLayoutFrames {
        CountryMapLayoutFrames(
            sceneFrame: layoutFrames.scene,
            titlePanelFrame: layoutFrames.titlePanel,
            illustratedRegionFrame: layoutFrames.illustratedRegion,
            feedbackPanelFrame: layoutFrames.feedbackPanel
        )
    }

    var feedbackTextForTesting: String {
        feedbackText
    }

    func enterCityForTesting(_ cityNumber: Int) {
        enterCity(cityNumber)
    }

    func cityNumberAtPointForTesting(_ point: CGPoint) -> Int? {
        cityNumber(at: point)
    }

    func cityNodePositionForTesting(_ cityNumber: Int) -> CGPoint? {
        cityNodes[cityNumber]?.position
    }

    func cityLabelPositionForTesting(_ cityNumber: Int) -> CGPoint? {
        cityLabels[cityNumber]?.position
    }

    func cityVisualStateForTesting(_ cityNumber: Int) -> CountryMapCityVisualState? {
        cityVisualStates[cityNumber]
    }

    func isUnlockedCityPulseRunningForTesting(_ cityNumber: Int) -> Bool {
        cityNodes[cityNumber]?.action(forKey: ActionKey.unlockedPulse) != nil
    }
}
#endif
