//
//  GameViewController.swift
//  Pyxis
//
//  Created by Chan Wai Chan on 5/5/2026.
//

import UIKit
import SpriteKit

protocol GameplayFeedbackRuntimeSoundControlling: AnyObject {
    func prepareIfNeeded()
    func handleAppDidEnterBackground()
    func handleAppWillEnterForeground()
    func handleAudioInterruptionBegan()
    func handleAudioInterruptionEnded(shouldResume: Bool)
    func handleLifecycleRecovery()
}

extension GameplaySoundOutputController: GameplayFeedbackRuntimeSoundControlling {}

@MainActor
final class GameViewControllerFeedbackRuntime {
    typealias AccessibilityAdapterFactory = @MainActor (SKView) -> FeedbackSettingsAccessibilityAdapter

    let preferences: FeedbackPreferencesManaging
    let feedback: GameplayFeedbackProviding
    let sound: GameplayFeedbackRuntimeSoundControlling
    private let makeAccessibilityAdapter: AccessibilityAdapterFactory
    private(set) var accessibilityAdapter: FeedbackSettingsAccessibilityAdapter?

    init(
        preferences: FeedbackPreferencesManaging,
        feedback: GameplayFeedbackProviding,
        sound: GameplayFeedbackRuntimeSoundControlling,
        makeAccessibilityAdapter: @escaping AccessibilityAdapterFactory
    ) {
        self.preferences = preferences
        self.feedback = feedback
        self.sound = sound
        self.makeAccessibilityAdapter = makeAccessibilityAdapter
    }

    static func production() -> GameViewControllerFeedbackRuntime {
        let preferences = FeedbackPreferencesStore.shared
        let clock = SystemMonotonicClock()
        let backend = AVAudioEngineGameplayAudioBackend()
        let sound = GameplaySoundOutputController(
            backend: backend,
            catalog: GameplaySoundCatalog.all,
            clock: clock
        )
        let haptics = UIKitGameplayHapticOutput()
        let feedback = DefaultGameplayFeedbackCoordinator(
            preferences: preferences,
            soundOutput: sound,
            hapticOutput: haptics,
            clock: clock
        )

        let runtime = GameViewControllerFeedbackRuntime(
            preferences: preferences,
            feedback: feedback,
            sound: sound,
            makeAccessibilityAdapter: { view in
                FeedbackSettingsAccessibilityAdapter(containerView: view)
            }
        )
        backend.interruptionBeganHandler = { [weak runtime] in
            runtime?.handleAudioInterruptionBegan()
        }
        backend.interruptionEndedHandler = { [weak runtime] shouldResume in
            runtime?.handleAudioInterruptionEnded(shouldResume: shouldResume)
        }
        backend.lifecycleRecoveryHandler = { [weak runtime] in
            runtime?.recoverSoundAfterLifecycle()
        }
        return runtime
    }

    func bindAccessibilityAdapter(to view: SKView) {
        guard accessibilityAdapter == nil else {
            return
        }
        accessibilityAdapter = makeAccessibilityAdapter(view)
    }

    func handleAppDidEnterBackground() {
        sound.handleAppDidEnterBackground()
    }

    func handleAppWillEnterForeground() {
        sound.handleAppWillEnterForeground()
    }

    func handleAudioInterruptionBegan() {
        sound.handleAudioInterruptionBegan()
    }

    func handleAudioInterruptionEnded(shouldResume: Bool) {
        sound.handleAudioInterruptionEnded(shouldResume: shouldResume)
    }

    func recoverSoundAfterLifecycle() {
        sound.handleLifecycleRecovery()
    }
}

final class GameViewController: UIViewController {
    private let store: KingdomGameStore
    private let layoutGateView = AppLayoutGateView()
    private var requestedMapGateReason: AppLayoutGateReason?
    private var activeLayoutGateReason: AppLayoutGateReason?
    private let now: () -> Date
    private let feedbackRuntimeOverride: GameViewControllerFeedbackRuntime?
    private lazy var feedbackRuntime = feedbackRuntimeOverride ?? .production()

    init(
        store: KingdomGameStore = .shared,
        now: @escaping () -> Date = Date.init,
        feedbackRuntime: GameViewControllerFeedbackRuntime? = nil
    ) {
        self.store = store
        self.now = now
        feedbackRuntimeOverride = feedbackRuntime
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.store = .shared
        self.now = Date.init
        feedbackRuntimeOverride = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let view = self.view as? SKView else {
            return
        }

        configure(view)
#if DEBUG
        installDevJumpGesture(on: view)
#endif
        feedbackRuntime.bindAccessibilityAdapter(to: view)
        // `GameplaySoundOutputController` enqueues preparation on its audio boundary;
        // do not wait for decoding before presenting the initial SpriteKit scene.
        feedbackRuntime.sound.prepareIfNeeded()
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

    private func presentSceneForCurrentStage(
        in view: SKView,
        preferredTab: GameplayTab = .battle
    ) {
        let state = store.load()

        if state.pendingBattleResult != nil {
            presentBattleScene(in: view)
            return
        }

        switch state.stageStatus {
        case .battleActive:
            switch preferredTab {
            case .battle:
                presentBattleScene(in: view)
            case .camp:
                presentBuildingViewScene(in: view)
            case .map:
                presentCountryMapScene(in: view)
            }
        case .cityConqueredPendingMap, .countryComplete:
            presentCountryMapScene(in: view)
        }
    }

    private func presentBattleScene(in view: SKView) {
        requestedMapGateReason = nil
        let scene = BattleScene(
            size: view.bounds.size,
            store: store,
            router: self,
            feedback: feedbackRuntime.feedback,
            feedbackPreferences: feedbackRuntime.preferences,
            feedbackSettingsAccessibilityAdapter: feedbackRuntime.accessibilityAdapter
        )
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        refreshLayoutSupport()
    }

    private func presentCountryMapScene(in view: SKView) {
        requestedMapGateReason = nil
        let scene = CountryMapScene(
            size: view.bounds.size,
            store: store,
            router: self,
            feedback: feedbackRuntime.feedback,
            feedbackPreferences: feedbackRuntime.preferences,
            feedbackSettingsAccessibilityAdapter: feedbackRuntime.accessibilityAdapter
        )
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        refreshLayoutSupport()
    }

    private func presentBuildingViewScene(in view: SKView) {
        requestedMapGateReason = nil
        let scene = BuildingViewScene(
            size: view.bounds.size,
            store: store,
            router: self,
            feedback: feedbackRuntime.feedback,
            feedbackPreferences: feedbackRuntime.preferences,
            feedbackSettingsAccessibilityAdapter: feedbackRuntime.accessibilityAdapter
        )
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
        } else if let battle = skView.scene as? BattleScene, battle.isConquestReportFitFailed {
            reason = .unsupportedGeometry
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

extension GameViewController: SceneLifecycleHandoff {
    func handleSceneDidEnterBackground() {
        feedbackRuntime.handleAppDidEnterBackground()
    }

    func handleSceneWillEnterForeground() {
        feedbackRuntime.handleAppWillEnterForeground()
    }
}

extension GameViewController: BattleSceneRouting {
    func battleSceneDidRequestGameplayTab(_ scene: BattleScene, tab: GameplayTab) {
        guard let view = self.view as? SKView else {
            return
        }

        presentSceneForCurrentStage(in: view, preferredTab: tab)
    }

    func battleScene(_ scene: BattleScene, didRequestLayoutGate reason: AppLayoutGateReason) {
        requestedMapGateReason = reason
        refreshLayoutSupport()
    }
}

extension GameViewController: CountryMapSceneRouting {
    @discardableResult
    func countryMapSceneDidRequestGameplayTab(
        _ scene: CountryMapScene,
        tab: GameplayTab
    ) -> Bool {
        guard let view = self.view as? SKView else {
            return false
        }

        presentSceneForCurrentStage(in: view, preferredTab: tab)
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
    @discardableResult
    func buildingViewSceneDidRequestGameplayTab(
        _ scene: BuildingViewScene,
        tab: GameplayTab
    ) -> Bool {
        guard let view = self.view as? SKView else {
            return false
        }

        presentSceneForCurrentStage(in: view, preferredTab: tab)
        return true
    }
}

#if DEBUG
private enum DevJumpUI {
    static let triggerSize: CGFloat = 64
    static let title = "[DEBUG] Jump to Country 1 City"
    static let message = "Replaces current save."
}

extension GameViewController {
    func installDevJumpGesture(on view: SKView) {
        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDevJumpGesture(_:))
        )
        gesture.numberOfTapsRequired = 5
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesEnded = false
        view.addGestureRecognizer(gesture)
    }

    func devJumpTriggerFrame(in view: SKView) -> CGRect {
        let size = min(
            DevJumpUI.triggerSize,
            min(view.bounds.width, view.bounds.height)
        )
        return CGRect(
            x: view.bounds.maxX - size,
            y: view.bounds.minY,
            width: size,
            height: size
        )
    }

    @objc func handleDevJumpGesture(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? SKView else { return }
        handleDevJumpTap(at: gesture.location(in: view), in: view)
    }

    func handleDevJumpTap(at point: CGPoint, in view: SKView) {
        guard devJumpTriggerFrame(in: view).contains(point),
              presentedViewController == nil else {
            return
        }
        present(makeDevJumpAlert(in: view), animated: true)
    }

    func makeDevJumpAlert(in view: SKView) -> UIAlertController {
        let alert = UIAlertController(
            title: DevJumpUI.title,
            message: DevJumpUI.message,
            preferredStyle: .actionSheet
        )

        for city in 1...KingdomGameState.firstCountryCityCount {
            alert.addAction(UIAlertAction(title: "City \(city)", style: .default) { [weak self] _ in
                self?.performDevJump(to: city, in: view)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = devJumpTriggerFrame(in: view)
        return alert
    }

    func performDevJump(to city: Int, in view: SKView) {
        store.save(DevJumpState.make(city: city))
        presentBattleScene(in: view)
    }

    func refreshLayoutSupportForTesting(
        environment: CountryMapLayoutEnvironment
    ) {
        refreshLayoutSupport(environment: environment)
    }

    func presentSceneForCurrentStageForTesting(
        in view: SKView,
        preferredTab: GameplayTab = .battle
    ) {
        presentSceneForCurrentStage(in: view, preferredTab: preferredTab)
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
