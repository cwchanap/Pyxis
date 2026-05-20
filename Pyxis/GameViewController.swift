//
//  GameViewController.swift
//  Pyxis
//
//  Created by Chan Wai Chan on 5/5/2026.
//

import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private let store: KingdomGameStore

    init(store: KingdomGameStore = .shared) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.store = .shared
        super.init(coder: coder)
    }

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
        presentSceneForCurrentStage(in: view)
    }

    private func presentSceneForCurrentStage(in view: SKView) {
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

    private func presentBuildingViewScene(in view: SKView) {
        let scene = BuildingViewScene(size: view.bounds.size, store: store, router: self)
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

    func battleSceneDidRequestBuildingView(_ scene: BattleScene) {
        guard let view = self.view as? SKView else {
            return
        }

        presentBuildingViewScene(in: view)
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

extension GameViewController: BuildingViewSceneRouting {
    func buildingViewSceneDidRequestBattle(_ scene: BuildingViewScene) {
        guard let view = self.view as? SKView else {
            return
        }

        presentSceneForCurrentStage(in: view)
    }
}
