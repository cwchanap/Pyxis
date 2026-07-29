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
    private let layoutGateView = AppLayoutGateView()
    private var requestedMapGateReason: AppLayoutGateReason?
    private var activeLayoutGateReason: AppLayoutGateReason?
    private let now: () -> Date

    init(
        store: KingdomGameStore = .shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.now = now
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.store = .shared
        self.now = Date.init
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ((view as? SKView)?.scene as? SceneLayoutRefreshable)?
            .refreshLayoutForCurrentEnvironment()
        refreshLayoutSupport()
    }

    static func interfaceOrientations(
        for idiom: UIUserInterfaceIdiom
    ) -> UIInterfaceOrientationMask {
        switch idiom {
        case .pad:
            return [.portrait, .portraitUpsideDown]
        default:
            return .portrait
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        Self.interfaceOrientations(for: traitCollection.userInterfaceIdiom)
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        ((view as? SKView)?.scene as? SceneLayoutRefreshable)?
            .refreshLayoutForCurrentEnvironment()
        refreshLayoutSupport()
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
        requestedMapGateReason = nil
        let scene = BattleScene(size: view.bounds.size, store: store, router: self)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        refreshLayoutSupport()
    }

    private func presentCountryMapScene(in view: SKView) {
        requestedMapGateReason = nil
        let scene = CountryMapScene(size: view.bounds.size, store: store, router: self)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        refreshLayoutSupport()
    }

    private func presentBuildingViewScene(in view: SKView) {
        requestedMapGateReason = nil
        let scene = BuildingViewScene(size: view.bounds.size, store: store, router: self)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        refreshLayoutSupport()
    }

    private func refreshLayoutSupport(
        environment override: CountryMapLayoutEnvironment? = nil
    ) {
        guard let skView = view as? SKView else { return }
        let environment = override ?? CountryMapLayoutUIKitAdapter.environment(for: skView)
        let layoutResult = environment.map {
            CountryMapLayout.compute(.init(
                sceneSize: skView.bounds.size,
                environment: $0,
                definition: .country1
            ))
        } ?? .unsupported(.unsupportedGeometry)

        let reason: AppLayoutGateReason?
        if requestedMapGateReason == .mapUnavailable {
            reason = .mapUnavailable
        } else {
            switch layoutResult {
            case .supported:
                if let mapScene = skView.scene as? CountryMapScene,
                   mapScene.isScoutCardFitFailed {
                    reason = .unsupportedGeometry
                } else {
                    reason = nil
                }
            case .unsupported(.invalidAuthoredData):
                reason = .mapUnavailable
            case .unsupported(.unsupportedGeometry):
                reason = .unsupportedGeometry
            }
        }

        applyLayoutGate(reason, in: skView)
    }

    private func applyLayoutGate(
        _ reason: AppLayoutGateReason?,
        in skView: SKView
    ) {
        if let reason {
            if activeLayoutGateReason == nil {
                (skView.scene as? LayoutGateLifecycleHandling)?
                    .layoutGateWillPause(at: now())
            }
            skView.isPaused = true
            skView.scene?.isUserInteractionEnabled = false
            activeLayoutGateReason = reason
            layoutGateView.apply(reason)
            if layoutGateView.superview == nil {
                layoutGateView.frame = view.bounds
                layoutGateView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                view.addSubview(layoutGateView)
            }
            return
        }

        if activeLayoutGateReason != nil {
            (skView.scene as? LayoutGateLifecycleHandling)?
                .layoutGateWillResume(at: now())
        }
        layoutGateView.removeFromSuperview()
        activeLayoutGateReason = nil
        skView.scene?.isUserInteractionEnabled = true
        skView.isPaused = false
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
    @discardableResult
    func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) -> Bool {
        guard let view = self.view as? SKView else {
            return false
        }

        presentBattleScene(in: view)
        return true
    }

    func countryMapScene(
        _ scene: CountryMapScene,
        didRequestLayoutGate reason: AppLayoutGateReason
    ) {
        requestedMapGateReason = reason
        refreshLayoutSupport()
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

#if DEBUG
extension GameViewController {
    func refreshLayoutSupportForTesting(
        environment: CountryMapLayoutEnvironment
    ) {
        refreshLayoutSupport(environment: environment)
    }

    var isLayoutGateVisibleForTesting: Bool {
        layoutGateView.superview != nil
    }

    var layoutGateReasonForTesting: AppLayoutGateReason? {
        activeLayoutGateReason
    }

    var layoutGateTextForTesting: String? {
        layoutGateView.messageLabel.text
    }
}
#endif
