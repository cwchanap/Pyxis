# Gameplay Sound, Haptics, and Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Self-reviewed and ready for execution after HPA-364 merges.

**Goal:** Add deterministic, non-starving gameplay sound effects and haptics, asynchronous bounded audio playback, and one accessible two-toggle SpriteKit settings surface across Battle, Country Map, and Building View.

**Architecture:** HPA-364 supplies semantic events, persisted preferences, observation, no-op/recording semantics, and a monotonic clock. HPA-389 adds pure output policy, `TickResult` projection, fair automatic-combat scheduling, platform outputs, reusable settings UI/accessibility, and scene integrations. `GameViewController` owns and injects one shared runtime.

**Tech Stack:** Swift 5, Swift Testing, Foundation, CoreGraphics, SpriteKit, UIKit, AVFAudio/AVFoundation, CoreHaptics, `AVAudioEngine`, `UIAccessibilityElement`, Xcode / `xcodebuild` on macOS.

## Global Constraints

- Design authority: `docs/superpowers/specs/2026-08-01-gameplay-sound-haptics-settings-design.md`.
- Do not execute until HPA-364 is merged to `main`.
- Intervals: global automatic 150 ms; melee/ranged/siege 200 ms; tower 250 ms; hit/death 300 ms; deployment sound/haptic independently 120 ms; construction 250 ms; invalid sound/haptic independently 500 ms; fortified warning 750 ms.
- After two successful global windows where attacks were eligible but non-attack sounds won, reserve the next successful global window for an attack; rotate siege → ranged → melee.
- Automatic clips are ≤750 ms.
- Exactly eight voices: six automatic capacity and two protected non-automatic capacity; never allocate a ninth voice during playback.
- Audio preparation is asynchronous. Pre-readiness and activation-failed SFX are dropped and never replayed.
- Use `.ambient`; activate only on first ready, eligible SFX and deactivate after stopping playback.
- Preserve Battle Z: settings `Z.modal - 10`, conquest report `Z.modal`, gold burst `Z.modal + 0.5`.
- Modal copy is exactly `Sound Effects`, `Haptics`, `Close`; outside taps are consumed and do not dismiss.
- VoiceOver order is Sound Effects, Haptics, Close.
- Battle pause adds settings visibility to the existing update guard; do not reset `lastUpdateTime` on settings open/close.
- Country Map idle conquest stays on map, retains transient text, emits reward then outcome plus one strong haptic, and does not route.
- Battle gold/soldier icons intentionally shrink from 30/36 pt to 26/30 pt; city icon is unchanged.
- Residual text floors: Battle value 48 pt, Map title 160 pt at ≥16 pt font, Building title/gold 200 pt.
- Every asset has repository-local license/attribution and measured processed duration.
- Do not edit `Pyxis.xcodeproj/project.pbxproj`; synchronized root groups add files automatically.
- Every task follows red → green → focused tests → commit.
- Run `git status --short` before every commit and stage only task files.
- Disable parallel testing:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/<SuiteName>
```

## Required HPA-364 Contract

Verify equivalent signatures before Task 1. If names differ, update this plan and the design before production changes.

```swift
enum GameplayFeedbackEvent: Equatable {
    case manualDeployment
    case soldierAttack(SoldierAttackSoundCategory)
    case towerFire
    case soldierDamage(SoldierDamageSoundKind)
    case buildingChanged
    case invalidAction
    case goldReward
    case cityConquest
    case countryCompletion
    case fortifiedLaneWarning
}

enum SoldierAttackSoundCategory: CaseIterable, Equatable { case melee, ranged, siege }
enum SoldierDamageSoundKind: Equatable { case hit, death }

struct FeedbackPreferences: Codable, Equatable {
    var soundEffectsEnabled: Bool
    var hapticsEnabled: Bool
}

protocol FeedbackPreferencesObservation: AnyObject { func cancel() }
protocol FeedbackPreferencesManaging: AnyObject {
    var current: FeedbackPreferences { get }
    @discardableResult func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences
    @discardableResult func setHapticsEnabled(_ enabled: Bool) -> FeedbackPreferences
    func observe(_ observer: @escaping (FeedbackPreferences) -> Void) -> FeedbackPreferencesObservation
}

protocol MonotonicClock { var now: TimeInterval { get } }
struct SystemMonotonicClock: MonotonicClock {
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}

protocol GameplayFeedbackProviding: AnyObject {
    func emit(_ event: GameplayFeedbackEvent)
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent])
}
```

## File Map

### Consume from HPA-364

- `Pyxis/GameplayFeedback.swift`
- `Pyxis/FeedbackPreferences.swift`
- `Pyxis/FeedbackPreferencesStore.swift`

### Create

- `Pyxis/GameplayOutputProtocols.swift`
- `Pyxis/GameplayFeedbackPolicy.swift`
- `Pyxis/CombatFeedbackProjector.swift`
- `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- `Pyxis/DefaultGameplayFeedbackCoordinator.swift`
- `Pyxis/GameplaySoundCatalog.swift`
- `Pyxis/GameplayAudioBackend.swift`
- `Pyxis/GameplaySoundOutputController.swift`
- `Pyxis/AVAudioEngineGameplayAudioBackend.swift`
- `Pyxis/UIKitGameplayHapticOutput.swift`
- `Pyxis/FeedbackSettingsLayout.swift`
- `Pyxis/SettingsGearNode.swift`
- `Pyxis/FeedbackSettingsNode.swift`
- `Pyxis/FeedbackSettingsAccessibilityAdapter.swift`
- `Pyxis/FeedbackSettingsController.swift`
- matching Swift Testing files under `PyxisTests/`
- `PyxisTests/GameplayFeedbackTestDoubles.swift`
- `docs/audio-assets.md`
- `docs/licenses/audio/README.md` plus local license/attribution files
- 13 `.caf` files under `Pyxis/Resources/Audio/Gameplay/`

### Modify

- `Pyxis/BattleScene.swift`
- `Pyxis/CountryMapLayout.swift`
- `Pyxis/CountryMapScene.swift`
- `Pyxis/BuildingViewScene.swift`
- `Pyxis/GameViewController.swift`
- corresponding files under `PyxisTests/`
- `CLAUDE.md`

---

### Task 1: Define Output Types, Pure Mapping, and Test Doubles

**Files:**
- Create: `Pyxis/GameplayOutputProtocols.swift`
- Create: `Pyxis/GameplayFeedbackPolicy.swift`
- Create: `PyxisTests/GameplayFeedbackTestDoubles.swift`
- Create: `PyxisTests/GameplayFeedbackPolicyTests.swift`

**Produces:**

```swift
enum GameplaySoundID: String, CaseIterable, Equatable {
    case deployment, attackMelee, attackRanged, attackSiege, towerFire
    case soldierHit, soldierDeath, construction, blocked, goldReward
    case cityConquest, countryCompletion, fortifiedWarning
}

enum GameplayHapticKind: Equatable { case lightImpact, mediumImpact, warning, strongSuccess }
enum GameplaySoundClass: Equatable { case automaticCombat, nonAutomatic }
enum GameplayGateID: Hashable {
    case deploymentSound, deploymentHaptic
    case constructionSound, invalidSound, invalidHaptic, fortifiedWarningSound
}

protocol GameplaySoundOutput: AnyObject {
    func prepareIfNeeded()
    func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass)
    func stopAllAndDeactivate()
}

protocol GameplayHapticOutput: AnyObject { func play(_ kind: GameplayHapticKind) }

struct GameplayFeedbackDirective: Equatable {
    let sound: GameplaySoundID?
    let soundClass: GameplaySoundClass?
    let soundGate: GameplayGateID?
    let haptic: GameplayHapticKind?
    let hapticGate: GameplayGateID?
}

enum GameplayFeedbackPolicy {
    static func directive(for event: GameplayFeedbackEvent) -> GameplayFeedbackDirective
}
```

- [ ] **Step 1: Write failing table tests for all 13 mappings, output classes, and gate IDs.**
- [ ] **Step 2: Run `GameplayFeedbackPolicyTests`; observe missing types.**
- [ ] **Step 3: Implement exhaustive mapping.** Automatic events are sound-only. City/country outcomes have no time gate because transition freshness deduplicates them.
- [ ] **Step 4: Add compiling test doubles:** `ManualMonotonicClock`, `RecordingFeedbackPreferencesManager`, `RecordingGameplaySoundOutput`, and `RecordingGameplayHapticOutput` using the protocols defined in this task.
- [ ] **Step 5: Run tests and commit.**

```bash
git add Pyxis/GameplayOutputProtocols.swift Pyxis/GameplayFeedbackPolicy.swift \
  PyxisTests/GameplayFeedbackTestDoubles.swift PyxisTests/GameplayFeedbackPolicyTests.swift
git commit -m "feat: map gameplay feedback outputs"
```

---

### Task 2: Project `TickResult` into Ordered Events

**Files:**
- Create: `Pyxis/CombatFeedbackProjector.swift`
- Create: `PyxisTests/CombatFeedbackProjectorTests.swift`

**Produces:**

```swift
enum CombatFeedbackProjector {
    static func events(from result: BattleCombatState.TickResult) -> [GameplayFeedbackEvent]
}
```

- [ ] **Step 1: Write failing tests.** Build mutable `TickResult` values; assert dense order death, tower, siege, ranged, melee, hit; duplicate coalescing; soldier-type category mapping; killed-ID subtraction.
- [ ] **Step 2: Run and observe missing projector.**
- [ ] **Step 3: Implement pure projection:**

```swift
let killed = Set(result.soldierLosses.map(\.soldierID))
let hasNonfatalHit = result.damagedSoldierIDs.contains { !killed.contains($0) }
let categories = Set(result.soldierAttacks.map { category(for: $0.type) })
```

Append events in the tested order; never inspect SpriteKit nodes.

- [ ] **Step 4: Run tests.**
- [ ] **Step 5: Commit.**

```bash
git add Pyxis/CombatFeedbackProjector.swift PyxisTests/CombatFeedbackProjectorTests.swift
git commit -m "feat: project combat feedback events"
```

---

### Task 3: Add Fair Automatic-Combat Scheduling

**Files:**
- Create: `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- Create: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`

**Produces:**

```swift
struct AutomaticCombatFeedbackScheduler {
    mutating func select(from orderedEvents: [GameplayFeedbackEvent], at now: TimeInterval)
        -> GameplayFeedbackEvent?
}
```

- [ ] **Step 1: Write failing tests** for every interval, closed category not consuming global, global-closed batch not changing starvation state, shared hit/death behavior, and dense trace:

```swift
#expect(scheduler.select(from: dense, at: 0.000) == .soldierDamage(.death))
#expect(scheduler.select(from: dense, at: 0.150) == .towerFire)
#expect(scheduler.select(from: dense, at: 0.300) == .soldierAttack(.siege))
```

Continue until ranged and melee are selected on later reserved windows.

- [ ] **Step 2: Run and observe missing scheduler.**
- [ ] **Step 3: Implement gates** with `global`, `melee`, `ranged`, `siege`, `tower`, `hitDeath` timestamps.
- [ ] **Step 4: Implement anti-starvation:** no state change while global closed; reset when no attack is category-open; reserve after two eligible non-attack wins; rotate present/open attack categories; update global and selected gate synchronously; queue nothing.
- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/AutomaticCombatFeedbackScheduler.swift \
  PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift
git commit -m "feat: schedule combat feedback fairly"
```

---

### Task 4: Compose Preferences, Discrete Gates, and Outputs

**Files:**
- Create: `Pyxis/DefaultGameplayFeedbackCoordinator.swift`
- Create: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`

**Produces:** `DefaultGameplayFeedbackCoordinator: GameplayFeedbackProviding`.

- [ ] **Step 1: Write failing tests** using Task 1 doubles: independent deployment gates, independent invalid gates, disabled output not consuming timestamps, enabled→disabled sound immediately calling `stopAllAndDeactivate`, outcomes, and automatic batch delegation.
- [ ] **Step 2: Run and observe missing coordinator.**
- [ ] **Step 3: Implement discrete gate evaluation.** Check preference before gate evaluation; update a timestamp only when that output fires; map every `GameplayGateID` to an exact interval.
- [ ] **Step 4: Retain one preference observation.** Cancel in `deinit`. `emitAutomaticCombat` selects one event and routes only sound; automatic combat never emits haptics.
- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/DefaultGameplayFeedbackCoordinator.swift \
  PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift
git commit -m "feat: coordinate gameplay feedback"
```

---

### Task 5: Install Catalog, Assets, and Offline Licensing

**Files:**
- Create: `Pyxis/GameplaySoundCatalog.swift`
- Create: `PyxisTests/GameplaySoundCatalogTests.swift`
- Create: `docs/audio-assets.md`
- Create: local license/attribution files under `docs/licenses/audio/`
- Create under `Pyxis/Resources/Audio/Gameplay/`:
  `deployment.caf`, `attack-melee.caf`, `attack-ranged.caf`, `attack-siege.caf`, `tower-fire.caf`, `soldier-hit.caf`, `soldier-death.caf`, `construction.caf`, `blocked.caf`, `gold-reward.caf`, `city-conquest.caf`, `country-completion.caf`, `fortified-warning.caf`.

**Produces:**

```swift
struct GameplaySoundResource: Equatable {
    let id: GameplaySoundID
    let resourceName: String
    let fileExtension: String
    let soundClass: GameplaySoundClass
    let maximumDuration: TimeInterval?
}

enum GameplaySoundCatalog {
    static let all: [GameplaySoundID: GameplaySoundResource]
}
```

- [ ] **Step 1: Write failing tests:** all IDs exactly once, `Bundle.main.url(forResource:withExtension:)` exists, automatic duration ≤0.750 s via `AVAudioFile`, and manifest fields. Resolve repo root from `#filePath` by deleting the test-file and `PyxisTests` path components.
- [ ] **Step 2: Run and observe missing catalog/resources.**
- [ ] **Step 3: Process real permitted assets:**

```bash
afconvert source.wav Pyxis/Resources/Audio/Gameplay/attack-melee.caf \
  -f caff -d LEI16@44100 -c 1
afinfo Pyxis/Resources/Audio/Gameplay/attack-melee.caf
```

Do not commit silence or unclear rights. Trim automatic clips to ≤0.750 s.

- [ ] **Step 4: Implement catalog and complete real source/creator/license/redistribution/local-license/duration entries.**
- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/GameplaySoundCatalog.swift PyxisTests/GameplaySoundCatalogTests.swift \
  Pyxis/Resources/Audio/Gameplay docs/audio-assets.md docs/licenses/audio
git commit -m "feat: add licensed gameplay sounds"
```

---

### Task 6: Build Async Sound State Machine and Voice Policy

**Files:**
- Create: `Pyxis/GameplayAudioBackend.swift`
- Create: `Pyxis/GameplaySoundOutputController.swift`
- Create: `PyxisTests/GameplaySoundOutputControllerTests.swift`

**Produces:**

```swift
protocol GameplayPreparedSound: AnyObject { var id: GameplaySoundID { get } }
protocol GameplayAudioVoice: AnyObject {
    var index: Int { get }
    func schedule(_ sound: GameplayPreparedSound)
    func stop()
}
protocol GameplayAudioBackend: AnyObject {
    func configureAmbientSession() throws
    func setSessionActive(_ active: Bool, notifyOthers: Bool) throws
    func prepareSound(_ resource: GameplaySoundResource) throws -> GameplayPreparedSound
    func makeVoice(index: Int) -> GameplayAudioVoice
    func startEngine() throws
    func stopEngine()
}

final class GameplaySoundOutputController: GameplaySoundOutput {
    func prepareIfNeeded()
    func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass)
    func stopAllAndDeactivate()
    func handleLifecycleRecovery()
}
```

- [ ] **Step 1: Write failing fake-backend tests:** asynchronous return, pre-readiness drop/no replay, first ready activation once, activation failure plus one-second cooldown, recovery clearing cooldown, exactly eight voices, automatic only indices 0...5, protected preference 6...7, non-automatic preempting oldest automatic, automatic never preempting non-automatic, all-non-automatic full pool dropping new event, and timestamp/index tie-break.
- [ ] **Step 2: Run and observe missing types.**
- [ ] **Step 3: Implement `SoundPreparationState` and serial preparation/output queues.** Publish the complete immutable prepared map only after all resources succeed; `play` returns unless ready.
- [ ] **Step 4: Implement activation and voice choice.** On failure set `nextActivationAttemptAt = clock.now + 1.0`. Select oldest automatic with explicit timestamp comparison and lower index tie-break. Stop before reuse; never create another voice.
- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/GameplayAudioBackend.swift Pyxis/GameplaySoundOutputController.swift \
  PyxisTests/GameplaySoundOutputControllerTests.swift
git commit -m "feat: add bounded async sound output"
```

---

### Task 7: Add Apple Audio Backend and Haptic Output

**Files:**
- Create: `Pyxis/AVAudioEngineGameplayAudioBackend.swift`
- Create: `Pyxis/UIKitGameplayHapticOutput.swift`
- Create: `PyxisTests/UIKitGameplayHapticOutputTests.swift`

- [ ] **Step 1: Write failing haptic tests** with injectable `HapticCapabilityProviding`, impact-generator, and notification-generator protocols. Test light, medium, warning, success, and unsupported no-op. Production capability uses `CHHapticEngine.capabilitiesForHardware().supportsHaptics`.
- [ ] **Step 2: Run and observe missing outputs.**
- [ ] **Step 3: Implement reusable haptic generators; never allocate per event.**
- [ ] **Step 4: Implement `AVAudioPreparedSound` and backend:** own one engine and eight nodes attached/connected once; `.ambient`; deferred activation/deactivation; `AVAudioFile` decode; engine start/stop; interruption/media-services recovery forwarding to controller.
- [ ] **Step 5: Run haptic/catalog tests, build, and commit.**

```bash
git add Pyxis/AVAudioEngineGameplayAudioBackend.swift Pyxis/UIKitGameplayHapticOutput.swift \
  PyxisTests/UIKitGameplayHapticOutputTests.swift
git commit -m "feat: add Apple feedback outputs"
```

---

### Task 8: Add Pure Settings Layout and Nodes

**Files:**
- Create: `Pyxis/FeedbackSettingsLayout.swift`
- Create: `Pyxis/SettingsGearNode.swift`
- Create: `Pyxis/FeedbackSettingsNode.swift`
- Create: `PyxisTests/FeedbackSettingsLayoutTests.swift`
- Create: `PyxisTests/FeedbackSettingsNodeTests.swift`

**Produces:**

```swift
struct FeedbackSettingsSafeAreaInsets: Equatable {
    let top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat
    static let zero = FeedbackSettingsSafeAreaInsets(top: 0, left: 0, bottom: 0, right: 0)
}

struct FeedbackSettingsLayout: Equatable {
    let scrimFrame: CGRect
    let panelFrame: CGRect
    let soundRowFrame: CGRect
    let hapticsRowFrame: CGRect
    let closeFrame: CGRect
    static func compute(sceneSize: CGSize, safeAreaInsets: FeedbackSettingsSafeAreaInsets)
        -> FeedbackSettingsLayout?
}

enum FeedbackSettingsAction: Equatable {
    case toggleSoundEffects, toggleHaptics, close, consumed
}
```

- [ ] **Step 1: Write failing layout tests** for 375×499, 375×667, tall phone, and iPad; panel 222, margin 16, max width 320, controls ≥44, nil for invalid geometry.
- [ ] **Step 2: Write failing node tests:** exact labels, two toggles plus Close, On/Off reapply, no duplicates, full-row targets, outside consumed, gear name on root/hit shape.
- [ ] **Step 3: Implement exact pure geometry** with `panelWidth = min(320, safeFrame.width - 32)` and `panelHeight = 222`.
- [ ] **Step 4: Build nodes once.** `apply` only updates nodes. Modal root `Z.modal - 10`; gear `Z.hud + 2`.
- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/FeedbackSettingsLayout.swift Pyxis/SettingsGearNode.swift \
  Pyxis/FeedbackSettingsNode.swift PyxisTests/FeedbackSettingsLayoutTests.swift \
  PyxisTests/FeedbackSettingsNodeTests.swift
git commit -m "feat: add feedback settings UI"
```

---

### Task 9: Add Scoped Accessibility and Settings Controller

**Files:**
- Create: `Pyxis/FeedbackSettingsAccessibilityAdapter.swift`
- Create: `Pyxis/FeedbackSettingsController.swift`
- Create: `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`
- Create: `PyxisTests/FeedbackSettingsControllerTests.swift`

**Produces:**

```swift
enum FeedbackSettingsFocusTarget {
    case outcome(UIAccessibilityElement)
    case openingGear
    case systemDefault
}
```

- [ ] **Step 1: Write failing accessibility tests:** one Settings gear; three modal elements in exact order; labels/values/traits/frames; activation; hidden underlying elements; outcome/gear/system focus paths.
- [ ] **Step 2: Write failing controller tests:** immediate preferences, modal remains open on toggles, outside consumed, Close-only dismissal, reapply, no feedback emission.
- [ ] **Step 3: Implement `ActionAccessibilityElement`:** subclass `UIAccessibilityElement`, retain an action closure, override `accessibilityActivate()` to invoke and return true. Post `.screenChanged` with Sound Effects, gear, outcome, or nil as specified.
- [ ] **Step 4: Implement controller:** own one gear, one modal, visibility, preferences, adapter; expose `open`, `handleTouch`, `applyGearFrame`, `reapply`, and `close`; never mutate game state or route.
- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/FeedbackSettingsAccessibilityAdapter.swift Pyxis/FeedbackSettingsController.swift \
  PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift \
  PyxisTests/FeedbackSettingsControllerTests.swift
git commit -m "feat: add accessible settings controller"
```

---

### Task 10: Integrate Battle

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Add failing tests:** injected dependencies; gear in left HUD and above parent `goldInfo`; 48 pt value width at 375×499/667; 26/30 resource icons and unchanged city icon; modal blocking; settings update guard with timestamp still refreshing; no open/close reset; layout-gate one reset; Z invariants.
- [ ] **Step 2: Add failing event tests:** manual success once, building spawn silent, rejected invalid once, one batch per `TickResult`, fresh reward→outcome, restored/reapply/resize silent.
- [ ] **Step 3: Implement HUD/touch:** `statusColumnWidth = leftHUDWidth - 58`; `valueWidth = statusColumnWidth - iconWidth - 6`; fail test seam below 48; modal then gear then controls.
- [ ] **Step 4: Implement pause/events:** add settings visibility to update guard; do not reset timestamp on open/close. Add origin-aligned `battlefieldActionLayer` for soldier roots and transient combat-only actions and pause only it. After each result call:

```swift
feedback.emitAutomaticCombat(CombatFeedbackProjector.events(from: result))
```

Emit discrete events only after successful authoritative mutations.

- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: integrate battle feedback settings"
```

---

### Task 11: Integrate Country Map

**Files:**
- Modify: `Pyxis/CountryMapLayout.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapLayoutTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

- [ ] **Step 1: Add failing layout tests:** `showsCurrentCityControl`; settings frame, optional current-city frame, title frame; both states; no overlap; title ≥160 and font ≥16; fail closed instead of 8 pt shrink.
- [ ] **Step 2: Add failing priority/modal tests:** layout/routing gate → modal → gear → scout attack/card → optional current-city → city nodes; complete blocking.
- [ ] **Step 3: Add failing idle-conquest tests:** stay on map, transient visible, reward then one outcome, one strong haptic, no route, no replay.
- [ ] **Step 4: Implement:** side inset 10, gear 44, gaps 8, current-city width 82; remove magic title offset; position from title frame; inject shared dependencies.
- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/CountryMapLayout.swift Pyxis/CountryMapScene.swift \
  PyxisTests/CountryMapLayoutTests.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "feat: integrate map feedback settings"
```

---

### Task 12: Integrate Building View

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

- [ ] **Step 1: Add failing layout/priority tests:** `textColumnWidth = contentWidth - 68`, minimum 200; modal → gear → palette → Upgrade/Battle → slots; slot-versus-slot reverse order preserved.
- [ ] **Step 2: Add failing mutation tests:** built/upgraded after save; rejected invalid once; settlement conquest reward+outcome without construction/invalid; only fresh lifecycle/Battle outcomes; no replay.
- [ ] **Step 3: Implement layout/touch:** inset 8, gear 44, gap 8, trailing 8; refit title/gold; move slot hit testing after controls.
- [ ] **Step 4: Wire returned result cases after save; never infer success from taps.**
- [ ] **Step 5: Run and commit.**

```bash
git add Pyxis/BuildingViewScene.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: integrate building feedback settings"
```

---

### Task 13: Compose Runtime, Lifecycle, Docs, and Acceptance

**Files:**
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Modify: `CLAUDE.md`
- Modify: `docs/audio-assets.md` only when measured values changed.

- [ ] **Step 1: Add failing composition tests:** identical coordinator/preferences/accessibility identities in all scenes; `viewDidLoad` starts nonblocking preparation; preferences survive scene replacement.
- [ ] **Step 2: Add failing lifecycle tests:** background stops/deactivates; interruption drops schedules; recovery restores readiness without activation/replay; layout-gate recovery preserves modal.
- [ ] **Step 3: Implement one composition root:**

```swift
let preferences = FeedbackPreferencesStore.shared
let clock = SystemMonotonicClock()
let backend = AVAudioEngineGameplayAudioBackend()
let sound = GameplaySoundOutputController(backend: backend, catalog: GameplaySoundCatalog.all, clock: clock)
let haptics = UIKitGameplayHapticOutput()
let feedback = DefaultGameplayFeedbackCoordinator(
    preferences: preferences,
    soundOutput: sound,
    hapticOutput: haptics,
    clock: clock
)
let accessibility = FeedbackSettingsAccessibilityAdapter(containerView: skView)
```

Call `sound.prepareIfNeeded()` after SKView construction without awaiting it. Inject the same instances into every scene/transition.

- [ ] **Step 4: Update `CLAUDE.md`:** semantic/platform boundaries, batch/fairness, async drop behavior, eight-voice derivation, accessibility scope, event ownership, no replay.
- [ ] **Step 5: Run all new and modified focused suites.**
- [ ] **Step 6: Run full automation:**

```bash
swiftlint lint
xcodebuild build -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO -only-testing:PyxisTests
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO -only-testing:PyxisUITests
```

- [ ] **Step 7: Required manual merge-gate smoke:** physical iPhone plus simulator; initial readiness/no replay; first activation and mixing; independent persisted toggles; rapid deployment; dense attack rotation; protected outcome audio; all three settings surfaces/minimum layouts; Battle/layout-gate no catch-up; VoiceOver; Map idle conquest; restored silence; Silent switch/background/interruption. Record device/OS/runtime/results in the implementation PR.
- [ ] **Step 8: Final review and commit:** search for unbounded voice creation, main-thread `AVAudioFile` reads, scene-owned platform generators, input fallthrough, and changed conquest Z.

```bash
git add Pyxis/GameViewController.swift PyxisTests/GameViewControllerTests.swift \
  CLAUDE.md docs/audio-assets.md
git commit -m "test: verify gameplay feedback integration"
```

## Plan Self-Review

### Spec Coverage

- HPA-364 contract: precondition + Tasks 1–4 and 13.
- Mapping/haptic exclusions: Tasks 1 and 4.
- Projection/death-over-hit: Task 2.
- Gates/anti-starvation: Task 3.
- Preferences/output independence: Task 4.
- Catalog/licensing/duration: Task 5.
- Async preparation/activation/pool: Tasks 6–7.
- Modal/gear/copy/outside consumption: Task 8.
- VoiceOver order/frames/focus: Task 9.
- Battle HUD/pause/Z/events: Task 10.
- Map optional control/residual width/idle outcome: Task 11.
- Building residual width/input/mutation precedence: Task 12.
- Shared composition/lifecycle/full verification/device smoke: Task 13.

### Placeholder Scan

No `TBD`, `TODO`, “implement later,” unnamed error handling, or unowned tests remain. Asset work is bounded by exact filenames, format, duration, licensing fields, local evidence, and validation commands.

### Type and Task Ordering

- Task 1 defines output IDs, classes, gate IDs, output protocols, policy, and test doubles before any consumer.
- Task 2 defines projector output before scheduler and scene use.
- Task 3 defines scheduler before coordinator.
- Task 4 defines coordinator before platform implementations and scenes.
- Task 5 defines catalog before preparation/backend work.
- Task 6 defines prepared-sound/backend/voice/controller types before Task 7.
- Task 8 defines settings geometry/nodes before Task 9 and scene integration.
- Task 9 defines accessibility/controller before Tasks 10–13.
