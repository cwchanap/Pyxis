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

final class CountryMapScene: SKScene {
    private enum NodeName {
        static let cityPrefix = "countryMapCity-"
    }

    private let store: KingdomGameStore
    private weak var router: CountryMapSceneRouting?
    private var state: KingdomGameState
    private var didBuildInterface = false

    private let routeLayer = SKNode()
    private let cityLayer = SKNode()
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var cityNodes: [Int: SKShapeNode] = [:]
    private var cityLabels: [Int: SKLabelNode] = [:]
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

        if !didBuildInterface {
            buildInterface()
            didBuildInterface = true
        }

        redraw()
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
        routeLayer.zPosition = 0
        cityLayer.zPosition = 10
        addChild(routeLayer)
        addChild(cityLayer)

        configureLabel(titleLabel, fontSize: 30, color: .white)
        configureLabel(feedbackLabel, fontSize: 16, color: SKColor(red: 0.95, green: 0.91, blue: 0.78, alpha: 1.0))
        addChild(titleLabel)
        addChild(feedbackLabel)

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
        let topMargin: CGFloat = isCompactHeight ? 38 : 72
        let bottomMargin: CGFloat = isCompactHeight ? 30 : 50
        let nodeRadius: CGFloat = isCompactHeight ? 9 : 18
        let labelFontSize: CGFloat = isCompactHeight ? 10 : 13
        let contentWidth = max(220, min(size.width - 48, 520))

        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - topMargin)
        feedbackLabel.position = CGPoint(x: size.width / 2, y: bottomMargin)
        titleLabel.fontSize = isCompactHeight ? 24 : 30
        feedbackLabel.fontSize = isCompactHeight ? 13 : 16

        let titleClearance: CGFloat = isCompactHeight ? 34 : 44
        let mapTop = min(size.height - nodeRadius - 4, titleLabel.position.y - titleClearance - nodeRadius)
        let mapBottom = max(nodeRadius + 4, feedbackLabel.position.y + 32)
        let mapHeight = max(0, mapTop - mapBottom)

        let positions = cityPositions(contentWidth: contentWidth, mapBottom: mapBottom, mapHeight: mapHeight)
        drawRoutes(positions: positions)

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            guard let position = positions[cityNumber] else {
                continue
            }

            cityNodes[cityNumber]?.setScale(nodeRadius / 18)
            cityNodes[cityNumber]?.lineWidth = isCompactHeight ? 2 : 3
            cityNodes[cityNumber]?.position = position
            cityLabels[cityNumber]?.fontSize = labelFontSize
            cityLabels[cityNumber]?.position = position
        }
    }

    private func cityPositions(contentWidth: CGFloat, mapBottom: CGFloat, mapHeight: CGFloat) -> [Int: CGPoint] {
        let centerX = size.width / 2
        let leftX = centerX - contentWidth * 0.36
        let midLeftX = centerX - contentWidth * 0.18
        let midRightX = centerX + contentWidth * 0.14
        let rightX = centerX + contentWidth * 0.36
        let stepY = mapHeight / CGFloat(KingdomGameState.firstCountryCityCount - 1)
        let columns = [
            leftX, midLeftX, midRightX, rightX, midRightX,
            midLeftX, leftX, midLeftX, centerX, midRightX,
            rightX, midRightX, centerX, midLeftX, midRightX,
        ]

        var positions: [Int: CGPoint] = [:]
        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            positions[cityNumber] = CGPoint(
                x: columns[cityNumber - 1],
                y: mapBottom + CGFloat(cityNumber - 1) * stepY
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
            switch state.mapStatus(for: cityNumber) {
            case .completed:
                cityNodes[cityNumber]?.fillColor = SKColor(red: 0.95, green: 0.76, blue: 0.17, alpha: 1.0)
                cityNodes[cityNumber]?.strokeColor = .white
                cityLabels[cityNumber]?.fontColor = SKColor(red: 0.12, green: 0.12, blue: 0.10, alpha: 1.0)
            case .unlocked:
                cityNodes[cityNumber]?.fillColor = SKColor(red: 0.18, green: 0.64, blue: 0.40, alpha: 1.0)
                cityNodes[cityNumber]?.strokeColor = .white
                cityLabels[cityNumber]?.fontColor = .white
            case .locked:
                cityNodes[cityNumber]?.fillColor = SKColor(red: 0.22, green: 0.31, blue: 0.38, alpha: 1.0)
                cityNodes[cityNumber]?.strokeColor = SKColor(white: 1.0, alpha: 0.26)
                cityLabels[cityNumber]?.fontColor = SKColor(white: 1.0, alpha: 0.55)
            }
        }
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
    var feedbackTextForTesting: String {
        feedbackText
    }

    func enterCityForTesting(_ cityNumber: Int) {
        enterCity(cityNumber)
    }
}
#endif
