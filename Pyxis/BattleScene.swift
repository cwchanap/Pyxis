//
//  BattleScene.swift
//  Pyxis
//
//  Created by Chan Wai Chan on 5/5/2026.
//

import Foundation
import SpriteKit
import UIKit

protocol BattleSceneRouting: AnyObject {
    func battleSceneDidRequestGameplayTab(_ scene: BattleScene, tab: GameplayTab)
    func battleScene(_ scene: BattleScene, didRequestLayoutGate reason: AppLayoutGateReason)
}

final class BattleScene: SKScene, LayoutGateLifecycleHandling, SceneLayoutRefreshable {
    private enum BattleAssetName {
        static let playerCastle = "player-castle"
        static let enemyCity = "enemy-city"
        static let normalSoldier = "normal-soldier"
        static let archerSoldier = "archer-soldier"
        static let captainAssetPrefix = "vanguard-captain"
        static let captainResting = "vanguard-captain-resting"
        /// Optional HPA-476 art for the Rally protection accent (feet/
        /// bottom-center, behind the protected soldier); procedural
        /// fallback until it ships.
        static let rallyProtectionAccent = "rally-protection-accent"
        static let battlefieldBackdrop = "battlefield-backdrop"
        static let buildingPadEmpty = "building-pad-empty"
        static let countryMarker = "conquered-marker"
        static let hitFlash = "hit-flash"
        static let towerProjectile = "tower-projectile"
        static let goldBurst = "gold-burst"
    }

    private enum EffectName {
        static let floatingFeedback = "floatingFeedback"
        static let goldBurst = "goldBurst"
        static let livingKingdomTransitionFX = "livingKingdomTransitionFX"
    }

    private enum BattlefieldNodeName {
        static let cityHPBarBackground = "cityHPBarBackground"
        static let cityHPBarFill = "cityHPBarFill"
        static let livingKingdomBattlefieldTreatment = "livingKingdomBattlefieldTreatment"
        static let defensiveFireProjectile = "defensiveFireProjectile"
        /// HPA-812: per-lane non-interactive "+N" overflow summary appended
        /// with `BattleLane.rawValue` (`soldierOverflowBadge-2` etc.).
        static let soldierOverflowBadgePrefix = "soldierOverflowBadge-"
    }

    /// Shipping HPA-476 art, bottom-center anchored with `-ruined` structure variants:
    /// gate 256×128, arrow tower 320×576, Barracks 320×480; Guard walk/attack/hit
    /// trios use 128×128 frames and infantry body geometry.
    enum SiegeObjectiveAssetContract {
        static let gate = "siege-gate"
        static let arrowTower = "siege-arrow-tower"
        static let barracks = "siege-barracks"
        static let guardAssetPrefix = "siege-guard"
    }

    private enum SiegeObjectiveNodeName {
        static let prefix = "siegeObjective-"
        static let structure = "siegeStructure"
        static let ruin = "siegeRuin"
        static let hpFill = "siegeHPFill"
        static let coveragePrefix = "siegeCoverage-"
    }

    private enum EffectStyle {
        static let floatingFeedbackFontSize: CGFloat = 22
        static let floatingFeedbackZ: CGFloat = 55
        static let goldBurstZ = GameUITheme.Z.modal + 0.5
        static let goldBurstSparkleZ: CGFloat = 0
        static let goldBurstRemovalDelayNanoseconds: UInt64 = 650_000_000
        static let tooltipVisibleDuration: TimeInterval = 1.65
    }

    private enum SoldierAnimationKey {
        static let walk = "soldierWalkAnimation"
        static let attack = "soldierAttackAnimation"
        static let hit = "soldierHitAnimation"
        static let delayedRemoval = "soldierDelayedRemoval"
    }

    private enum GuardNodeName {
        static let root = "siege-guard"
        static let visual = "guardVisual"
        static let body = "guardBody"
        static let shield = "guardShield"
        static let head = "guardHead"
        static let helmet = "guardHelmet"
        static let statusLabel = "siegeBarracksStatus"
    }

    private enum GuardAnimationKey {
        static let loss = "guardLossAction"
    }

    private struct GuardNodeBundle {
        let root: SKNode
        let visual: SKNode
        /// `SKSpriteNode` on the animated-canvas path (complete `siege-guard`
        /// trio installed); the procedural torso `SKShapeNode` on the
        /// fallback path, where no sprite exists to animate.
        let body: SKNode
        /// `true` when the complete `siege-guard` animation trio passed the
        /// `firstAvailableSoldierAnimationFrameName` probe and `body` is an
        /// animation-canvas sprite. `false` for the procedural fallback —
        /// walk/transient playback must not install on it, mirroring
        /// `SoldierNodeBundle.isAnimatedCanvas`.
        let isAnimatedCanvas: Bool
        var transientAction: SoldierAnimationAction?
        var transientRemaining: TimeInterval = 0
    }

    private struct SoldierNodeBundle {
        let root: SKNode
        let body: SKNode
        let hpBarBackground: SKShapeNode
        let hpBarFill: SKShapeNode
        let type: SoldierType
        /// HPA-475: the flagged Captain reuses the infantry type for all
        /// combat/animation math; this flag only retargets the asset prefix
        /// (`vanguard-captain` vs `SoldierType.rawValue`).
        let isCaptain: Bool
        let lane: BattleLane
        let formationSlot: Int
        /// `true` when `body` is an animation-canvas sprite whose texture is a
        /// 128px full-canvas animation frame and whose size is therefore owned
        /// by `SoldierAnimationGeometry`. `false` for the static fallback
        /// sprite (a standalone asset not authored against those normalized
        /// bounds), which must stay on the legacy `fitBattleNode` fit path.
        let isAnimatedCanvas: Bool
        /// Lazily attached Rally protection accent (HPA-475), toggled via
        /// `isHidden` by `syncRallyProtectionAccent` each combat tick.
        var rallyAccent: SKNode?
        /// `soldierTargetHeight()` the accent was authored at; a resize
        /// rebuilds it so the glow tracks the refit body.
        var rallyAccentHeight: CGFloat = 0
        /// HPA-812: `true` once the root has actually RENDERED at least
        /// once — a member that has never been visible has no meaningful
        /// rendered position, so its bookkeeping position is written
        /// directly; previously rendered members move at the bounded
        /// combat-time glide speed instead (no teleports).
        var presentationSeeded = false
        /// HPA-812: `true` once a pending-removal corpse has been given its
        /// collision-free placement under the CURRENT layout — afterwards
        /// its position stays fixed (a dead body does not slide with the
        /// formation grid). A layout remap clears this so the corpse is
        /// re-placed in the new coordinate system.
        var corpseRevealed = false
        /// HPA-812: the corpse's ACTUAL reserved footprint (scene space)
        /// while it is pending removal — the ground live soldiers may not
        /// claim a seat on. Recomputed each sync from the node's own
        /// transform and kept until the node is handed to the fade-out list.
        var corpseFootprint: CGRect?
        /// Last fill/width inputs laid out into the bar paths — the fill
        /// as a 1/4096-quantized percent so a pending casualty (whose
        /// `Soldier` is already gone from combat) can replay its
        /// last-rendered fill across a layout refit — unchanged members
        /// (notably the hidden folded roster) skip the CGPath rebuild
        /// entirely.
        var hpBarSignature: (percent: Int, width: Int)?
    }

    private enum SoldierFormation {
        static let columns = [0, -1, 1]
        static let crowdedScale: CGFloat = 0.8
        static let spacing: CGFloat = 2
        /// HPA-812: chrome reserved at the lane's floor for the "+N"
        /// overflow badge — the deepest presented row's feet stay above
        /// this reserve so the badge always clears the lowest presented
        /// soldier inside the battlefield.
        static let overflowBadgeHeight: CGFloat = 16
        static let overflowBadgeReserve: CGFloat = 24
        /// HPA-812: how fast a soldier root glides toward its ideal
        /// formation point, in points per COMBAT second. Clocked by the
        /// tick's clamped delta — not the sync count — so the same
        /// transition takes the same wall time at any frame cadence, and a
        /// marching ideal (≈53 pt/s) can never outrun the glide. 200 pt/s
        /// keeps a 0.05 s test tick inside the 0.2·height no-teleport bound
        /// on both portrait layouts (10 pt ≪ 10.8 pt).
        static let presentationGlidePointsPerSecond: CGFloat = 200
        /// Sub-point distance under which a hidden-converging member counts
        /// as arrived on its seat — SpriteKit stores node positions at
        /// Float precision, so exact `==` would keep promoted members
        /// hidden forever.
        static let seatArrivalTolerance: CGFloat = 0.75
        /// HPA-812: readability floor for crowded formations. The HP bar
        /// is ≥36 pt local, so ≥0.62 keeps a presented bar ≥22 pt and a
        /// body ≥30 pt. A lane drops to two — then one — columns rather
        /// than scaling below this floor when the widest member's canvas
        /// (attack reach, Captain banner) is broad.
        static let minReadableScale: CGFloat = 0.62
    }

    private struct SoldierFormationLayout {
        let scale: CGFloat
        /// Claim-priority column offsets, in pitches from the lane centre —
        /// [0, -1, 1] for three columns, [-0.5, 0.5] for two, [0] for one.
        /// The count adapts to what the lane can host at the readability
        /// floor so seats never shrink below readable to stay three-wide.
        let columnOffsets: [CGFloat]
        let column: CGFloat
        let row: CGFloat
        let frontLimit: CGFloat
        /// Half-width of the lane's uniform rendered footprint at `scale` —
        /// the widest member's whole-canvas ∪ HP-bar bounds.
        let footprintHalfWidth: CGFloat
        /// Height of that footprint at `scale` — the tallest member's
        /// canvas-bottom-to-visual-top span. Pitches are `spacing` larger
        /// than the footprint, so distinct cells never touch.
        let footprintHeight: CGFloat
        /// Scaled distance the deepest-margin member's ROOT sits below its
        /// rendered footprint bottom (foot margin − canvas bottom). Cell
        /// rects anchor at `rowY − rootDrop` so the generic cell covers
        /// every member's actual footprint regardless of per-member
        /// margins.
        let rootDrop: CGFloat
    }

    /// A live-objective damage presentation sink (HPA-812 final review):
    /// ordinary soldier attacks and Captain attacks are the only two, and
    /// tracking which of them contributed to a same-tick aggregate is what
    /// makes the aggregate label's color deterministic instead of
    /// inheriting whatever color the later-running sink happened to pass.
    private enum ObjectiveDamageSource {
        case ordinary
        case captain
    }

    private let store: KingdomGameStore
    private weak var router: BattleSceneRouting?
    private let feedback: GameplayFeedbackProviding
    private let feedbackPreferences: FeedbackPreferencesManaging
    private let feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter?
    private var feedbackSettingsController: FeedbackSettingsController?
    private var state: KingdomGameState
    private var combat: BattleCombatState
    private var lastUpdateTime: TimeInterval?
    private var isLayoutGatePaused = false
    #if DEBUG
    static let freezeCombatLaunchArgument = "-pyxis-freeze-combat"
    private let isCombatFrozen: Bool
    private var lastAdvanceCombatDeltaForTestingStorage: TimeInterval?
    private var lastTowerProjectileEndpointForTestingStorage: CGPoint?
    #endif
    private var soldierNodes: [BattleCombatState.SoldierID: SoldierNodeBundle] = [:]
    private var guardNodes: [BattleCombatState.GuardID: GuardNodeBundle] = [:]
    private var didBuildInterface = false
    private var isObservingLifecycle = false
    private var selectedManualSoldierType: SoldierType = .infantry
    private let battleHUD = BattleHUDNode()
    private var battleChromeLayout: BattleChromeLayout?
    private(set) var isBattleChromeFitFailed = false
    private let settingsGearHost = SKNode()

    private let battlefieldLayer = SKNode()
    private let environmentLayer = SKNode()
    /// Keeps simulation-coupled SpriteKit actions in one origin-aligned subtree
    /// so Settings can freeze them without pausing HUD or modal interaction.
    private let battlefieldActionLayer = SKNode()
    private let soldierLayer = SKNode()
    private let effectsLayer = SKNode()
    private var objectiveDamageLabels: [String: SKLabelNode] = [:]
    private var objectiveDamageThisTick: [String: Int] = [:]
    /// Which damage sinks contributed live damage to each objective's
    /// same-tick aggregate (HPA-812 final review). Cleared beside
    /// `objectiveDamageThisTick` at the same two tick boundaries so the
    /// aggregate-color policy sees every contributing source.
    private var objectiveDamageSourcesThisTick: [String: Set<ObjectiveDamageSource>] = [:]
    private var playerCastleNode: SKNode?
    private var enemyCityNode: SKNode?
    private var battlefieldBackdropNode: SKSpriteNode?
    /// Optional Living Kingdom battlefield treatment sprite (one per scene).
    /// Hidden for frontier cities; lives in the environment layer behind the
    /// fortress so the enemy-city node keeps its own texture identity.
    private let livingKingdomTreatmentNode = SKSpriteNode()
    private let forgedAtmosphereNode = SKSpriteNode(
        color: SKColor(red: 52 / 255, green: 26 / 255, blue: 6 / 255, alpha: 1),
        size: .zero
    )
    private var forgedAtmosphereTextureSize: CGSize?
    private var forgedAtmosphereTexture: SKTexture?
    private var battlefieldLayout = BattlefieldLayout(
        frame: .zero, structureHeight: 0,
        castleGatePoints: [:], enemyGatePoints: [:],
        isVisible: false, lanePathWidth: 14
    )
    private var laneNodes: [SKShapeNode] = []
    private var laneIndicatorNodes: [SKNode] = []
    /// Pilot-objective containers keyed by stable ID; single-Keep cities use `enemy-city`.
    private var siegeObjectiveNodes: [String: SKNode] = [:]
    private var siegeStructureTextures: [String: SKTexture] = [:]
    private var appliedSiegeObjectiveSnapshot: BattleCombatState.SiegeSnapshot?
    private var appliedSiegeObjectiveGeometry: BattlefieldLayout?
    private var appliedSiegeObjectiveMaxPower: Int?
    private var pendingAnimatedRemovalSoldierIDs: Set<BattleCombatState.SoldierID> = []

    /// HPA-812: footprints of soldier roots already unregistered from
    /// `soldierNodes` but still ON SCREEN fading out (`removeSoldierNode(
    /// animated: true)` — the 0.18 s tail of a casualty). Reserved so live
    /// soldiers can never be placed or glide onto ground a fading corpse
    /// still occupies. Keyed by the root node (not soldier id) so a combat
    /// rebuild reusing ids can never release another soldier's ground.
    /// Entries are removed by the fade sequence's own release action.
    private var soldierFadingFootprints: [ObjectIdentifier: (root: SKNode, rect: CGRect)] = [:]

    /// HPA-812: battlefield frame used by the last soldier sync. A change
    /// means the layout coordinate system moved (resize): the next sync
    /// re-places every root in the new coordinates immediately, because
    /// combat-time glides can never repair stale coordinates while ticking
    /// is paused.
    private var lastSoldierSyncBattlefieldFrame: CGRect?

    /// HPA-812 round 3: each lane's last-sync seat assignment —
    /// `soldierID → (row, column)`. Persistence is what makes seats
    /// STABLE: a member keeps its cell while the cell is still its
    /// natural row and still free, so lateral churn only happens when the
    /// roster or the corpse layout actually changed. Folded members drop
    /// out of the map (their seat is released); cleared on teardown.
    private var soldierSeats:
        [BattleLane: [BattleCombatState.SoldierID: (row: Int, column: Int)]] = [:]

    /// HPA-812 round 3 test seam: the seat cell rects claimed by rendered
    /// members during the last sync — the disjointness unit the stable-seat
    /// model guarantees every sync.
    private var seatFootprintsBySoldierID: [BattleCombatState.SoldierID: CGRect] = [:]

    /// HPA-812: the soldier the defensive tower most recently fired at —
    /// recorded at shot time (production state, not only a test probe) so
    /// presentation can keep the projectile's actual target rendered; a
    /// post-movement rank 0 is not necessarily the soldier the preceding
    /// tower event aimed at. Cleared by the projectile's own landing
    /// action (see `playTowerShot`) and on combat teardown, so protection
    /// never outlives the shot it belongs to or bleeds onto a reused id.
    private var lastDefensiveShotTargetID: BattleCombatState.SoldierID?

    /// Remaining time (in seconds) of each soldier's authored hit-reaction
    /// animation, decremented per combat tick. Used by
    /// `playSoldierAnimation`'s attack guard to suppress attack triggers
    /// while a hit reaction is still playing — see the guard comment for why
    /// this is a combat-tick countdown rather than an SKAction-key check.
    private var soldierHitAnimationRemaining: [BattleCombatState.SoldierID: TimeInterval] = [:]

    /// Memoized per-(asset-prefix, action) animation textures. Each call to
    /// `soldierAnimationTextures` previously performed ~20 `UIImage(named:)`
    /// lookups plus fresh `SKTexture` allocations; this cache returns the same
    /// `SKTexture` instances across soldiers and across the scene's lifetime.
    /// Textures are keyed by static asset names, so they never need invalidation.
    /// Keys are asset prefixes (`SoldierType.rawValue` or `vanguard-captain`),
    /// not `SoldierType` — the flagged Captain shares `.infantry` and must not
    /// collide with the ordinary infantry catalog (HPA-475).
    private var soldierAnimationTextureCache: [String: [SoldierAnimationAction: [SKTexture]]] = [:]

    /// Memoized result of `firstAvailableSoldierAnimationFrameName` per
    /// asset prefix (`SoldierType.rawValue` or `vanguard-captain`). The probe
    /// validates all 30 trio frames (10 walk + 10 attack + 10 hit) and is
    /// called from both `createSoldierNode` and
    /// `makeSoldierNode` for every spawn, so without this cache a single
    /// soldier costs 60 `UIImage(named:)` lookups. The value is the walk-01
    /// frame name when the full trio is installed, or `nil` when any frame is
    /// missing (caching the negative result too, so a missing-asset scenario
    /// doesn't re-probe on every spawn). Asset names are static, so the cache
    /// never needs invalidation — mirrors `soldierAnimationTextureCache`.
    private var soldierAnimatedCanvasFrameNameCache: [String: String?] = [:]

    private var enemyCityImpactPoint: CGPoint {
        battlefieldLayout.enemyCityImpactPoint
    }

    private var currentMilestoneTier: Country1MilestoneTier? {
        guard state.currentCityKey.countryNumber == 1 else { return nil }
        return Country1MilestoneTier.forCity(state.currentCityKey.cityNumber)
    }

    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let feedbackPanel = PanelNode(size: CGSize(width: 260, height: 34))
    private let milestoneArrivalPanel = PanelNode(size: .zero)
    private let milestoneArrivalTitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let milestoneArrivalSubtitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let milestoneCityAccent = SKShapeNode()
    private let milestoneConquestAccent = SKShapeNode()
    private let countryCompleteLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let cityHPBarBackground = SKShapeNode()
    private let cityHPBarFill = SKShapeNode()
    private let conquestReportNode = ConquestReportNode()
    private var hasPresentedPendingConquestReport = false
    private var isConquestReportVisible = false
    private var isConquestContinueEnabled = true
    private(set) var isConquestReportFitFailed = false
    private var hasPresentedMilestoneArrival = false
    private var isMilestoneArrivalVisible = false
    private var hasPresentedMilestoneConquestFlourish = false
    private var lastAppliedConquestReportContent: ConquestReportContent?
    private var isGoldBurstRemovalScheduled = false
    private var goldBurstRemovalTask: Task<Void, Never>?

    private enum ConquestReportPresentationOrigin { case freshLive, freshIdle, restored }
    #if DEBUG
    private var milestoneArrivalPresentationCountForTestingStorage = 0
    private var lastConquestReportOriginForTestingStorage: ConquestReportPresentationOrigin?
    private var conquestEffectPresentationCountForTestingStorage = 0
    private var lastGoldBurstAnchorForTestingStorage: CGPoint?
    private var lastConquestReportLayoutInputForTestingStorage: ConquestReportLayout.Input?
    private var milestoneConquestFlourishCountForTestingStorage = 0
    private var lastMilestoneFlourishCityForTestingStorage: Int?
    /// Requested Living Kingdom transition effects, in request order. Recorded
    /// before any playback guard (including Reduce Motion) so tests can assert
    /// requests regardless of the runner's accessibility settings.
    private var livingKingdomTransitionEffectsForTestingStorage: [LivingKingdomPresentation.TransitionEffect] = []
    /// Requested non-Keep structure-fall events (HPA-582), in request order.
    /// Recorded before any playback guard (including Reduce Motion) so tests
    /// can assert requests regardless of the runner's accessibility settings.
    private var structureFallRequestsForTestingStorage: [String] = []
    /// Floating-feedback label texts in presentation order, recorded before
    /// playback so tests can assert the reduced-motion variants too.
    private var floatingFeedbackTextsForTestingStorage: [String] = []
    private var appliedLivingKingdomFortressAssetForTestingStorage: String?
    private var appliedLivingKingdomTreatmentAssetForTestingStorage: String?
    #endif

    private var feedbackText = ""
    private var lastPresentedTooltipText = ""
    /// Cached battle chrome content width from the most recent layout pass.
    /// `showTooltip` reads this instead of recomputing the full metrics struct.
    /// Defaults to a sane positive floor so a tooltip fired before the first
    /// layout pass still gets a non-zero panel width.
    private var cachedContentWidth: CGFloat = 220
    #if DEBUG
    private var battlefieldLayoutCount = 0
    private var soldierAttackAnimationTriggerCount = 0
    private var soldierHitAnimationTriggerCount = 0
    /// Call counter for `layoutCityHPBar`, exposed via
    /// `layoutCityHPBarCallCountForTesting` so tests can verify `redraw` does
    /// not invoke it twice when `shouldLayout` is true (the layout pass in
    /// `layoutInterface` already runs it). DEBUG-only like the sibling layout
    /// counters above; release builds never read it.
    private var layoutCityHPBarCallCount = 0
    #endif
    private var buildingProgressSaveAccumulator: TimeInterval = 0
    private static let buildingProgressSaveInterval: TimeInterval = 2.0
    /// Captain-strip HUD cadence (HPA-475): live HP / Rally / recovery
    /// countdowns change every combat tick, but the full HUD apply is too
    /// heavy to rebuild per frame, so the Captain-driven refresh runs on a
    /// coarser 5 Hz cadence. Event-driven refreshes (building spawns,
    /// losses, Rally activation, layout passes) are unaffected.
    private var captainHUDRefreshAccumulator: TimeInterval = 0
    private static let captainHUDRefreshInterval: TimeInterval = 0.2
    /// Last Captain status the HUD actually applied (HPA-475). The 0.2s
    /// cadence re-projects this cheap strip-only value and skips the full
    /// `applyBattleHUD` rebuild while it is unchanged.
    private var lastAppliedCaptainStatus: BattleHUDContent.CaptainStatus?
    /// Last range-aware Guard-blocker flag the HUD applied (HPA-582
    /// review). Engagement flips without producing soldier attacks — a
    /// Guard marching into range, falling, or its wave landing inside an
    /// entrenched soldier's reach — so the tick compares the live flag
    /// against this value and refreshes only on a transition, never on
    /// Guard HP drift.
    private var lastAppliedLaneGuardBlockerEngaged = false
    private let combatSeed: UInt64?
    /// Reduce Motion read as an injectable closure (the CountryMapScene
    /// pattern) so tests can drive reduced-motion paths without touching
    /// the runner's accessibility settings.
    var isReduceMotionEnabled: () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    /// Deploy-denial messages the scene clears once their condition stops
    /// being true — without this a stale message re-presents its tooltip on
    /// the next non-attack redraw (HPA-582 review).
    private static let deployRechargingMessage = "Deploy is recharging."
    private static let manualSquadFullMessage = "Manual squad is full."

    init(
        size: CGSize,
        store: KingdomGameStore = .shared,
        router: BattleSceneRouting? = nil,
        feedback: GameplayFeedbackProviding = NoOpGameplayFeedbackProvider(),
        feedbackPreferences: FeedbackPreferencesManaging = MainActor.assumeIsolated {
            FeedbackPreferencesStore.shared
        },
        feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter? = nil,
        launchArguments: [String]? = nil,
        combatSeed: UInt64? = nil
    ) {
        let loadedState = store.load()
        self.store = store
        self.state = loadedState
        self.combatSeed = combatSeed
        self.combat = Self.makeCombat(for: loadedState, seed: combatSeed)
        self.router = router
        self.feedback = feedback
        self.feedbackPreferences = feedbackPreferences
        self.feedbackSettingsAccessibilityAdapter = feedbackSettingsAccessibilityAdapter
        #if DEBUG
        self.isCombatFrozen = (launchArguments ?? ProcessInfo.processInfo.arguments)
            .contains(Self.freezeCombatLaunchArgument)
        #endif
        super.init(size: size)
        restorePersistedGuardsIntoCombat()
        restorePersistedCaptainIntoCombat()
    }

    required init?(coder aDecoder: NSCoder) {
        let loadedState = KingdomGameStore.shared.load()
        self.store = .shared
        self.state = loadedState
        self.combatSeed = nil
        self.combat = Self.makeCombat(for: loadedState, seed: nil)
        self.router = nil
        self.feedback = NoOpGameplayFeedbackProvider()
        self.feedbackPreferences = FeedbackPreferencesStore.shared
        self.feedbackSettingsAccessibilityAdapter = nil
        #if DEBUG
        self.isCombatFrozen = ProcessInfo.processInfo.arguments.contains(Self.freezeCombatLaunchArgument)
        #endif
        super.init(coder: aDecoder)
        restorePersistedGuardsIntoCombat()
        restorePersistedCaptainIntoCombat()
    }

    /// Restores persisted Country 1 Guards into combat (HPA-469): only lane
    /// + HP survive persistence, so each snapshot is reconstructed at Keep
    /// progress with its persisted (possibly damaged) HP — deliberately no
    /// clamp-to-max healing. Transient IDs and positions are always new; the
    /// nodes appear via `syncGuardNodes`. Called wherever combat must
    /// converge to the durable roster: scene init and the foreground return
    /// (see `clearLiveCombat` for why it is excluded there).
    /// The roster is REPLACED, never appended: UIKit fires willEnterForeground
    /// on initial activation too (with no prior background), where init
    /// already restored — rebuilding the same roster is a durable no-op. A
    /// cold relaunch still carrying `lastBackgroundedAt` instead settles that
    /// init-restored roster inside `returnFromBackground`, so replacing is
    /// what keeps combat converged: the next live-snapshot sync cannot
    /// resurrect pre-idle HP or drop wave-materialized Guards (which would
    /// leak their consumed reserve), and no phantom roster can charge the
    /// finite reserve twice.
    private func restorePersistedGuardsIntoCombat() {
        guard let snapshots = state.siegeProgress.guardReinforcements?.unresolvedGuards else {
            return
        }
        combat.replaceGuards(with: snapshots, siege: state.currentSiegeSnapshot)
    }

    /// Restores the persisted Vanguard Captain beside the Guards (HPA-475).
    /// Durable progress retains lane, HP, recovery, and Rally consumption;
    /// only lane + HP project into a deployable live actor. A Captain with
    /// battle active and HP > 0 re-enters through the ordinary Soldier roster
    /// via `spawnCaptain`; a recovering (HP 0) Captain deploys nothing —
    /// recovery advances only in live Battle. The flagged Soldier's node is
    /// discovered by `syncSoldierNodes`; there is no Captain node bundle.
    /// Called wherever combat must converge to the durable roster: scene
    /// init and the foreground return (mirroring the Guards).
    private func restorePersistedCaptainIntoCombat() {
        guard state.stageStatus == .battleActive,
              let captain = state.siegeProgress.captain else {
            return
        }
        combat.spawnCaptain(progress: captain, captainLevel: state.captainLevel)
    }

    private static func makeCombat(for state: KingdomGameState, seed: UInt64?) -> BattleCombatState {
        let configuration = BattleCombatState.Configuration.live(
            cityLevel: state.cityLevel,
            laneDamageMultipliers: state.currentCityLaneDefenseProfile.towerDamageMultipliers
        )
        if let seed {
            return BattleCombatState(configuration: configuration, seed: seed)
        }
        return BattleCombatState(configuration: configuration)
    }

    deinit {
        goldBurstRemovalTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1.0)

        if !didBuildInterface {
            buildInterface()
            didBuildInterface = true
        }

        configureFeedbackSettingsIfNeeded(in: view)

        observeLifecycleNotificationsIfNeeded()
        redraw()

        if state.pendingBattleResult != nil, !hasPresentedPendingConquestReport {
            _ = presentPendingConquestReport(origin: .restored, resetsContinueState: true)
        } else {
            presentMilestoneArrivalIfNeeded()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutInterface()
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)

        defer {
            lastUpdateTime = currentTime
        }

        guard let lastUpdateTime else {
            return
        }

        guard state.stageStatus == .battleActive,
              !isConquestReportVisible,
              !isFeedbackSettingsVisible else {
            return
        }

        #if DEBUG
        guard !isCombatFrozen else {
            return
        }
        #endif

        advanceCombat(deltaTime: currentTime - lastUpdateTime)
    }

    func layoutGateWillPause(at date: Date) {
        isLayoutGatePaused = true
    }

    func layoutGateWillResume(at date: Date) {
        guard isLayoutGatePaused else {
            return
        }
        isLayoutGatePaused = false
        lastUpdateTime = nil
        #if DEBUG
        lastAdvanceCombatDeltaForTestingStorage = nil
        #endif
        layoutInterface()
    }

    func refreshLayoutForCurrentEnvironment() {
        layoutInterface()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return
        }
        handleTouch(at: point)
    }

    private func handleTouch(at point: CGPoint) {
        if isConquestReportVisible || isConquestReportFitFailed {
            guard !isConquestReportFitFailed,
                  conquestReportNode.containsContinue(point) else {
                return
            }
            continueFromConquestReport()
            return
        }

        if isMilestoneArrivalVisible {
            dismissMilestoneArrival()
            return
        }

        if let feedbackSettingsController,
           feedbackSettingsController.isVisible {
            _ = feedbackSettingsController.handleTouch(at: point)
            synchronizeBattlefieldActionPause()
            return
        }

        if feedbackSettingsController?.gear.contains(point, in: self) == true {
            openFeedbackSettings()
            return
        }

        if handleBattleHUDTouch(at: point) {
            return
        }

        if let layout = battleChromeLayout {
            if layout.incomeFrame.contains(point) {
                showGoldInfoTooltip()
                return
            }

            if layout.cityProgressFrame.contains(point) {
                showCityInfoTooltip()
                return
            }
        }

    }

    private func handleBattleHUDTouch(at point: CGPoint) -> Bool {
        guard let action = battleHUD.action(at: point) else {
            return false
        }

        switch action {
        case .select(let soldierType):
            selectManualSoldierType(soldierType)
        case .deploy:
            spawnSoldier()
        case .rally:
            // HPA-475: manual activation through the one shared funnel.
            activateRally()
        case .selectLane(let lane):
            selectAssaultLane(lane)
        case .tab(let tab):
            requestGameplayTab(tab)
        case let .requirement(soldierType, unlocksAtCity):
            feedback.emit(.invalidAction)
            if let unlocksAtCity {
                feedbackText = "\(soldierType.displayName) unlocks at City \(unlocksAtCity)."
            } else {
                feedbackText = "Build \(soldierType.displayName) first."
            }
            redraw(shouldLayout: false)
        }
        return true
    }

    private var isFeedbackSettingsVisible: Bool {
        feedbackSettingsController?.isVisible == true
    }

    private func configureFeedbackSettingsIfNeeded(in view: SKView) {
        if feedbackSettingsController == nil {
            let accessibilityAdapter = feedbackSettingsAccessibilityAdapter
                ?? FeedbackSettingsAccessibilityAdapter.sceneAdapter(
                    containerView: view,
                    sceneHeight: { [weak self] in self?.size.height ?? 0 }
                )
            feedbackSettingsController = FeedbackSettingsController(
                preferences: feedbackPreferences,
                accessibilityAdapter: accessibilityAdapter
            )
            accessibilityAdapter.configureActions(
                onGearActivate: { [weak self] in
                    self?.openFeedbackSettings()
                },
                onToggleSoundEffects: { [weak self] in
                    self?.activateFeedbackSettings(.toggleSoundEffects)
                },
                onToggleHaptics: { [weak self] in
                    self?.activateFeedbackSettings(.toggleHaptics)
                },
                onClose: { [weak self] in
                    self?.activateFeedbackSettings(.close)
                }
            )
            feedbackSettingsController?.rebindAccessibilityForScene()
            if state.pendingBattleResult != nil {
                feedbackSettingsController?.setSettingsAccessibilityActionable(false)
            }
        }

        guard let feedbackSettingsController else {
            return
        }

        if feedbackSettingsController.gear.parent !== settingsGearHost {
            settingsGearHost.addChild(feedbackSettingsController.gear)
        }
        // The shared gear is scene-owned and positioned by BattleChromeLayout;
        // keeping it outside BattleHUDNode prevents the HUD from owning modal
        // Settings behavior.
        feedbackSettingsController.gear.zPosition = 2
        if feedbackSettingsController.modal.parent !== self {
            addChild(feedbackSettingsController.modal)
        }
    }

    private func openFeedbackSettings() {
        guard !isLayoutGatePaused,
              !isConquestReportVisible,
              !isConquestReportFitFailed,
              let feedbackSettingsController,
              !feedbackSettingsController.isVisible else {
            return
        }

        dismissMilestoneArrival(animated: false)
        guard feedbackSettingsController.open() else {
            return
        }
        synchronizeBattlefieldActionPause()
    }

    private func closeFeedbackSettings(
        focusTarget: FeedbackSettingsFocusTarget = .openingGear
    ) {
        feedbackSettingsController?.close(focusTarget: focusTarget)
        synchronizeBattlefieldActionPause()
    }

    private func activateFeedbackSettings(_ action: FeedbackSettingsAction) {
        guard let feedbackSettingsController,
              feedbackSettingsController.isVisible,
              let layout = feedbackSettingsLayoutForCurrentEnvironment() else {
            return
        }

        let point: CGPoint
        switch action {
        case .toggleSoundEffects:
            point = CGPoint(x: layout.soundRowFrame.midX, y: layout.soundRowFrame.midY)
        case .toggleHaptics:
            point = CGPoint(x: layout.hapticsRowFrame.midX, y: layout.hapticsRowFrame.midY)
        case .close:
            point = CGPoint(x: layout.closeFrame.midX, y: layout.closeFrame.midY)
        case .consumed:
            return
        }
        _ = feedbackSettingsController.handleTouch(at: point)
        synchronizeBattlefieldActionPause()
    }

    private func synchronizeBattlefieldActionPause() {
        let shouldPauseCombatActions = isFeedbackSettingsVisible
        battlefieldActionLayer.isPaused = shouldPauseCombatActions

        // The city itself stays in the static environment layer, but its hit
        // and conquest feedback actions run directly on that node. Pausing the
        // action host freezes those transient effects without hiding the city.
        enemyCityNode?.isPaused = shouldPauseCombatActions
    }

    private func buildInterface() {
        battlefieldLayer.zPosition = 0
        environmentLayer.zPosition = 10
        battlefieldActionLayer.position = .zero
        battlefieldActionLayer.zPosition = 0
        soldierLayer.zPosition = 20
        effectsLayer.zPosition = 30

        addChild(battlefieldLayer)
        battlefieldLayer.addChild(environmentLayer)
        battlefieldLayer.addChild(battlefieldActionLayer)
        battlefieldActionLayer.addChild(soldierLayer)
        battlefieldActionLayer.addChild(effectsLayer)

        buildBattlefield()

        feedbackPanel.name = "feedbackPanel"
        feedbackLabel.name = "feedbackLabel"
        feedbackPanel.zPosition = GameUITheme.Z.hud - 1
        addChild(feedbackPanel)
        addChild(feedbackLabel)

        settingsGearHost.name = "battleSettingsHost"
        settingsGearHost.zPosition = GameUITheme.Z.hud
        addChild(settingsGearHost)

        milestoneArrivalPanel.zPosition = GameUITheme.Z.modal - 1
        milestoneArrivalPanel.isHidden = true
        milestoneArrivalTitleLabel.fontColor = GameUITheme.Color.textPrimary
        milestoneArrivalTitleLabel.horizontalAlignmentMode = .center
        milestoneArrivalTitleLabel.verticalAlignmentMode = .center
        milestoneArrivalSubtitleLabel.fontColor = GameUITheme.Color.textSecondary
        milestoneArrivalSubtitleLabel.horizontalAlignmentMode = .center
        milestoneArrivalSubtitleLabel.verticalAlignmentMode = .center
        milestoneArrivalPanel.addChild(milestoneArrivalTitleLabel)
        milestoneArrivalPanel.addChild(milestoneArrivalSubtitleLabel)
        addChild(milestoneArrivalPanel)

        milestoneCityAccent.fillColor = .clear
        milestoneCityAccent.strokeColor = GameUITheme.Color.gold
        milestoneCityAccent.isHidden = true
        environmentLayer.addChild(milestoneCityAccent)

        milestoneConquestAccent.fillColor = .clear
        milestoneConquestAccent.strokeColor = GameUITheme.Color.gold
        milestoneConquestAccent.zPosition = GameUITheme.Z.modal - 0.25
        milestoneConquestAccent.isHidden = true
        addChild(milestoneConquestAccent)

        countryCompleteLabel.text = "Country 1 Complete"
        countryCompleteLabel.fontColor = GameUITheme.Color.gold
        countryCompleteLabel.horizontalAlignmentMode = .center
        countryCompleteLabel.verticalAlignmentMode = .center
        countryCompleteLabel.zPosition = GameUITheme.Z.modal + 0.25
        countryCompleteLabel.isHidden = true
        addChild(countryCompleteLabel)

        feedbackLabel.fontSize = 15
        feedbackLabel.fontColor = GameUITheme.Color.gold
        feedbackLabel.horizontalAlignmentMode = .center
        feedbackLabel.verticalAlignmentMode = .center

        conquestReportNode.zPosition = GameUITheme.Z.modal
        battleHUD.zPosition = GameUITheme.Z.hud
        feedbackLabel.zPosition = GameUITheme.Z.hud

        addChild(battleHUD)
        addChild(conquestReportNode)

        feedbackPanel.alpha = 0
        feedbackLabel.alpha = 0
    }

    private func layoutInterface() {
        guard didBuildInterface else {
            return
        }

        layoutForgedInterface()
    }

    private func layoutForgedInterface() {
        let insets = view?.safeAreaInsets ?? .zero
        let chromeInput = BattleChromeLayout.Input(
            sceneSize: size,
            safeAreaInsets: .init(
                top: insets.top,
                left: insets.left,
                bottom: insets.bottom,
                right: insets.right
            ),
            // Same predicate the HUD applies through `captainStatus`: the
            // strip renders only while durable Captain progress exists on a
            // City 3+ siege.
            requiresCaptainSplit: state.siegeProgress.captain != nil
                && VanguardCaptainRules.isAvailable(cityNumber: state.cityNumberInCountry)
        )

        guard let layout = BattleChromeLayout.compute(chromeInput) else {
            battleChromeLayout = nil
            battleHUD.isHidden = true
            setBattlefieldHidden(true)
            removeLaneNodes()
            removeLaneIndicatorNodes()
            setBattleChromeFitFailed(true)
            feedbackSettingsController?.applyGearFrame(.zero)
            updateSettingsGearVisibility()
            // Keep an already-open Settings modal alive while the app-level
            // unsupported-geometry gate is presented. Recovery below reapplies
            // the newly fitted layout without synthesizing a close/catch-up.
            return
        }

        battleChromeLayout = layout
        setBattleChromeFitFailed(false)
        layoutBattlefield(
            contentWidth: layout.battlefieldFrame.width,
            hpBarBottomY: layout.battlefieldFrame.maxY,
            fieldBottomY: layout.battlefieldFrame.minY,
            feedbackY: layout.battlefieldFrame.minY,
            precomputed: layout.battlefield
        )
        applyBattleHUD()

        if let feedbackSettingsController {
            feedbackSettingsController.applyGearFrame(
                layout.settingsFrame,
                appearance: .forged
            )
            feedbackSettingsController.gear.position = settingsGearHost.convert(
                CGPoint(x: layout.settingsFrame.midX, y: layout.settingsFrame.midY),
                from: self
            )
            feedbackSettingsController.reapply(layout: feedbackSettingsLayoutForCurrentEnvironment())
            updateSettingsGearVisibility()
            synchronizeBattlefieldActionPause()
        }

        feedbackLabel.position = CGPoint(
            x: layout.feedbackFrame.midX,
            y: layout.feedbackFrame.midY
        )
        feedbackPanel.position = feedbackLabel.position
        cachedContentWidth = layout.safeFrame.width

        if state.pendingBattleResult != nil,
           hasPresentedPendingConquestReport || isConquestReportFitFailed {
            _ = applyPendingConquestReport(resetsContinueState: false)
        }

        if isMilestoneArrivalVisible {
            _ = layoutMilestoneArrival()
        }
    }

    private func setBattleChromeFitFailed(_ value: Bool) {
        guard isBattleChromeFitFailed != value else {
            return
        }

        isBattleChromeFitFailed = value
        if value {
            router?.battleScene(self, didRequestLayoutGate: .unsupportedGeometry)
        }
    }

    private func applyBattleHUD() {
        updateSettingsGearVisibility()
        guard let layout = battleChromeLayout,
              !isConquestReportVisible,
              !isConquestReportFitFailed else {
            battleHUD.isHidden = true
            return
        }

        let laneGuardBlockerEngaged = combat.isGuardBlockerEngaged(
            onLane: state.siegeProgress.selectedLane
        )
        let content = BattleHUDContent.project(
            from: state,
            manualCount: combat.livingSoldierCount(source: .manual),
            selectedSoldierType: selectedManualSoldierType,
            captainIsDeployed: combat.captainSoldier != nil,
            rallyRemainingSeconds: combat.rallyRemainingSeconds,
            manualDeployCharges: combat.manualDeployCharges,
            selectedLaneGuardBlockerEngaged: laneGuardBlockerEngaged
        )
        lastAppliedCaptainStatus = content.captainStatus
        lastAppliedLaneGuardBlockerEngaged = laneGuardBlockerEngaged
        switch battleHUD.apply(content: content, layout: layout) {
        case .presented:
            setBattleChromeFitFailed(false)
        case .requiredContentDoesNotFit:
            battleHUD.isHidden = true
            setBattleChromeFitFailed(true)
        }
    }

    private func updateSettingsGearVisibility() {
        guard let feedbackSettingsController else {
            return
        }

        let reportBlocksSettings = isConquestReportVisible || isConquestReportFitFailed
        settingsGearHost.isHidden = reportBlocksSettings
        feedbackSettingsController.gear.isHidden = reportBlocksSettings
        if reportBlocksSettings {
            feedbackSettingsController.setSettingsAccessibilityActionable(false)
        }
    }

    private func fitMilestoneLabel(
        _ label: SKLabelNode,
        fontName: String,
        startingAt: CGFloat,
        minimum: CGFloat,
        maximumWidth: CGFloat
    ) -> Bool {
        guard let text = label.text,
              let size = SingleLineTextFitter.fittedFontSize(
                  text,
                  startingAt: startingAt,
                  minimum: minimum,
                  maximumWidth: maximumWidth,
                  measure: { candidate, fontSize in
                      let font = UIFont(name: fontName, size: fontSize)
                          ?? UIFont.systemFont(ofSize: fontSize)
                      return (candidate as NSString).size(withAttributes: [.font: font]).width
                  }
              ) else {
            return false
        }
        label.fontName = fontName
        label.fontSize = size
        return true
    }

    @discardableResult
    private func layoutMilestoneArrival() -> Bool {
        guard isMilestoneArrivalVisible || hasPresentedMilestoneArrival else { return false }

        let insets = view?.safeAreaInsets ?? .zero
        let safeWidth = size.width - insets.left - insets.right
        let safeHeight = size.height - insets.top - insets.bottom
        let compactHeight = battleChromeLayout?.isCompact ?? (size.height < 780)
        let contentWidth = battleChromeLayout?.topBandFrame.width
            ?? min(560, max(0, safeWidth - BattleChromeLayout.sideMargin * 2))
        let width = min(contentWidth, safeWidth - 24)
        let height: CGFloat = compactHeight ? 64 : 76
        guard width >= 120, safeHeight >= height + 24 else {
            finishMilestoneArrivalDismissal()
            return false
        }

        let safeMinY = insets.bottom + 12
        let safeMaxY = size.height - insets.top - 12
        let desiredCenterY = battlefieldLayout.isVisible
            ? battlefieldLayout.frame.midY
            : (safeMinY + safeMaxY) / 2
        let centerY = min(max(desiredCenterY, safeMinY + height / 2), safeMaxY - height / 2)

        milestoneArrivalPanel.update(size: CGSize(width: width, height: height))
        milestoneArrivalPanel.position = CGPoint(x: size.width / 2, y: centerY)
        milestoneArrivalTitleLabel.position = CGPoint(x: 0, y: height * 0.18)
        milestoneArrivalSubtitleLabel.position = CGPoint(x: 0, y: -height * 0.18)

        let titleFits = fitMilestoneLabel(
            milestoneArrivalTitleLabel,
            fontName: GameUITheme.Font.bold,
            startingAt: compactHeight ? 17 : 20,
            minimum: 12,
            maximumWidth: width - 24
        )
        let subtitleFits = fitMilestoneLabel(
            milestoneArrivalSubtitleLabel,
            fontName: GameUITheme.Font.medium,
            startingAt: compactHeight ? 12 : 14,
            minimum: 12,
            maximumWidth: width - 24
        )
        let localBounds = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        guard titleFits,
              subtitleFits,
              localBounds.contains(milestoneArrivalTitleLabel.frame),
              localBounds.contains(milestoneArrivalSubtitleLabel.frame),
              !milestoneArrivalTitleLabel.frame.intersects(milestoneArrivalSubtitleLabel.frame) else {
            finishMilestoneArrivalDismissal()
            return false
        }
        return true
    }

    private func presentMilestoneArrivalIfNeeded() {
        guard state.stageStatus == .battleActive,
              state.pendingBattleResult == nil,
              currentMilestoneTier != nil,
              !hasPresentedMilestoneArrival,
              let definition = Country1CityCatalog.definitionIfPresent(
                  for: state.currentCityKey.cityNumber
              ) else {
            return
        }

        hasPresentedMilestoneArrival = true
        isMilestoneArrivalVisible = true
        milestoneArrivalTitleLabel.text = definition.displayTitle
        milestoneArrivalSubtitleLabel.text = definition.flavorText
        guard layoutMilestoneArrival() else { return }

        milestoneArrivalPanel.isHidden = false
        milestoneArrivalPanel.alpha = 0
        milestoneArrivalPanel.setScale(isReduceMotionEnabled() ? 1 : 0.97)
        #if DEBUG
        milestoneArrivalPresentationCountForTestingStorage += 1
        #endif

        let appear = isReduceMotionEnabled()
            ? SKAction.fadeIn(withDuration: 0.15)
            : SKAction.group([
                SKAction.fadeIn(withDuration: 0.15),
                SKAction.scale(to: 1, duration: 0.15)
            ])
        let wait = SKAction.wait(forDuration: 1.15)
        let disappear = SKAction.fadeOut(withDuration: 0.20)
        let finish = SKAction.run { [weak self] in
            self?.finishMilestoneArrivalDismissal()
        }
        milestoneArrivalPanel.run(
            SKAction.sequence([appear, wait, disappear, finish]),
            withKey: "milestoneArrival"
        )
    }

    private func finishMilestoneArrivalDismissal() {
        milestoneArrivalPanel.removeAllActions()
        milestoneArrivalPanel.isHidden = true
        milestoneArrivalPanel.alpha = 1
        milestoneArrivalPanel.setScale(1)
        isMilestoneArrivalVisible = false
    }

    private func dismissMilestoneArrival(animated: Bool = true) {
        guard isMilestoneArrivalVisible || !milestoneArrivalPanel.isHidden else { return }
        isMilestoneArrivalVisible = false
        milestoneArrivalPanel.removeAllActions()
        guard animated else {
            finishMilestoneArrivalDismissal()
            return
        }
        milestoneArrivalPanel.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.10),
            SKAction.run { [weak self] in self?.finishMilestoneArrivalDismissal() }
        ]))
    }

    private func feedbackSettingsLayoutForCurrentEnvironment() -> FeedbackSettingsLayout? {
        let safeAreaInsets = view?.safeAreaInsets ?? .zero
        return FeedbackSettingsLayout.compute(
            sceneSize: size,
            safeAreaInsets: .init(
                top: safeAreaInsets.top,
                left: safeAreaInsets.left,
                bottom: safeAreaInsets.bottom,
                right: safeAreaInsets.right
            )
        )
    }

    private func buildBattlefield() {
        if UIImage(named: BattleAssetName.battlefieldBackdrop) != nil {
            let backdrop = SKSpriteNode(imageNamed: BattleAssetName.battlefieldBackdrop)
            backdrop.name = BattleAssetName.battlefieldBackdrop
            backdrop.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            backdrop.zPosition = GameUITheme.Z.background
            environmentLayer.addChild(backdrop)
            battlefieldBackdropNode = backdrop
        }

        forgedAtmosphereNode.name = "battleForgedAtmosphere"
        forgedAtmosphereNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        forgedAtmosphereNode.zPosition = GameUITheme.Z.background + 1
        forgedAtmosphereNode.blendMode = .alpha
        forgedAtmosphereNode.alpha = 1
        forgedAtmosphereNode.colorBlendFactor = 0
        environmentLayer.addChild(forgedAtmosphereNode)

        livingKingdomTreatmentNode.name = BattlefieldNodeName.livingKingdomBattlefieldTreatment
        livingKingdomTreatmentNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        livingKingdomTreatmentNode.zPosition = GameUITheme.Z.background + 0.5
        livingKingdomTreatmentNode.blendMode = .alpha
        livingKingdomTreatmentNode.isHidden = true
        environmentLayer.addChild(livingKingdomTreatmentNode)

        let castleNode = makeBattleSprite(
            named: BattleAssetName.playerCastle,
            fallbackColor: SKColor(red: 0.22, green: 0.40, blue: 0.64, alpha: 1.0)
        )
        // Created once with the currently projected fortress asset; later
        // stage changes swap the texture only. All Living Kingdom fortress
        // textures share the 512×540 canvas, so the swap never resizes the
        // node and the semantic "enemy-city" name below never changes.
        let cityNode = makeBattleSprite(
            named: livingKingdomBattlePresentation.fortressAssetName,
            fallbackColor: SKColor(red: 0.58, green: 0.28, blue: 0.26, alpha: 1.0)
        )

        castleNode.name = BattleAssetName.playerCastle
        cityNode.name = BattleAssetName.enemyCity
        playerCastleNode = castleNode
        enemyCityNode = cityNode
        environmentLayer.addChild(castleNode)
        environmentLayer.addChild(cityNode)
        configureCityHPBar()
        environmentLayer.addChild(cityHPBarBackground)
        environmentLayer.addChild(cityHPBarFill)
    }

    private func configureCityHPBar() {
        cityHPBarBackground.name = BattlefieldNodeName.cityHPBarBackground
        cityHPBarBackground.fillColor = SKColor(white: 0.05, alpha: 0.9)
        cityHPBarBackground.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        cityHPBarBackground.lineWidth = 1
        cityHPBarBackground.zPosition = 4

        cityHPBarFill.name = BattlefieldNodeName.cityHPBarFill
        cityHPBarFill.fillColor = SKColor(red: 0.25, green: 0.9, blue: 0.38, alpha: 1.0)
        cityHPBarFill.strokeColor = .clear
        cityHPBarFill.zPosition = 5
    }

    private func makeBattleSprite(named assetName: String, fallbackColor: SKColor) -> SKNode {
        if UIImage(named: assetName) != nil {
            let sprite = SKSpriteNode(imageNamed: assetName)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            return sprite
        }

        let node = SKShapeNode(rect: CGRect(x: -48, y: 0, width: 96, height: 92), cornerRadius: 8)
        node.fillColor = fallbackColor
        node.strokeColor = SKColor(white: 1.0, alpha: 0.22)
        node.lineWidth = 2
        return node
    }

    private var livingKingdomBattlePresentation: LivingKingdomPresentation.Battle {
        LivingKingdomPresentation.battle(
            cityNumber: state.currentCityKey.cityNumber,
            remainingHP: state.currentKeepRemainingPower,
            maxHP: state.currentKeepMaxPower,
            hasPendingConquest: state.pendingBattleResult != nil
        )
    }

    /// Projects the current Living Kingdom fortress stage onto the existing
    /// enemy-city sprite (texture swap only — the node and its semantic name
    /// are never replaced) and syncs the optional battlefield treatment.
    private func applyLivingKingdomStaticPresentation() {
        let presentation = livingKingdomBattlePresentation
        if let citySprite = enemyCityNode as? SKSpriteNode {
            citySprite.texture = SKTexture(imageNamed: presentation.fortressAssetName)
        }
        if let treatmentAssetName = presentation.battlefieldTreatmentAssetName {
            livingKingdomTreatmentNode.texture = SKTexture(imageNamed: treatmentAssetName)
            livingKingdomTreatmentNode.isHidden = false
        } else {
            livingKingdomTreatmentNode.isHidden = true
        }
        #if DEBUG
        appliedLivingKingdomFortressAssetForTestingStorage = presentation.fortressAssetName
        appliedLivingKingdomTreatmentAssetForTestingStorage = presentation.battlefieldTreatmentAssetName
        #endif
    }

    /// Mirrors the backdrop's center position and scale-to-scene fill for the
    /// treatment sprite, matching the existing environment-layer treatment.
    private func layoutLivingKingdomBattlefieldTreatment() {
        guard !livingKingdomTreatmentNode.isHidden,
              let texture = livingKingdomTreatmentNode.texture else {
            return
        }
        livingKingdomTreatmentNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        livingKingdomTreatmentNode.setScale(1)
        let scale = max(
            size.width / max(1, texture.size().width),
            size.height / max(1, texture.size().height)
        )
        livingKingdomTreatmentNode.setScale(scale)
    }

    private func layoutBattlefield(
        contentWidth: CGFloat,
        hpBarBottomY: CGFloat,
        fieldBottomY: CGFloat,
        feedbackY: CGFloat,
        precomputed: BattlefieldLayout? = nil
    ) {
        #if DEBUG
        battlefieldLayoutCount += 1
        #endif

        battlefieldLayout = precomputed ?? BattlefieldLayout.compute(constraints: .init(
                sceneSize: size,
                contentWidth: contentWidth,
                safeTopY: hpBarBottomY - 8,
                safeBottomY: fieldBottomY + 2,
                feedbackY: feedbackY,
                feedbackFontSize: 0
            ))

        if !isConquestReportVisible {
            cancelCityFeedbackActions()
        }

        if !battlefieldLayout.isVisible {
            setBattlefieldHidden(true)
            removeLaneNodes()
            removeLaneIndicatorNodes()
            removeSiegeObjectiveNodes()
            layoutMilestoneCityAccent()
            return
        }

        setBattlefieldHidden(false)

        if let battlefieldBackdropNode {
            battlefieldBackdropNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
            battlefieldBackdropNode.setScale(1)
            let scale = max(
                size.width / max(1, battlefieldBackdropNode.size.width),
                size.height / max(1, battlefieldBackdropNode.size.height)
            )
            battlefieldBackdropNode.setScale(scale)
        }
        applyLivingKingdomStaticPresentation()
        layoutLivingKingdomBattlefieldTreatment()
        if forgedAtmosphereTextureSize != size {
            forgedAtmosphereTextureSize = size
            forgedAtmosphereTexture = makeForgedAtmosphereTexture(size: size)
        }
        forgedAtmosphereNode.texture = forgedAtmosphereTexture
        forgedAtmosphereNode.size = size
        forgedAtmosphereNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        let playerCastleHeight = battleChromeLayout?.isCompact == false
            ? 104
            : battlefieldLayout.structureHeight
        let enemyCityHeight = battleChromeLayout?.isCompact == false
            ? 132
            : battlefieldLayout.enemyCityTargetHeight
        if let playerCastleNode {
            fitBattleNode(playerCastleNode, targetHeight: playerCastleHeight)
        }
        if let enemyCityNode {
            fitBattleNode(enemyCityNode, targetHeight: enemyCityHeight)
        }

        let centerX = size.width / 2
        playerCastleNode?.position = CGPoint(
            x: centerX,
            y: battlefieldLayout.frame.minY + (battleChromeLayout?.isCompact == false ? 6 : 0)
        )
        // The city sprite uses a bottom anchor; the layout's enemy gate is the
        // city base after reserving room for the HP bar above the body.
        enemyCityNode?.position = CGPoint(
            x: centerX,
            y: battleChromeLayout?.isCompact == false
                ? battlefieldLayout.frame.maxY - enemyCityHeight - 2
                : battlefieldLayout.enemyGatePoints[.center]?.y ?? (
                battlefieldLayout.frame.maxY
                    - BattlefieldLayout.enemyCityHPBarClearance
                    - enemyCityHeight
            )
        )

        layoutCityHPBar()
        drawLanePaths()
        layoutLaneIndicators()
        syncSiegeObjectiveNodes()
        syncSoldierNodes()
        layoutMilestoneCityAccent()
        if let transitionFX = effectsLayer.childNode(withName: EffectName.livingKingdomTransitionFX)
            as? SKSpriteNode {
            // Keep an in-flight transition anchored to the fortress without
            // restarting its playback.
            layoutLivingKingdomTransitionFX(transitionFX)
        }
    }

    private func makeForgedAtmosphereTexture(size: CGSize) -> SKTexture? {
        guard size.width > 0, size.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let warmColors = [
                SKColor(red: 52 / 255, green: 26 / 255, blue: 6 / 255, alpha: 0.60).cgColor,
                SKColor(red: 30 / 255, green: 16 / 255, blue: 4 / 255, alpha: 0.10).cgColor,
                SKColor(red: 46 / 255, green: 14 / 255, blue: 4 / 255, alpha: 0.55).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: warmColors,
                locations: [0, 0.44, 1]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width / 2, y: 0),
                    end: CGPoint(x: size.width / 2, y: size.height),
                    options: []
                )
            }

            let vignetteColors = [
                SKColor(white: 0, alpha: 0).cgColor,
                SKColor(red: 24 / 255, green: 10 / 255, blue: 2 / 255, alpha: 0.62).cgColor
            ] as CFArray
            if let vignette = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: vignetteColors,
                locations: [0, 1]
            ) {
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
                context.cgContext.scaleBy(x: 1, y: size.height / size.width)
                context.cgContext.drawRadialGradient(
                    vignette,
                    startCenter: .zero,
                    startRadius: size.width * 0.20,
                    endCenter: .zero,
                    endRadius: size.width * 0.68,
                    options: .drawsAfterEndLocation
                )
                context.cgContext.restoreGState()
            }
        }
        return SKTexture(image: image)
    }

    private func layoutMilestoneCityAccent() {
        guard let tier = currentMilestoneTier,
              battlefieldLayout.isVisible,
              let enemyCityNode else {
            milestoneCityAccent.isHidden = true
            milestoneCityAccent.path = nil
            return
        }

        let cityFrame = enemyCityNode.calculateAccumulatedFrame()
        let expansion: CGFloat
        switch tier {
        case .first:
            expansion = 5
        case .second:
            expansion = 7
        case .finale:
            expansion = 9
        }

        let insets = view?.safeAreaInsets ?? .zero
        let safeFrame = CGRect(
            x: insets.left,
            y: insets.bottom,
            width: max(0, size.width - insets.left - insets.right),
            height: max(0, size.height - insets.top - insets.bottom)
        )
        let accentFrame = cityFrame
            .insetBy(dx: -expansion, dy: -expansion)
            .intersection(safeFrame)
        guard !accentFrame.isNull, accentFrame.width > 0, accentFrame.height > 0 else {
            milestoneCityAccent.isHidden = true
            milestoneCityAccent.path = nil
            return
        }

        milestoneCityAccent.path = CGPath(
            roundedRect: accentFrame,
            cornerWidth: 12,
            cornerHeight: 12,
            transform: nil
        )
        switch tier {
        case .first:
            milestoneCityAccent.lineWidth = 2
            milestoneCityAccent.glowWidth = 1
        case .second:
            milestoneCityAccent.lineWidth = 3
            milestoneCityAccent.glowWidth = 3
        case .finale:
            milestoneCityAccent.lineWidth = 4
            milestoneCityAccent.glowWidth = 5
        }
        milestoneCityAccent.isHidden = false
    }

    private func hideCityHPBar() {
        cityHPBarBackground.isHidden = true
        cityHPBarFill.isHidden = true
        cityHPBarBackground.path = nil
        cityHPBarFill.path = nil
    }

    private func layoutCityHPBar() {
        #if DEBUG
        layoutCityHPBarCallCount &+= 1
        #endif
        guard battleChromeLayout?.isCompact != false else {
            hideCityHPBar()
            return
        }
        guard !isConquestReportVisible, !isConquestReportFitFailed else {
            hideCityHPBar()
            return
        }
        cityHPBarBackground.isHidden = false
        cityHPBarFill.isHidden = false
        guard battlefieldLayout.isVisible, let enemyCityNode else {
            cityHPBarBackground.path = nil
            cityHPBarFill.path = nil
            return
        }

        let cityFrame = enemyCityNode.calculateAccumulatedFrame()
        guard cityFrame.width > 0, cityFrame.height > 0 else {
            cityHPBarBackground.path = nil
            cityHPBarFill.path = nil
            return
        }

        let width = max(96, min(180, cityFrame.width * 0.72))
        let height: CGFloat = 7
        let topLimitY = battlefieldLayout.frame.maxY - height - 2
        let y = min(topLimitY, cityFrame.maxY + 4)
        let percent = min(max(CGFloat(state.currentKeepRemainingPower)
            / CGFloat(max(1, state.currentKeepMaxPower)), 0), 1)
        let backgroundRect = CGRect(
            x: cityFrame.midX - width / 2,
            y: y,
            width: width,
            height: height
        )
        let fillRect = CGRect(
            x: backgroundRect.minX,
            y: backgroundRect.minY,
            width: max(1, backgroundRect.width * percent),
            height: backgroundRect.height
        )

        cityHPBarBackground.path = CGPath(
            roundedRect: backgroundRect,
            cornerWidth: height / 2,
            cornerHeight: height / 2,
            transform: nil
        )
        if state.currentKeepRemainingPower > 0 {
            cityHPBarFill.path = CGPath(
                roundedRect: fillRect,
                cornerWidth: height / 2,
                cornerHeight: height / 2,
                transform: nil
            )
        } else {
            cityHPBarFill.path = nil
        }
    }

    private func fitBattleNode(_ node: SKNode, targetHeight: CGFloat) {
        guard targetHeight > 0 else {
            return
        }

        node.setScale(1)

        let currentHeight: CGFloat
        if let sprite = node as? SKSpriteNode {
            currentHeight = sprite.size.height
        } else if let shape = node as? SKShapeNode {
            currentHeight = shape.frame.height
        } else {
            currentHeight = node.calculateAccumulatedFrame().height
        }

        guard currentHeight > 0 else {
            return
        }

        node.setScale(targetHeight / currentHeight)
    }

    private func drawLanePaths() {
        removeLaneNodes()

        let laneWidth = battlefieldLayout.lanePathWidth
        for lane in BattleLane.allCases {
            guard let start = battlefieldLayout.castleGatePoints[lane],
                  let end = battlefieldLayout.enemyGatePoints[lane] else {
                continue
            }

            let laneRect = CGRect(
                x: start.x - laneWidth / 2,
                y: start.y,
                width: laneWidth,
                height: max(0, end.y - start.y)
            )
            let node = SKShapeNode(rect: laneRect, cornerRadius: min(22, laneWidth * 0.22))
            node.name = "battleLaneTerrain-\(lane.rawValue)"
            node.fillColor = laneTerrainColor(for: lane)
            node.strokeColor = SKColor(red: 0.75, green: 0.64, blue: 0.39, alpha: 0.22)
            node.lineWidth = 1
            node.zPosition = -1
            addLaneTerrainDetails(to: node, lane: lane, rect: laneRect)
            environmentLayer.addChild(node)
            laneNodes.append(node)
        }
    }

    private func laneTerrainColor(for lane: BattleLane) -> SKColor {
        switch lane {
        case .left:
            return SKColor(red: 0.32, green: 0.42, blue: 0.23, alpha: 0.12)
        case .center:
            return SKColor(red: 0.70, green: 0.54, blue: 0.29, alpha: 0.14)
        case .right:
            return SKColor(red: 0.30, green: 0.40, blue: 0.24, alpha: 0.12)
        }
    }

    private func addLaneTerrainDetails(to laneNode: SKShapeNode, lane: BattleLane, rect: CGRect) {
        let detailCount = max(4, min(9, Int(rect.height / 58)))
        guard detailCount > 0 else {
            return
        }

        for index in 0..<detailCount {
            let progress = (CGFloat(index) + 0.5) / CGFloat(detailCount)
            let lateralPattern = CGFloat(((index * 37 + lane.rawValue * 19) % 100)) / 100
            let x = rect.minX + rect.width * (0.20 + lateralPattern * 0.60)
            let y = rect.minY + rect.height * progress
            let radius = CGFloat(2 + ((index + lane.rawValue) % 3))
            let detail = SKShapeNode(circleOfRadius: radius)
            detail.name = "battleLaneDetail-\(lane.rawValue)-\(index)"
            detail.fillColor = index.isMultiple(of: 2)
                ? SKColor(red: 0.20, green: 0.29, blue: 0.14, alpha: 0.28)
                : SKColor(red: 0.62, green: 0.51, blue: 0.32, alpha: 0.24)
            detail.strokeColor = .clear
            detail.position = CGPoint(x: x, y: y)
            detail.zPosition = 1
            laneNode.addChild(detail)
        }

        let ridgeRect = CGRect(
            x: rect.midX - rect.width * 0.08,
            y: rect.minY,
            width: rect.width * 0.16,
            height: rect.height
        )
        let centerRidge = SKShapeNode(rect: ridgeRect, cornerRadius: rect.width * 0.08)
        centerRidge.name = "battleLaneDetail-\(lane.rawValue)-ridge"
        centerRidge.fillColor = SKColor(red: 0.77, green: 0.62, blue: 0.34, alpha: 0.08)
        centerRidge.strokeColor = .clear
        centerRidge.zPosition = 0.5
        laneNode.addChild(centerRidge)
    }

    private func removeLaneNodes() {
        laneNodes.forEach { $0.removeFromParent() }
        laneNodes.removeAll()
    }

    private func layoutLaneIndicators() {
        removeLaneIndicatorNodes()

        let profile = state.currentCityLaneDefenseProfile
        for lane in BattleLane.allCases {
            let role = profile.role(for: lane)
            guard role != .standard, let gate = battlefieldLayout.enemyGatePoints[lane] else {
                continue
            }

            let indicator = makeLaneIndicator(role: role)
            indicator.position = CGPoint(x: gate.x, y: gate.y - 18)
            indicator.zPosition = 2
            environmentLayer.addChild(indicator)
            laneIndicatorNodes.append(indicator)
        }
    }

    /// Builds a lane-defense-role indicator glyph (shield, cracked shield, or plain).
    /// Shield is drawn in a ~16×19 pt local coordinate space (x: −8…+8, y: −10…+9).
    private func makeLaneIndicator(role: LaneDefenseRole) -> SKNode {
        let container = SKNode()
        container.name = "laneIndicator-\(role.rawValue)"

        // Shield outline in a 16×19 pt local space
        let shieldPath = CGMutablePath()
        shieldPath.move(to: CGPoint(x: 0, y: 9))
        shieldPath.addLine(to: CGPoint(x: 8, y: 5))
        shieldPath.addLine(to: CGPoint(x: 8, y: -2))
        shieldPath.addCurve(
            to: CGPoint(x: 0, y: -10),
            control1: CGPoint(x: 8, y: -6),
            control2: CGPoint(x: 5, y: -9)
        )
        shieldPath.addCurve(
            to: CGPoint(x: -8, y: -2),
            control1: CGPoint(x: -5, y: -9),
            control2: CGPoint(x: -8, y: -6)
        )
        shieldPath.addLine(to: CGPoint(x: -8, y: 5))
        shieldPath.closeSubpath()

        let shield = SKShapeNode(path: shieldPath)
        shield.lineWidth = 1.5

        switch role {
        case .fortified:
            shield.fillColor = GameUITheme.Color.danger
            shield.strokeColor = SKColor(white: 1.0, alpha: 0.7)
        case .exposed:
            shield.fillColor = SKColor(white: 0.55, alpha: 0.55)
            shield.strokeColor = SKColor(white: 1.0, alpha: 0.4)
            let crackPath = CGMutablePath()
            crackPath.move(to: CGPoint(x: -2, y: 9))
            crackPath.addLine(to: CGPoint(x: 2, y: 2))
            crackPath.addLine(to: CGPoint(x: -1, y: -3))
            crackPath.addLine(to: CGPoint(x: 2, y: -10))
            let crack = SKShapeNode(path: crackPath)
            crack.strokeColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1.0)
            crack.lineWidth = 2
            crack.zPosition = 1
            container.addChild(crack)
        case .standard:
            break
        }

        container.addChild(shield)
        return container
    }

    private func removeLaneIndicatorNodes() {
        laneIndicatorNodes.forEach { $0.removeFromParent() }
        laneIndicatorNodes.removeAll()
    }

    // MARK: Falconridge siege objective visuals (HPA-468 pilot)

    /// Rebuilds the procedural pilot-objective visuals from the current
    /// siege snapshot. Local to BattleScene on purpose: the Keep stays the
    /// `enemy-city` sprite, and these builders are the only scene objects —
    /// no duplicate objective state, no generic scene-object framework.
    /// Every placement reads `Objective.visualProgress` through the shared
    /// battlefield lane geometry.
    private func syncSiegeObjectiveNodes() {
        guard battlefieldLayout.isVisible else {
            removeSiegeObjectiveNodes()
            return
        }

        let snapshot = state.currentSiegeSnapshot
        if appliedSiegeObjectiveSnapshot == snapshot,
           appliedSiegeObjectiveGeometry == battlefieldLayout,
           appliedSiegeObjectiveMaxPower == state.cityMaxPower {
            return
        }
        removeSiegeObjectiveNodes()
        appliedSiegeObjectiveSnapshot = snapshot
        appliedSiegeObjectiveGeometry = battlefieldLayout
        appliedSiegeObjectiveMaxPower = state.cityMaxPower
        let layout = snapshot.layout
        let remaining = snapshot.objectiveRemainingPower
        let maxPowers = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)

        for objective in layout.objectives where objective.kind != .keep {
            let node: SKNode
            switch objective.kind {
            case .arrowTower:
                node = makeArrowTowerObjective(
                    objective,
                    remainingPower: remaining[objective.id, default: 0],
                    maxPower: maxPowers[objective.id, default: 0]
                )
            case .gate:
                node = makeGateObjective(
                    objective,
                    layout: layout,
                    remainingPower: remaining[objective.id, default: 0],
                    maxPower: maxPowers[objective.id, default: 0]
                )
            case .barracks:
                node = makeBarracksObjective(
                    objective,
                    remainingPower: remaining[objective.id, default: 0],
                    maxPower: maxPowers[objective.id, default: 0]
                )
            case .keep:
                continue
            }
            environmentLayer.addChild(node)
            siegeObjectiveNodes[objective.id] = node
        }

        // Live-tower coverage treatment: a quiet danger tint on each covered
        // lane's in-range band, present only while the source tower lives.
        if let source = layout.objective(id: layout.defensiveFire.sourceObjectiveID),
           source.kind != .keep,
           remaining[source.id, default: 0] > 0 {
            for lane in layout.defensiveFire.coveredLanes {
                environmentLayer.addChild(makeCoverageNode(for: lane, source: source))
            }
        }
    }

    private func removeSiegeObjectiveNodes() {
        for node in environmentLayer.children where isSiegeObjectiveNode(node) {
            node.removeFromParent()
        }
        siegeObjectiveNodes.removeAll()
        appliedSiegeObjectiveSnapshot = nil
        appliedSiegeObjectiveGeometry = nil
        appliedSiegeObjectiveMaxPower = nil
    }

    private func isSiegeObjectiveNode(_ node: SKNode) -> Bool {
        guard let name = node.name else { return false }
        return name.hasPrefix(SiegeObjectiveNodeName.prefix)
            || name.hasPrefix(SiegeObjectiveNodeName.coveragePrefix)
    }

    /// Arrow Tower at its authored progress: bottom-center anchored
    /// structure with an HP bar, or a rubble ruin once destroyed.
    private func makeArrowTowerObjective(
        _ objective: CitySiegeLayout.Objective,
        remainingPower: Int,
        maxPower: Int
    ) -> SKNode {
        let container = SKNode()
        container.name = SiegeObjectiveNodeName.prefix + objective.id
        container.position = point(forLane: objective.visualLane, position: objective.visualProgress)
        container.zPosition = 3

        let width = max(16, battlefieldLayout.lanePathWidth * 0.36)
        let height = width * 1.8
        let isRuined = remainingPower <= 0
        let structure = makeSiegeStructure(
            assetName: SiegeObjectiveAssetContract.arrowTower,
            targetSize: CGSize(width: width, height: height),
            intactColor: SKColor(red: 0.45, green: 0.42, blue: 0.40, alpha: 1),
            ruinedColor: SKColor(red: 0.30, green: 0.26, blue: 0.22, alpha: 1),
            isRuined: isRuined
        )
        structure.name = SiegeObjectiveNodeName.structure
        container.addChild(structure)

        if isRuined {
            container.addChild(makeRuinMarker(width: width))
        } else {
            addObjectiveHPBar(
                to: container,
                width: width,
                bottomY: height + 3,
                remaining: remainingPower,
                maximum: maxPower
            )
        }
        return container
    }

    /// One segment per blocked lane plus a single shared HP/ruin indicator
    /// across the span; safe approaches stay clear.
    private func makeGateObjective(
        _ objective: CitySiegeLayout.Objective,
        layout: CitySiegeLayout,
        remainingPower: Int,
        maxPower: Int
    ) -> SKNode {
        let container = SKNode()
        container.name = SiegeObjectiveNodeName.prefix + objective.id
        let isRuined = remainingPower <= 0
        let progress = objective.visualProgress
        let spannedLanes = BattleLane.allCases.filter { lane in
            layout.routes[lane]?.contains(objective.id) == true
        }
        let xs = spannedLanes.map { point(forLane: $0, position: progress).x }
        let halfLane = battlefieldLayout.lanePathWidth / 2
        let spanMinX = (xs.min() ?? 0) - halfLane
        let spanMaxX = (xs.max() ?? 0) + halfLane
        let basePoint = point(forLane: objective.visualLane, position: progress)
        container.position = CGPoint(
            x: (spanMinX + spanMaxX) / 2,
            y: basePoint.y
        )
        container.zPosition = 3

        let height = max(10, battlefieldLayout.lanePathWidth * 0.5)
        for laneX in xs {
            let offsetX = laneX - container.position.x
            let structure = makeSiegeStructure(
                assetName: SiegeObjectiveAssetContract.gate,
                targetSize: CGSize(width: battlefieldLayout.lanePathWidth, height: height),
                intactColor: SKColor(red: 0.55, green: 0.38, blue: 0.20, alpha: 1),
                ruinedColor: SKColor(red: 0.30, green: 0.24, blue: 0.18, alpha: 1),
                isRuined: isRuined
            )
            structure.name = SiegeObjectiveNodeName.structure
            // One bottom-anchored segment per blocked approach keeps safe lanes clear.
            structure.position = CGPoint(x: offsetX, y: -height / 2)
            container.addChild(structure)
        }

        guard !xs.isEmpty else { return container }
        if isRuined {
            let ruin = makeRuinMarker(width: battlefieldLayout.lanePathWidth * 0.6)
            ruin.position = CGPoint(x: 0, y: -height / 2)
            container.addChild(ruin)
        } else {
            addObjectiveHPBar(
                to: container,
                width: min(64, battlefieldLayout.lanePathWidth * 0.8),
                bottomY: height / 2 + 3,
                remaining: remainingPower,
                maximum: maxPower
            )
        }
        return container
    }

    /// The Country 1 Guard Barracks objective (HPA-469 pilot, HPA-477 rollout): bottom-center anchored
    /// structure with an HP bar and a compact attached status label, or a
    /// rubble ruin labeled SHUT DOWN once destroyed. Reuses the shared
    /// siege structure/HP/ruin helpers — only the label is Barracks-specific.
    private func makeBarracksObjective(
        _ objective: CitySiegeLayout.Objective,
        remainingPower: Int,
        maxPower: Int
    ) -> SKNode {
        let container = SKNode()
        container.name = SiegeObjectiveNodeName.prefix + objective.id
        container.position = point(forLane: objective.visualLane, position: objective.visualProgress)
        container.zPosition = 3

        let width = max(18, battlefieldLayout.lanePathWidth * 0.42)
        let height = width * 1.5
        let isRuined = remainingPower <= 0
        let structure = makeSiegeStructure(
            assetName: SiegeObjectiveAssetContract.barracks,
            targetSize: CGSize(width: width, height: height),
            intactColor: SKColor(red: 0.42, green: 0.32, blue: 0.19, alpha: 1),
            ruinedColor: SKColor(red: 0.28, green: 0.23, blue: 0.17, alpha: 1),
            isRuined: isRuined
        )
        structure.name = SiegeObjectiveNodeName.structure
        container.addChild(structure)

        if isRuined {
            container.addChild(makeRuinMarker(width: width))
        } else {
            addObjectiveHPBar(
                to: container,
                width: width * 0.8,
                bottomY: height + 3,
                remaining: remainingPower,
                maximum: maxPower
            )
        }

        let statusLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        statusLabel.name = GuardNodeName.statusLabel
        statusLabel.fontSize = 9
        statusLabel.fontColor = GameUITheme.Color.textSecondary
        statusLabel.verticalAlignmentMode = .bottom
        statusLabel.position = CGPoint(x: 0, y: height + 10)
        statusLabel.zPosition = 16
        statusLabel.text = barracksStatusText
        container.addChild(statusLabel)
        return container
    }

    /// Durable-state-driven Barracks status (HPA-469): `GUARDS <count>` while
    /// the Barracks is alive and reserve remains, `SHUT DOWN` after its death,
    /// no label once the reserve is spent. Recomputed from persisted state so
    /// it can never drift from the synced Guard snapshots.
    private var barracksStatusText: String {
        let snapshot = state.currentSiegeSnapshot
        guard let barracks = snapshot.layout.barracksObjective else {
            return ""
        }
        guard snapshot.objectiveRemainingPower[barracks.id, default: 0] > 0 else {
            return "SHUT DOWN"
        }
        guard let progress = state.siegeProgress.guardReinforcements,
              progress.remainingReserve > 0 else {
            return ""
        }
        return "GUARDS \(progress.unresolvedGuards.count)"
    }

    /// Fits bottom-anchored shipping art to scene geometry, with a shape if art is unavailable.
    private func makeSiegeStructure(
        assetName: String,
        targetSize: CGSize,
        intactColor: SKColor,
        ruinedColor: SKColor,
        isRuined: Bool
    ) -> SKNode {
        let variantName = isRuined ? assetName + "-ruined" : assetName
        if let image = UIImage(named: variantName) {
            let texture = siegeStructureTextures[variantName] ?? SKTexture(imageNamed: variantName)
            siegeStructureTextures[variantName] = texture
            let sprite = SKSpriteNode(texture: texture)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            let scale = min(
                targetSize.width / max(1, image.size.width),
                targetSize.height / max(1, image.size.height)
            )
            sprite.size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            return sprite
        }

        let rect = CGRect(x: -targetSize.width / 2, y: 0, width: targetSize.width, height: targetSize.height)
        let shape = SKShapeNode(rect: rect, cornerRadius: 4)
        shape.fillColor = isRuined ? ruinedColor : intactColor
        shape.strokeColor = SKColor(white: 1.0, alpha: 0.25)
        shape.lineWidth = 1
        return shape
    }

    /// Small rubble cluster marking a destroyed objective.
    private func makeRuinMarker(width: CGFloat) -> SKNode {
        let ruin = SKNode()
        ruin.name = SiegeObjectiveNodeName.ruin
        ruin.zPosition = 1
        let rubbleColor = SKColor(red: 0.24, green: 0.20, blue: 0.16, alpha: 1)
        for (index, offset) in [-0.32, 0.0, 0.34].enumerated() {
            let stone = SKShapeNode(circleOfRadius: width * (index == 1 ? 0.16 : 0.11))
            stone.fillColor = rubbleColor
            stone.strokeColor = .clear
            stone.position = CGPoint(x: width * offset, y: width * 0.08)
            ruin.addChild(stone)
        }
        return ruin
    }

    /// Objective HP bar (background + fill) hovering above the structure.
    /// Shapes attach directly to the objective container so the fill is
    /// reachable by name for tests and stays aligned with the structure.
    private func addObjectiveHPBar(
        to container: SKNode,
        width: CGFloat,
        bottomY: CGFloat,
        centerX: CGFloat = 0,
        remaining: Int,
        maximum: Int
    ) {
        let barHeight: CGFloat = 4
        let barY = bottomY
        let percent = min(max(CGFloat(remaining) / CGFloat(max(1, maximum)), 0), 1)

        let background = SKShapeNode()
        background.name = "siegeHPBackground"
        background.fillColor = SKColor(white: 0.05, alpha: 0.9)
        background.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        background.lineWidth = 1
        // Keep objective status above actors, below battlefield effects.
        background.zPosition = 14
        background.position.x = centerX
        background.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: barY, width: width, height: barHeight),
            cornerWidth: barHeight / 2,
            cornerHeight: barHeight / 2,
            transform: nil
        )
        container.addChild(background)

        let fill = SKShapeNode()
        fill.name = SiegeObjectiveNodeName.hpFill
        fill.fillColor = SKColor(red: 0.85, green: 0.33, blue: 0.20, alpha: 1)
        fill.strokeColor = .clear
        fill.zPosition = 15
        fill.position.x = centerX
        fill.path = CGPath(
            roundedRect: CGRect(
                x: -width / 2,
                y: barY,
                width: max(1, width * percent),
                height: barHeight
            ),
            cornerWidth: barHeight / 2,
            cornerHeight: barHeight / 2,
            transform: nil
        )
        container.addChild(fill)
    }

    /// Quiet danger tint over the band of `lane` inside the live source's
    /// defensive-fire range (`source.visualProgress - range ... progress`).
    private func makeCoverageNode(for lane: BattleLane, source: CitySiegeLayout.Objective) -> SKNode {
        let range = max(0, min(1, combat.configuration.towerAttackRange))
        let from = point(forLane: lane, position: max(0, source.visualProgress - range))
        let to = point(forLane: lane, position: source.visualProgress)
        let width = battlefieldLayout.lanePathWidth * 0.5
        let node = SKShapeNode(rect: CGRect(
            x: from.x - width / 2,
            y: from.y,
            width: width,
            height: max(0, to.y - from.y)
        ))
        node.name = SiegeObjectiveNodeName.coveragePrefix + String(lane.rawValue)
        node.fillColor = SKColor(red: 0.90, green: 0.25, blue: 0.15, alpha: 0.10)
        node.strokeColor = .clear
        node.zPosition = 1.5
        return node
    }

    private func setBattlefieldHidden(_ isHidden: Bool) {
        environmentLayer.isHidden = isHidden
        soldierLayer.isHidden = isHidden
        effectsLayer.isHidden = isHidden
    }

    private var manualSpawnableSoldierTypes: [SoldierType] {
        state.manualSpawnableSoldierTypes()
    }

    private func reconcileSelectedManualSoldierType() {
        let spawnableTypes = manualSpawnableSoldierTypes
        if !spawnableTypes.contains(selectedManualSoldierType), let firstSpawnableType = spawnableTypes.first {
            selectedManualSoldierType = firstSpawnableType
        }
    }

    private func redraw(shouldLayout: Bool = true) {
        reconcileSelectedManualSoldierType()
        feedbackLabel.text = feedbackText
        if shouldLayout {
            layoutInterface()
        } else {
            layoutCityHPBar()
            applyLivingKingdomStaticPresentation()
            syncSiegeObjectiveNodes()
            applyBattleHUD()
        }
        syncGuardNodes()
        presentFeedbackTooltipIfNeeded()
    }

    private func refreshBattleHUD() {
        layoutCityHPBar()
        applyBattleHUD()
    }

    private func presentFeedbackTooltipIfNeeded() {
        guard !feedbackText.isEmpty, feedbackText != lastPresentedTooltipText else {
            return
        }

        showTooltip(feedbackText)
    }

    private func showTooltip(_ text: String) {
        guard !text.isEmpty else {
            return
        }

        lastPresentedTooltipText = text
        feedbackLabel.text = text
        let feedbackPanelWidth = min(cachedContentWidth, max(220, feedbackLabel.frame.width + 32))
        feedbackPanel.update(size: CGSize(width: feedbackPanelWidth, height: max(32, feedbackLabel.fontSize + 18)))
        feedbackPanel.position = feedbackLabel.position
        feedbackPanel.removeAllActions()
        feedbackLabel.removeAllActions()
        feedbackPanel.alpha = 1
        feedbackLabel.alpha = 1

        let panelWait = SKAction.wait(forDuration: EffectStyle.tooltipVisibleDuration)
        let panelFade = SKAction.fadeOut(withDuration: 0.22)
        let labelWait = SKAction.wait(forDuration: EffectStyle.tooltipVisibleDuration)
        let labelFade = SKAction.fadeOut(withDuration: 0.22)
        // Reset the dedupe token once the tooltip finishes fading out so a
        // repeated action warning can re-trigger the tooltip.
        let resetToken = SKAction.run { [weak self] in
            self?.resetFeedbackTooltipDedupeToken()
        }
        feedbackPanel.run(SKAction.sequence([panelWait, panelFade, resetToken]), withKey: "feedbackTooltip")
        feedbackLabel.run(SKAction.sequence([labelWait, labelFade]), withKey: "feedbackTooltip")
    }

    /// Clears the tooltip dedupe token. Called by the fade-out `SKAction` once
    /// the tooltip has fully hidden, so a subsequent identical feedback message
    /// can re-trigger the tooltip instead of being silently suppressed.
    private func resetFeedbackTooltipDedupeToken() {
        lastPresentedTooltipText = ""
    }

    /// Durable-state-driven gate for the shared progress-save cadence
    /// (HPA-469): true while Country 1 Guard reinforcement has something to
    /// persist — the Barracks is alive and waves remain in reserve or Guards
    /// are unresolved. No second timer: this only broadens the existing
    /// two-second cadence condition.
    private var isGuardReinforcementProgressActive: Bool {
        guard let progress = state.siegeProgress.guardReinforcements,
              let barracks = state.currentSiegeLayout.barracksObjective else {
            return false
        }
        let barracksAlive = state.currentSiegeSnapshot
            .objectiveRemainingPower[barracks.id, default: 0] > 0
        return barracksAlive
            && (progress.remainingReserve > 0 || !progress.unresolvedGuards.isEmpty)
    }

    /// Broadens the existing two-second progress-save cadence (HPA-469) to
    /// ticks whose only durable change is the Captain recovery countdown
    /// (HPA-475). No second timer.
    private var isCaptainRecoveryProgressActive: Bool {
        guard let captain = state.siegeProgress.captain else {
            return false
        }
        return captain.remainingHP == 0 && captain.recoveryRemainingSeconds > 0
    }

    private func advanceCombat(deltaTime: TimeInterval) {
        guard state.stageStatus == .battleActive,
              !isConquestReportVisible,
              !isFeedbackSettingsVisible else {
            return
        }

        let clampedDeltaTime = combat.clampedDeltaTime(deltaTime)
        if clampedDeltaTime > 0 {
            state.recordActiveBattleTime(clampedDeltaTime)
        }

        #if DEBUG
        lastAdvanceCombatDeltaForTestingStorage = deltaTime
        #endif

        let shouldSaveProgress = deltaTime > 0
            && (state.cityBattleStateForCurrentCity.occupiedSlotCount > 0
                || isGuardReinforcementProgressActive
                || isCaptainRecoveryProgressActive)
        let buildingSpawns = state.resolveActiveBuildingSpawns(deltaTime: deltaTime)
        for spawn in buildingSpawns {
            let soldierID = combat.spawnSoldier(
                type: spawn.soldierType,
                source: .building,
                level: spawn.level,
                attackPower: state.traitAdjustedSoldierAttackPower(for: spawn.soldierType, level: spawn.level),
                lane: state.siegeProgress.selectedLane,
                maxHPMultiplier: state.equipmentMaxHPMultiplier(for: spawn.soldierType),
                specialistBonus: state.equipmentSpecialistBonus(for: spawn.soldierType)
            )
            if let soldier = combat.soldier(id: soldierID) {
                state.recordSoldierDeployment(type: soldier.type, source: soldier.source, lane: soldier.lane)
            }
            createSoldierNode(id: soldierID)
        }
        // One save per tick (HPA-475): every durable mutation below — spawn
        // timers, ordinary attacks/losses, Captain damage/HP/retreat/recovery,
        // Guard snapshots/waves — marks the flag and the tick persists once.
        // The auto-Rally funnel below is the one exception: it saves inside
        // activateRally() (the consumption bit must land before protection
        // starts) and saves a second time here when the flag is also set.
        // Crash semantics are unchanged: the write still lands before the
        // frame returns to the run loop.
        var tickNeedsSave = updateBuildingProgressSaveCadence(
            deltaTime: deltaTime,
            shouldSaveProgress: shouldSaveProgress,
            spawnFired: !buildingSpawns.isEmpty
        )

        // Decrement hit-reaction countdowns BEFORE combat.tick arms any new
        // timers in applyCombatResult. Arming at 0.9s and then subtracting
        // deltaTime in the same tick would shorten every hit animation by one
        // frame; decrementing first means timers armed this tick keep their
        // full authored duration and are first reduced on the next tick.
        //
        // The countdown is decremented by the RAW frame delta, not the clamped
        // combat delta. The hit SKAction advances by real frame time (SpriteKit
        // does not clamp SKAction deltas), so the countdown must track the same
        // clock to stay in sync with the visual pose. Clamping the countdown to
        // `maxDeltaTime` would make it lag behind the SKAction during a stall
        // longer than the hit duration: the SKAction would finish and remove
        // itself while the countdown still reported time remaining, falsely
        // suppressing the next attack trigger even though no hit pose is
        // playing. The combat tick's attack cooldown is still clamped, so
        // attack IDs cannot fire faster than the clamped combat clock — the
        // countdown lifting early cannot produce an attack that the combat
        // tick hasn't authorized. Building spawn resolution also uses the raw
        // `deltaTime` so production reflects real elapsed time during stalls.
        decrementSoldierHitAnimationRemaining(deltaTime: deltaTime)
        decrementGuardAnimationRemaining(deltaTime: deltaTime)

        let chargesBeforeTick = combat.manualDeployCharges
        let result = combat.tick(
            deltaTime: deltaTime,
            siege: state.currentSiegeSnapshot,
            rallyAutoTriggerAvailable: isRallyAutoTriggerAvailable
        )
        // HPA-582: the Deploy label tracks the integer charge count only —
        // fractional recharge progress never triggers a refresh.
        let chargesChanged = combat.manualDeployCharges != chargesBeforeTick
        // A refill retires the recharge denial — otherwise the stale
        // message re-presents its tooltip on the next non-attack redraw.
        if combat.manualDeployCharges > chargesBeforeTick,
           feedbackText == Self.deployRechargingMessage {
            feedbackText = ""
        }
        feedback.emitAutomaticCombat(result)
        // Named locals — not `||` chaining — so all three sinks always run;
        // a short-circuit would skip Captain/Guard sync whenever an earlier
        // sink already reported a durable change.
        objectiveDamageThisTick.removeAll()
        objectiveDamageSourcesThisTick.removeAll()
        let attacksMutatedState = applyCombatResult(result)
        let captainMutatedState = synchronizeAndPersistCaptain(result, deltaTime: clampedDeltaTime)
        objectiveDamageThisTick.removeAll()
        objectiveDamageSourcesThisTick.removeAll()
        let guardsMutatedState = synchronizeAndPersistCountry1Guards(deltaTime: clampedDeltaTime)
        tickNeedsSave = tickNeedsSave
            || attacksMutatedState
            || captainMutatedState
            || guardsMutatedState
        // Auto Rally fires after the current tick returns (HPA-475): the
        // triggering hit and any later same-tick hit stay unprotected; the
        // next tick is the first protected one. `activateRally` keeps its own
        // save inside the funnel — the durable consumption bit must persist
        // before the transient protection begins.
        if result.shouldAutoActivateRally {
            activateRally()
        }
        if tickNeedsSave {
            store.save(state)
        }

        syncSoldierNodes(elapsedCombatTime: clampedDeltaTime)
        // Teardown can clear the target during the result sinks above. Never
        // restore it (or create a shot for a reused id) after that happens.
        for shot in result.towerShots where lastDefensiveShotTargetID == shot.soldierID {
            playTowerShot(at: shot.soldierID)
        }
        syncGuardNodes()
        // City 3+ Captain strip content (live HP, Rally countdown, recovery
        // countdown) changes over time, so while a Captain is in play the
        // HUD re-applies on the coarser Captain cadence rather than every
        // combat tick. Cities 1–2 have no Captain and keep their existing
        // refresh triggers unchanged (HPA-475).
        if !buildingSpawns.isEmpty {
            // A spawn-driven refresh just ran — restart the Captain
            // cadence from this fresh apply.
            captainHUDRefreshAccumulator = 0
            applyBattleHUD()
        } else if chargesChanged
            || combat.isGuardBlockerEngaged(onLane: state.siegeProgress.selectedLane)
                != lastAppliedLaneGuardBlockerEngaged {
            // Guard-blocker engagement flips the lane's role-multiplier
            // projection without producing soldier attacks — a wave
            // landing in reach, the blocker falling — so it refreshes
            // here on transition only (HPA-582 review). Mid-tick applies
            // (losses, Captain) already stamped the current flag, so a
            // same-tick flip plus their refresh costs no extra rebuild.
            applyBattleHUD()
        } else {
            refreshCaptainHUDOnCadence(deltaTime: deltaTime)
        }
    }

    /// Advances the building-progress save cadence for one tick (HPA-475).
    /// A spawn forces a write so a crash can never double-spawn; otherwise
    /// the two-second accumulator decides. Returns whether this tick needs
    /// a persistence write.
    private func updateBuildingProgressSaveCadence(
        deltaTime: TimeInterval,
        shouldSaveProgress: Bool,
        spawnFired: Bool
    ) -> Bool {
        guard shouldSaveProgress else {
            return false
        }
        if spawnFired {
            buildingProgressSaveAccumulator = 0
            return true
        }
        buildingProgressSaveAccumulator += deltaTime
        guard buildingProgressSaveAccumulator >= Self.buildingProgressSaveInterval else {
            return false
        }
        buildingProgressSaveAccumulator = 0
        return true
    }

    /// Applies the battle HUD at most once per `captainHUDRefreshInterval`
    /// while a Captain is in play — and only when the strip's projected
    /// status actually changed (HPA-475). The full apply re-tessellates
    /// every panel and recomputes the camp recommendation, so the cadence
    /// re-projects the cheap strip-only CaptainStatus and skips the rebuild
    /// while nothing visible moved (recovery seconds are pre-quantized in
    /// the projection, so the countdown ticks at ~1Hz).
    private func refreshCaptainHUDOnCadence(deltaTime: TimeInterval) {
        guard state.siegeProgress.captain != nil else {
            return
        }
        captainHUDRefreshAccumulator += deltaTime
        guard captainHUDRefreshAccumulator >= Self.captainHUDRefreshInterval else {
            return
        }
        captainHUDRefreshAccumulator = 0
        let status = BattleHUDContent.captainStatus(
            for: state,
            captainIsDeployed: combat.captainSoldier != nil,
            rallyRemainingSeconds: combat.rallyRemainingSeconds
        )
        guard status != lastAppliedCaptainStatus else {
            return
        }
        applyBattleHUD()
    }

    /// Per-tick Country 1 Guard persistence (HPA-469). Runs AFTER
    /// `applyCombatResult` — outside its structure-attack guard — so a tick
    /// where allies only damage a Guard (`soldierAttacks` empty) still syncs
    /// living-Guard HP into SiegeProgress. A Keep conquered this tick
    /// changed the stage: a dead Keep spawns nothing, so the wave advance is
    /// skipped entirely. Returns whether durable state changed; the tick
    /// folds it into the single end-of-tick save.
    @discardableResult
    private func synchronizeAndPersistCountry1Guards(deltaTime: TimeInterval) -> Bool {
        let guardStateChanged = state.synchronizeLiveGuardSnapshots(combat.guardSnapshots)
        var spawnedGuards: [GuardSnapshot] = []
        if state.stageStatus == .battleActive {
            spawnedGuards = state.advanceActiveGuardReinforcements(deltaTime: deltaTime)
            for snapshot in spawnedGuards {
                combat.restoreGuard(snapshot, siege: state.currentSiegeSnapshot)
            }
        }
        return guardStateChanged || !spawnedGuards.isEmpty
    }

    /// Per-tick Vanguard Captain persistence (HPA-475). Runs as a sibling
    /// AFTER `applyCombatResult` — beside the Guard sibling, never inside
    /// its ordinary conquest continuation. Captain structure damage is
    /// applied through `applyObjectiveDamage` (no siege-session attack
    /// attribution); a Captain loss records a retreat (never an ordinary
    /// casualty); a live Captain's lane + HP sync into durable progress;
    /// recovery advances only from live combat's clamped delta and spawns
    /// one Captain from the newly durable state on completion. Returns
    /// whether durable state changed — the tick folds it into the single
    /// end-of-tick save; a recovery-countdown-only tick rides the existing
    /// two-second progress cadence. Captain damage runs the same
    /// live-objective presentation as ordinary attacks (HP bar, objective
    /// nodes, floating damage) and a Captain-only Keep kill runs the
    /// conquest branch of it exactly once — the reward was already
    /// calculated once inside the model.
    @discardableResult
    private func synchronizeAndPersistCaptain(
        _ result: BattleCombatState.TickResult,
        deltaTime: TimeInterval
    ) -> Bool {
        let stageBefore = state.stageStatus
        let previousPresentationStage = livingKingdomBattlePresentation.stage
        let captainAttacks = result.soldierAttacks.filter(\.isCaptain)

        var appliedObjectiveDamage = 0
        for attack in captainAttacks {
            appliedObjectiveDamage += state.applyObjectiveDamage(
                attack.appliedDamage,
                toObjectiveID: attack.objectiveID
            )
        }
        let captainCompletedConquest = stageBefore == .battleActive
            && state.stageStatus != .battleActive

        var durableStateChanged = appliedObjectiveDamage > 0 || captainCompletedConquest
        var needsHUDRefresh = false

        // A Captain loss is a retreat while Battle is still active; on a
        // conquest tick the model's stage gate refuses it (a won siege is
        // not a retreat) and the live sync below is likewise gated.
        var recordedRetreat = false
        if result.soldierLosses.contains(where: \.isCaptain),
           state.stageStatus == .battleActive {
            state.recordCaptainRetreat()
            recordedRetreat = true
            durableStateChanged = true
            needsHUDRefresh = true
        } else if let captain = combat.captainSoldier,
                  state.synchronizeLiveCaptain(lane: captain.lane, remainingHP: captain.currentHP) {
            durableStateChanged = true
            needsHUDRefresh = true
        }

        if combat.captainSoldier == nil {
            // The retreat tick starts the clock at full recovery — the
            // Captain was alive for part of that delta, so the same tick
            // never also chips the countdown it just set. Recovery resumes
            // on the next tick.
            let recoveryCompleted = !recordedRetreat
                && state.advanceCaptainRecovery(deltaTime: deltaTime)
            if recoveryCompleted {
                durableStateChanged = true
                needsHUDRefresh = true
                if let captain = state.siegeProgress.captain {
                    combat.spawnCaptain(progress: captain, captainLevel: state.captainLevel)
                }
            }
        }

        if captainCompletedConquest {
            presentLiveObjectiveDamageOutcome(
                attacks: captainAttacks,
                damageColor: .white,
                previousPresentationStage: previousPresentationStage,
                goldEarned: state.pendingBattleResult?.goldEarned ?? 0,
                conqueredCities: 1
            )
        } else if appliedObjectiveDamage > 0 {
            presentLiveObjectiveDamageOutcome(
                attacks: captainAttacks,
                damageColor: .white,
                previousPresentationStage: previousPresentationStage,
                goldEarned: 0,
                conqueredCities: 0
            )
        }

        // Retreat/recovery transitions mutate durable state after the tick's
        // earlier loss-driven HUD apply — refresh now so the strip reflects
        // them this frame instead of waiting for the Captain cadence.
        if needsHUDRefresh {
            applyBattleHUD()
        }
        return durableStateChanged
    }

    /// The one live-objective-damage presentation shared by ordinary soldier
    /// attacks and Captain attacks (HPA-475): clears transient feedback,
    /// tears down combat on conquest, emits the outcome feedback, redraws,
    /// plays the fortress-stage transition, and either presents the pending
    /// conquest report or plays the non-conquest damage feedback. The green
    /// "advantaged" damage color applies only to trait-adjusted soldiers —
    /// Captain damage is flat and always reads white. Conquest persists
    /// here, before the semantic outcome feedback fires (a crash between
    /// them must never lose a celebrated win); non-conquest damage rides
    /// the tick's single end-of-tick save.
    private func presentLiveObjectiveDamageOutcome(
        attacks: [SoldierAttackEvent],
        damageColor: SKColor,
        previousPresentationStage: LivingKingdomPresentation.FortressStage,
        goldEarned: Int,
        conqueredCities: Int
    ) {
        let conqueredCity = conqueredCities > 0
        feedbackText = ""

        if conqueredCity {
            feedbackSettingsController?.setSettingsAccessibilityActionable(false)
            closeFeedbackSettings(focusTarget: .systemDefault)
            clearLiveCombat()
            // The outcome must be durable before its semantic feedback
            // events fire — a crash between them must not lose the win.
            store.save(state)
        }

        emitFreshOutcomeFeedback(goldEarned: goldEarned, conqueredCities: conqueredCities)
        redraw(shouldLayout: conqueredCity)

        playLivingKingdomTransitionForStageChange(from: previousPresentationStage)

        if conqueredCity {
            if presentPendingConquestReport(origin: .freshLive, resetsContinueState: true) {
                playObjectiveAttackFeedback(attacks, color: damageColor, isConquest: true)
            }
        } else {
            playObjectiveAttackFeedback(attacks, color: damageColor, isConquest: false)
        }
    }

    /// The one Rally activation funnel (HPA-475): the HUD action and the
    /// tick's auto-trigger both converge here. Order is deliberate — the
    /// durable consumption bit saves BEFORE the transient protection begins,
    /// so an interruption can never double-use Rally; later requests (manual
    /// or automatic) are rejected by `consumeVanguardRally`. The lane is
    /// captured from the live flagged Captain; lane-chip changes never move
    /// it. Feedback reuses the existing deployment sound/haptic — no new SFX.
    private func activateRally() {
        guard state.stageStatus == .battleActive,
              let captain = combat.captainSoldier else {
            return
        }
        let rallyLane = captain.lane
        guard state.consumeVanguardRally() else {
            return
        }
        store.save(state)
        combat.startRally(lane: rallyLane)
        feedback.emit(.manualDeployment)
        redraw(shouldLayout: false)
    }

    /// Arms the tick's auto-Rally request only while the Captain is durably
    /// deployed (HP > 0), still alive in combat, and Rally is unused.
    /// Recovery and Used states never arm it.
    private var isRallyAutoTriggerAvailable: Bool {
        guard let captain = state.siegeProgress.captain else {
            return false
        }
        return captain.remainingHP > 0
            && !captain.rallyConsumed
            && combat.captainSoldier != nil
    }

    /// Advances the per-soldier hit-reaction countdown by `deltaTime`,
    /// removing entries that have elapsed. Driven by the combat tick (not
    /// the SpriteKit render loop) so it advances identically in production
    /// and in `advanceCombatForTesting`-driven tests.
    private func decrementSoldierHitAnimationRemaining(deltaTime: TimeInterval) {
        guard !soldierHitAnimationRemaining.isEmpty, deltaTime > 0 else {
            return
        }
        var decremented: [BattleCombatState.SoldierID: TimeInterval] = [:]
        for (id, remaining) in soldierHitAnimationRemaining {
            let newValue = remaining - deltaTime
            // Snap to zero below a 1ms epsilon to avoid floating-point
            // residue (e.g. 1.4e-16 after nine 0.1s steps from 0.9s) that
            // would otherwise keep the suppression active past the authored
            // hit duration and block the next attack trigger.
            if newValue > 0.001 {
                decremented[id] = newValue
            }
        }
        soldierHitAnimationRemaining = decremented
    }

    /// Applies one combat tick's ordinary events: hit/death animations,
    /// loss-driven HUD refresh, session loss recording, and — when ordinary
    /// attacks landed — the shared live-objective-damage presentation.
    /// Returns whether durable state changed (the tick saves once at the end).
    @discardableResult
    private func applyCombatResult(_ result: BattleCombatState.TickResult) -> Bool {
        for towerShot in result.towerShots where soldierNodes[towerShot.soldierID] != nil {
            // Protect the combat-selected identity during the formation sync.
            // The projectile itself uses the target's post-sync transform.
            lastDefensiveShotTargetID = towerShot.soldierID
        }

        playGuardEventFeedback(for: result)

        for attack in result.soldierAttacks {
            playSoldierAttackFeedback(for: attack.soldierID)
        }

        // HPA-475: the only identity partition `applyCombatResult` makes.
        // Ordinary (non-Captain) events feed ordinary persistence and
        // reporting; Captain events flow through `synchronizeAndPersistCaptain`.
        let ordinaryAttacks = result.soldierAttacks.filter { !$0.isCaptain }
        let ordinaryLosses = result.soldierLosses.filter { !$0.isCaptain }

        let killedIDs = Set(result.soldierLosses.map(\.soldierID))
        let captainLossIDs = Set(result.soldierLosses.filter(\.isCaptain).map(\.soldierID))
        playSoldierDamageFeedback(
            damagedIDs: result.damagedSoldierIDs,
            killedIDs: killedIDs,
            captainLossIDs: captainLossIDs
        )

        // Note: `killedIDs` is a structural subset of `damagedSoldierIDs`
        // (BattleCombatState appends to both in the same tower-shot block), so
        // every killed soldier is already routed through playSoldierHitFeedback
        // above with schedulesRemoval=true. No separate killed-loop is needed.

        if !result.soldierLosses.isEmpty {
            // Deaths can reopen the squad cap — retire the stale denial so
            // a later redraw cannot re-present it.
            if feedbackText == Self.manualSquadFullMessage {
                feedbackText = ""
            }
            applyBattleHUD()
        }

        state.recordSoldierLosses(ordinaryLosses)

        guard !ordinaryAttacks.isEmpty else {
            if !ordinaryLosses.isEmpty {
                refreshBattleHUD()
            }
            return !ordinaryLosses.isEmpty
        }

        // Capture the stage around the live mutation so at most one final-stage
        // transition is requested per mutation; restore/resize/redraw paths
        // never replay historical effects.
        let previousStage = livingKingdomBattlePresentation.stage
        // Conquest can grant and auto-equip gear, so color the hit using the
        // loadout that existed before applying its damage.
        let damageColor = ordinaryAttackFeedbackColor(ordinaryAttacks)
        let damageResult = state.applyLiveSoldierAttacks(ordinaryAttacks)
        guard damageResult.attackApplied else {
            return !ordinaryLosses.isEmpty
        }

        presentLiveObjectiveDamageOutcome(
            attacks: ordinaryAttacks,
            damageColor: damageColor,
            previousPresentationStage: previousStage,
            goldEarned: damageResult.goldEarned,
            conqueredCities: damageResult.conqueredCities
        )
        return true
    }

    private func ordinaryAttackFeedbackColor(_ attacks: [SoldierAttackEvent]) -> SKColor {
        let layout = state.currentSiegeLayout
        let isAdvantaged = attacks.allSatisfy { attack in
            let hitKind = layout.objective(id: attack.objectiveID)?.kind
            let specialist = combat.soldier(id: attack.soldierID)?.specialistBonus
            return state.currentCityDefenseTrait.damageMultiplier(for: attack.type)
                * state.equipmentAttackMultiplier(for: attack.type)
                * attack.type.objectiveDamageMultiplier(against: hitKind)
                * (hitKind == specialist?.target ? specialist?.multiplier ?? 1 : 1) > 1
        }
        return isAdvantaged
            ? SKColor(red: 142 / 255, green: 247 / 255, blue: 173 / 255, alpha: 1)
            : .white
    }

    /// Routes each damaged soldier's visual feedback: a Captain loss is a
    /// retreat (procedural fade/scale), everything else uses the ordinary
    /// hit/death flow (HPA-475).
    private func playSoldierDamageFeedback(
        damagedIDs: some Collection<BattleCombatState.SoldierID>,
        killedIDs: Set<BattleCombatState.SoldierID>,
        captainLossIDs: Set<BattleCombatState.SoldierID>
    ) {
        for soldierID in damagedIDs {
            if captainLossIDs.contains(soldierID) {
                // A Captain loss is a retreat, not a hit casualty: procedural
                // fade/scale instead of the ordinary hit/death flow.
                playCaptainRetreatFeedback(for: soldierID)
            } else {
                playSoldierHitFeedback(for: soldierID, schedulesRemoval: killedIDs.contains(soldierID))
            }
        }
    }

    /// Procedural Captain retreat (HPA-475): fade + scale down through the
    /// ordinary node bookkeeping — no Captain art, no parallel runtime.
    /// Runs on the combat-tick path so it behaves identically under
    /// `advanceCombatForTesting` (installed SKActions never advance in
    /// tests; the removal itself lands through `removeSoldierNode`).
    private func playCaptainRetreatFeedback(for soldierID: BattleCombatState.SoldierID) {
        guard let bundle = soldierNodes[soldierID] else {
            return
        }
        pendingAnimatedRemovalSoldierIDs.insert(soldierID)
        soldierHitAnimationRemaining.removeValue(forKey: soldierID)
        bundle.root.removeAction(forKey: SoldierAnimationKey.delayedRemoval)
        bundle.body.removeAllActions()
        let duration: TimeInterval = 0.35
        bundle.root.run(SKAction.group([
            SKAction.fadeOut(withDuration: duration),
            SKAction.scale(to: 0.6, duration: duration)
        ]))
        let remove = SKAction.run { [weak self] in
            self?.removeSoldierNode(id: soldierID, animated: false)
        }
        bundle.root.run(
            SKAction.sequence([SKAction.wait(forDuration: duration), remove]),
            withKey: SoldierAnimationKey.delayedRemoval
        )
    }

    private func emitFreshOutcomeFeedback(
        goldEarned: Int,
        conqueredCities: Int
    ) {
        guard conqueredCities > 0 else {
            return
        }

        if goldEarned > 0 {
            feedback.emit(.goldReward)
        }

        switch state.stageStatus {
        case .countryComplete:
            feedback.emit(.countryCompletion)
        case .cityConqueredPendingMap:
            feedback.emit(.cityConquest)
        case .battleActive:
            assertionFailure("Fresh Battle outcome did not advance stage status")
        }
    }

    private func spawnSoldier() {
        guard !isConquestReportVisible, state.stageStatus == .battleActive else {
            return
        }

        guard let manualSoldierLevel = state.manualSoldierLevel(for: selectedManualSoldierType) else {
            feedback.emit(.invalidAction)
            feedbackText = manualSpawnableSoldierTypes.isEmpty
                ? "Build a unit building first."
                : "Build \(selectedManualSoldierType.displayName) first."
            redraw()
            return
        }

        guard combat.livingSoldierCount(source: .manual) < KingdomGameState.manualSoldierCap else {
            feedback.emit(.invalidAction)
            feedbackText = Self.manualSquadFullMessage
            redraw()
            return
        }

        // HPA-582: charges are spent only after the type/cap guards — a
        // rejected deploy never consumes one.
        guard combat.spendManualDeployCharge() else {
            feedback.emit(.invalidAction)
            feedbackText = Self.deployRechargingMessage
            redraw()
            return
        }

        // A successful deploy contradicts every earlier denial — clear it
        // so a later non-attack redraw cannot re-present the stale tooltip.
        feedbackText = ""
        deployManualSoldier(type: selectedManualSoldierType, level: manualSoldierLevel)
    }

    /// The post-guard manual deploy pipeline shared by `spawnSoldier` and
    /// the direct-injection test seam: combat spawn, session deployment
    /// record, deploy feedback, node creation, roster sync, HUD apply.
    private func deployManualSoldier(type: SoldierType, level: Int) {
        let soldierID = combat.spawnSoldier(
            type: type,
            source: .manual,
            level: level,
            attackPower: state.traitAdjustedSoldierAttackPower(
                for: type,
                level: level
            ),
            lane: state.siegeProgress.selectedLane,
            maxHPMultiplier: state.equipmentMaxHPMultiplier(for: type),
            specialistBonus: state.equipmentSpecialistBonus(for: type)
        )
        if let soldier = combat.soldier(id: soldierID) {
            state.recordSoldierDeployment(type: soldier.type, source: soldier.source, lane: soldier.lane)
            feedback.emit(.manualDeployment)
        }
        createSoldierNode(id: soldierID)
        syncSoldierNodes()
        applyBattleHUD()
    }

    private func selectManualSoldierType(_ type: SoldierType) {
        guard !isConquestReportVisible, state.stageStatus == .battleActive else {
            return
        }

        guard manualSpawnableSoldierTypes.contains(type) else {
            feedback.emit(.invalidAction)
            feedbackText = "Build \(type.displayName) first."
            redraw(shouldLayout: false)
            return
        }

        selectedManualSoldierType = type
        redraw(shouldLayout: false)
    }

    private func showGoldInfoTooltip() {
        showTooltip("Gold \(CompactNumberFormatter.string(from: state.gold)) | Soldiers \(combat.livingSoldierCount)")
    }

    private func showCityInfoTooltip() {
        showTooltip(
            "\(state.displayCityTitle) | \(state.currentCityDefenseTrait.displayName) | HP "
                + "\(CompactNumberFormatter.string(from: state.currentKeepRemainingPower))/"
                + CompactNumberFormatter.string(from: state.currentKeepMaxPower)
        )
    }

    private func requestGameplayTab(_ tab: GameplayTab) {
        guard !isConquestReportVisible,
              state.stageStatus == .battleActive,
              tab != .battle else {
            return
        }

        guard combat.livingSoldierCount(source: .manual) == 0 else {
            feedback.emit(.invalidAction)
            feedbackText = switch tab {
            case .map: "Finish the current squad before viewing world."
            case .camp: "Finish the current squad before building."
            default: "Finish the current squad before opening the treasury."
            }
            redraw()
            return
        }

        state.markCurrentCityBuildingProgressInactive(at: Date())
        store.save(state)
        router?.battleSceneDidRequestGameplayTab(
            self,
            tab: tab
        )
    }

    private func createSoldierNode(id: BattleCombatState.SoldierID) {
        guard soldierNodes[id] == nil else {
            return
        }
        guard let soldier = combat.soldier(id: id) else {
            return
        }

        let root = SKNode()
        root.name = BattleAssetName.normalSoldier

        let body = makeSoldierNode(for: soldier)
        body.zPosition = 1
        root.addChild(body)

        let hpBackground = SKShapeNode()
        hpBackground.fillColor = SKColor(white: 0.05, alpha: 0.9)
        hpBackground.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        hpBackground.lineWidth = 1
        hpBackground.zPosition = 2

        let hpFill = SKShapeNode()
        hpFill.fillColor = SKColor(red: 0.25, green: 0.9, blue: 0.38, alpha: 1.0)
        hpFill.strokeColor = .clear
        hpFill.zPosition = 3

        let formationSlot = nextAvailableFormationSlot(for: soldier.lane)
        let assetPrefix = soldierAssetPrefix(for: soldier.type, isCaptain: soldier.isCaptain)
        let isAnimatedCanvas = firstAvailableSoldierAnimationFrameName(for: assetPrefix) != nil

        root.addChild(hpBackground)
        root.addChild(hpFill)
        soldierLayer.addChild(root)
        soldierNodes[id] = SoldierNodeBundle(
            root: root,
            body: body,
            hpBarBackground: hpBackground,
            hpBarFill: hpFill,
            type: soldier.type,
            isCaptain: soldier.isCaptain,
            lane: soldier.lane,
            formationSlot: formationSlot,
            isAnimatedCanvas: isAnimatedCanvas,
            rallyAccent: nil
        )
    }

    private func nextAvailableFormationSlot(for lane: BattleLane) -> Int {
        let occupiedSlots = Set(
            soldierNodes.values
                .filter { $0.lane == lane }
                .map(\.formationSlot)
        )
        // The slot space is unbounded and only as many slots are occupied as
        // there are live soldiers in this lane, so a free slot always exists.
        var slot = 0
        while occupiedSlots.contains(slot) {
            slot += 1
        }
        return slot
    }

    /// The pre-overflow formation offset (slot → column/row with asymptotic
    /// depth compression). Retained for FOLDED soldiers only: folded roots
    /// are hidden but must keep positions that are inside the battlefield,
    /// off the floor pile, and stale-free so the `floorCount` formation
    /// invariants keep describing the visible roster's footprint.
    private func soldierFormationOffset(
        for slot: Int,
        availableDepth: CGFloat,
        columnSpacing: CGFloat,
        rowSpacing: CGFloat
    ) -> CGPoint {
        let clampedSlot = max(0, slot)
        let column = SoldierFormation.columns[clampedSlot % SoldierFormation.columns.count]
        let row = CGFloat(clampedSlot / SoldierFormation.columns.count)
        let compressedDepth = max(0, availableDepth) * row / (row + 1)
        return CGPoint(
            x: CGFloat(column) * columnSpacing,
            y: -min(row * rowSpacing, compressedDepth)
        )
    }

    /// One lane's seat geometry for this sync. The SEAT unit is the
    /// readable steady-state footprint — the logical walk-pose body
    /// unioned with its HP bar, exactly the parts that merge into an
    /// unreadable block when they overlap. The full animation canvas
    /// (attack/hit reach, Captain banner) is deliberately NOT the seat
    /// unit: a square ~88-pt canvas would collapse the grid to a single
    /// column and one row, and its reach is transient pose art, not
    /// standing ground. Corpses and fades still reserve their ACTUAL
    /// canvas footprint — only the living seat pitch is logical.
    private func soldierFormationLayout(
        lane: BattleLane,
        soldiers: [BattleCombatState.Soldier],
        bundles: [SoldierNodeBundle]
    ) -> SoldierFormationLayout {
        let maxWidth = bundles.map { bundle -> CGFloat in
            let logicalWidth = soldierLogicalBodyFrame(for: bundle).width
            return max(
                logicalWidth,
                soldierHPBarWidth(forBodyWidth: logicalWidth)
                    + bundle.hpBarBackground.lineWidth
            )
        }.max() ?? 0
        let maxSpan = bundles.map {
            soldierLogicalBodyFrame(for: $0).maxY + 6.5
                - animatedSoldierFootMargin(for: $0)
        }.max() ?? 0
        let maxRootDrop = bundles.map {
            animatedSoldierFootMargin(for: $0)
                - min(
                    animatedSoldierFootMargin(for: $0),
                    $0.body.calculateAccumulatedFrame().minY
                )
        }.max() ?? 0
        let laneWidth = battlefieldLayout.frame.width / 3
        let singleBounds = bundles.first.map { soldierHorizontalBounds(for: $0) } ?? 0...0
        let singleWidth = singleBounds.upperBound - singleBounds.lowerBound
        // Seats must be READABLE and stay inside the lane: rather than
        // shrinking everyone below the readability floor when the
        // widest member's canvas is broad (attack reach, Captain
        // banner), the formation drops a column — three columns of a
        // 76-pt-wide canvas cannot render ≥22-pt HP bars inside the
        // lane, but two can. The pitch then exceeds the member's own
        // footprint, so claimed seats stay pairwise disjoint.
        let columnOffsets: [CGFloat]
        if soldiers.count > 1 {
            let fitColumns = Int(
                (laneWidth - 6)
                    / (max(1, maxWidth) * SoldierFormation.minReadableScale)
            )
            switch max(1, min(3, fitColumns)) {
            case 3: columnOffsets = [0, -1, 1]
            case 2: columnOffsets = [-0.5, 0.5]
            default: columnOffsets = [0]
            }
        } else {
            columnOffsets = SoldierFormation.columns.map { CGFloat($0) }
        }
        let scale = soldiers.count > 1
            ? min(
                SoldierFormation.crowdedScale,
                max(0, laneWidth - 6) / (CGFloat(columnOffsets.count) * max(1, maxWidth))
            )
            : min(1, max(0, laneWidth - SoldierFormation.spacing) / max(1, singleWidth))
        let gateBarBottom = state.currentSiegeLayout.objectives
            .filter { $0.kind == .gate && state.currentSiegeLayout.routes[lane]?.contains($0.id) == true }
            .compactMap { objective -> CGFloat? in
                guard let bar = siegeObjectiveNodes[objective.id]?.childNode(withName: "siegeHPBackground")
                else { return nil }
                return sceneFrame(for: bar)?.minY
            }
            .min()
        return SoldierFormationLayout(
            scale: scale,
            columnOffsets: columnOffsets,
            column: maxWidth * scale + SoldierFormation.spacing,
            row: maxSpan * scale + SoldierFormation.spacing,
            frontLimit: gateBarBottom.map { $0 - maxSpan * scale - 2 } ?? .greatestFiniteMagnitude,
            footprintHalfWidth: maxWidth * scale / 2,
            footprintHeight: maxSpan * scale,
            rootDrop: maxRootDrop * scale
        )
    }

    /// One lane's seat grid for a single sync — pure geometry: rows one
    /// pitch apart from the lane head's clamped front down to just above
    /// the "+N" badge reserve, cells the readable-seat rect the seat plan
    /// claims and the corpse pass invalidates.
    private struct SoldierSeatGrid {
        let laneCenterX: CGFloat
        let columnOffsets: [CGFloat]
        let columnPitch: CGFloat
        let rowPitch: CGFloat
        let headY: CGFloat
        let rowCount: Int
        let footprintHalfWidth: CGFloat
        let footprintHeight: CGFloat

        func rowY(_ row: Int) -> CGFloat {
            headY - CGFloat(row) * rowPitch
        }

        /// The readable-seat rect one cell covers — the reservation unit
        /// seats claim and `soldierSeatFootprintsForTesting` reports.
        func cellRect(row: Int, column: Int) -> CGRect {
            CGRect(
                x: laneCenterX + columnOffsets[column] * columnPitch - footprintHalfWidth,
                y: rowY(row),
                width: footprintHalfWidth * 2,
                height: footprintHeight
            )
        }
    }

    /// One lane's seat claims for a single sync — the small stateful part
    /// of the presentation. Cells touched by corpse/fade footprints are
    /// unclaimable; claims are stable across syncs via `previousSeats`.
    private struct SoldierSeatPlanner {
        private let grid: SoldierSeatGrid
        private let previousSeats:
            [BattleCombatState.SoldierID: (row: Int, column: Int)]
        private let preferredColumn: (BattleCombatState.SoldierID) -> Int
        private var taken: [Int: Set<Int>] = [:]
        var assigned: [BattleCombatState.SoldierID: (row: Int, column: Int)] = [:]

        init(
            grid: SoldierSeatGrid,
            reservedFootprints: [CGRect],
            previousSeats: [BattleCombatState.SoldierID: (row: Int, column: Int)],
            preferredColumn: @escaping (BattleCombatState.SoldierID) -> Int
        ) {
            self.grid = grid
            self.previousSeats = previousSeats
            self.preferredColumn = preferredColumn
            for footprint in reservedFootprints {
                for row in 0..<grid.rowCount {
                    for column in grid.columnOffsets.indices
                    where grid.cellRect(row: row, column: column).intersects(footprint) {
                        taken[row, default: []].insert(column)
                    }
                }
            }
        }

        /// Claims a cell on `row` for the soldier — keeping its last-sync
        /// column while it is still on the same row and still free, else
        /// its preferred column, else the first free one. `false` when the
        /// whole row is taken.
        @discardableResult
        mutating func claim(_ id: BattleCombatState.SoldierID, row: Int) -> Bool {
            guard (0..<grid.rowCount).contains(row) else { return false }
            let blocked = taken[row, default: []]
            let column: Int?
            if let previous = previousSeats[id],
               previous.row == row,
               previous.column < grid.columnOffsets.count,
               !blocked.contains(previous.column) {
                column = previous.column
            } else {
                let preferred = preferredColumn(id) % grid.columnOffsets.count
                if !blocked.contains(preferred) {
                    column = preferred
                } else {
                    column = grid.columnOffsets.indices.first { !blocked.contains($0) }
                }
            }
            guard let column else { return false }
            taken[row, default: []].insert(column)
            assigned[id] = (row, column)
            return true
        }

        /// The free row (fewer claimed cells than columns) nearest a y —
        /// used by deferred ordinary members and protected members whose
        /// natural row is saturated. `nil` when the grid is fully taken.
        func nearestFreeRow(to targetY: CGFloat) -> Int? {
            (0..<grid.rowCount)
                .filter { (taken[$0, default: []]).count < grid.columnOffsets.count }
                .min {
                    let d0 = abs(grid.rowY($0) - targetY)
                    let d1 = abs(grid.rowY($1) - targetY)
                    if d0 != d1 { return d0 < d1 }
                    return $0 > $1
                }
        }

        /// Moves a claimed cell from an ordinary occupant to a protected
        /// member — the cell stays marked, only the owner changes.
        mutating func displace(_ victim: BattleCombatState.SoldierID, by id: BattleCombatState.SoldierID) {
            guard let seat = assigned.removeValue(forKey: victim) else { return }
            assigned[id] = seat
        }
    }

    /// The per-sync constants shared by every member in a lane: measured
    /// geometry, already-reserved ground, this sync's claimed seats, the
    /// live occupancy probe, and the bounded move budget.
    private struct LanePresentation {
        let formation: SoldierFormationLayout
        let grid: SoldierSeatGrid
        let reservedFootprints: [CGRect]
        /// Cells the seat plan assigned this sync — unseated landings
        /// must not park on a seat somebody else is converging to.
        let claimedSeatRects: [CGRect]
        /// Readable footprints of every OTHER member rendered right now.
        /// Evaluated live inside the placement pass, so members placed
        /// earlier this sync already occupy their new ground — a
        /// materializing member can never pop onto a seat its previous
        /// occupant still stands on.
        let contestedFootprints: (BattleCombatState.SoldierID) -> [CGRect]
        let battlefieldFloorY: CGFloat
        let presentationStep: CGFloat
        let layoutRemapped: Bool
    }

    /// One member's presentation inputs for a single sync.
    private struct SoldierPlacement {
        let id: BattleCombatState.SoldierID
        let bundle: SoldierNodeBundle
        let lanePoint: CGPoint
        let frontY: CGFloat
        let footMargin: CGFloat
        let seat: (row: Int, column: Int)?
        let unseatedProtected: Bool
    }

    /// `elapsedCombatTime` is the clamped combat delta that produced this
    /// sync — presentation motion is clocked by it, so layout/deploy/redraw
    /// syncs (zero elapsed) refresh ideals without moving roots.
    private func syncSoldierNodes(elapsedCombatTime: TimeInterval = 0) {
        let liveSoldiers = combat.soldiers.filter(\.isAlive)
        let liveIDs = Set(liveSoldiers.map(\.id))

        for id in Array(soldierNodes.keys)
            where !liveIDs.contains(id) && !pendingAnimatedRemovalSoldierIDs.contains(id) {
            removeSoldierNode(id: id, animated: false)
        }

        for soldier in liveSoldiers {
            if soldierNodes[soldier.id] == nil {
                createSoldierNode(id: soldier.id)
            }
            guard let bundle = soldierNodes[soldier.id] else { continue }
            fitSoldierBodyNode(
                bundle.body,
                type: bundle.type,
                targetHeight: soldierTargetHeight(),
                isAnimatedCanvas: bundle.isAnimatedCanvas
            )
        }

        let soldiersByLane = Dictionary(grouping: liveSoldiers, by: \.lane)
        var formationByLane: [BattleLane: SoldierFormationLayout] = [:]
        for (lane, soldiers) in soldiersByLane {
            formationByLane[lane] = soldierFormationLayout(
                lane: lane,
                soldiers: soldiers,
                bundles: soldiers.compactMap { soldierNodes[$0.id] }
            )
        }

        // HPA-812 round 4 — bounded stable seats, small state: finite
        // screen depth cannot show arbitrarily many bodies + HP bars, so
        // each lane renders at most a grid of DISJOINT stable seats and
        // folds the remainder into a truthful "+N" badge.
        //
        // * Live soldiers rank by combat's foremost ordering EXACTLY —
        //   position, then the Captain on ties, then roster precedence:
        //   rank 0 is always the soldier the tower can actually shoot.
        // * A member KEEPS its seat cell while the cell is still on its
        //   natural row and still free (`soldierSeats` lane ledger) —
        //   lateral churn only happens when the roster actually changes.
        // * A casualty that died RENDERED keeps the ground it fell on:
        //   its actual footprint is reserved immediately (recomputed per
        //   sync through the node's own transform) and held until
        //   removal. A casualty that died hidden STAYS hidden until
        //   removal — no reveal search; an invisible body can reserve
        //   nothing and is never badge-counted (the badge only counts
        //   live soldiers).
        // * Protected members (Captains, the lane's fire candidate, the
        //   in-flight tower-shot target) claim seats first and never fold.
        // * A promoted member converges HIDDEN and unhides only on
        //   arrival — it never renders at its stale folded spot and never
        //   glides visibly across ground other bodies occupy.
        // * Everything moves at the bounded combat-time rate; a
        //   battlefield-frame change re-places every root in the NEW
        //   coordinates this sync, since combat-time glides cannot repair
        //   stale coordinates while ticking is paused.
        let battlefieldFloorY = battlefieldLayout.frame.minY
        let presentationStep = SoldierFormation.presentationGlidePointsPerSecond
            * max(0, elapsedCombatTime)
        let layoutRemapped = lastSoldierSyncBattlefieldFrame != nil
            && lastSoldierSyncBattlefieldFrame != battlefieldLayout.frame
        if layoutRemapped {
            // Mid-fade roots belong to the old coordinate system — their
            // removal lands explicitly rather than leaving a stale ghost
            // in old coordinates.
            for entry in soldierFadingFootprints.values {
                entry.root.removeFromParent()
            }
            soldierFadingFootprints.removeAll()
        }
        lastSoldierSyncBattlefieldFrame = battlefieldLayout.frame

        let casualtyReservationsByLane = syncPendingCasualtyFootprints(
            layoutRemapped: layoutRemapped,
            formationByLane: formationByLane
        )
        seatFootprintsBySoldierID.removeAll()
        var foldedCountByLane: [BattleLane: Int] = [:]
        var badgeAnchorXByLane: [BattleLane: CGFloat] = [:]

        for (lane, laneSoldiers) in soldiersByLane {
            guard let formation = formationByLane[lane] else { continue }
            let outcome = syncLaneFormation(
                lane: lane,
                laneSoldiers: laneSoldiers,
                formation: formation,
                laneReservedFootprints: (casualtyReservationsByLane[lane] ?? [])
                    + soldierFadingFootprints.values.map(\.rect),
                battlefieldFloorY: battlefieldFloorY,
                presentationStep: presentationStep,
                layoutRemapped: layoutRemapped
            )
            foldedCountByLane[lane] = outcome.foldedCount
            badgeAnchorXByLane[lane] = outcome.badgeAnchorX
        }

        for lane in BattleLane.allCases {
            syncSoldierOverflowBadge(
                lane: lane,
                foldedCount: foldedCountByLane[lane] ?? 0,
                anchorX: badgeAnchorXByLane[lane]
            )
        }
    }

    /// One lane's presentation for this sync — seat claims, then one
    /// application pass over the rank-ordered roster. The lane's reserved
    /// ground is the corpses rendered when they died in this lane plus
    /// every fading removal; seats never claim the cells those footprints
    /// touch.
    private func syncLaneFormation(
        lane: BattleLane,
        laneSoldiers: [BattleCombatState.Soldier],
        formation: SoldierFormationLayout,
        laneReservedFootprints: [CGRect],
        battlefieldFloorY: CGFloat,
        presentationStep: CGFloat,
        layoutRemapped: Bool
    ) -> (foldedCount: Int, badgeAnchorX: CGFloat) {
        let ranked = laneSoldiers.sorted { lhs, rhs in
            if lhs.position != rhs.position {
                return lhs.position > rhs.position
            }
            if lhs.isCaptain != rhs.isCaptain {
                return lhs.isCaptain
            }
            return lhs.id < rhs.id
        }

        var lanePoints: [BattleCombatState.SoldierID: CGPoint] = [:]
        var frontYs: [BattleCombatState.SoldierID: CGFloat] = [:]
        var footMargins: [BattleCombatState.SoldierID: CGFloat] = [:]
        for soldier in ranked {
            guard let bundle = soldierNodes[soldier.id] else { continue }
            let lanePoint = point(forLane: lane, position: soldier.position)
            lanePoints[soldier.id] = lanePoint
            frontYs[soldier.id] = min(lanePoint.y, formation.frontLimit)
            footMargins[soldier.id] = animatedSoldierFootMargin(for: bundle)
        }

        let protectedIDs = laneProtectedIDs(ranked: ranked, laneSoldiers: laneSoldiers)

        let headY = ranked.compactMap { frontYs[$0.id] }.max() ?? 0
        let laneMaxFoot = (footMargins.values.max() ?? 0) * formation.scale
        let grid = SoldierSeatGrid(
            laneCenterX: point(forLane: lane, position: 0).x,
            columnOffsets: formation.columnOffsets,
            columnPitch: formation.column,
            rowPitch: formation.row,
            headY: headY,
            rowCount: max(
                1,
                Int(((headY - laneMaxFoot - battlefieldFloorY
                    - SoldierFormation.overflowBadgeReserve) / formation.row).rounded(.down)) + 1
            ),
            footprintHalfWidth: formation.footprintHalfWidth,
            footprintHeight: formation.footprintHeight
        )
        func naturalRow(of soldier: BattleCombatState.Soldier) -> Int {
            guard let frontY = frontYs[soldier.id] else { return 0 }
            let row = Int(((headY - frontY) / formation.row + 0.5).rounded(.down))
            return min(max(0, row), grid.rowCount - 1)
        }

        let seatPlan = planSoldierSeats(
            ranked: ranked,
            grid: grid,
            reservedFootprints: laneReservedFootprints,
            previousSeats: soldierSeats[lane] ?? [:],
            protectedIDs: protectedIDs,
            naturalRow: naturalRow,
            preferredColumn: {
                self.soldierNodes[$0].map(\.formationSlot) ?? 0
            },
            frontY: { frontYs[$0] ?? 0 }
        )
        // Folded members release their seat — `assigned` IS the lane's
        // seat map for next sync.
        soldierSeats[lane] = seatPlan.assigned
        // The claimed reservation is the seat CELL — the same readable
        // rect the corpse/fade passes invalidate — exclusive across
        // seats by the ≥footprint+spacing pitch. Recorded for every
        // assigned member, including one still converging hidden.
        for (id, cell) in seatPlan.assigned {
            seatFootprintsBySoldierID[id] = grid.cellRect(
                row: cell.row, column: cell.column
            )
        }

        let loneSoldier = laneSoldiers.count == 1
        let unseatedProtected = Set(seatPlan.unseatedProtected)
        let claimedSeatRects = seatPlan.assigned.values.map {
            grid.cellRect(row: $0.row, column: $0.column)
        }
        let presentation = LanePresentation(
            formation: formation,
            grid: grid,
            reservedFootprints: laneReservedFootprints,
            claimedSeatRects: claimedSeatRects,
            contestedFootprints: { [self] excludedID in
                ranked.compactMap { other in
                    guard other.id != excludedID,
                          let otherBundle = soldierNodes[other.id],
                          !otherBundle.root.isHidden
                    else { return nil }
                    return soldierReadableFootprint(
                        at: otherBundle.root.position,
                        for: otherBundle
                    )
                }
            },
            battlefieldFloorY: battlefieldFloorY,
            presentationStep: presentationStep,
            layoutRemapped: layoutRemapped
        )
        var foldedInLane = 0
        for soldier in ranked {
            guard let bundle = soldierNodes[soldier.id],
                  let lanePoint = lanePoints[soldier.id],
                  let frontY = frontYs[soldier.id],
                  let footMargin = footMargins[soldier.id] else { continue }
            // The formation scale lands BEFORE the placement pass:
            // every footprint the landing and occupancy checks measure
            // is read through the root's own scale — a still-unscaled
            // node measures ~1/scale too large and contests ground its
            // real rect never touches.
            bundle.root.setScale(formation.scale)
            let placement = SoldierPlacement(
                id: soldier.id,
                bundle: bundle,
                lanePoint: lanePoint,
                frontY: frontY,
                footMargin: footMargin,
                seat: seatPlan.assigned[soldier.id],
                unseatedProtected: unseatedProtected.contains(soldier.id)
            )
            let presented = placement.seat != nil || placement.unseatedProtected
            applySoldierLanePlacement(
                placement,
                presented: presented,
                loneSoldier: loneSoldier,
                protectedIDs: protectedIDs,
                in: presentation
            )
            if bundle.root.isHidden {
                foldedInLane += 1
            }
            // Folded bookkeeping is still O(1) per member — HP path,
            // walk-cycle check, and Rally accent all stay current so
            // a member emerging from the badge renders a correct
            // first frame; SpriteKit never draws hidden subtrees.
            layoutSoldierHPBar(bundle, soldier: soldier)
            startSoldierWalkAnimation(for: soldier.id)
            syncRallyProtectionAccent(for: soldier)
        }

        return (
            foldedInLane,
            ranked.last.flatMap { lanePoints[$0.id] }?.x
                ?? point(forLane: lane, position: 0).x
        )
    }

    /// The members a lane's presentation must never fold: every Captain,
    /// combat's foremost rank, the lane's ACTUAL fire candidate — the
    /// lowest roster id at the maximal position, which differs from the
    /// visual `ranked` first when a Captain shares the front — and the
    /// tower's live projectile target: combat fired at THIS soldier, so
    /// a post-shot re-rank must not fold it before the arrow
    /// lands. That protection is tied to the projectile's own lifecycle —
    /// it clears when the shot lands (see `playTowerShot`), never
    /// persisting onto a later reused id.
    private func laneProtectedIDs(
        ranked: [BattleCombatState.Soldier],
        laneSoldiers: [BattleCombatState.Soldier]
    ) -> Set<BattleCombatState.SoldierID> {
        var protectedIDs = Set(ranked.filter(\.isCaptain).map(\.id))
        if let foremost = ranked.first {
            protectedIDs.insert(foremost.id)
        }
        if let maxPosition = laneSoldiers.map(\.position).max(),
           let candidate = laneSoldiers
               .filter({ $0.position == maxPosition })
               .min(by: { $0.id < $1.id }) {
            protectedIDs.insert(candidate.id)
        }
        if let target = lastDefensiveShotTargetID,
           laneSoldiers.contains(where: { $0.id == target }) {
            protectedIDs.insert(target)
        }
        return protectedIDs
    }

    /// Corpse pass for every pending casualty — runs before seat claims so
    /// the ground corpses still hold is unclaimable. A casualty that died
    /// RENDERED keeps the ground it fell on: its actual footprint is
    /// reserved immediately (recomputed per sync through the node's own
    /// transform, so a Captain's retreat scale-down shrinks for real) and
    /// held until the authored removal lands. A casualty that died hidden
    /// STAYS hidden until removal — there is no reveal search; lanes with
    /// no live roster left keep their corpses where they fell as well.
    /// A battlefield remap refits the corpse into the NEW layout's
    /// geometry — body canvas, HP bar, and ordinary casualty formation scale —
    /// then lands its WHOLE transformed footprint inside the new field.
    /// A retreating Captain keeps the scale driven by its in-flight action;
    /// clamping only the root would let the canvas and bar escape.
    private func syncPendingCasualtyFootprints(
        layoutRemapped: Bool,
        formationByLane: [BattleLane: SoldierFormationLayout]
    ) -> [BattleLane: [CGRect]] {
        var byLane: [BattleLane: [CGRect]] = [:]
        for id in pendingAnimatedRemovalSoldierIDs.sorted() {
            guard let bundle = soldierNodes[id] else { continue }
            if !bundle.corpseRevealed {
                if bundle.presentationSeeded && !bundle.root.isHidden {
                    // Died rendered: the ground under it is already the
                    // truthful footprint — it simply stays there.
                    soldierNodes[id]?.corpseRevealed = true
                } else {
                    // Died hidden: stays hidden until the authored removal
                    // lands — never revealed onto another body.
                    continue
                }
            }
            if layoutRemapped {
                // Refit into the NEW layout's geometry first — canvas,
                // bar, and root scale all feed the footprint measured
                // below — then contain the whole thing, not the point.
                fitSoldierBodyNode(
                    bundle.body,
                    type: bundle.type,
                    targetHeight: soldierTargetHeight(),
                    isAnimatedCanvas: bundle.isAnimatedCanvas
                )
                // Ordinary casualties use their lane's formation scale.
                // A Captain's root scale is owned by its retreat action:
                // preserve its current progress rather than resetting it.
                if !bundle.isCaptain {
                    bundle.root.setScale(
                        formationByLane[bundle.lane]?.scale
                            ?? soldierFormationLayout(
                                lane: bundle.lane,
                                soldiers: [],
                                bundles: [bundle]
                            ).scale
                    )
                }
                // The Soldier has already left `combat.soldiers`, so the
                // bar cannot be relaid out from live state — replay the
                // fill it rendered with against the refit body. A corpse
                // with no recorded signature died before its first bar
                // layout and renders an empty one.
                layoutSoldierHPBar(
                    bundle,
                    id: id,
                    hpPercent: bundle.hpBarSignature
                        .map { CGFloat($0.percent) / 4096 } ?? 0
                )
                bundle.root.position = clampedRootPosition(
                    for: bundle,
                    inside: battlefieldLayout.frame
                )
            }
            bundle.root.isHidden = false
            let rect = soldierRenderedFootprint(at: bundle.root.position, for: bundle)
            soldierNodes[id]?.corpseFootprint = rect
            byLane[bundle.lane, default: []].append(rect)
        }
        return byLane
    }

    /// The nearest root position whose WHOLE rendered footprint — canvas
    /// ∪ HP bar through the node's current transform — sits inside
    /// `frame`. A footprint wider or taller than the field centers on
    /// that axis instead (no root position can contain it). The clamp
    /// runs against a hair-inset frame: float associativity can leave a
    /// boundary-exact shift a few ULPs outside, and the reservation rect
    /// is re-measured from the same arithmetic — a 0.01 pt margin is
    /// invisible but keeps the recorded footprint strictly contained.
    private func clampedRootPosition(
        for bundle: SoldierNodeBundle,
        inside frame: CGRect
    ) -> CGPoint {
        clampedFootprintPosition(
            bundle.root.position, for: bundle, inside: frame
        )
    }

    /// The nearest root position to `point` whose whole rendered
    /// footprint sits inside `frame` — the same minimal inward shift
    /// `clampedRootPosition` performs on the root's own position,
    /// applied to an arbitrary destination.
    private func clampedFootprintPosition(
        _ point: CGPoint,
        for bundle: SoldierNodeBundle,
        inside frame: CGRect
    ) -> CGPoint {
        let frame = frame.insetBy(dx: 0.01, dy: 0.01)
        let rect = soldierRenderedFootprint(at: point, for: bundle)
        var position = point
        if rect.width <= frame.width {
            if rect.minX < frame.minX {
                position.x += frame.minX - rect.minX
            } else if rect.maxX > frame.maxX {
                position.x += frame.maxX - rect.maxX
            }
        } else {
            position.x += frame.midX - rect.midX
        }
        if rect.height <= frame.height {
            if rect.minY < frame.minY {
                position.y += frame.minY - rect.minY
            } else if rect.maxY > frame.maxY {
                position.y += frame.maxY - rect.maxY
            }
        } else {
            position.y += frame.midY - rect.midY
        }
        return position
    }

    /// One sync's bounded step toward a point — returns `ideal` when the
    /// remaining distance fits the step, else the point `maxDistance`
    /// along the straight line. Motion is clocked by `elapsedCombatTime`,
    /// so a zero-elapsed sync never moves a root.
    private func steppedPosition(
        from position: CGPoint,
        toward ideal: CGPoint,
        maxDistance: CGFloat
    ) -> CGPoint {
        let dx = ideal.x - position.x
        let dy = ideal.y - position.y
        let distance = hypot(dx, dy)
        guard distance > maxDistance, distance > 0 else {
            return ideal
        }
        return CGPoint(
            x: position.x + dx / distance * maxDistance,
            y: position.y + dy / distance * maxDistance
        )
    }

    /// One lane's seat plan for this sync (pure claims — no node writes).
    /// Cells touched by corpse/fade footprints are taken first; protected
    /// members claim their natural rows first, everyone else claims in
    /// rank order, deferred members take the free row nearest their own
    /// front. A protected member the grid cannot seat takes the nearest
    /// free row, then displaces the lowest-rank ordinary member nearest
    /// its natural row — only in the corpse-blanketed extreme does one
    /// stay unseated, rendered at its own true position rather than fold.
    private func planSoldierSeats(
        ranked: [BattleCombatState.Soldier],
        grid: SoldierSeatGrid,
        reservedFootprints: [CGRect],
        previousSeats: [BattleCombatState.SoldierID: (row: Int, column: Int)],
        protectedIDs: Set<BattleCombatState.SoldierID>,
        naturalRow: (BattleCombatState.Soldier) -> Int,
        preferredColumn: @escaping (BattleCombatState.SoldierID) -> Int,
        frontY: (BattleCombatState.SoldierID) -> CGFloat
    ) -> (
        assigned: [BattleCombatState.SoldierID: (row: Int, column: Int)],
        unseatedProtected: [BattleCombatState.SoldierID]
    ) {
        var planner = SoldierSeatPlanner(
            grid: grid,
            reservedFootprints: reservedFootprints,
            previousSeats: previousSeats,
            preferredColumn: preferredColumn
        )
        for soldier in ranked where protectedIDs.contains(soldier.id) {
            planner.claim(soldier.id, row: naturalRow(soldier))
        }
        var deferred: [BattleCombatState.Soldier] = []
        for soldier in ranked where planner.assigned[soldier.id] == nil {
            if !planner.claim(soldier.id, row: naturalRow(soldier)) {
                deferred.append(soldier)
            }
        }
        for soldier in deferred {
            if let row = planner.nearestFreeRow(to: frontY(soldier.id)) {
                planner.claim(soldier.id, row: row)
            }
        }
        for soldier in ranked
        where protectedIDs.contains(soldier.id) && planner.assigned[soldier.id] == nil {
            if let row = planner.nearestFreeRow(to: frontY(soldier.id)) {
                planner.claim(soldier.id, row: row)
            }
        }
        displaceOrdinaryOccupantsForProtected(
            ranked: ranked,
            protectedIDs: protectedIDs,
            naturalRow: naturalRow,
            planner: &planner
        )
        let unseatedProtected = ranked.filter {
            protectedIDs.contains($0.id) && planner.assigned[$0.id] == nil
        }.map(\.id)
        return (planner.assigned, unseatedProtected)
    }

    /// Last-resort seat for a protected member whose whole grid is taken:
    /// displace the lowest-rank ordinary occupant nearest its natural row
    /// — the Captain and the tower's actual target never fold.
    private func displaceOrdinaryOccupantsForProtected(
        ranked: [BattleCombatState.Soldier],
        protectedIDs: Set<BattleCombatState.SoldierID>,
        naturalRow: (BattleCombatState.Soldier) -> Int,
        planner: inout SoldierSeatPlanner
    ) {
        var rankIndex: [BattleCombatState.SoldierID: Int] = [:]
        for (index, soldier) in ranked.enumerated() {
            rankIndex[soldier.id] = index
        }
        for soldier in ranked
        where protectedIDs.contains(soldier.id) && planner.assigned[soldier.id] == nil {
            let targetRow = naturalRow(soldier)
            guard let victim = planner.assigned
                .filter({ !protectedIDs.contains($0.key) })
                .min(by: {
                    let d0 = abs($0.value.row - targetRow)
                    let d1 = abs($1.value.row - targetRow)
                    if d0 != d1 { return d0 < d1 }
                    return (rankIndex[$0.key] ?? .max) > (rankIndex[$1.key] ?? .max)
                }) else { continue }
            planner.displace(victim.key, by: soldier.id)
        }
    }

    /// Where a member would stand if motion were free this sync: its own
    /// seat cell or the hidden folded slot. Unseated protected members
    /// never reach here — `unseatedProtectedLanding` resolves their
    /// checked ground before placement runs.
    private func soldierIdealPosition(
        _ placement: SoldierPlacement,
        in presentation: LanePresentation
    ) -> CGPoint {
        let grid = presentation.grid
        if let seat = placement.seat {
            return CGPoint(
                x: grid.cellRect(row: seat.row, column: seat.column).midX,
                y: grid.rowY(seat.row)
                    - placement.footMargin * presentation.formation.scale
            )
        }
        // Folded: the legacy compressed slot offset — hidden, but above
        // the floor pile, spread, and stale-free. Bookkeeping positions
        // stay inside the field too: a folded member's own readable reach
        // decides the clamp, so nothing — visible or hidden — parks
        // off-field.
        let offset = soldierFormationOffset(
            for: placement.bundle.formationSlot,
            availableDepth: placement.frontY
                - placement.footMargin * presentation.formation.scale
                - presentation.battlefieldFloorY,
            columnSpacing: grid.columnPitch,
            rowSpacing: grid.rowPitch
        )
        let reach = soldierReadableFootprint(at: .zero, for: placement.bundle)
        return CGPoint(
            x: min(
                max(placement.lanePoint.x + offset.x,
                    battlefieldLayout.frame.minX - reach.minX),
                battlefieldLayout.frame.maxX - reach.maxX
            ),
            y: max(
                presentation.battlefieldFloorY,
                placement.frontY + offset.y
                    - placement.footMargin * presentation.formation.scale
            )
        )
    }

    /// A lone member's ideal is its base placement (seat cell or
    /// protected fallback) with x clamped inside the lane's authored
    /// bounds — the exact pre-easing placement the lone-survivor
    /// transition keeps.
    private func loneIdealPosition(
        _ placement: SoldierPlacement,
        baseIdeal: CGPoint,
        in presentation: LanePresentation
    ) -> CGPoint {
        let bounds = soldierHorizontalBounds(for: placement.bundle)
        let laneWidth = battlefieldLayout.frame.width / 3
        let padding = min(SoldierFormation.spacing / 2, laneWidth / 2)
        let minX = placement.lanePoint.x - laneWidth / 2 + padding
            - bounds.lowerBound * presentation.formation.scale
        let maxX = placement.lanePoint.x + laneWidth / 2 - padding
            - bounds.upperBound * presentation.formation.scale
        return CGPoint(x: min(max(baseIdeal.x, minX), maxX), y: baseIdeal.y)
    }

    /// One member's placement for this sync — the protected-unseated,
    /// lone-survivor, and ordinary dispatch. A protected member the grid
    /// could not seat lands on CHECKED free ground — never the shared
    /// lane point every unseated fallback used to hand out — or waits
    /// hidden when no collision-free ground exists. A lone member keeps
    /// the exact pre-easing placement: its own seat cell clamped inside
    /// the lane's authored bounds, landed directly when that ground is
    /// free — a lone seat is never held hostage. Everyone else takes the
    /// ordinary seat placement; a HIDDEN protected member lands this
    /// sync rather than converging hidden while shots are in the air —
    /// but only onto ground no rendered body still occupies (contested
    /// seats hand over when the vacating member actually clears).
    private func applySoldierLanePlacement(
        _ placement: SoldierPlacement,
        presented: Bool,
        loneSoldier: Bool,
        protectedIDs: Set<BattleCombatState.SoldierID>,
        in presentation: LanePresentation
    ) {
        if placement.unseatedProtected {
            applyUnseatedProtectedPlacement(placement, in: presentation)
            return
        }
        if loneSoldier && presented {
            if applyLonePlacement(
                placement,
                ideal: loneIdealPosition(
                    placement,
                    baseIdeal: soldierIdealPosition(
                        placement, in: presentation),
                    in: presentation
                ),
                in: presentation
            ) {
                soldierNodes[placement.id]?.presentationSeeded = true
            }
            return
        }
        applySoldierPlacement(
            placement,
            presented: presented,
            ideal: soldierIdealPosition(placement, in: presentation),
            // Visible protected members still glide.
            landImmediately: placement.bundle.root.isHidden
                && protectedIDs.contains(placement.id),
            in: presentation
        )
        soldierNodes[placement.id]?.presentationSeeded = true
    }

    /// Apply an unseated protected member's placement for this sync. A
    /// member already drawing outside the field is pulled back by the
    /// minimal inward shift BEFORE the landing pick — otherwise "the
    /// ground it already stands on" is the escaping spot and it parks
    /// off-field forever, or glides visibly through off-field space to
    /// get back. With a lawful current position the member lands on
    /// CHECKED free ground; with none it waits hidden rather than
    /// overlap another body on an unchecked point (a rendered member's
    /// own ground was already checked first — a `nil` landing means even
    /// that is occupied now).
    private func applyUnseatedProtectedPlacement(
        _ placement: SoldierPlacement,
        in presentation: LanePresentation
    ) {
        let bundle = placement.bundle
        if !bundle.root.isHidden,
           !battlefieldLayout.frame.contains(
               soldierRenderedFootprint(at: bundle.root.position, for: bundle)
           ) {
            bundle.root.position = clampedRootPosition(
                for: bundle, inside: battlefieldLayout.frame
            )
        }
        if let landing = unseatedProtectedLanding(
            placement, in: presentation
        ) {
            applySoldierPlacement(
                placement,
                presented: true,
                ideal: landing,
                landImmediately: bundle.root.isHidden,
                in: presentation
            )
            soldierNodes[placement.id]?.presentationSeeded = true
        } else {
            bundle.root.isHidden = true
        }
    }

    /// The checked landing for a protected member the seat grid could not
    /// place. Candidates in preference order: the ground it already
    /// stands on (rendered members keep it while it is free), its true
    /// combat position, then the extended grid cells nearest that
    /// position — each checked against EVERY reservation this sync knows
    /// (corpse/fade footprints, the claimed seat cells, and every other
    /// member's current readable rect). `nil` when no bounded
    /// collision-free ground exists: the caller keeps the member hidden
    /// rather than park two protected bodies on the same unchecked point.
    private func unseatedProtectedLanding(
        _ placement: SoldierPlacement,
        in presentation: LanePresentation
    ) -> CGPoint? {
        let bundle = placement.bundle
        let scale = presentation.formation.scale
        let bounds = soldierHorizontalBounds(for: bundle)
        let minX = battlefieldLayout.frame.minX - bounds.lowerBound * scale
        let maxX = battlefieldLayout.frame.maxX - bounds.upperBound * scale
        let truePosition = CGPoint(
            x: min(max(placement.lanePoint.x, minX), maxX),
            y: max(
                presentation.battlefieldFloorY,
                placement.frontY - placement.footMargin * scale
            )
        )
        func free(_ point: CGPoint) -> Bool {
            // A landing that draws outside the field is not free ground:
            // the whole canvas ∪ HP bar must stay contained, not just
            // the readable rect.
            guard battlefieldLayout.frame.contains(
                soldierRenderedFootprint(at: point, for: bundle)
            ) else { return false }
            let rect = soldierReadableFootprint(at: point, for: bundle)
            return !presentation.reservedFootprints
                    .contains { $0.intersects(rect) }
                && !presentation.claimedSeatRects
                    .contains { $0.intersects(rect) }
                && !presentation.contestedFootprints(placement.id)
                    .contains { $0.intersects(rect) }
        }
        var candidates: [CGPoint] = []
        if !bundle.root.isHidden && !presentation.layoutRemapped {
            // A rendered member keeps its own ground while it stays
            // free — but on a battlefield remap that position is stale
            // old-layout coordinates, never a candidate.
            candidates.append(bundle.root.position)
        }
        candidates.append(truePosition)
        // Extended rows reach the real floor — the same candidate fan a
        // lone survivor scans — ordered nearest the true position.
        let grid = presentation.grid
        let rowCount = max(
            grid.rowCount,
            Int(((grid.headY - presentation.battlefieldFloorY)
                / grid.rowPitch).rounded(.down)) + 1
        )
        var cells: [CGPoint] = []
        for row in 0..<rowCount {
            let rowRootY = max(
                presentation.battlefieldFloorY,
                grid.rowY(row) - placement.footMargin * scale
            )
            for columnIndex in grid.columnOffsets.indices {
                cells.append(CGPoint(
                    x: min(max(
                        grid.laneCenterX
                            + grid.columnOffsets[columnIndex] * grid.columnPitch,
                        minX
                    ), maxX),
                    y: rowRootY
                ))
            }
        }
        cells.sort {
            let lhs = hypot($0.x - truePosition.x, $0.y - truePosition.y)
            let rhs = hypot($1.x - truePosition.x, $1.y - truePosition.y)
            return lhs < rhs
        }
        candidates.append(contentsOf: cells)
        if let point = candidates.first(where: free) {
            return point
        }
        // Truthful targets cannot vanish: when every bounded landing
        // touches a corpse/fade reservation, fall back to ground that is
        // still clear of claimed seats and every LIVE readable body. A
        // fading corpse may share the member's ground — it is already on
        // its way out — but two live bodies may never merge, and the
        // lane's actual fire candidate must stay visible.
        func freeOfLiveGround(_ point: CGPoint) -> Bool {
            guard battlefieldLayout.frame.contains(
                soldierRenderedFootprint(at: point, for: bundle)
            ) else { return false }
            let rect = soldierReadableFootprint(at: point, for: bundle)
            return !presentation.claimedSeatRects
                    .contains { $0.intersects(rect) }
                && !presentation.contestedFootprints(placement.id)
                    .contains { $0.intersects(rect) }
        }
        if let point = candidates.first(where: freeOfLiveGround) {
            return point
        }
        // A battlefield remap must land every root in NEW coordinates:
        // the clamped true position is always inside the field, so it is
        // the fallback even when nothing is collision-free.
        return presentation.layoutRemapped ? truePosition : nil
    }

    /// Apply a lone member's placement for this sync. Its seat is never
    /// held hostage: when the ideal's actual rendered footprint is free
    /// — or it already stands there — that is the destination; otherwise
    /// it heads for the nearest free grid cell inside the authored drift
    /// (half a body height laterally, ~2.5 rows deep — never sideways
    /// around a body, never a snap across rows or the battlefield), and
    /// only when NOTHING bounded is free does it converge on the ideal
    /// anyway. The destination is contained outright — the whole canvas
    /// ∪ HP bar stays inside the field, not just the root — and a
    /// survivor already drawing outside is pulled back by the minimal
    /// inward shift THIS sync (a combat-time glide would render the
    /// canvas off-field for every frame in between). Otherwise how it
    /// GETS there is clocked by combat time: a rendered survivor glides
    /// at the bounded rate — a zero-elapsed redraw can never teleport it
    /// onto ground a corpse just vacated — while a battlefield remap or
    /// a never-rendered member still lands this sync. `true` when the
    /// member was placed/rendered this sync, `false` only for the
    /// never-rendered no-free-ground extreme.
    private func applyLonePlacement(
        _ placement: SoldierPlacement,
        ideal: CGPoint,
        in presentation: LanePresentation
    ) -> Bool {
        let bundle = placement.bundle
        func free(_ point: CGPoint) -> Bool {
            !presentation.reservedFootprints.contains {
                $0.intersects(soldierRenderedFootprint(at: point, for: bundle))
            }
        }
        // The destination keeps the WHOLE rendered footprint — canvas ∪
        // HP bar — inside the field, not just the root point: a seat
        // cell near the field's edge would otherwise park the survivor
        // with its canvas hanging off the battlefield.
        let containedIdeal = clampedFootprintPosition(
            ideal, for: bundle, inside: battlefieldLayout.frame
        )
        let idealIsFree = free(containedIdeal)
            || bundle.root.position == containedIdeal
        var boundedFreeSpot: CGPoint?
        if !idealIsFree {
            let grid = presentation.grid
            let scale = presentation.formation.scale
            let bounds = soldierHorizontalBounds(for: bundle)
            let canvasMinX = battlefieldLayout.frame.minX - bounds.lowerBound * scale
            let canvasMaxX = battlefieldLayout.frame.maxX - bounds.upperBound * scale
            // A lone member never folds, so the "+N" badge reserve does
            // not apply: candidates reach the real floor — the deepest
            // row whose top still sits above it (root y clamps to the
            // floor).
            let loneRowCount = max(
                grid.rowCount,
                Int(((grid.headY - presentation.battlefieldFloorY)
                    / grid.rowPitch).rounded(.down)) + 1
            )
            var candidates: [CGPoint] = []
            for row in 0..<loneRowCount {
                let rowRootY = max(
                    presentation.battlefieldFloorY,
                    grid.rowY(row) - placement.footMargin * scale
                )
                for columnIndex in grid.columnOffsets.indices {
                    candidates.append(CGPoint(
                        x: min(max(
                            placement.lanePoint.x
                                + grid.columnOffsets[columnIndex] * grid.columnPitch,
                            canvasMinX
                        ), canvasMaxX),
                        y: rowRootY
                    ))
                }
            }
            // Prefer the SMALLEST lateral drift: the survivor keeps its
            // column and steps back a row before it ever slides around a
            // corpse.
            candidates.sort {
                let lhsX = abs($0.x - ideal.x)
                let rhsX = abs($1.x - ideal.x)
                if lhsX != rhsX { return lhsX < rhsX }
                return abs($0.y - ideal.y) < abs($1.y - ideal.y)
            }
            let maxDriftX = soldierTargetHeight() * 0.5
            let maxDriftY = grid.rowPitch * 2.5
            boundedFreeSpot = candidates.first(where: { point in
                abs(point.x - bundle.root.position.x) <= maxDriftX
                    && abs(point.y - bundle.root.position.y) <= maxDriftY
                    && point.x >= canvasMinX - 0.5
                    && point.x <= canvasMaxX + 0.5
                    && free(point)
            })
        }
        let destination = idealIsFree
            ? containedIdeal
            : (boundedFreeSpot ?? containedIdeal)
        if presentation.layoutRemapped {
            // Combat-time glides cannot repair stale coordinates while
            // ticking is paused: land in the NEW coordinate system this
            // sync, on free ground when a bounded one exists.
            bundle.root.position = destination
            bundle.root.isHidden = false
            return true
        }
        if bundle.presentationSeeded && !bundle.root.isHidden,
           !battlefieldLayout.frame.contains(
               soldierRenderedFootprint(at: bundle.root.position, for: bundle)
           ) {
            // A rendered survivor already drawing outside the field
            // cannot wait for the combat-time glide — every sampled
            // frame in between would render the canvas off-field. It is
            // pulled back by the minimal inward shift this sync, then
            // converges on the destination as usual from inside.
            bundle.root.position = clampedRootPosition(
                for: bundle, inside: battlefieldLayout.frame
            )
            bundle.root.isHidden = false
            return true
        }
        if bundle.presentationSeeded && !bundle.root.isHidden {
            // A rendered survivor's motion is clocked by elapsed combat
            // time — the freed ideal is a destination, never a snap
            // target, however it became free this sync.
            bundle.root.position = steppedPosition(
                from: bundle.root.position,
                toward: destination,
                maxDistance: presentation.presentationStep
            )
            bundle.root.isHidden = false
            return true
        }
        // Never rendered (or sitting hidden): appear on free ground —
        // the ideal when it is free, else the bounded free cell — and
        // stay hidden rather than land on a corpse or at the origin.
        if idealIsFree || boundedFreeSpot != nil {
            bundle.root.position = destination
            bundle.root.isHidden = false
            return true
        }
        bundle.root.isHidden = true
        return false
    }

    /// Apply one member's presentation for this sync:
    /// * folded → hidden, bookkeeping converges at the bounded rate;
    /// * fresh spawn / layout remap → lands directly on its seat;
    /// * already rendered → converges visibly at the bounded rate;
    /// * hidden→presented promotion → converges HIDDEN and unhides only
    ///   on arrival — it never renders at its stale folded spot, so it
    ///   can never park on other bodies or freeze the overlap on a pause.
    /// Every materialization — fresh landing, protected promotion, or a
    /// converged unhide — is additionally occupancy-gated: the member
    /// reveals only onto ground no rendered body currently occupies, so
    /// a contested seat hands over when its previous occupant actually
    /// clears rather than popping a second body into it.
    private func applySoldierPlacement(
        _ placement: SoldierPlacement,
        presented: Bool,
        ideal: CGPoint,
        landImmediately: Bool,
        in presentation: LanePresentation
    ) {
        let bundle = placement.bundle
        let step = presentation.presentationStep
        let fresh = presentation.layoutRemapped || !bundle.presentationSeeded
        // Occupancy is checked against LIVE readable rects — evaluated at
        // decision time so members placed earlier this sync already
        // contest the ground they now stand on. A battlefield remap is
        // exempt: every root re-places at once, so stale pre-remap
        // positions cannot legitimately contest anything.
        func landingIsFree() -> Bool {
            guard !presentation.layoutRemapped else { return true }
            let rect = soldierReadableFootprint(at: ideal, for: bundle)
            return !presentation.contestedFootprints(placement.id)
                .contains { $0.intersects(rect) }
        }
        if !presented {
            bundle.root.isHidden = true
            bundle.root.position = fresh || landImmediately
                ? ideal
                : steppedPosition(
                    from: bundle.root.position,
                    toward: ideal,
                    maxDistance: step
                )
            return
        }
        if (fresh || landImmediately) && landingIsFree() {
            bundle.root.position = ideal
            bundle.root.isHidden = false
            return
        }
        if fresh {
            // A never-seeded node whose ground is still physically
            // occupied must not pop in at the creation origin and glide
            // visibly across other bodies: it waits hidden at the seat's
            // bookkeeping spot and reveals on the arrival check below
            // once the ground actually clears (contested-seat handover).
            bundle.root.isHidden = true
            bundle.root.position = ideal
        }
        bundle.root.position = steppedPosition(
            from: bundle.root.position,
            toward: ideal,
            maxDistance: step
        )
        if !bundle.root.isHidden {
            return
        }
        // Arrival, not bitwise equality — SpriteKit quantizes node
        // positions to Float precision, so a converged root reads back a
        // few micro-points off `ideal` forever. And arrival alone is not
        // enough: the member unhides only once the ground it lands on is
        // actually clear.
        bundle.root.isHidden = hypot(
            bundle.root.position.x - ideal.x,
            bundle.root.position.y - ideal.y
        ) > SoldierFormation.seatArrivalTolerance
            || !landingIsFree()
    }

    /// The rendered reservation unit for a soldier node whose root sits at
    /// `position`: its ACTUAL horizontal bounds — the whole sprite canvas
    /// plus the HP bar — and its visual top at the root's CURRENT scale.
    /// Measured from the bundle's own nodes rather than the lane's shared
    /// formation constants, so a pending corpse reserves its real
    /// transformed bounds (a Captain mid-retreat scale-down shrinks for
    /// real), and attack/hit art that reaches past the walk-pose logical
    /// body is still covered.
    private func soldierRenderedFootprint(
        at position: CGPoint,
        for bundle: SoldierNodeBundle
    ) -> CGRect {
        let scale = bundle.root.xScale > 0 ? bundle.root.xScale : 1
        let bounds = soldierHorizontalBounds(for: bundle)
        let width = (bounds.upperBound - bounds.lowerBound) * scale
        let footMargin = animatedSoldierFootMargin(for: bundle)
        let accumulated = bundle.body.calculateAccumulatedFrame()
        // The rect covers everything the node can draw: its bottom is the
        // LOWER of the logical foot margin and the sprite's own accumulated
        // bounds (a full-canvas frame reaches below the walk pose's feet),
        // its top the higher of body+bar and the canvas top, and its
        // horizontal extent the actual (possibly asymmetric) bounds — all
        // through the root's current scale.
        let bottom = min(footMargin, accumulated.minY)
        let top = max(
            soldierLogicalBodyFrame(for: bundle).maxY + 6.5,
            accumulated.maxY
        )
        return CGRect(
            x: position.x + bounds.lowerBound * scale,
            y: position.y + bottom * scale,
            width: width,
            height: max(4, (top - bottom) * scale)
        )
    }

    /// The READABLE presentation unit for a soldier node whose root sits at
    /// `position`: the logical walk-pose body unioned with its HP bar —
    /// exactly the parts that merge into an unreadable block when they
    /// overlap, and the unit the seat grid is pitched on. Transient
    /// attack/hit canvas reach beyond this rect is pose art, not standing
    /// ground; corpses and fades keep the full `soldierRenderedFootprint`.
    private func soldierReadableFootprint(
        at position: CGPoint,
        for bundle: SoldierNodeBundle
    ) -> CGRect {
        let scale = bundle.root.xScale > 0 ? bundle.root.xScale : 1
        let bodyFrame = soldierLogicalBodyFrame(for: bundle)
        let barHalfWidth = (
            soldierHPBarWidth(forBodyWidth: bodyFrame.width)
                + bundle.hpBarBackground.lineWidth
        ) / 2
        let minX = min(bodyFrame.minX, -barHalfWidth)
        let maxX = max(bodyFrame.maxX, barHalfWidth)
        let footMargin = animatedSoldierFootMargin(for: bundle)
        return CGRect(
            x: position.x + minX * scale,
            y: position.y + footMargin * scale,
            width: (maxX - minX) * scale,
            height: (bodyFrame.maxY + 6.5 - footMargin) * scale
        )
    }

    /// HPA-812: the per-lane "+N" overflow summary for folded live soldiers —
    /// a small non-interactive pill pinned just above the battlefield floor
    /// under the lane's column. Created on demand, updated every sync, and
    /// removed the moment nothing is folded.
    private func syncSoldierOverflowBadge(
        lane: BattleLane,
        foldedCount: Int,
        anchorX: CGFloat?
    ) {
        let name = "\(BattlefieldNodeName.soldierOverflowBadgePrefix)\(lane.rawValue)"
        let badge = soldierLayer.childNode(withName: name)
        guard foldedCount > 0, let anchorX else {
            badge?.removeFromParent()
            return
        }
        let badgeNode = badge ?? makeSoldierOverflowBadge(name: name)
        if let label = badgeNode.childNode(withName: "count") as? SKLabelNode {
            label.text = "+\(foldedCount)"
            // The count is truthful and unbounded, so the pill fits the
            // label — but must stay inside its lane column: past that width
            // the FONT shrinks until the exact count still fits with
            // padding, so a three-digit "+N" never crops and never spills
            // over a neighbouring lane's ground.
            let maxPillWidth = max(28, battlefieldLayout.frame.width / 3 - 8)
            var fontSize: CGFloat = 10
            label.fontSize = fontSize
            while label.frame.width + 16 > maxPillWidth, fontSize > 6 {
                fontSize -= 1
                label.fontSize = fontSize
            }
            if let pill = badgeNode.childNode(withName: "pill") as? SKShapeNode {
                let pillWidth = min(maxPillWidth, max(36, label.frame.width + 16))
                if abs(pill.frame.width - pillWidth) > 0.5 {
                    let height = SoldierFormation.overflowBadgeHeight
                    pill.path = CGPath(
                        roundedRect: CGRect(
                            x: -pillWidth / 2, y: -height / 2,
                            width: pillWidth, height: height
                        ),
                        cornerWidth: height / 2,
                        cornerHeight: height / 2,
                        transform: nil
                    )
                }
            }
        }
        // Clamp the anchor as well as the pill: a wide count under a lane
        // edge must not push chrome off the battlefield either way.
        let pillHalf = (badgeNode.childNode(withName: "pill")?.frame.width ?? 36) / 2
        badgeNode.position = CGPoint(
            x: min(
                max(anchorX, battlefieldLayout.frame.minX + pillHalf),
                battlefieldLayout.frame.maxX - pillHalf
            ),
            y: battlefieldLayout.frame.minY + SoldierFormation.overflowBadgeHeight / 2 + 2
        )
    }

    private func makeSoldierOverflowBadge(name: String) -> SKNode {
        let badge = SKNode()
        badge.name = name
        badge.zPosition = 4
        let pill = SKShapeNode(
            rectOf: CGSize(width: 36, height: SoldierFormation.overflowBadgeHeight),
            cornerRadius: SoldierFormation.overflowBadgeHeight / 2
        )
        pill.name = "pill"
        pill.fillColor = SKColor(white: 0.05, alpha: 0.85)
        pill.strokeColor = GameUITheme.Color.gold.withAlphaComponent(0.7)
        pill.lineWidth = 1
        badge.addChild(pill)
        let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        label.name = "count"
        label.fontSize = 10
        label.fontColor = GameUITheme.Color.gold
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        badge.addChild(label)
        soldierLayer.addChild(badge)
        return badge
    }

    /// Keeps one live soldier's Rally protection accent in step with the
    /// transient timer (HPA-475): a protected ordinary soldier in the
    /// captured lane shows a feet/bottom-center accent behind its body;
    /// the Captain, off-lane soldiers, and an expired timer never do.
    /// Driven by the combat tick's node sync, so visibility tracks
    /// `rallyRemainingSeconds` exactly like the HUD's Active state.
    private func syncRallyProtectionAccent(for soldier: BattleCombatState.Soldier) {
        guard let bundle = soldierNodes[soldier.id] else {
            return
        }
        if combat.isRallyProtected(soldier) {
            let bodyHeight = soldierTargetHeight()
            if let accent = bundle.rallyAccent, bundle.rallyAccentHeight == bodyHeight {
                accent.isHidden = false
            } else {
                // Body refits every tick while the accent is authored once —
                // rebuild when the target height moved (resize mid-Rally).
                bundle.rallyAccent?.removeFromParent()
                let accent = makeRallyProtectionAccent(bodyHeight: bodyHeight)
                bundle.root.addChild(accent)
                soldierNodes[soldier.id]?.rallyAccent = accent
                soldierNodes[soldier.id]?.rallyAccentHeight = bodyHeight
            }
        } else {
            bundle.rallyAccent?.isHidden = true
        }
    }

    /// Builds the Rally protection accent (HPA-475): probes the optional
    /// `rally-protection-accent` art (feet/bottom-center, behind the
    /// soldier — the HPA-476 contract) and falls back to a restrained
    /// procedural glow until that asset ships. The soldier root's origin
    /// is the feet baseline; z 0 keeps the accent behind the body (z 1)
    /// and HP bar (z 2–3).
    private func makeRallyProtectionAccent(bodyHeight: CGFloat) -> SKNode {
        let accent: SKNode
        if UIImage(named: BattleAssetName.rallyProtectionAccent) != nil {
            let sprite = SKSpriteNode(imageNamed: BattleAssetName.rallyProtectionAccent)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.size = CGSize(width: bodyHeight, height: bodyHeight)
            accent = sprite
        } else {
            let glow = SKShapeNode(
                ellipseOf: CGSize(width: bodyHeight * 0.72, height: bodyHeight * 0.2)
            )
            glow.fillColor = GameUITheme.Color.gold.withAlphaComponent(0.32)
            glow.strokeColor = GameUITheme.Color.gold.withAlphaComponent(0.55)
            glow.lineWidth = 1
            glow.glowWidth = 2
            glow.position = CGPoint(x: 0, y: bodyHeight * 0.06)
            accent = glow
        }
        accent.zPosition = 0
        return accent
    }

    /// Scaled transparent-foot margin for an animated soldier — the vertical
    /// distance between the canvas bottom (anchorPoint.y == 0) and the visible
    /// feet. Returns 0 for non-animated (static fallback) sprites, which are
    /// authored without the full-canvas margin.
    private func animatedSoldierFootMargin(for bundle: SoldierNodeBundle) -> CGFloat {
        guard bundle.isAnimatedCanvas else {
            return 0
        }

        let geometry = SoldierAnimationGeometry(type: bundle.type)
        let frameSize = geometry.frameSize(forBodyHeight: soldierTargetHeight())
        return geometry.bodyRegion.minY * frameSize.height
    }

    private func soldierTargetHeight() -> CGFloat {
        if size.height < 500 {
            return max(38, min(50, size.height * 0.12))
        }

        return max(54, min(70, size.height * 0.075))
    }

    private func fitSoldierBodyNode(
        _ node: SKNode,
        type: SoldierType,
        targetHeight: CGFloat,
        isAnimatedCanvas: Bool
    ) {
        guard let sprite = node as? SKSpriteNode else {
            fitBattleNode(node, targetHeight: targetHeight)
            return
        }

        // Only the animation-canvas sprite is authored against the normalized
        // `SoldierAnimationGeometry` body bounds. The static fallback sprite is
        // a standalone asset; sizing it via the geometry would stretch it to
        // the full animation canvas and misplace its HP bar, so it stays on the
        // legacy fit path that scales to its intrinsic texture dimensions.
        guard isAnimatedCanvas else {
            fitBattleNode(sprite, targetHeight: targetHeight)
            return
        }

        sprite.setScale(1)
        sprite.size = SoldierAnimationGeometry(type: type).frameSize(forBodyHeight: targetHeight)
    }

    // MARK: Guard scene presentation (HPA-469)

    /// Mirrors `syncSoldierNodes` for Guards: positions come from combat
    /// state every tick, dead Guards drop their nodes, and the Barracks
    /// status label tracks the durable Guard count. Presentation is purely
    /// observational — the model remains the sole timing authority.
    private func syncGuardNodes() {
        let livingGuards = combat.guards.filter(\.isAlive)
        let liveIDs = Set(livingGuards.map(\.id))

        for id in Array(guardNodes.keys) where !liveIDs.contains(id) {
            guardNodes[id]?.root.removeFromParent()
            guardNodes.removeValue(forKey: id)
        }

        for guardActor in livingGuards {
            let bundle = guardNodes[guardActor.id] ?? createGuardNode()
            bundle.root.position = point(forLane: guardActor.lane, position: guardActor.position)
            bundle.root.setScale(soldierTargetHeight())
            guardNodes[guardActor.id] = bundle
            syncGuardLocomotion(for: guardActor.id)
        }

        if let barracks = state.currentSiegeLayout.barracksObjective,
           let container = siegeObjectiveNodes[barracks.id],
           let label = container.childNode(withName: GuardNodeName.statusLabel) as? SKLabelNode {
            label.text = barracksStatusText
        }
    }

    private func createGuardNode() -> GuardNodeBundle {
        let root = SKNode()
        root.name = GuardNodeName.root
        let visual = SKNode()
        visual.name = GuardNodeName.visual
        root.addChild(visual)

        // The animated path requires the complete 30-frame `siege-guard`
        // trio — the same gate `makeSoldierNode` applies. A partial or
        // missing trio would leave `soldierAnimationTextures` returning an
        // empty set (asserting in DEBUG) and the sprite textureless, so the
        // node falls back to the procedural Guard body instead.
        let isAnimatedCanvas = firstAvailableSoldierAnimationFrameName(
            for: SiegeObjectiveAssetContract.guardAssetPrefix
        ) != nil
        let body: SKNode
        if isAnimatedCanvas {
            let sprite = SKSpriteNode(texture: soldierAnimationTextures(
                for: SiegeObjectiveAssetContract.guardAssetPrefix, action: .walk
            ).first)
            let geometry = SoldierAnimationGeometry(type: .infantry)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.size = geometry.frameSize(forBodyHeight: 1)
            sprite.position.y = -geometry.bodyRegion.minY * sprite.size.height
            visual.addChild(sprite)
            body = sprite
        } else {
            body = makeGuardFallbackBody(in: visual)
        }
        body.name = GuardNodeName.body
        soldierLayer.addChild(root)
        return GuardNodeBundle(
            root: root, visual: visual, body: body, isAnimatedCanvas: isAnimatedCanvas
        )
    }

    /// Procedural Guard placeholder for a missing `siege-guard` trio: the
    /// pre-art body/shield/head/helmet composition laid out in the same
    /// unit-height space as the animated canvas, so the root's scale still
    /// owns on-screen size. Release keeps the Guards visible rather than
    /// shipping a textureless sprite; the trio's completeness is guarded
    /// separately by `PyxisTests.allSoldierAnimationFramesAreInstalled`.
    private func makeGuardFallbackBody(in visual: SKNode) -> SKNode {
        let body = SKShapeNode(
            rect: CGRect(x: -0.16, y: 0.10, width: 0.32, height: 0.42), cornerRadius: 0.06
        )
        body.fillColor = SKColor(red: 0.52, green: 0.20, blue: 0.16, alpha: 1)
        body.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        body.lineWidth = 0.02
        visual.addChild(body)

        let shield = SKShapeNode(
            rect: CGRect(x: -0.13, y: 0.02, width: 0.26, height: 0.34), cornerRadius: 0.09
        )
        shield.name = GuardNodeName.shield
        shield.fillColor = SKColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1)
        shield.strokeColor = SKColor(white: 1.0, alpha: 0.45)
        shield.lineWidth = 0.02
        shield.zPosition = 1
        visual.addChild(shield)

        let head = SKShapeNode(circleOfRadius: 0.11)
        head.name = GuardNodeName.head
        head.fillColor = SKColor(red: 0.78, green: 0.66, blue: 0.50, alpha: 1)
        head.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        head.lineWidth = 0.02
        head.position = CGPoint(x: 0, y: 0.60)
        visual.addChild(head)

        let helmet = SKShapeNode(
            rect: CGRect(x: -0.13, y: 0.60, width: 0.26, height: 0.14), cornerRadius: 0.06
        )
        helmet.name = GuardNodeName.helmet
        helmet.fillColor = SKColor(red: 0.24, green: 0.27, blue: 0.32, alpha: 1)
        helmet.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        helmet.lineWidth = 0.02
        visual.addChild(helmet)
        return body
    }

    private func syncGuardLocomotion(for guardID: BattleCombatState.GuardID) {
        guard let bundle = guardNodes[guardID], bundle.transientRemaining <= 0 else { return }
        // The procedural fallback has no walk frames or idle texture to drive.
        guard bundle.isAnimatedCanvas, let sprite = bundle.body as? SKSpriteNode else { return }
        if combat.guards.first(where: { $0.id == guardID })?.isMoving == true {
            startWalkAnimation(
                on: bundle.visual, sprite: sprite,
                assetPrefix: SiegeObjectiveAssetContract.guardAssetPrefix, type: .infantry
            )
        } else {
            bundle.visual.removeAction(forKey: SoldierAnimationKey.walk)
            sprite.texture = soldierAnimationTextures(
                for: SiegeObjectiveAssetContract.guardAssetPrefix, action: .walk
            ).first
        }
    }

    // Raw frame time matches SpriteKit actions, including a frame that stalls past the pose duration.
    private func decrementGuardAnimationRemaining(deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }
        for id in Array(guardNodes.keys) {
            guard var bundle = guardNodes[id], bundle.transientRemaining > 0 else { continue }
            bundle.transientRemaining = max(0, bundle.transientRemaining - deltaTime)
            // Snap to zero below the same 1ms epsilon the soldier hit
            // countdown uses: floating-point residue (e.g. 1.4e-16 after
            // nine 0.1s steps from 0.9s) would otherwise keep the transient
            // "active" past the authored duration and drop the next attack
            // trigger in `playGuardTransient`.
            if bundle.transientRemaining <= 0.001 {
                bundle.transientRemaining = 0
                bundle.transientAction = nil
                bundle.visual.removeAction(forKey: SoldierAnimationKey.attack)
                bundle.visual.removeAction(forKey: SoldierAnimationKey.hit)
            }
            guardNodes[id] = bundle
        }
    }

    private func playGuardTransient(_ action: SoldierAnimationAction, for guardID: BattleCombatState.GuardID) {
        guard action != .walk, var bundle = guardNodes[guardID],
              bundle.isAnimatedCanvas, let sprite = bundle.body as? SKSpriteNode else { return }
        // Guard priority is stricter than the shared soldier helper: a hit
        // preempts a live attack, a live hit absorbs repeated hits without
        // restarting, and no attack starts while any transient is in flight
        // (the 0.9s hit reaction is shorter than the Guard's 1.0s attack
        // interval, so the soldier helper's hit-duration carve-out would
        // never suppress an attack on a live hit).
        if bundle.transientRemaining > 0,
           action == .attack || bundle.transientAction == .hit { return }
        bundle.transientAction = action
        bundle.transientRemaining = SoldierAnimationTiming.totalDuration(for: action, type: .infantry)
        guardNodes[guardID] = bundle
        let visual = bundle.visual
        runTransientAnimation(
            action, on: visual, sprite: sprite,
            actor: (SiegeObjectiveAssetContract.guardAssetPrefix, .infantry)
        ) { [weak self, weak visual] in
            guard let self, let visual, self.guardNodes[guardID]?.visual === visual else { return }
            self.guardNodes[guardID]?.transientRemaining = 0
            self.guardNodes[guardID]?.transientAction = nil
            visual.removeAction(forKey: SoldierAnimationKey.attack)
            visual.removeAction(forKey: SoldierAnimationKey.hit)
            self.syncGuardLocomotion(for: guardID)
        }
    }

    /// Maps Guard tick events to short observational actions (HPA-469).
    /// Runs above `applyCombatResult`'s soldierAttacks early return so a
    /// guard-only tick still presents; the model stays the sole timing
    /// authority.
    private func playGuardEventFeedback(for result: BattleCombatState.TickResult) {
        for attack in result.guardAttacks {
            playGuardAttackFeedback(for: attack.guardID)
        }
        for hit in result.guardHits {
            playGuardHitFeedback(for: hit.guardID)
        }
        for loss in result.guardLosses {
            playGuardLossFeedback(for: loss.guardID)
        }
    }

    private func playGuardAttackFeedback(for guardID: BattleCombatState.GuardID) {
        playGuardTransient(.attack, for: guardID)
    }

    private func playGuardHitFeedback(for guardID: BattleCombatState.GuardID) {
        playGuardTransient(.hit, for: guardID)
    }

    /// Fade-out removal for a dead Guard. The node leaves `guardNodes`
    /// immediately so per-tick sync never resurrects it; the fade action
    /// removes it from the scene when done.
    private func playGuardLossFeedback(for guardID: BattleCombatState.GuardID) {
        guard let bundle = guardNodes.removeValue(forKey: guardID) else {
            return
        }
        let fade = SKAction.fadeOut(withDuration: 0.18)
        let remove = SKAction.removeFromParent()
        bundle.root.run(SKAction.sequence([fade, remove]), withKey: GuardAnimationKey.loss)
    }

    private func point(forLane lane: BattleLane, position: Double) -> CGPoint {
        battlefieldLayout.point(forLane: lane, position: position)
    }

    private func layoutSoldierHPBar(_ bundle: SoldierNodeBundle, soldier: BattleCombatState.Soldier) {
        layoutSoldierHPBar(
            bundle,
            id: soldier.id,
            hpPercent: min(
                max(CGFloat(soldier.currentHP) / CGFloat(max(1, soldier.maxHP)), 0),
                1
            )
        )
    }

    /// Rebuilds the bar paths for `bundle`'s CURRENT body geometry at the
    /// given fill — also reachable for a pending-removal corpse, whose
    /// `Soldier` has already left `combat.soldiers` but whose bar must
    /// still track the refit body or its painted pixels escape the
    /// measured footprint.
    private func layoutSoldierHPBar(
        _ bundle: SoldierNodeBundle,
        id: BattleCombatState.SoldierID,
        hpPercent percent: CGFloat
    ) {
        let bodyFrame = soldierLogicalBodyFrame(for: bundle)
        let width = soldierHPBarWidth(forBodyWidth: bodyFrame.width)
        // The path depends only on the body's laid-out width, its top edge,
        // and the fill ratio — identical inputs rebuild an identical path,
        // so unchanged members skip the CGPath work entirely (HPA-812
        // hidden-roster perf).
        let signature = (
            percent: Int((min(max(percent, 0), 1) * 4096).rounded()),
            width: Int((width * 4 + bodyFrame.maxY * 4).rounded())
        )
        if bundle.hpBarSignature.map({ $0 == signature }) == true {
            return
        }
        soldierNodes[id]?.hpBarSignature = signature
        let height: CGFloat = 5
        let y = bodyFrame.maxY + 1.5
        let percent = min(max(percent, 0), 1)

        bundle.hpBarBackground.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: y, width: width, height: height),
            cornerWidth: height / 2,
            cornerHeight: height / 2,
            transform: nil
        )
        bundle.hpBarFill.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: y, width: max(1, width * percent), height: height),
            cornerWidth: height / 2,
            cornerHeight: height / 2,
            transform: nil
        )
    }

    private func soldierHPBarWidth(forBodyWidth bodyWidth: CGFloat) -> CGFloat {
        max(36, min(56, bodyWidth * 0.72))
    }

    private func soldierHorizontalBounds(for bundle: SoldierNodeBundle) -> ClosedRange<CGFloat> {
        let bodyFrame = bundle.body.calculateAccumulatedFrame()
        let barWidth = soldierHPBarWidth(forBodyWidth: soldierLogicalBodyFrame(for: bundle).width)
        let barHalfWidth = (barWidth + bundle.hpBarBackground.lineWidth) / 2
        return min(bodyFrame.minX, -barHalfWidth)...max(bodyFrame.maxX, barHalfWidth)
    }

    private func soldierLogicalBodyFrame(for bundle: SoldierNodeBundle) -> CGRect {
        guard bundle.isAnimatedCanvas,
              let sprite = bundle.body as? SKSpriteNode else {
            return bundle.body.calculateAccumulatedFrame()
        }

        return SoldierAnimationGeometry(type: bundle.type).logicalBodyFrame(frameSize: sprite.size)
    }

    /// Axis-aligned frame of `node` in scene coordinates, or nil while the
    /// node is detached. Production geometry (the dense-formation gate-bar
    /// clearance in `syncSoldierNodes`) and the DEBUG test probes share this
    /// one conversion, so it lives outside the `#if DEBUG` extension.
    private func sceneFrame(for node: SKNode) -> CGRect? {
        guard let parent = node.parent else {
            return nil
        }

        let frame = node.calculateAccumulatedFrame()
        let points = [
            CGPoint(x: frame.minX, y: frame.minY),
            CGPoint(x: frame.maxX, y: frame.minY),
            CGPoint(x: frame.minX, y: frame.maxY),
            CGPoint(x: frame.maxX, y: frame.maxY)
        ].map { parent.convert($0, to: self) }

        guard
            let minX = points.map(\.x).min(),
            let maxX = points.map(\.x).max(),
            let minY = points.map(\.y).min(),
            let maxY = points.map(\.y).max()
        else {
            return nil
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func clearLiveCombat() {
        // Charges refill only from valid active-tick time (HPA-582): carry
        // the banked counters across the combat rebuild so a
        // background/foreground cycle can never silently refill the pool.
        let deployCharges = combat.manualDeployCharges
        let deployRechargeSeconds = combat.manualDeployRechargeSeconds
        combat = Self.makeCombat(for: state, seed: combatSeed)
        combat.restoreManualDeployCharges(deployCharges, rechargeSeconds: deployRechargeSeconds)
        // Deliberately no Guard restoration here: clearLiveCombat runs on
        // conquest/idle-conquest (stage leaves .battleActive, so this combat
        // never ticks again and nothing can sync it) and on background —
        // where the foreground handler rehydrates persisted Guards into this
        // fresh combat BEFORE the first tick can sync an empty roster over
        // the post-idle-settlement durable state.
        lastUpdateTime = nil

        for id in Array(soldierNodes.keys) {
            removeSoldierNode(id: id, animated: false)
        }
        for bundle in guardNodes.values {
            bundle.root.removeFromParent()
        }
        guardNodes.removeAll()
        pendingAnimatedRemovalSoldierIDs.removeAll()
        soldierHitAnimationRemaining.removeAll()
        // Fading roots are still parented — detach them explicitly instead
        // of only dropping the reservation, or the scene keeps rendering
        // ghost corpses whose owner map forgot them (round-3 review).
        for entry in soldierFadingFootprints.values {
            entry.root.removeFromParent()
        }
        soldierFadingFootprints.removeAll()
        soldierSeats.removeAll()
        seatFootprintsBySoldierID.removeAll()
        lastSoldierSyncBattlefieldFrame = nil
        lastDefensiveShotTargetID = nil
        #if DEBUG
        lastTowerProjectileEndpointForTestingStorage = nil
        #endif
        // The overflow badges belong to the live presentation too: teardown
        // does not run another soldier sync, so they must leave explicitly
        // rather than linger as a stale "+N" in the cleared scene.
        for lane in BattleLane.allCases {
            soldierLayer.childNode(
                withName: "\(BattlefieldNodeName.soldierOverflowBadgePrefix)\(lane.rawValue)"
            )?.removeFromParent()
        }
        for label in objectiveDamageLabels.values {
            label.removeAllActions()
            label.removeFromParent()
        }
        objectiveDamageLabels.removeAll()

        applyBattleHUD()
    }

    private func removeSoldierNode(id: BattleCombatState.SoldierID, animated: Bool) {
        guard let bundle = soldierNodes.removeValue(forKey: id) else {
            return
        }
        pendingAnimatedRemovalSoldierIDs.remove(id)
        soldierHitAnimationRemaining.removeValue(forKey: id)
        soldierSeats[bundle.lane]?.removeValue(forKey: id)
        seatFootprintsBySoldierID.removeValue(forKey: id)

        bundle.root.removeAllActions()
        // Body actions (walk/attack/hit) live on `bundle.body`, not `root`.
        // Stop them too so a killed soldier doesn't keep animating its body
        // during the fade-out.
        bundle.body.removeAllActions()

        if animated {
            // The authored 0.18 s fade still renders — the ground stays
            // reserved until the remove action actually lands, so no live
            // soldier can ever be seated on a still-visible corpse. The
            // reservation keys on the root itself (the bundle leaves
            // `soldierNodes` immediately).
            let key = ObjectIdentifier(bundle.root)
            soldierFadingFootprints[key] = (
                root: bundle.root,
                rect: bundle.corpseFootprint ?? soldierRenderedFootprint(
                    at: bundle.root.position, for: bundle
                )
            )
            let fade = SKAction.fadeOut(withDuration: 0.18)
            let release = SKAction.run { [weak self] in
                self?.soldierFadingFootprints.removeValue(forKey: key)
            }
            let remove = SKAction.removeFromParent()
            bundle.root.run(SKAction.sequence([fade, release, remove]))
        } else {
            bundle.root.removeFromParent()
        }
    }

    /// HPA-475 asset-prefix parameterization: ordinary soldiers look their
    /// frames up under `SoldierType.rawValue`; the flagged Captain under
    /// `vanguard-captain`. The Captain reuses the infantry type for all
    /// combat/animation math — only the asset catalog differs.
    private func soldierAssetPrefix(for type: SoldierType, isCaptain: Bool) -> String {
        isCaptain ? BattleAssetName.captainAssetPrefix : type.rawValue
    }

    private func soldierAssetPrefix(for bundle: SoldierNodeBundle) -> String {
        soldierAssetPrefix(for: bundle.type, isCaptain: bundle.isCaptain)
    }

    private func makeSoldierNode(for soldier: BattleCombatState.Soldier) -> SKNode {
        let body: SKNode
        let visualColor = soldierVisualColor(for: soldier.type)
        let assetPrefix = soldierAssetPrefix(for: soldier.type, isCaptain: soldier.isCaptain)
        let preferredAssetName = soldier.isCaptain
            ? BattleAssetName.captainResting
            : soldierAssetName(for: soldier.type)
        let fallbackAssetName = BattleAssetName.normalSoldier
        let assetName = UIImage(named: preferredAssetName) != nil ? preferredAssetName : fallbackAssetName

        if let animatedTextureName = firstAvailableSoldierAnimationFrameName(for: assetPrefix) {
            let sprite = SKSpriteNode(texture: soldierAnimationTexture(named: animatedTextureName))
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            body = sprite
        } else if UIImage(named: assetName) != nil {
            let sprite = SKSpriteNode(imageNamed: assetName)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            if assetName == fallbackAssetName {
                sprite.color = visualColor
                sprite.colorBlendFactor = soldier.type == .infantry ? 0.15 : 0.55
            }
            body = sprite
        } else {
            // Both the animated canvas and the static sprite asset are missing.
            // This is almost always a build/asset mistake; in DEBUG we fail
            // loudly so it gets noticed, mirroring `soldierAnimationTextures`.
            // In release we keep the colored-rectangle fallback so a missing
            // asset never crashes the game, but it should never ship this far.
            #if DEBUG
            assertionFailure(
                "Missing soldier asset for \(assetPrefix) (no animated canvas or static sprite \"\(assetName)\")"
            )
            #endif
            let shape = SKShapeNode(rect: CGRect(x: -10, y: 0, width: 20, height: 28), cornerRadius: 5)
            shape.fillColor = visualColor
            shape.strokeColor = SKColor(white: 1.0, alpha: 0.4)
            shape.lineWidth = 2
            body = shape
        }

        body.name = assetName
        return body
    }

    private func soldierAssetName(for type: SoldierType) -> String {
        switch type {
        case .archer:
            return BattleAssetName.archerSoldier
        case .infantry, .cavalry, .mage, .siege:
            return BattleAssetName.normalSoldier
        }
    }

    private func soldierAnimationFrameNames(for assetPrefix: String, action: SoldierAnimationAction) -> [String] {
        (1...SoldierAnimationTiming.frameCount).map {
            "\(assetPrefix)-\(action.rawValue)-\(String(format: "%02d", $0))"
        }
    }

    /// Probes whether the animated-canvas sprite path is available for `type`
    /// by checking every frame of every action in the trio (10 walk + 10
    /// attack + 10 hit = 30 frames). Returns the walk-01 frame name only when
    /// the complete trio is installed, so `isAnimatedCanvas` is true only for
    /// a fully authored set — a partial set (e.g. walk + attack but no hit, or
    /// a hand-edited mid-sequence drop like `cavalry-walk-07` removed while
    /// `cavalry-walk-01` is kept) falls through to the static sprite path
    /// instead of leaving `playSoldierAnimation` to silently no-op the
    /// missing action while the soldier keeps walking.
    ///
    /// This is stricter than the previous first-frame-only probe, which left a
    /// gap: a mid-sequence drop kept `isAnimatedCanvas == true`, then
    /// `soldierAnimationTextures(for:action:)` returned an empty array for the
    /// incomplete action (firing `assertionFailure` in DEBUG) and
    /// `playSoldierAnimation` silently no-oped in release, leaving a frozen or
    /// partially animated soldier instead of using the static fallback.
    /// Requiring all 30 frames here closes that gap at the gate.
    ///
    /// The full 30-frame trio is also guarded synchronously at test time by
    /// `PyxisTests.allSoldierAnimationFramesAreInstalled`, and the all-or-nothing
    /// storyboard validation in `tools/slice_soldier_animation_strips.py` makes
    /// a partial trio unlikely in practice — this probe is the runtime safety
    /// net. Results are memoized in `soldierAnimatedCanvasFrameNameCache`
    /// because the probe is called twice per soldier (once in
    /// `createSoldierNode`, once in `makeSoldierNode`) and 30 `UIImage(named:)`
    /// lookups per call would otherwise dominate spawn cost.
    private func firstAvailableSoldierAnimationFrameName(for assetPrefix: String) -> String? {
        if let cached = soldierAnimatedCanvasFrameNameCache[assetPrefix] {
            return cached
        }
        let walkFrameNames = soldierAnimationFrameNames(for: assetPrefix, action: .walk)
        guard let firstWalkFrameName = walkFrameNames.first,
              walkFrameNames.allSatisfy({ UIImage(named: $0) != nil }) else {
            soldierAnimatedCanvasFrameNameCache[assetPrefix] = .some(nil)
            return nil
        }
        for action in SoldierAnimationAction.allCases where action != .walk {
            let actionFrameNames = soldierAnimationFrameNames(for: assetPrefix, action: action)
            guard !actionFrameNames.isEmpty,
                  actionFrameNames.allSatisfy({ UIImage(named: $0) != nil }) else {
                soldierAnimatedCanvasFrameNameCache[assetPrefix] = .some(nil)
                return nil
            }
        }
        soldierAnimatedCanvasFrameNameCache[assetPrefix] = firstWalkFrameName
        return firstWalkFrameName
    }

    private func soldierAnimationTextures(for assetPrefix: String, action: SoldierAnimationAction) -> [SKTexture] {
        if let cached = soldierAnimationTextureCache[assetPrefix]?[action] {
            return cached
        }
        let frameNames = soldierAnimationFrameNames(for: assetPrefix, action: action)
        let missingFrameNames = frameNames.filter { UIImage(named: $0) == nil }
        if !missingFrameNames.isEmpty {
            // An incomplete texture set usually means an asset was dropped or
            // misnamed. In DEBUG this is almost always a build/asset mistake
            // worth failing loudly on; in release we fall through to the
            // static fallback sprite path.
            #if DEBUG
            let actionKey = "\(assetPrefix)-\(action.rawValue)"
            assertionFailure("Missing soldier animation frames for \(actionKey): \(missingFrameNames)")
            #endif
            return []
        }
        let textures = frameNames.map { soldierAnimationTexture(named: $0) }
        // Only cache complete (non-empty) texture sets; an incomplete set likely
        // means an asset is missing at this call, which we want to re-resolve
        // rather than pin the empty result for the scene's lifetime.
        if !textures.isEmpty {
            if soldierAnimationTextureCache[assetPrefix] == nil {
                soldierAnimationTextureCache[assetPrefix] = [:]
            }
            soldierAnimationTextureCache[assetPrefix]?[action] = textures
        }
        return textures
    }

    private func soldierAnimationTexture(named frameName: String) -> SKTexture {
        SKTexture(imageNamed: frameName)
    }

    private func soldierVisualColor(for type: SoldierType) -> SKColor {
        switch type {
        case .infantry:
            return SKColor(red: 0.18, green: 0.52, blue: 1.0, alpha: 1.0)
        case .archer:
            return SKColor(red: 0.18, green: 0.76, blue: 0.34, alpha: 1.0)
        case .cavalry:
            return SKColor(red: 0.92, green: 0.58, blue: 0.22, alpha: 1.0)
        case .mage:
            return SKColor(red: 0.62, green: 0.38, blue: 0.94, alpha: 1.0)
        case .siege:
            return SKColor(red: 0.64, green: 0.68, blue: 0.70, alpha: 1.0)
        }
    }

    /// Presentation target for one damaged objective (HPA-468): the Keep
    /// keeps its `enemy-city` sprite and impact point; support objectives
    /// resolve to their own container node and structure frame. A support
    /// hit never falls back to the Keep — that would visually damage it.
    private func objectiveFeedbackTarget(for objectiveID: String) -> (node: SKNode?, impactPoint: CGPoint) {
        guard let objective = state.currentSiegeLayout.objective(id: objectiveID),
              objective.kind != .keep else {
            return (enemyCityNode, enemyCityImpactPoint)
        }
        let node = siegeObjectiveNodes[objectiveID]
        let frame = node?.calculateAccumulatedFrame()
        let impactPoint: CGPoint
        if let frame, frame.width > 0, frame.height > 0 {
            impactPoint = CGPoint(x: frame.midX, y: frame.midY)
        } else {
            impactPoint = point(forLane: objective.visualLane, position: objective.visualProgress)
        }
        return (node, impactPoint)
    }

    /// Plays attack feedback per damaged objective (HPA-468): each
    /// objective's floating damage, impact flash, and hit flash land on that
    /// objective's own presentation target, so Gate/Tower hits never touch
    /// Keep displays. Presentation only — the same events were already
    /// applied to the model above.
    private func playObjectiveAttackFeedback(
        _ events: [SoldierAttackEvent],
        color: SKColor,
        isConquest: Bool
    ) {
        var orderedObjectiveIDs = [String]()
        var damageByObjectiveID = [String: Int]()
        var destroyedObjectiveIDs = Set<String>()
        for event in events {
            if damageByObjectiveID[event.objectiveID] == nil {
                orderedObjectiveIDs.append(event.objectiveID)
            }
            damageByObjectiveID[event.objectiveID, default: 0] += event.appliedDamage
            if event.appliedDamage > 0 {
                objectiveDamageSourcesThisTick[event.objectiveID, default: []]
                    .insert(event.isCaptain ? .captain : .ordinary)
            }
            if event.depletedObjective {
                destroyedObjectiveIDs.insert(event.objectiveID)
            }
        }

        // The layout/catalog reads hoist out of the per-objective loop —
        // they used to be re-resolved (and the remaining-power snapshot
        // rebuilt) once per attacked objective.
        let layout = state.currentSiegeLayout
        let keepID = layout.keepObjective.id
        for objectiveID in orderedObjectiveIDs {
            let damage = damageByObjectiveID[objectiveID] ?? 0
            guard damage > 0 else { continue }
            let target = objectiveFeedbackTarget(for: objectiveID)
            if let kind = layout.objective(id: objectiveID)?.kind,
               kind != .keep,
               destroyedObjectiveIDs.contains(objectiveID) {
                // HPA-582: the model flags the killing hit on the attack
                // event itself (`depletedObjective`), so the fall is
                // authoritative — not inferred from post-mutation HP — and
                // it plays once per objective however many same-tick hits
                // landed.
                playStructureFallFeedback(
                    objectiveID: objectiveID,
                    kind: kind,
                    on: target.node,
                    impactPoint: target.impactPoint
                )
                continue
            }
            objectiveDamageThisTick[objectiveID, default: 0] += damage
            let tickDamage = objectiveDamageThisTick[objectiveID, default: 0]
            playFloatingFeedback(
                text: "-\(CompactNumberFormatter.string(from: tickDamage))",
                at: target.impactPoint,
                color: objectiveAggregateDamageColor(
                    for: objectiveID,
                    singleSourceColor: color
                ),
                reduceMotion: isReduceMotionEnabled(),
                objectiveID: objectiveID
            )
            if isConquest, objectiveID == keepID {
                playCityConquestFeedback(on: target.node, impactPoint: target.impactPoint)
            } else {
                playCityHitFeedback(on: target.node, impactPoint: target.impactPoint)
            }
        }
    }

    /// Same-tick aggregate color policy (HPA-812 final review): while only
    /// one sink contributed to an objective's aggregate this tick the label
    /// keeps that sink's color — advantaged ordinary hits stay green;
    /// unadvantaged hits and Captain hits stay white. Once BOTH an ordinary
    /// and a Captain hit landed on the same objective in one tick the
    /// combined label is deterministic neutral white — never whichever
    /// color the later-running sink happened to pass.
    private func objectiveAggregateDamageColor(
        for objectiveID: String,
        singleSourceColor: SKColor
    ) -> SKColor {
        (objectiveDamageSourcesThisTick[objectiveID]?.count ?? 0) > 1
            ? .white
            : singleSourceColor
    }

    /// Plays the one-shot fall response for a support objective destroyed by
    /// the just-applied live damage (HPA-582): a kind-specific label, the
    /// existing impact burst, and the short shake, all anchored at the
    /// objective's feedback geometry — redraw has already rebuilt the
    /// structure node as a ruin, so nothing here references the old node
    /// beyond this call. Requests are recorded before the Reduce Motion
    /// guard so tests can assert them regardless of the runner's
    /// accessibility settings; playback itself is skipped under Reduce
    /// Motion. Presentation only — reuses existing FX, no new sound,
    /// haptic kind, or image.
    private func playStructureFallFeedback(
        objectiveID: String,
        kind: CitySiegeLayout.ObjectiveKind,
        on target: SKNode?,
        impactPoint: CGPoint
    ) {
        #if DEBUG
        structureFallRequestsForTestingStorage.append(objectiveID)
        #endif

        let fallText: String
        switch kind {
        case .gate: fallText = "Gate down"
        case .arrowTower: fallText = "Tower down"
        case .barracks: fallText = "Barracks down"
        case .keep: fallText = "Keep down" // unreachable: keep is conquest-only
        }

        // Reduce Motion keeps the kill visible — the label fades in place
        // and the burst is a fade — while only the shake drops.
        let reduceMotion = isReduceMotionEnabled()
        playFloatingFeedback(text: fallText, at: impactPoint, reduceMotion: reduceMotion)
        playImpactFlash(at: impactPoint)
        if !reduceMotion {
            target?.run(cityShakeAction(), withKey: "structureFallFeedback")
        }
    }

    private func playCityHitFeedback(on target: SKNode?, impactPoint: CGPoint) {
        guard let target else {
            return
        }

        target.removeAction(forKey: "cityHitFeedback")

        if let sprite = target as? SKSpriteNode {
            let originalColor = sprite.color
            let originalBlendFactor = sprite.colorBlendFactor
            let flash = SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.06)
            let restore = SKAction.colorize(with: originalColor, colorBlendFactor: originalBlendFactor, duration: 0.12)
            sprite.run(SKAction.sequence([flash, restore]), withKey: "cityHitFeedback")
        } else {
            target.run(cityShakeAction(), withKey: "cityHitFeedback")
        }

        playImpactFlash(at: impactPoint)
    }

    private func playCityConquestFeedback(on target: SKNode?, impactPoint: CGPoint) {
        guard let target else {
            return
        }

        target.removeAction(forKey: "cityConquestFeedback")

        if let sprite = target as? SKSpriteNode {
            let originalColor = sprite.color
            let originalBlendFactor = sprite.colorBlendFactor
            let flash = SKAction.colorize(with: GameUITheme.Color.gold, colorBlendFactor: 0.65, duration: 0.09)
            let restore = SKAction.colorize(with: originalColor, colorBlendFactor: originalBlendFactor, duration: 0.18)
            sprite.run(SKAction.sequence([flash, restore]), withKey: "cityConquestFeedback")
        } else {
            target.run(cityShakeAction(), withKey: "cityConquestFeedback")
        }

        playImpactFlash(at: impactPoint)
    }

    /// Requests the one-shot Living Kingdom transition for the stage change
    /// the just-applied live mutation produced (at most one per mutation).
    /// `previousStage` is captured immediately before the model mutation, so
    /// restore/resize/redraw paths never replay historical effects.
    private func playLivingKingdomTransitionForStageChange(
        from previousStage: LivingKingdomPresentation.FortressStage
    ) {
        let currentStage = livingKingdomBattlePresentation.stage
        guard let effect = LivingKingdomPresentation.transitionEffect(
            from: previousStage,
            to: currentStage
        ) else {
            return
        }
        playLivingKingdomTransition(effect)
    }

    /// Plays a one-shot Living Kingdom fortress transition in the existing
    /// `effectsLayer` (never under the colorized fortress). The request is
    /// recorded before the Reduce Motion guard so tests can assert requests
    /// regardless of the runner's accessibility settings; playback itself is
    /// skipped under Reduce Motion. `battlefieldActionLayer` pauses this layer
    /// along with combat, so Settings freezes the effect with no extra
    /// controller.
    private func playLivingKingdomTransition(
        _ effect: LivingKingdomPresentation.TransitionEffect
    ) {
        #if DEBUG
        livingKingdomTransitionEffectsForTestingStorage.append(effect)
        #endif

        effectsLayer.childNode(withName: EffectName.livingKingdomTransitionFX)?.removeFromParent()
        guard !isReduceMotionEnabled() else { return }

        let textures = effect.frameNames.map(SKTexture.init(imageNamed:))
        guard let first = textures.first else { return }

        let fx = SKSpriteNode(texture: first)
        fx.name = EffectName.livingKingdomTransitionFX
        fx.anchorPoint = CGPoint(x: 0.5, y: 0)
        fx.zPosition = GameUITheme.Z.effects
        effectsLayer.addChild(fx)
        layoutLivingKingdomTransitionFX(fx)
        fx.run(.sequence([
            .animate(with: textures, timePerFrame: effect.secondsPerFrame),
            .removeFromParent()
        ]))
    }

    /// Anchors a transition FX to the fortress bottom-center, scaled to the
    /// displayed fortress height (all FX frames share the 512×512 canvas;
    /// fortresses are 512×540). `environmentLayer` and `battlefieldActionLayer`
    /// share the battlefield origin, so the city's position is the same
    /// battlefield coordinate inside `effectsLayer`.
    private func layoutLivingKingdomTransitionFX(_ fx: SKSpriteNode) {
        guard let city = enemyCityNode as? SKSpriteNode else { return }
        let displayedFortressHeight = city.size.height * abs(city.yScale)
        let fxHeight = 512 * displayedFortressHeight / 540
        fx.position = city.position
        fx.size = CGSize(width: fxHeight, height: fxHeight)
    }

    private func playImpactFlash(at point: CGPoint) {
        let flash: SKNode
        if UIImage(named: BattleAssetName.hitFlash) != nil {
            let sprite = SKSpriteNode(imageNamed: BattleAssetName.hitFlash)
            sprite.size = CGSize(width: 34, height: 34)
            flash = sprite
        } else {
            let shape = SKShapeNode(circleOfRadius: 9)
            shape.fillColor = SKColor(red: 1.0, green: 0.78, blue: 0.16, alpha: 0.9)
            shape.strokeColor = SKColor(red: 1.0, green: 0.38, blue: 0.08, alpha: 0.95)
            shape.lineWidth = 2
            flash = shape
        }
        flash.position = point
        flash.zPosition = GameUITheme.Z.effects
        flash.setScale(1)
        effectsLayer.addChild(flash)

        let fade = SKAction.fadeOut(withDuration: 0.18)
        fade.timingMode = .easeOut
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([fade, remove]))
    }

    private func playFloatingFeedback(
        text: String,
        at position: CGPoint,
        color: SKColor = GameUITheme.Color.gold,
        reduceMotion: Bool = false,
        objectiveID: String? = nil
    ) {
        #if DEBUG
        floatingFeedbackTextsForTestingStorage.append(text)
        #endif

        objectiveDamageLabels = objectiveDamageLabels.filter { $0.value.parent === effectsLayer }
        let label: SKLabelNode
        if let objectiveID, let existing = objectiveDamageLabels[objectiveID] {
            label = existing
            label.removeAction(forKey: EffectName.floatingFeedback)
        } else {
            label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            effectsLayer.addChild(label)
            if let objectiveID {
                objectiveDamageLabels[objectiveID] = label
            }
        }
        let shadow = NSShadow()
        shadow.shadowColor = SKColor(white: 0, alpha: 0.85)
        shadow.shadowOffset = CGSize(width: 0, height: 2)
        shadow.shadowBlurRadius = 5
        label.name = EffectName.floatingFeedback
        label.text = text
        label.fontSize = EffectStyle.floatingFeedbackFontSize
        label.fontColor = color
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont(name: GameUITheme.Font.bold, size: label.fontSize)
                    ?? UIFont.boldSystemFont(ofSize: label.fontSize),
                .foregroundColor: color,
                .shadow: shadow
            ]
        )
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: position.x, y: position.y - 20)
        label.zPosition = EffectStyle.floatingFeedbackZ
        label.alpha = 0
        label.setScale(reduceMotion ? 1 : 0.7)

        // Reduce Motion keeps the text but drops the movement: fade in
        // place, then fade out — no rise, no scale.
        let appear = reduceMotion
            ? SKAction.fadeIn(withDuration: 0.2)
            : SKAction.group([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.moveBy(x: 0, y: 14, duration: 0.2),
                SKAction.scale(to: 1.12, duration: 0.2)
            ])
        appear.timingMode = .easeOut
        let floatAway = reduceMotion
            ? SKAction.fadeOut(withDuration: 0.9)
            : SKAction.group([
                SKAction.fadeOut(withDuration: 0.9),
                SKAction.moveBy(x: 0, y: 50, duration: 0.9),
                SKAction.scale(to: 0.94, duration: 0.9)
            ])
        floatAway.timingMode = .easeOut
        let clearReference = SKAction.run { [weak self, weak label] in
            guard let self, let objectiveID, let label,
                  self.objectiveDamageLabels[objectiveID] === label else { return }
            self.objectiveDamageLabels.removeValue(forKey: objectiveID)
        }
        let remove = SKAction.removeFromParent()
        label.run(
            SKAction.sequence([appear, floatAway, clearReference, remove]),
            withKey: EffectName.floatingFeedback
        )
    }

    private func playTowerShot(at soldierID: BattleCombatState.SoldierID) {
        guard let bundle = soldierNodes[soldierID] else {
            if lastDefensiveShotTargetID == soldierID {
                lastDefensiveShotTargetID = nil
            }
            return
        }

        let target = towerShotTargetPoint(for: bundle)
        #if DEBUG
        lastTowerProjectileEndpointForTestingStorage = target
        #endif
        let shot: SKNode
        if UIImage(named: BattleAssetName.towerProjectile) != nil {
            let sprite = SKSpriteNode(imageNamed: BattleAssetName.towerProjectile)
            sprite.size = CGSize(width: 26, height: 16)
            shot = sprite
        } else {
            let shape = SKShapeNode(circleOfRadius: 4)
            shape.fillColor = SKColor(red: 1.0, green: 0.28, blue: 0.18, alpha: 1.0)
            shape.strokeColor = .clear
            shot = shape
        }
        shot.name = BattlefieldNodeName.defensiveFireProjectile
        shot.position = defensiveFireProjectileOrigin(forTargetLane: bundle.lane)
        shot.zPosition = GameUITheme.Z.effects
        effectsLayer.addChild(shot)

        let move = SKAction.move(to: target, duration: 0.12)
        // Protection dies with the projectile: once THIS shot lands the
        // recorded target id clears (guarded — an interleaved newer shot
        // keeps its own target), so presentation never holds a seat for a
        // shot that already resolved or for an id combat later reused.
        let clearTarget = SKAction.run { [weak self] in
            if self?.lastDefensiveShotTargetID == soldierID {
                self?.lastDefensiveShotTargetID = nil
            }
        }
        let remove = SKAction.removeFromParent()
        shot.run(SKAction.sequence([move, clearTarget, remove]))
    }

    /// Scene-space origin for defensive-fire projectile visuals (HPA-468):
    /// shots leave the actual source objective node — the Falconridge arrow
    /// tower at its authored 0.68 progress — rather than the lane gate
    /// point. Keep-source layouts (the Keep is the only fire source) keep the pre-siege
    /// per-lane gate spawn, which is the fortress itself, so those visuals
    /// remain equivalent.
    private func defensiveFireProjectileOrigin(forTargetLane lane: BattleLane) -> CGPoint {
        let layout = state.currentSiegeLayout
        let sourceID = layout.defensiveFire.sourceObjectiveID
        if let source = layout.objective(id: sourceID),
           source.kind != .keep,
           let node = siegeObjectiveNodes[sourceID] {
            return node.position
        }
        return battlefieldLayout.enemyGatePoints[lane] ?? enemyCityImpactPoint
    }

    /// Scene-space point where a tower projectile should connect with a
    /// soldier. Targets the body center (via `soldierLogicalBodyFrame`) rather
    /// than the raw root position, which — after the foot-margin offset is
    /// applied to animated soldiers — sits below the lane baseline. The
    /// root-local midpoint is converted through the root's own transform so
    /// crowded scaled-down formation roots (`root.setScale(formation.scale)`
    /// in `syncSoldierNodes`) land the endpoint on the rendered body center;
    /// adding the unscaled midpoint would float it above the soldier.
    private func towerShotTargetPoint(for bundle: SoldierNodeBundle) -> CGPoint {
        let bodyFrame = soldierLogicalBodyFrame(for: bundle)
        return bundle.root.convert(
            CGPoint(x: bodyFrame.midX, y: bodyFrame.midY),
            to: effectsLayer
        )
    }

    private func playSoldierAttackFeedback(for soldierID: BattleCombatState.SoldierID) {
        playSoldierAnimation(.attack, for: soldierID, resumesWalk: true)
    }

    private func playSoldierHitFeedback(
        for soldierID: BattleCombatState.SoldierID,
        schedulesRemoval: Bool
    ) {
        playSoldierAnimation(.hit, for: soldierID, resumesWalk: !schedulesRemoval)
        if schedulesRemoval {
            scheduleDelayedSoldierRemoval(for: soldierID)
        }
    }

    private func startSoldierWalkAnimation(for soldierID: BattleCombatState.SoldierID) {
        guard let bundle = soldierNodes[soldierID],
              bundle.isAnimatedCanvas,
              let sprite = bundle.body as? SKSpriteNode,
              sprite.action(forKey: SoldierAnimationKey.walk) == nil,
              sprite.action(forKey: SoldierAnimationKey.attack) == nil,
              sprite.action(forKey: SoldierAnimationKey.hit) == nil else {
            return
        }

        // `isAnimatedCanvas` is false when the catalog is missing any of the
        // 30 trio frames (see `firstAvailableSoldierAnimationFrameName`). In
        // that case the node was built on the static-fallback path and sized
        // via `fitBattleNode` to the static sprite's intrinsic dimensions, not
        // the animation canvas geometry. Starting full-canvas walk textures on
        // it would display the 128×128 canvas at the wrong size. The same gate
        // is applied in `playSoldierAnimation` for transient (attack/hit)
        // playback — without it, a partial catalog where one action is
        // complete but another is missing would let the complete action's
        // full-canvas textures be installed on the differently-sized static
        // sprite, mixing fallback and animated rendering. Textures are looked
        // up under the soldier's asset prefix (HPA-475), while the frame
        // timing stays on the shared per-type curve the bundle carries.
        startWalkAnimation(
            on: sprite, sprite: sprite, assetPrefix: soldierAssetPrefix(for: bundle), type: bundle.type
        )
    }

    private func startWalkAnimation(
        on node: SKNode, sprite: SKSpriteNode, assetPrefix: String, type: SoldierType
    ) {
        guard node.action(forKey: SoldierAnimationKey.walk) == nil else { return }
        let textures = soldierAnimationTextures(for: assetPrefix, action: .walk)
        guard !textures.isEmpty else { return }
        node.run(.repeatForever(soldierTextureAction(
            textures: textures, action: .walk, type: type, sprite: sprite
        )), withKey: SoldierAnimationKey.walk)
    }

    private func isAttackAnimationBlocked(
        type: SoldierType, attackInterval: TimeInterval, attackInProgress: Bool, hitRemaining: TimeInterval
    ) -> Bool {
        attackInProgress || (SoldierAnimationTiming.totalDuration(for: .hit, type: type) > attackInterval
            && hitRemaining > 0)
    }

    private func runTransientAnimation(
        _ action: SoldierAnimationAction, on node: SKNode, sprite: SKSpriteNode,
        actor: (assetPrefix: String, type: SoldierType), completion: @escaping () -> Void
    ) {
        let textures = soldierAnimationTextures(for: actor.assetPrefix, action: action)
        guard let first = textures.first else { return }
        node.removeAction(forKey: SoldierAnimationKey.walk)
        node.removeAction(forKey: SoldierAnimationKey.attack)
        node.removeAction(forKey: SoldierAnimationKey.hit)
        sprite.texture = first
        let key: String
        switch action {
        case .walk: key = SoldierAnimationKey.walk
        case .attack: key = SoldierAnimationKey.attack
        case .hit: key = SoldierAnimationKey.hit
        }
        node.run(.sequence([
            soldierTextureAction(textures: textures, action: action, type: actor.type, sprite: sprite),
            .run(completion)
        ]), withKey: key)
    }

    private func soldierTextureAction(
        textures: [SKTexture],
        action: SoldierAnimationAction,
        type: SoldierType,
        sprite: SKSpriteNode
    ) -> SKAction {
        let durations = SoldierAnimationTiming.frameDurations(for: action, type: type)
        let steps = zip(textures, durations).flatMap { texture, duration in
            // On iOS 26, SKAction.setTexture can restore the texture's intrinsic
            // size even with resize disabled. Direct assignment preserves the
            // fitted geometry owned by fitSoldierBodyNode.
            [SKAction.run { [weak sprite] in
                sprite?.texture = texture
            }, SKAction.wait(forDuration: duration)]
        }
        return SKAction.sequence(steps)
    }

    private func playSoldierAnimation(
        _ action: SoldierAnimationAction,
        for soldierID: BattleCombatState.SoldierID,
        resumesWalk: Bool
    ) {
        guard let bundle = soldierNodes[soldierID],
              bundle.isAnimatedCanvas,
              let sprite = bundle.body as? SKSpriteNode else {
            return
        }

        let textures = soldierAnimationTextures(for: soldierAssetPrefix(for: bundle), action: action)
        guard !textures.isEmpty else {
            return
        }
        let soldierType = bundle.type

        // Attack animations last longer than the combat attack interval for
        // infantry, archer, cavalry, and mage (e.g. infantry attacks every
        // 1.0s but its attack cycle is 1.2s). Restarting the attack sequence
        // on every attack tick would pop it back to frame 1 before it ever
        // reaches the final frames or resumes walking. Ignore attack triggers
        // while an attack animation is already in flight; the in-flight cycle
        // finishes, resumes walk, and the next trigger starts a fresh cycle.
        // Hit still interrupts an in-flight attack (a tower-hit reaction
        // should override the attack pose), so the attack-action check is
        // attack-only with respect to *re-triggering the same action*.
        //
        // The guard also suppresses attack triggers while a hit reaction is
        // still playing, but ONLY for soldier types whose hit duration
        // exceeds their attack interval (currently cavalry: 0.9s hit vs
        // ~0.87s attack interval). For those types, the next attack tick
        // would always land mid-hit and the remove-all-transient-keys block
        // below would cut off the authored hit reaction. Treating the hit as
        // higher priority lets it finish, resume walk, and the next attack
        // tick starts a fresh attack cycle. This only affects the *visual*
        // pose — combat damage is applied by BattleCombatState.tick
        // regardless of which animation is playing.
        //
        // For types where hit < attack interval (infantry, archer, mage,
        // siege), the hit usually finishes before the next attack tick, so
        // the attack replaces an already-completed hit (not a cut-off).
        // Suppressing attacks for those types would cause a severe visual
        // regression — the tower re-arms the 0.9s hit timer every 1.25s,
        // so the suppression would be active ~72% of the time and soldiers
        // would barely visually attack. The occasional 0.25s hit cut-off
        // for those types is the accepted pre-review behavior.
        //
        // The hit check uses a combat-tick-driven countdown
        // (`soldierHitAnimationRemaining`) rather than
        // `sprite.action(forKey: .hit) != nil` because the test suite drives
        // combat via `advanceCombatForTesting` without a SpriteKit render
        // loop — installed SKActions never advance in tests, so an
        // action-key check would suppress attacks forever after the first
        // hit. The countdown is decremented in `advanceCombat` and lifts
        // after the authored hit duration elapses, matching production
        // behavior where the SKAction completes and removes itself.
        //
        // Documented side-effect: because every other attack trigger lands
        // while the previous cycle is still playing, the *visual* attack
        // cadence for those four types is ~2x their damage cadence (infantry
        // and archer cycle every ~2.0s, cavalry every ~1.74s, mage every
        // ~2.36s; siege is unaffected because its 1.6s animation is shorter
        // than its 1.82s damage interval). This is an accepted tradeoff —
        // the alternative (restarting on every trigger) never reaches the
        // strike frames and looks worse. See CLAUDE.md "Attack animations
        // last longer..." note for the design rationale.
        if action == .attack && isAttackAnimationBlocked(
            type: soldierType,
            attackInterval: combat.attackInterval(for: soldierType),
            attackInProgress: sprite.action(forKey: SoldierAnimationKey.attack) != nil,
            hitRemaining: soldierHitAnimationRemaining[soldierID] ?? 0
        ) { return }

        #if DEBUG
        switch action {
        case .attack:
            soldierAttackAnimationTriggerCount += 1
        case .hit:
            soldierHitAnimationTriggerCount += 1
        case .walk:
            break
        }
        #endif

        if action == .hit {
            soldierHitAnimationRemaining[soldierID] =
                SoldierAnimationTiming.totalDuration(for: .hit, type: soldierType)
        }
        runTransientAnimation(
            action, on: sprite, sprite: sprite,
            actor: (soldierAssetPrefix(for: bundle), soldierType)
        ) { [weak self] in
            self?.resumeWalkForSoldierIfNeeded(
                id: soldierID, type: soldierType, isAllowed: resumesWalk
            )
        }
    }

    /// Restarts the looping walk animation for a soldier after a transient
    /// (attack/hit) animation finishes, iff the soldier is still alive and the
    /// calling animation was allowed to resume walk. Extracted from
    /// `playSoldierAnimation` so the resume path is unit-testable without
    /// driving the SpriteKit render loop.
    ///
    /// The transient action key is still installed on the sprite when this runs
    /// in production: the `SKAction.run` closure fires as the final step of the
    /// `[animate, resumeWalk]` sequence, which SpriteKit removes only *after*
    /// the closure returns. We therefore clear the transient keys here before
    /// starting walk — otherwise `startSoldierWalkAnimation`'s guard would bail
    /// and walk would never resume from the closure (it would only resume on
    /// the next `syncSoldierNodes` tick).
    private func resumeWalkForSoldierIfNeeded(
        id: BattleCombatState.SoldierID,
        type: SoldierType,
        isAllowed: Bool
    ) {
        guard isAllowed, combat.soldier(id: id)?.isAlive == true else {
            return
        }
        if let sprite = soldierNodes[id]?.body as? SKSpriteNode {
            sprite.removeAction(forKey: SoldierAnimationKey.attack)
            sprite.removeAction(forKey: SoldierAnimationKey.hit)
        }
        startSoldierWalkAnimation(for: id)
    }

    private func scheduleDelayedSoldierRemoval(for soldierID: BattleCombatState.SoldierID) {
        guard let bundle = soldierNodes[soldierID] else {
            return
        }

        pendingAnimatedRemovalSoldierIDs.insert(soldierID)
        // A killed soldier's protection ends with it — the accent must not
        // outlive the body through the hit-then-fade removal animation.
        bundle.rallyAccent?.isHidden = true
        bundle.root.removeAction(forKey: SoldierAnimationKey.delayedRemoval)

        // Match the full hit animation duration so killed soldiers finish the
        // authored hit cycle before fading out.
        let duration = SoldierAnimationTiming.totalDuration(for: .hit, type: bundle.type)
        let wait = SKAction.wait(forDuration: duration)
        let remove = SKAction.run { [weak self] in
            self?.removeSoldierNode(id: soldierID, animated: true)
        }
        bundle.root.run(SKAction.sequence([wait, remove]), withKey: SoldierAnimationKey.delayedRemoval)
    }

    private func cancelCityFeedbackActions() {
        guard let enemyCityNode else {
            return
        }

        enemyCityNode.removeAction(forKey: "cityConquestFeedback")
        enemyCityNode.removeAction(forKey: "cityHitFeedback")

        if let sprite = enemyCityNode as? SKSpriteNode {
            sprite.colorBlendFactor = 0
            sprite.color = .clear
        }
    }

    private func cityShakeAction() -> SKAction {
        SKAction.sequence([
            SKAction.moveBy(x: -5, y: 0, duration: 0.03),
            SKAction.moveBy(x: 10, y: 0, duration: 0.05),
            SKAction.moveBy(x: -8, y: 0, duration: 0.04),
            SKAction.moveBy(x: 3, y: 0, duration: 0.03)
        ])
    }

    private func observeLifecycleNotificationsIfNeeded() {
        guard !isObservingLifecycle else {
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidEnterBackground),
            name: .pyxisSceneDidEnterBackground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneWillEnterForeground),
            name: .pyxisSceneWillEnterForeground,
            object: nil
        )
        isObservingLifecycle = true
    }

    @objc private func sceneDidEnterBackground(_ notification: Notification) {
        handleSceneDidEnterBackground(at: Date())
    }

    @objc private func sceneWillEnterForeground(_ notification: Notification) {
        handleSceneWillEnterForeground(at: Date())
    }

    private func handleSceneDidEnterBackground(at date: Date) {
        state.enterBackground(at: date)
        store.save(state)
        clearLiveCombat()
    }

    private func handleSceneWillEnterForeground(at date: Date) {
        let result = state.returnFromBackground(at: date)

        store.save(state)
        // Combat was torn down on background, but Country 1 Guards are
        // durable (HPA-469): rehydrate them from the post-idle-settlement
        // state so the first tick's live-snapshot sync cannot overwrite
        // `unresolvedGuards` with an empty roster. Skipped when the idle
        // settlement conquered the city — that combat never ticks again.
        if state.stageStatus == .battleActive {
            restorePersistedGuardsIntoCombat()
            restorePersistedCaptainIntoCombat()
        }
        reconcileSelectedManualSoldierType()

        if result.elapsedSeconds > 0 {
            if result.conqueredCities > 0 {
                presentFreshIdleConquest(
                    goldEarned: result.goldEarned,
                    conqueredCities: result.conqueredCities
                )
                return
            }
            if result.damageDealt > 0 {
                feedbackText = "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage."
            } else {
                // A real credited return that produced no damage stays silent:
                // clear any stale message rather than reporting a no-damage copy.
                feedbackText = ""
            }
        }

        redraw()
    }

    /// Presents a just-settled fresh idle conquest through the same
    /// transaction as a foreground return (HPA-468): outcome feedback, live
    /// combat teardown, refresh, then the pending conquest report.
    private func presentFreshIdleConquest(goldEarned: Int, conqueredCities: Int) {
        feedbackSettingsController?.setSettingsAccessibilityActionable(false)
        closeFeedbackSettings(focusTarget: .systemDefault)
        emitFreshOutcomeFeedback(
            goldEarned: goldEarned,
            conqueredCities: conqueredCities
        )
        clearLiveCombat()
        // The conquest popup communicates the result; clear any stale
        // feedback so the tooltip doesn't present behind the overlay and
        // linger after the popup closes. Mirrors the live-combat conquest
        // path. Clearing (rather than just not setting) also covers a
        // stale message left over from before backgrounding.
        feedbackText = ""

        redraw()

        _ = presentPendingConquestReport(origin: .freshIdle, resetsContinueState: true)
    }

    /// Settle-before-select lane routing (HPA-468): the model result decides
    /// the transaction. `.unavailable` mutates nothing; a settlement conquest
    /// presents the pending report via the fresh-idle path; a selection (or a
    /// no-op) persists and refreshes the HUD.
    private func selectAssaultLane(_ lane: BattleLane) {
        switch state.selectAssaultLane(lane, at: Date()) {
        case .unavailable:
            return
        case .conqueredDuringSettlement(let idleProgress):
            store.save(state)
            presentFreshIdleConquest(
                goldEarned: idleProgress.goldEarned,
                conqueredCities: idleProgress.conqueredCities
            )
        case .selected, .unchanged:
            store.save(state)
            redraw(shouldLayout: false)
        }
    }

    private static func isPendingResultPresentable(
        _ result: BattleResult,
        currentCityKey: CityKey
    ) -> Bool {
        result.cityKey == currentCityKey
    }

    private func pendingResultForPresentation() -> BattleResult? {
        guard let result = state.pendingBattleResult else { return nil }
        guard Self.isPendingResultPresentable(result, currentCityKey: state.currentCityKey) else {
            assertionFailure("Pending BattleResult city does not match current city")
            // A stale pending result whose city no longer matches the current
            // city would re-launch BattleScene and re-fail on every subsequent
            // presentation (GameViewController routes on a non-nil pending
            // result regardless of stageStatus). Clear and persist it so the
            // app falls back to normal stage-status routing on the next
            // launch instead of looping on the unpresentable result. This
            // branch is unreachable in practice — KingdomGameState.init
            // normalizes mismatched pending results to nil on construct and
            // decode, and completeCurrentCity guards on city match before
            // setting pendingBattleResult — so the assertionFailure is the
            // real tripwire; the acknowledge+save is defense-in-depth.
            state.acknowledgePendingBattleResult()
            store.save(state)
            return nil
        }
        return result
    }

    private func conquestReportContent(for result: BattleResult) -> ConquestReportContent {
        .project(
            from: result,
            title: KingdomGameState.displayConquestTitle(for: result.cityKey)
        )
    }

    private func conquestReportLayout(
        for content: ConquestReportContent,
        result: BattleResult
    ) -> ConquestReportLayout? {
        let insets = view?.safeAreaInsets ?? .zero
        let safeWidth = size.width - insets.left - insets.right
        let compactHeight = battleChromeLayout?.isCompact ?? (size.height < 780)
        let contentWidth = battleChromeLayout?.topBandFrame.width
            ?? min(560, max(0, safeWidth - BattleChromeLayout.sideMargin * 2))
        let tier = result.cityKey.countryNumber == 1
            ? Country1MilestoneTier.forCity(result.cityKey.cityNumber)
            : nil
        let input = ConquestReportLayout.Input(
            sceneSize: size,
            safeAreaInsets: .init(top: insets.top, left: insets.left,
                                  bottom: insets.bottom, right: insets.right),
            battleContentWidth: contentWidth,
            tileCount: content.tiles.count,
            chipCount: content.achievements.count,
            compactHeight: compactHeight,
            includesCountryCompletion: tier?.isCountryFinale == true,
            includesGearLine: content.newGearLineText != nil
        )
        #if DEBUG
        lastConquestReportLayoutInputForTestingStorage = input
        #endif
        return .compute(input)
    }

    private func applyMilestoneConquestPresentation(
        result: BattleResult,
        layout: ConquestReportLayout
    ) -> Bool {
        let tier = result.cityKey.countryNumber == 1
            ? Country1MilestoneTier.forCity(result.cityKey.cityNumber)
            : nil
        guard let tier else {
            milestoneConquestAccent.isHidden = true
            milestoneConquestAccent.path = nil
            countryCompleteLabel.isHidden = true
            return true
        }

        let expansion: CGFloat
        switch tier {
        case .first:
            expansion = 5
            milestoneConquestAccent.lineWidth = 2
            milestoneConquestAccent.glowWidth = 1
        case .second:
            expansion = 7
            milestoneConquestAccent.lineWidth = 3
            milestoneConquestAccent.glowWidth = 3
        case .finale:
            expansion = 9
            milestoneConquestAccent.lineWidth = 4
            milestoneConquestAccent.glowWidth = 5
        }
        var accentFrame = layout.panelFrame
            .insetBy(dx: -expansion, dy: -expansion)
            .intersection(layout.safeFrame)
        if let completion = layout.countryCompleteFrame,
           accentFrame.maxY > completion.minY - 2 {
            accentFrame.size.height = max(0, completion.minY - 2 - accentFrame.minY)
        }
        if accentFrame.width > 0, accentFrame.height > 0 {
            milestoneConquestAccent.path = CGPath(
                roundedRect: accentFrame,
                cornerWidth: layout.panelCornerRadius + 4,
                cornerHeight: layout.panelCornerRadius + 4,
                transform: nil
            )
            milestoneConquestAccent.isHidden = false
        } else {
            milestoneConquestAccent.isHidden = true
            milestoneConquestAccent.path = nil
        }

        guard tier.isCountryFinale else {
            countryCompleteLabel.isHidden = true
            return true
        }
        guard let frame = layout.countryCompleteFrame else {
            assertionFailure("Finale report layout omitted required Country 1 Complete frame")
            return false
        }

        countryCompleteLabel.text = "Country 1 Complete"
        countryCompleteLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        let fits = fitMilestoneLabel(
            countryCompleteLabel,
            fontName: GameUITheme.Font.bold,
            startingAt: battleChromeLayout?.isCompact ?? (size.height < 780) ? 15 : 18,
            minimum: 15,
            maximumWidth: frame.width
        )
        countryCompleteLabel.isHidden = !fits
        return fits
    }

    @discardableResult
    private func presentPendingConquestReport(
        origin: ConquestReportPresentationOrigin,
        resetsContinueState: Bool
    ) -> Bool {
        guard let result = applyPendingConquestReport(
            resetsContinueState: resetsContinueState
        ) else {
            return false
        }
        #if DEBUG
        lastConquestReportOriginForTestingStorage = origin
        conquestEffectPresentationCountForTestingStorage += origin == .restored ? 0 : 1
        #endif
        presentFreshMilestoneConquestFlourishIfNeeded(result: result, origin: origin)
        if origin != .restored,
           let anchor = conquestReportNode.goldEffectAnchor(in: self) {
            playGoldBurst(at: anchor)
        }
        return true
    }

    private func presentFreshMilestoneConquestFlourishIfNeeded(
        result: BattleResult,
        origin: ConquestReportPresentationOrigin
    ) {
        guard origin != .restored,
              !hasPresentedMilestoneConquestFlourish,
              result.cityKey.countryNumber == 1,
              Country1MilestoneTier.forCity(result.cityKey.cityNumber) != nil else {
            return
        }

        hasPresentedMilestoneConquestFlourish = true
        #if DEBUG
        milestoneConquestFlourishCountForTestingStorage += 1
        lastMilestoneFlourishCityForTestingStorage = result.cityKey.cityNumber
        #endif

        milestoneConquestAccent.removeAllActions()
        milestoneConquestAccent.alpha = 0.45
        milestoneConquestAccent.setScale(isReduceMotionEnabled() ? 1 : 0.97)
        let fade = SKAction.fadeAlpha(to: 1, duration: 0.24)
        let emphasis = isReduceMotionEnabled()
            ? fade
            : SKAction.group([fade, SKAction.scale(to: 1, duration: 0.24)])
        milestoneConquestAccent.run(emphasis)
    }

    @discardableResult
    private func applyPendingConquestReport(resetsContinueState: Bool) -> BattleResult? {
        guard let result = pendingResultForPresentation() else { return nil }
        dismissMilestoneArrival(animated: false)
        feedbackSettingsController?.setSettingsAccessibilityActionable(false)
        if resetsContinueState { isConquestContinueEnabled = true }
        let content = conquestReportContent(for: result)
        lastAppliedConquestReportContent = content
        guard let layout = conquestReportLayout(for: content, result: result),
              conquestReportNode.apply(
                  content: content,
                  layout: layout,
                  isContinueEnabled: isConquestContinueEnabled,
                  cityNumber: result.cityKey.cityNumber,
                  cityName: state.displayCityTitle(for: result.cityKey.cityNumber)
              ) == .presented,
              applyMilestoneConquestPresentation(result: result, layout: layout) else {
            isConquestReportVisible = true
            isConquestReportFitFailed = true
            conquestReportNode.isHidden = true
            milestoneConquestAccent.isHidden = true
            countryCompleteLabel.isHidden = true
            refreshBattleHUD()
            // A fresh live/idle conquest that cannot render blocks all scene
            // input, but the fit-failed flag alone never surfaces to the
            // controller unless a layout event happens to refresh the gate.
            // Notify the router immediately so the unsupported-geometry gate
            // appears without waiting for a resize/safe-area change.
            router?.battleScene(self, didRequestLayoutGate: .unsupportedGeometry)
            return nil
        }
        isConquestReportVisible = true
        isConquestReportFitFailed = false
        hasPresentedPendingConquestReport = true
        refreshBattleHUD()
        return result
    }

    private func continueFromConquestReport() {
        guard isConquestReportVisible,
              isConquestContinueEnabled,
              !isConquestReportFitFailed,
              state.pendingBattleResult != nil,
              let router else {
            return
        }
        isConquestContinueEnabled = false
        // Reapply with Continue disabled so the node re-renders dimmed and
        // drops its hit target. If that re-fit fails (e.g. the safe area
        // shrank between presentation and the tap), abort the transaction:
        // keep the pending result, restore Continue, and stay on the battle
        // scene so the player can retry once geometry recovers. Do not
        // acknowledge, save, or route — none of those steps may run.
        guard applyPendingConquestReport(resetsContinueState: false) != nil else {
            isConquestContinueEnabled = true
            return
        }
        state.acknowledgePendingBattleResult()
        store.save(state)
        router.battleSceneDidRequestGameplayTab(self, tab: .map)
    }

    private func playGoldBurst(at anchor: CGPoint) {
        goldBurstRemovalTask?.cancel()
        childNode(withName: EffectName.goldBurst)?.removeFromParent()
        isGoldBurstRemovalScheduled = false
        #if DEBUG
        lastGoldBurstAnchorForTestingStorage = anchor
        #endif

        let burst = SKNode()
        burst.name = EffectName.goldBurst
        burst.position = anchor
        burst.zPosition = EffectStyle.goldBurstZ
        addChild(burst)

        if UIImage(named: BattleAssetName.goldBurst) != nil {
            let sprite = SKSpriteNode(imageNamed: BattleAssetName.goldBurst)
            sprite.size = CGSize(width: 120, height: 120)
            sprite.zPosition = EffectStyle.goldBurstSparkleZ
            sprite.alpha = 0.72
            burst.addChild(sprite)
        }

        for index in 0..<6 {
            let sparkle = SKShapeNode(circleOfRadius: 3)
            sparkle.fillColor = GameUITheme.Color.gold
            sparkle.strokeColor = .clear
            sparkle.position = .zero
            sparkle.zPosition = EffectStyle.goldBurstSparkleZ
            burst.addChild(sparkle)

            let angle = CGFloat(index) * (.pi * 2 / 6)
            let distance: CGFloat = 30
            let destination = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            let move = SKAction.move(to: destination, duration: 0.32)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.32)
            sparkle.run(SKAction.group([move, fade]))
        }

        let scale = SKAction.scale(to: 1.12, duration: 0.12)
        scale.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.12)
        settle.timingMode = .easeIn
        let wait = SKAction.wait(forDuration: 0.18)
        let fade = SKAction.fadeOut(withDuration: 0.18)
        let markComplete = SKAction.run { [weak self, weak burst] in
            guard let self, let burst, self.childNode(withName: EffectName.goldBurst) === burst else {
                return
            }
            self.isGoldBurstRemovalScheduled = false
        }
        let remove = SKAction.removeFromParent()
        isGoldBurstRemovalScheduled = true
        burst.run(SKAction.sequence([scale, settle, wait, fade, markComplete, remove]), withKey: EffectName.goldBurst)

        goldBurstRemovalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: EffectStyle.goldBurstRemovalDelayNanoseconds)
            guard !Task.isCancelled, let self else {
                return
            }

            self.childNode(withName: EffectName.goldBurst)?.removeFromParent()
            self.isGoldBurstRemovalScheduled = false
            self.goldBurstRemovalTask = nil
        }
    }
}

#if DEBUG
extension BattleScene {
    var milestoneTierForTesting: Int? {
        currentMilestoneTier?.rawValue
    }

    /// Living Kingdom transition effects requested so far, in request order.
    var livingKingdomTransitionEffectsForTesting: [LivingKingdomPresentation.TransitionEffect] {
        livingKingdomTransitionEffectsForTestingStorage
    }

    /// Non-Keep structure-fall requests so far, in request order (HPA-582).
    var structureFallRequestsForTesting: [String] {
        structureFallRequestsForTestingStorage
    }

    /// Floating-feedback label texts requested so far, in request order —
    /// records the text, not the node, so reduced-motion variants count too.
    var floatingFeedbackTextsForTesting: [String] {
        floatingFeedbackTextsForTestingStorage
    }

    /// Fortress asset the scene last projected onto the enemy-city sprite.
    var appliedLivingKingdomFortressAssetForTesting: String? {
        appliedLivingKingdomFortressAssetForTestingStorage
    }

    /// Treatment asset the scene last projected (nil for frontier cities).
    var appliedLivingKingdomTreatmentAssetForTesting: String? {
        appliedLivingKingdomTreatmentAssetForTestingStorage
    }

    var livingKingdomTreatmentNodeForTesting: SKNode? {
        environmentLayer.childNode(withName: BattlefieldNodeName.livingKingdomBattlefieldTreatment)
    }

    var livingKingdomTransitionFXNodeForTesting: SKNode? {
        effectsLayer.childNode(withName: EffectName.livingKingdomTransitionFX)
    }

    /// True when an in-flight transition FX sits in a subtree rooted at
    /// `battlefieldActionLayer` — the layer Settings pauses — so the effect
    /// freezes with combat without a second controller.
    var isLivingKingdomTransitionFXUnderBattlefieldActionLayerForTesting: Bool {
        guard var ancestor = livingKingdomTransitionFXNodeForTesting?.parent else {
            return false
        }
        while true {
            if ancestor === battlefieldActionLayer {
                return true
            }
            guard let parent = ancestor.parent else {
                return false
            }
            ancestor = parent
        }
    }

    var isMilestoneArrivalVisibleForTesting: Bool {
        isMilestoneArrivalVisible
    }

    var milestoneArrivalPresentationCountForTesting: Int {
        milestoneArrivalPresentationCountForTestingStorage
    }

    var milestoneArrivalTitleForTesting: String? {
        milestoneArrivalTitleLabel.text
    }

    var milestoneArrivalSubtitleForTesting: String? {
        milestoneArrivalSubtitleLabel.text
    }

    var milestoneArrivalTitleFontSizeForTesting: CGFloat {
        milestoneArrivalTitleLabel.fontSize
    }

    var milestoneArrivalSubtitleFontSizeForTesting: CGFloat {
        milestoneArrivalSubtitleLabel.fontSize
    }

    var milestoneArrivalFrameForTesting: CGRect? {
        milestoneArrivalPanel.isHidden ? nil : sceneFrame(for: milestoneArrivalPanel)
    }

    var milestoneArrivalTitleFrameForTesting: CGRect? {
        milestoneArrivalPanel.isHidden ? nil : sceneFrame(for: milestoneArrivalTitleLabel)
    }

    var milestoneArrivalSubtitleFrameForTesting: CGRect? {
        milestoneArrivalPanel.isHidden ? nil : sceneFrame(for: milestoneArrivalSubtitleLabel)
    }

    var milestoneCityAccentFrameForTesting: CGRect? {
        milestoneCityAccent.isHidden ? nil : sceneFrame(for: milestoneCityAccent)
    }

    var milestoneConquestFlourishCountForTesting: Int {
        milestoneConquestFlourishCountForTestingStorage
    }

    var lastMilestoneFlourishCityForTesting: Int? {
        lastMilestoneFlourishCityForTestingStorage
    }

    var milestoneConquestAccentFrameForTesting: CGRect? {
        milestoneConquestAccent.isHidden ? nil : sceneFrame(for: milestoneConquestAccent)
    }

    var countryCompleteTextForTesting: String? {
        countryCompleteLabel.isHidden ? nil : countryCompleteLabel.text
    }

    var countryCompleteFrameForTesting: CGRect? {
        countryCompleteLabel.isHidden ? nil : sceneFrame(for: countryCompleteLabel)
    }

    func dismissMilestoneArrivalForTesting() {
        dismissMilestoneArrival(animated: false)
    }

    var lastUpdateTimeForTesting: TimeInterval? {
        lastUpdateTime
    }

    var isFeedbackSettingsVisibleForTesting: Bool {
        isFeedbackSettingsVisible
    }

    var feedbackSettingsGearFrameForTesting: CGRect? {
        feedbackSettingsController?.gear.hitFrameForTesting
    }

    var feedbackSettingsGearHiddenForTesting: Bool {
        feedbackSettingsController?.gear.isHidden ?? true
    }

    func activateFeedbackSettingsForTesting(_ action: FeedbackSettingsAction) {
        activateFeedbackSettings(action)
    }

    var feedbackSettingsModalZPositionForTesting: CGFloat? {
        feedbackSettingsController?.modal.zPosition
    }

    var feedbackSettingsGearZPositionForTesting: CGFloat? {
        feedbackSettingsController?.gear.zPosition
    }

    var isBattleChromeFitFailedForTesting: Bool {
        isBattleChromeFitFailed
    }

    func setBattleChromeFitFailedForTesting(_ value: Bool) {
        setBattleChromeFitFailed(value)
    }

    var battleChromeLayoutForTesting: BattleChromeLayout? {
        battleChromeLayout
    }

    var battleHUDForTesting: BattleHUDNode {
        battleHUD
    }

    var battlefieldActionLayerPositionForTesting: CGPoint {
        battlefieldActionLayer.position
    }

    var isBattlefieldActionLayerPausedForTesting: Bool {
        battlefieldActionLayer.isPaused
    }

    var isBattlefieldLayerPausedForTesting: Bool {
        battlefieldLayer.isPaused
    }

    var lastAdvanceCombatDeltaForTesting: TimeInterval? {
        lastAdvanceCombatDeltaForTestingStorage
    }

    var feedbackTextForTesting: String {
        feedbackText
    }

    /// Injects a feedback message without driving the tooltip pipeline, so tests
    /// can reproduce the post-fade stale state (a prior message left in
    /// `feedbackText` after its tooltip has faded and reset the dedupe token).
    func setFeedbackTextForTesting(_ text: String) {
        feedbackText = text
    }

    var defenseTraitTextForTesting: String? {
        "Trait: \(state.currentCityDefenseTrait.displayName)"
    }

    var isUpgradeButtonVisibleForTesting: Bool {
        false
    }

    var manualSpawnableSoldierTypesForTesting: [SoldierType] {
        manualSpawnableSoldierTypes
    }

    var liveSoldierCountForTesting: Int {
        combat.livingSoldierCount
    }

    var selectedManualSoldierTypeForTesting: SoldierType {
        selectedManualSoldierType
    }

    var manualLiveSoldierCountForTesting: Int {
        combat.livingSoldierCount(source: .manual)
    }

    var buildingLiveSoldierCountForTesting: Int {
        combat.livingSoldierCount(source: .building)
    }

    var combatLaneDamageMultipliersForTesting: [BattleLane: Double] {
        combat.configuration.laneDamageMultipliers
    }

    var enemyCityFrameForTesting: CGRect? {
        enemyCityNode.map { $0.calculateAccumulatedFrame() }
    }

    var playerCastleFrameForTesting: CGRect? {
        playerCastleNode.map { $0.calculateAccumulatedFrame() }
    }

    var battlefieldBackdropFrameForTesting: CGRect? {
        battlefieldBackdropNode?.calculateAccumulatedFrame()
    }

    var laneCenterXsForTesting: [CGFloat] {
        BattleLane.allCases.compactMap { battlefieldLayout.enemyGatePoints[$0]?.x }
    }

    func castleGatePointForTesting(lane: BattleLane) -> CGPoint? {
        battlefieldLayout.castleGatePoints[lane]
    }

    func enemyGatePointForTesting(lane: BattleLane) -> CGPoint? {
        battlefieldLayout.enemyGatePoints[lane]
    }

    var laneIndicatorsForTesting: [(role: LaneDefenseRole, position: CGPoint)] {
        laneIndicatorNodes.compactMap { node in
            guard let name = node.name,
                  name.hasPrefix("laneIndicator-"),
                  let role = LaneDefenseRole(rawValue: String(name.dropFirst("laneIndicator-".count)))
            else {
                return nil
            }
            return (role: role, position: node.position)
        }
    }

    func makeGateObjectiveForTesting(
        _ objective: CitySiegeLayout.Objective,
        layout: CitySiegeLayout,
        remainingPower: Int,
        maxPower: Int
    ) -> SKNode {
        makeGateObjective(objective, layout: layout, remainingPower: remainingPower, maxPower: maxPower)
    }

    /// The scene node for a pilot objective kind, or nil when the
    /// city has no such objective (single-Keep layouts, or the Keep itself,
    /// which stays the `enemy-city` sprite).
    func siegeObjectiveNodeForTesting(_ kind: CitySiegeLayout.ObjectiveKind) -> SKNode? {
        guard let id = state.currentSiegeLayout.objectives.first(where: { $0.kind == kind })?.id else {
            return nil
        }
        return siegeObjectiveNodes[id]
    }

    /// Number of pilot objective containers currently built (tower + gate
    /// for Falconridge; zero for a single-Keep city).
    var siegeObjectiveNodeCountForTesting: Int {
        siegeObjectiveNodes.count
    }

    /// Lanes currently showing the live-tower coverage treatment.
    var siegeCoveredLanesForTesting: [BattleLane] {
        environmentLayer.children.compactMap { node -> BattleLane? in
            guard let name = node.name,
                  name.hasPrefix(SiegeObjectiveNodeName.coveragePrefix) else {
                return nil
            }
            return BattleLane(rawValue: Int(String(name.dropFirst(SiegeObjectiveNodeName.coveragePrefix.count))) ?? -1)
        }
    }

    /// Scene-space origin of the most recent defensive-fire projectile
    /// visual. Projectile actions never advance without a render loop, so
    /// tests read the captured spawn position.
    var defensiveFireProjectileOriginForTesting: CGPoint? {
        effectsLayer.children.first {
            $0.name == BattlefieldNodeName.defensiveFireProjectile
        }?.position
    }

    var lastTowerProjectileEndpointForTesting: CGPoint? {
        lastTowerProjectileEndpointForTestingStorage
    }

    var defensiveFireProjectileCountForTesting: Int {
        effectsLayer.children.filter {
            $0.name == BattlefieldNodeName.defensiveFireProjectile
        }.count
    }

    func soldierRootForTesting(_ id: BattleCombatState.SoldierID) -> SKNode? {
        soldierNodes[id]?.root
    }

    var soldierLanePlacementsForTesting: [(lane: BattleLane, nodePosition: CGPoint)] {
        combat.soldiers.filter(\.isAlive).compactMap { soldier in
            soldierNodes[soldier.id].map { (lane: soldier.lane, nodePosition: $0.root.position) }
        }
    }

    /// Per-live-soldier presentation state (HPA-812): id, lane, folded
    /// (hidden) vs presented, and the root's node position — so banded
    /// formation tests can track one soldier through band-boundary
    /// transitions instead of only sampling aggregate counts.
    struct SoldierPresentationForTesting {
        let id: BattleCombatState.SoldierID
        let lane: BattleLane
        let isFolded: Bool
        let position: Double
        let nodePosition: CGPoint
    }

    var soldierPresentationsForTesting: [SoldierPresentationForTesting] {
        combat.soldiers.filter(\.isAlive).compactMap { soldier in
            soldierNodes[soldier.id].map {
                SoldierPresentationForTesting(
                    id: soldier.id,
                    lane: soldier.lane,
                    isFolded: $0.root.isHidden,
                    position: soldier.position,
                    nodePosition: $0.root.position
                )
            }
        }
    }

    /// The soldier the defensive tower most recently fired at — the actual
    /// combat-chosen target (foremost in-range, Captain tie-preferred), not
    /// an assumed formation rank.
    var lastTowerShotSoldierIDForTesting: BattleCombatState.SoldierID? {
        lastDefensiveShotTargetID
    }

    /// Whether a live soldier's root is folded out of the lane's individual
    /// presentation (HPA-812 overflow). `nil` when the soldier has no node
    /// (already removed), `false` while it renders normally or is animating
    /// its casualty removal.
    func soldierRootIsHiddenForTesting(_ id: BattleCombatState.SoldierID) -> Bool? {
        soldierNodes[id]?.root.isHidden
    }

    /// Root position + visibility for ANY soldier node — including pending
    /// casualties, which `soldierPresentationsForTesting` excludes because
    /// they are no longer live. Lets teardown tests verify a corpse stays
    /// rendered on reserved ground until removal.
    func soldierNodePresentationForTesting(
        _ id: BattleCombatState.SoldierID
    ) -> (position: CGPoint, isHidden: Bool)? {
        soldierNodes[id].map { ($0.root.position, $0.root.isHidden) }
    }

    /// Completes every pending animated soldier removal as if the authored
    /// delayed-removal SKAction had finished. SpriteKit actions never
    /// advance under `advanceCombatForTesting` (no render pass), so
    /// casualty-teardown tests run the same `removeSoldierNode` landing the
    /// action block performs.
    func completePendingAnimatedSoldierRemovalsForTesting() {
        for id in pendingAnimatedRemovalSoldierIDs {
            removeSoldierNode(id: id, animated: false)
        }
    }

    /// Footprint the given pending-casualty corpse is actually reserving
    /// this layout — lets tests assert live soldiers stay off the real
    /// ground a corpse still occupies through its hit/fade.
    func soldierCorpseFootprintForTesting(_ id: BattleCombatState.SoldierID) -> CGRect? {
        soldierNodes[id]?.corpseFootprint
    }

    /// The pending casualty's reveal/seed flags — a corpse whose reveal
    /// found no free ground retries instead of landing on someone, and
    /// must also be HIDDEN while it waits (no reservation, no render).
    func soldierCorpseStateForTesting(
        _ id: BattleCombatState.SoldierID
    ) -> (revealed: Bool, seeded: Bool)? {
        soldierNodes[id].map { ($0.corpseRevealed, $0.presentationSeeded) }
    }

    /// The seat cell rects rendered members claimed during the last sync,
    /// keyed by soldier id — the disjointness unit the stable-seat model
    /// guarantees every sync (round 3). A folded member has no entry.
    var soldierSeatFootprintsForTesting: [BattleCombatState.SoldierID: CGRect] {
        seatFootprintsBySoldierID
    }

    /// One presented live soldier's READABLE footprint — logical body ∪
    /// HP bar at its real transform — the unit parked-member disjointness
    /// is asserted on. Transient attack canvas reach outside it is pose
    /// art, not standing ground (round 3).
    struct SoldierReadableFootprintForTesting {
        let id: BattleCombatState.SoldierID
        let rect: CGRect
        let position: CGPoint
    }

    var soldierReadableFootprintsForTesting: [SoldierReadableFootprintForTesting] {
        combat.soldiers.filter(\.isAlive).compactMap { soldier in
            guard let bundle = soldierNodes[soldier.id], !bundle.root.isHidden else {
                return nil
            }
            return SoldierReadableFootprintForTesting(
                id: soldier.id,
                rect: soldierReadableFootprint(at: bundle.root.position, for: bundle),
                position: bundle.root.position
            )
        }
    }

    /// The roots still rendering their removal fade — lets tests prove the
    /// nodes are actually detached (not just unreserved) when teardown or a
    /// resize retires them.
    var fadingSoldierRootsForTesting: [SKNode] {
        soldierFadingFootprints.values.map(\.root)
    }

    /// Whether the pending casualty still carries its authored
    /// hit-then-remove SKAction — the real timing evidence for the corpse
    /// lifecycle (SKActions never advance under test stepping, so tests
    /// assert the authored wait exists rather than simulating its clock).
    func soldierNodeHasDelayedRemovalActionForTesting(
        _ id: BattleCombatState.SoldierID
    ) -> Bool {
        soldierNodes[id]?.root.action(forKey: SoldierAnimationKey.delayedRemoval) != nil
    }

    /// Runs the production `removeSoldierNode` landing — including the
    /// 0.18 s fade tail for `animated: true` — so tests can verify the
    /// corpse's ground stays reserved while the fade still renders.
    func removeSoldierNodeForTesting(id: BattleCombatState.SoldierID, animated: Bool) {
        removeSoldierNode(id: id, animated: animated)
    }

    /// Roots that left `soldierNodes` but still render their fade tail —
    /// their footprints stay reserved until the remove action lands.
    var fadingSoldierFootprintsForTesting: [CGRect] {
        soldierFadingFootprints.values.map(\.rect)
    }

    /// Scene positions of the roots still rendering their removal fade —
    /// lets tests identify the fading node among enumerated soldier roots.
    var fadingSoldierRootPositionsForTesting: [CGPoint] {
        soldierFadingFootprints.values.map(\.root.position)
    }

    /// Number of fading-removal reservations still held.
    var fadingSoldierFootprintCountForTesting: Int {
        soldierFadingFootprints.count
    }

    /// Completes the 0.18 s fade tail of every animated-removal soldier —
    /// the SKAction sequence (fade → release → remove) never advances in
    /// tests, so this performs its landing: detach + reservation release.
    func finishFadingSoldierRemovalsForTesting() {
        for entry in soldierFadingFootprints.values {
            entry.root.removeFromParent()
        }
        soldierFadingFootprints.removeAll()
    }

    /// Drives the production badge sync directly — lets containment tests
    /// exercise the real pill-fit path at counts no live battle can
    /// produce (six+ digits) without faking a roster.
    func updateSoldierOverflowBadgeForTesting(lane: BattleLane, foldedCount: Int) {
        syncSoldierOverflowBadge(
            lane: lane,
            foldedCount: foldedCount,
            anchorX: point(forLane: lane, position: 0).x
        )
    }

    var liveSoldierTypesForTesting: [SoldierType] {
        // Ordinary-roster probes exclude the flagged Captain (HPA-475),
        // matching the `combat.livingSoldierCount` convention.
        combat.soldiers.filter { $0.isAlive && !$0.isCaptain }.map(\.type)
    }

    var liveSoldierLevelsForTesting: [Int] {
        combat.soldiers.filter { $0.isAlive && !$0.isCaptain }.map(\.level)
    }

    var liveSoldierAttackPowersForTesting: [Int] {
        combat.soldiers.filter { $0.isAlive && !$0.isCaptain }.map(\.attackPower)
    }

    var liveSoldierMaxHPsForTesting: [Int] {
        combat.soldiers.filter { $0.isAlive && !$0.isCaptain }.map(\.maxHP)
    }

    var liveSoldierSpecialistBonusesForTesting: [SoldierSpecialistBonus?] {
        combat.soldiers.filter { $0.isAlive && !$0.isCaptain }.map(\.specialistBonus)
    }

    var firstLiveSoldierHPBarFrameForTesting: CGRect? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }

        return sceneFrame(for: bundle.hpBarBackground)
    }

    /// Path-space (stroke-free) bounds of the first live soldier's HP bar
    /// background and fill, as authored by `layoutSoldierHPBar`. Scene
    /// accumulated frames include SKShapeNode stroke padding, so tests
    /// comparing the fill fraction read the raw paths instead.
    var firstLiveSoldierHPBarPathBoundsForTesting: (background: CGRect, fill: CGRect)? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID],
              let background = bundle.hpBarBackground.path?.boundingBox,
              let fill = bundle.hpBarFill.path?.boundingBox else {
            return nil
        }

        return (background, fill)
    }

    var firstLiveSoldierBodyFrameForTesting: CGRect? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }

        return sceneFrame(for: bundle.body)
    }

    /// Returns the first live soldier's body as an `SKSpriteNode` for tests
    /// that need to sample texture/size across animation frames. Returns nil
    /// when the body is the static `SKShapeNode` fallback or no live soldier
    /// exists.
    var firstLiveSoldierBodySpriteForTesting: SKSpriteNode? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }
        return bundle.body as? SKSpriteNode
    }

    var firstLiveSoldierTowerShotTargetForTesting: CGPoint? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }

        return towerShotTargetPoint(for: bundle)
    }

    /// One live soldier's tower-shot endpoint paired with the root
    /// transform terms the conversion must respect. Lets tests prove a
    /// crowded scaled formation (`root.setScale(formation.scale)` in
    /// `syncSoldierNodes`) shrinks the endpoint onto the rendered body
    /// midpoint instead of landing at the unscaled logical midpoint
    /// (HPA-812 final review).
    struct LiveSoldierTowerShotTargetForTesting {
        let type: SoldierType
        let rootPosition: CGPoint
        let rootScale: CGFloat
        let target: CGPoint
    }

    /// Every live soldier's tower-shot endpoint in effects-layer space, in
    /// combat roster order.
    var liveSoldierTowerShotTargetsForTesting: [LiveSoldierTowerShotTargetForTesting] {
        combat.soldiers.filter(\.isAlive).compactMap { soldier in
            soldierNodes[soldier.id].map { bundle in
                LiveSoldierTowerShotTargetForTesting(
                    type: bundle.type,
                    rootPosition: bundle.root.position,
                    rootScale: bundle.root.xScale,
                    target: towerShotTargetPoint(for: bundle)
                )
            }
        }
    }

    var firstLiveSoldierBodyNameForTesting: String? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }

        return bundle.body.name
    }

    var soldierTargetHeightForTesting: CGFloat {
        soldierTargetHeight()
    }

    var soldierFormationMaximumLateralOffsetForTesting: CGFloat {
        battlefieldLayout.frame.width / 9
    }

    func soldierAnimationFrameDurationsForTesting(
        action: String,
        soldierType: SoldierType = .infantry
    ) -> [TimeInterval] {
        guard let action = SoldierAnimationAction(rawValue: action) else { return [] }
        return SoldierAnimationTiming.frameDurations(for: action, type: soldierType)
    }

    func soldierAnimationDurationForTesting(
        action: String,
        soldierType: SoldierType = .infantry
    ) -> TimeInterval {
        guard let action = SoldierAnimationAction(rawValue: action) else {
            return 0
        }

        return SoldierAnimationTiming.totalDuration(for: action, type: soldierType)
    }

    func soldierDelayedRemovalWaitDurationForTesting(soldierType: SoldierType) -> TimeInterval {
        SoldierAnimationTiming.totalDuration(for: .hit, type: soldierType)
    }

    /// Deterministic resolution of "the first live soldier" for test accessors.
    /// Uses the combat roster (stable ordering) instead of `soldierNodes.first`
    /// (Dictionary, non-deterministic across hash seeds) so tests stay
    /// reproducible as the suite grows beyond a single soldier.
    private var firstLiveSoldierIDForTesting: BattleCombatState.SoldierID? {
        combat.soldiers.first(where: \.isAlive)?.id
    }

    func triggerFirstLiveSoldierAnimationForTesting(_ rawAction: String) {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let action = SoldierAnimationAction(rawValue: rawAction) else {
            return
        }
        playSoldierAnimation(action, for: soldierID, resumesWalk: true)
    }

    func firstLiveSoldierHasActionForTesting(_ key: String) -> Bool {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return false
        }

        return bundle.body.action(forKey: key) != nil
            || bundle.root.action(forKey: key) != nil
    }

    func anyVisibleSoldierHasActionForTesting(_ key: String) -> Bool {
        soldierNodes.values.contains { bundle in
            bundle.body.action(forKey: key) != nil
                || bundle.root.action(forKey: key) != nil
        }
    }

    /// Returns the remaining hit-reaction countdown for the first live soldier,
    /// or `nil` if no hit timer is armed. Used by regression tests that verify
    /// a tower-generated hit arms the timer at the full authored duration
    /// (0.9s) rather than `0.9s - deltaTime` (the bug fixed by reordering
    /// `decrementSoldierHitAnimationRemaining` before `combat.tick`).
    var firstLiveSoldierHitAnimationRemainingForTesting: TimeInterval? {
        guard let soldierID = firstLiveSoldierIDForTesting else {
            return nil
        }
        return soldierHitAnimationRemaining[soldierID]
    }

    /// Simulates the SpriteKit render loop completing the first live soldier's
    /// current transient (attack/hit) animation by invoking the same
    /// resume-walk path the `SKAction.run` closure fires on the real render
    /// loop. Crucially, this does NOT pre-clear the transient action key — in
    /// production the closure runs as the final step of the keyed sequence, so
    /// the key is still installed when `resumeWalkForSoldierIfNeeded` enters.
    /// `resumeWalkForSoldierIfNeeded` is responsible for clearing it. Lets tests
    /// verify the spec's "resume walk after attack/hit" contract without
    /// driving SKAction time, while exercising the real production ordering.
    ///
    /// `isAllowed` mirrors the `resumesWalk` flag the production path passes
    /// to `resumeWalkForSoldierIfNeeded` (`true` for attacks, `!schedulesRemoval`
    /// for hits). It defaults to `true` for the positive-case tests and can be
    /// set to `false` to exercise the guard's negative branch.
    func completeFirstLiveSoldierTransientAnimationForTesting(isAllowed: Bool = true) {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return
        }
        resumeWalkForSoldierIfNeeded(id: soldierID, type: bundle.type, isAllowed: isAllowed)
    }

    var soldierAttackAnimationTriggerCountForTesting: Int {
        soldierAttackAnimationTriggerCount
    }

    var soldierHitAnimationTriggerCountForTesting: Int {
        soldierHitAnimationTriggerCount
    }

    func firstLiveSoldierVisualMatchesForTesting(_ type: SoldierType) -> Bool {
        guard
            let soldier = combat.soldiers.first(where: \.isAlive),
            let bundle = soldierNodes[soldier.id]
        else {
            return false
        }

        let preferredAssetName = soldierAssetName(for: type)
        if bundle.body.name == preferredAssetName {
            return true
        }

        return colorsMatch(soldierBodyColor(bundle.body), soldierVisualColor(for: type))
    }

    var isCityConquestFeedbackRunningForTesting: Bool {
        enemyCityNode?.action(forKey: "cityConquestFeedback") != nil
    }

    var floatingFeedbackCountForTesting: Int {
        effectsLayer.children.filter { $0.name == EffectName.floatingFeedback }.count
    }

    /// Scene-space positions of the floating damage labels. Projectile/label
    /// actions never advance without a render loop, so tests read the
    /// captured placement to prove feedback landed on the hit objective.
    var floatingFeedbackPositionsForTesting: [CGPoint] {
        effectsLayer.children
            .filter { $0.name == EffectName.floatingFeedback }
            .map(\.position)
    }

    var impactEffectScalesForTesting: [(x: CGFloat, y: CGFloat)] {
        effectsLayer.children
            .filter { $0.zPosition == GameUITheme.Z.effects }
            .map { (x: $0.xScale, y: $0.yScale) }
    }

    var battlefieldLayoutCountForTesting: Int {
        battlefieldLayoutCount
    }

    var isGoldBurstVisibleForTesting: Bool {
        childNode(withName: EffectName.goldBurst) != nil
    }

    var isGoldBurstRemovalScheduledForTesting: Bool {
        isGoldBurstRemovalScheduled
    }

    var goldBurstZPositionForTesting: CGFloat {
        childNode(withName: EffectName.goldBurst)?.zPosition ?? -.greatestFiniteMagnitude
    }

    var conquestReportNodeZPositionForTesting: CGFloat {
        conquestReportNode.zPosition
    }

    var conquestReportTitleForTesting: String {
        lastAppliedConquestReportContent?.title ?? ""
    }

    var conquestReportTilesForTesting: [ConquestReportContent.StatTile] {
        lastAppliedConquestReportContent?.tiles ?? []
    }

    var conquestReportRewardTextForTesting: String {
        lastAppliedConquestReportContent?.rewardText ?? ""
    }

    var lastConquestReportOriginForTesting: String? {
        guard let origin = lastConquestReportOriginForTestingStorage else { return nil }
        switch origin {
        case .freshLive: return "freshLive"
        case .freshIdle: return "freshIdle"
        case .restored: return "restored"
        }
    }

    var conquestEffectPresentationCountForTesting: Int {
        conquestEffectPresentationCountForTestingStorage
    }

    var conquestReportGoldAnchorForTesting: CGPoint? {
        conquestReportNode.goldEffectAnchor(in: self)
    }

    var goldBurstAnchorForTesting: CGPoint? {
        lastGoldBurstAnchorForTestingStorage
    }

    var isConquestContinueEnabledForTesting: Bool {
        isConquestContinueEnabled
    }

    var lastConquestReportLayoutInputForTesting: ConquestReportLayout.Input? {
        lastConquestReportLayoutInputForTestingStorage
    }

    func setConquestReportFitFailedForTesting(_ value: Bool) {
        isConquestReportFitFailed = value
    }

    var isConquestReportFitFailedForTesting: Bool {
        isConquestReportFitFailed
    }

    var conquestReportControlCountForTesting: Int {
        conquestReportNode.nodeCountsForTesting
    }

    var conquestReportChipCountForTesting: Int {
        conquestReportNode.renderedChipSymbolsForTesting.count
    }

    /// The visible new-gear receipt line on the conquest report, or nil when
    /// hidden (no receipt, compact height, or unfittable text) — HPA-671.
    var conquestReportGearLineTextForTesting: String? {
        conquestReportNode.renderedGearLineTextForTesting
    }

    func repeatDidMoveForTesting() {
        guard let view else { return }
        didMove(to: view)
    }

    /// Keep HP is the sole conquest/liveness authority (HPA-468); Battle
    /// player-facing reads go through this accessor.
    var keepRemainingPowerForTesting: Int {
        state.currentKeepRemainingPower
    }

    var livingKingdomBattlePresentationForTesting: LivingKingdomPresentation.Battle {
        livingKingdomBattlePresentation
    }

    var cityLevelForTesting: Int {
        state.cityLevel
    }

    var goldForTesting: Int {
        state.gold
    }

    var gameStateForTesting: KingdomGameState {
        state
    }

    /// Applies durable damage to one siege objective through the same
    /// `applyObjectiveDamage` path combat writes — lets a test retire a
    /// live Arrow Tower after it has produced its casualty window, so
    /// later assertions are not cut short by continued defensive fire.
    func applyObjectiveDamageForTesting(_ damage: Int, toObjectiveID objectiveID: String) {
        _ = state.applyObjectiveDamage(damage, toObjectiveID: objectiveID)
    }

    var cityTitleTextForTesting: String? {
        battleHUD.currentContentForTesting?.cityTitle
    }

    var liveCombatStatusTextForTesting: String? {
        battleHUD.currentContentForTesting.map { "\($0.manualCount)" }
    }

    var battleHUDCurrentContentForTesting: BattleHUDContent? {
        battleHUD.currentContentForTesting
    }

    var manualDeployChargesForTesting: Int {
        combat.manualDeployCharges
    }

    var isConquestPopupVisibleForTesting: Bool {
        isConquestReportVisible && !isConquestReportFitFailed
    }

    static func isPendingResultPresentableForTesting(
        _ result: BattleResult,
        currentCityKey: CityKey
    ) -> Bool {
        isPendingResultPresentable(result, currentCityKey: currentCityKey)
    }

    /// True when the feedback tooltip panel is currently shown (alpha > 0).
    /// A fresh scene presents no tooltip, so this starts false.
    var isFeedbackTooltipVisibleForTesting: Bool {
        feedbackPanel.alpha > 0.01
    }

    /// The current tooltip dedupe token. Tests use this to verify that an
    /// identical feedback message re-triggers the tooltip after the fade-out
    /// completion resets the token.
    var lastPresentedTooltipTextForTesting: String {
        lastPresentedTooltipText
    }

    /// Simulates the tooltip fade-out `SKAction` completing, clearing the
    /// dedupe token so a repeated identical message can re-trigger the tooltip.
    /// Tests can't drive `SKAction` time without a render loop, so this invokes
    /// the same production reset path the action's `run` block calls.
    func completeFeedbackTooltipFadeOutForTesting() {
        resetFeedbackTooltipDedupeToken()
    }

    /// True when the city HP bar fill is hidden because the Keep's remaining
    /// power has reached 0 (the fill path is removed to avoid rendering a sliver).
    var isCityHPBarFillHiddenForTesting: Bool {
        cityHPBarFill.path == nil
    }

    var cityHPBarFrameForTesting: CGRect? {
        sceneFrame(for: cityHPBarBackground)
    }

    var cityHPBarFillFrameForTesting: CGRect? {
        sceneFrame(for: cityHPBarFill)
    }

    /// Number of times `layoutCityHPBar` has run since scene creation. Tests
    /// use this to verify `redraw(shouldLayout: true)` invokes it exactly once
    /// (via `layoutInterface`) rather than twice (a discarded first pass).
    var layoutCityHPBarCallCountForTesting: Int {
        layoutCityHPBarCallCount
    }

    /// Drives `redraw` with an explicit `shouldLayout` flag so tests can verify
    /// the HP bar layout count under each path.
    func redrawForTesting(shouldLayout: Bool) {
        redraw(shouldLayout: shouldLayout)
    }

    func spawnSoldierForTesting() {
        spawnSoldier()
    }

    /// Injects `count` manual soldiers straight into the combat roster —
    /// bypasses the deploy-charge mechanic so tests can place more soldiers
    /// than the transient 3-charge pool allows without driving real recharge
    /// time (which would conquer the tiny authored smoke camps first).
    /// Runs the same post-guard deploy pipeline as `spawnSoldier` so nodes,
    /// session records, and HUD stay consistent.
    func spawnManualSoldiersDirectlyForTesting(_ count: Int) {
        for _ in 0..<max(0, count) {
            guard combat.livingSoldierCount(source: .manual) < KingdomGameState.manualSoldierCap,
                  let level = state.manualSoldierLevel(for: selectedManualSoldierType) else {
                break
            }
            deployManualSoldier(type: selectedManualSoldierType, level: level)
        }
    }

    func selectManualSoldierTypeForTesting(_ type: SoldierType) {
        selectManualSoldierType(type)
    }

    func animationFrameNamesForTesting(soldierType: SoldierType, action: String) -> [String] {
        guard let action = SoldierAnimationAction(rawValue: action) else {
            return []
        }
        return soldierAnimationFrameNames(for: soldierType.rawValue, action: action)
    }

    /// Returns the (cached) `[SKTexture]` for `soldierType`/`action`. Exposed so
    /// tests can verify the cache memoizes — repeated calls must return the same
    /// `SKTexture` instances rather than re-allocating from `UIImage(named:)`.
    func cachedSoldierAnimationTexturesForTesting(soldierType: SoldierType, action: String) -> [SKTexture] {
        guard let action = SoldierAnimationAction(rawValue: action) else {
            return []
        }
        return soldierAnimationTextures(for: soldierType.rawValue, action: action)
    }

    /// Number of (type, action) entries currently held in the texture cache.
    var soldierAnimationTextureCacheEntryCountForTesting: Int {
        soldierAnimationTextureCache.values.reduce(0) { $0 + $1.count }
    }

    /// Forces `isAnimatedCanvas` to be false for `soldierType` on the next
    /// node creation, simulating a partially installed catalog (some actions
    /// complete, at least one frame missing elsewhere) without touching the
    /// texture cache — so `soldierAnimationTextures(for:action:)` still
    /// returns the real textures for whichever actions ARE complete. Mirrors
    /// the release-build failure mode where a static-fallback soldier would
    /// otherwise have transient playback installed on its differently-sized
    /// sprite. Pre-seeds `soldierAnimatedCanvasFrameNameCache` so the probe
    /// short-circuits without re-running 30 `UIImage(named:)` lookups.
    func forceStaticFallbackCanvasForTesting(soldierType: SoldierType) {
        soldierAnimatedCanvasFrameNameCache[soldierType.rawValue] = .some(nil)
    }

    /// Returns true when the first live soldier's bundle was built on the
    /// animated-canvas path. Exposed so tests can verify the
    /// `forceStaticFallbackCanvasForTesting` hook actually flips the flag on
    /// the spawned node (and, after the fix, that transient playback is
    /// therefore suppressed for that soldier).
    var firstLiveSoldierIsAnimatedCanvasForTesting: Bool? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }
        return bundle.isAnimatedCanvas
    }

    /// IDs of soldiers awaiting animated removal after a tower kill. Exposed so
    /// tests can verify the death-flow scheduler fires for killed soldiers.
    var pendingAnimatedRemovalSoldierIDsForTesting: Set<BattleCombatState.SoldierID> {
        pendingAnimatedRemovalSoldierIDs
    }

    func requestGameplayTabForTesting(_ tab: GameplayTab) {
        requestGameplayTab(tab)
    }

    var battleHUDTabBarForTesting: GameplayTabBarNode {
        battleHUD.tabBarForTesting
    }

    var battleHUDContentForTesting: GameplayTabBarNode.Content {
        battleHUD.currentContentForTesting?.tabContent
            ?? GameplayTabBarNode.Content(selected: .battle, enabledTabs: [], showsCampAttention: false)
    }

    var battleHUDTabBarFrameForTesting: CGRect {
        battleChromeLayout?.tabBarFrame ?? .zero
    }

    // MARK: Guard presentation testing accessors (HPA-469)

    struct LivingGuardInfoForTesting {
        let id: BattleCombatState.GuardID
        let lane: BattleLane
        let currentHP: Int
        let position: Double
    }

    var livingGuardsForTesting: [LivingGuardInfoForTesting] {
        combat.guards.filter(\.isAlive)
            .map {
                LivingGuardInfoForTesting(
                    id: $0.id,
                    lane: $0.lane,
                    currentHP: $0.currentHP,
                    position: $0.position
                )
            }
    }

    /// The live range-aware Guard-blocker flag the medallion projection
    /// reads (HPA-582 review). Exposed so tests can align the displayed
    /// multiplier with combat's actual diversion state per tick.
    var isSelectedLaneGuardBlockerEngagedForTesting: Bool {
        combat.isGuardBlockerEngaged(onLane: state.siegeProgress.selectedLane)
    }

    func playGuardAttackFeedbackForTesting() {
        guard let id = combat.guards.first(where: \.isAlive)?.id else { return }
        playGuardAttackFeedback(for: id)
    }

    func playGuardHitFeedbackForTesting() {
        guard let id = combat.guards.first(where: \.isAlive)?.id else { return }
        playGuardHitFeedback(for: id)
    }

    var guardNodeCountForTesting: Int {
        guardNodes.count
    }

    /// Pre-seeds the `siege-guard` animated-canvas probe with a negative
    /// result (mirrors `forceStaticFallbackCanvasForTesting`) and rebuilds
    /// any live Guard nodes so they are created on the procedural fallback
    /// path — simulating the release-build failure mode where the trio is
    /// partially installed while `soldierAnimationTextures` still returns
    /// real textures for whichever actions ARE complete.
    func forceGuardStaticFallbackCanvasForTesting() {
        soldierAnimatedCanvasFrameNameCache[SiegeObjectiveAssetContract.guardAssetPrefix] = .some(nil)
        for id in guardNodes.keys {
            guardNodes[id]?.root.removeFromParent()
        }
        guardNodes.removeAll()
        syncGuardNodes()
    }

    /// Returns true when the first living Guard's bundle was built on the
    /// animated-canvas path; false when it is on the procedural fallback.
    var firstLivingGuardIsAnimatedCanvasForTesting: Bool? {
        guard let id = combat.guards.first(where: \.isAlive)?.id,
              let bundle = guardNodes[id] else { return nil }
        return bundle.isAnimatedCanvas
    }

    // MARK: Captain testing accessors (HPA-475)

    struct LivingCaptainInfoForTesting: Equatable {
        let id: BattleCombatState.SoldierID
        let lane: BattleLane
        let currentHP: Int
        let maxHP: Int
    }

    var livingCaptainForTesting: LivingCaptainInfoForTesting? {
        combat.captainSoldier.map {
            LivingCaptainInfoForTesting(
                id: $0.id,
                lane: $0.lane,
                currentHP: $0.currentHP,
                maxHP: $0.maxHP
            )
        }
    }

    var rallyRemainingSecondsForTesting: Double {
        combat.rallyRemainingSeconds
    }

    /// IDs of soldier bundles whose Rally protection accent is attached and
    /// visible (HPA-475). Soldiers without an accent — including the
    /// Captain, which is never protected — are absent.
    var rallyAccentVisibleSoldierIDsForTesting: Set<BattleCombatState.SoldierID> {
        Set(
            soldierNodes.compactMap { entry in
                guard let accent = entry.value.rallyAccent, !accent.isHidden else {
                    return nil
                }
                return entry.key
            }
        )
    }

    var soldierNodeCountForTesting: Int {
        soldierNodes.count
    }

    var firstLivingGuardRootNodeForTesting: SKNode? {
        combat.guards.filter(\.isAlive).first.flatMap { guardNodes[$0.id]?.root }
    }

    var firstLivingGuardVisualNodeForTesting: SKNode? {
        combat.guards.filter(\.isAlive).first.flatMap { guardNodes[$0.id]?.visual }
    }

    /// Remaining time on the first living Guard's transient animation
    /// countdown; nil when no transient is in flight.
    var firstLivingGuardTransientRemainingForTesting: TimeInterval? {
        guard let id = combat.guards.first(where: \.isAlive)?.id,
              let bundle = guardNodes[id],
              bundle.transientRemaining > 0 else { return nil }
        return bundle.transientRemaining
    }

    func advanceCombatForTesting(deltaTime: TimeInterval) {
        var remaining = max(0, deltaTime)

        while remaining > 0 {
            let step = min(remaining, 0.1)
            advanceCombat(deltaTime: step)
            remaining -= step
        }
    }

    func enterBackgroundForTesting(at date: Date) {
        handleSceneDidEnterBackground(at: date)
    }

    func enterForegroundForTesting(at date: Date) {
        handleSceneWillEnterForeground(at: date)
    }

    /// Drives a single `advanceCombat` call with the raw `deltaTime` (no
    /// chunking), exposing the production frame-stall path where
    /// `deltaTime` can exceed `combat.configuration.maxDeltaTime`. Used to
    /// verify the hit-reaction countdown tracks real frame time (matching
    /// the SKAction clock) rather than the combat tick's clamped delta.
    func advanceCombatSingleStepForTesting(deltaTime: TimeInterval) {
        advanceCombat(deltaTime: deltaTime)
    }

    /// Test-only overlay reset that lifts the conquest report's modal block
    /// without running the production Continue transaction. Use this to leave
    /// the report-gated state in tests that need to confirm behavior re-enables
    /// once the overlay is gone (e.g. info tooltips). It does NOT route, save,
    /// acknowledge, or disable Continue — the real handoff is `handleTouch(at:)`
    /// → `continueFromConquestReport()`.
    func forceDismissConquestOverlayForTesting() {
        isConquestReportVisible = false
        conquestReportNode.isHidden = true
        refreshBattleHUD()
    }

    /// Presents the conquest report flag without requiring a live conquest, so
    /// tests can verify HUD interactions are gated while the report overlays.
    func presentConquestPopupForTesting() {
        isConquestReportVisible = true
        hasPresentedPendingConquestReport = true
        refreshBattleHUD()
    }

    func flushBuildingProgressSaveForTesting() {
        buildingProgressSaveAccumulator = 0
        store.save(state)
    }

    var popupContinueButtonFrameForTesting: CGRect? {
        conquestReportNode.continueHitFrameForTesting
    }

    /// Taps the Continue hit-frame center through the production touch path
    /// (`handleTouch(at:)`), so tests exercise the real Continue transaction
    /// (disable → re-present → acknowledge → save → route) rather than a bypass.
    func tapConquestContinueForTesting() {
        guard let frame = conquestReportNode.continueHitFrameForTesting else {
            return
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        handleTouch(at: center)
    }

    /// Drives the production touch dispatcher at an arbitrary scene point.
    func handleTouchForTesting(at point: CGPoint) {
        handleTouch(at: point)
    }

    /// Centers of the spawn/world/build/gold-info/city-info controls, so the
    /// modal-block test can iterate every underlying touch path while the
    /// conquest report overlays the HUD.
    var underlyingControlCentersForTesting: [CGPoint] {
        guard let layout = battleChromeLayout else {
            return []
        }
        func tabCenter(_ tab: GameplayTab) -> CGPoint? {
            guard let index = GameplayTab.allCases.firstIndex(of: tab),
                  layout.tabHitFrames.indices.contains(index) else {
                return nil
            }
            return CGPoint(x: layout.tabHitFrames[index].midX, y: layout.tabHitFrames[index].midY)
        }
        var centers = [
            CGPoint(x: layout.deployFrame.midX, y: layout.deployFrame.midY)
        ]
        if let mapCenter = tabCenter(.map) {
            centers.append(mapCenter)
        }
        if let campCenter = tabCenter(.camp) {
            centers.append(campCenter)
        }
        centers.append(CGPoint(x: layout.incomeFrame.midX, y: layout.incomeFrame.midY))
        centers.append(CGPoint(x: layout.cityProgressFrame.midX, y: layout.cityProgressFrame.midY))
        return centers
    }

    private func soldierBodyColor(_ node: SKNode) -> SKColor {
        if let sprite = node as? SKSpriteNode {
            return sprite.color
        }
        if let shape = node as? SKShapeNode {
            return shape.fillColor
        }
        return .clear
    }

    private func colorsMatch(_ lhs: SKColor, _ rhs: SKColor) -> Bool {
        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0

        lhs.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha)
        rhs.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha)

        return abs(lhsRed - rhsRed) < 0.001
            && abs(lhsGreen - rhsGreen) < 0.001
            && abs(lhsBlue - rhsBlue) < 0.001
            && abs(lhsAlpha - rhsAlpha) < 0.001
    }
}
#endif
