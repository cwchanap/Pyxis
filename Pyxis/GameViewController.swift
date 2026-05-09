//
//  GameViewController.swift
//  Pyxis
//
//  Created by Chan Wai Chan on 5/5/2026.
//

import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private let store = KingdomGameStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let view = self.view as? SKView else {
            return
        }

        configure(view)
        presentInitialScene(in: view)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    private func configure(_ view: SKView) {
        view.ignoresSiblingOrder = true
        view.showsFPS = true
        view.showsNodeCount = true
    }

    private func presentInitialScene(in view: SKView) {
        let state = store.load()

        switch state.stageStatus {
        case .battleActive:
            presentBattleScene(in: view)
        case .cityConqueredPendingMap, .countryComplete:
            presentCountryMapScene(in: view)
        }
    }

    private func presentBattleScene(in view: SKView) {
        let scene = BattleScene(size: view.bounds.size, store: store, router: self)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
    }

    private func presentCountryMapScene(in view: SKView) {
        let scene = CountryMapScene(size: view.bounds.size, store: store, router: self)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
    }
}

extension GameViewController: BattleSceneRouting {
    func battleSceneDidRequestCountryMap(_ scene: BattleScene) {
        guard let view = self.view as? SKView else {
            return
        }

        presentCountryMapScene(in: view)
    }
}

extension GameViewController: CountryMapSceneRouting {
    func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) {
        guard let view = self.view as? SKView else {
            return
        }

        presentBattleScene(in: view)
    }
}
