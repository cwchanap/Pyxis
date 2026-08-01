# Gameplay Sound, Haptics, and Settings Design

**Issue:** HPA-389  
**Dependency:** HPA-364  
**Related:** HPA-362, HPA-388  
**Status:** Third-pass review incorporated; awaiting user approval  
**Date:** 2026-08-01

## Goal

Add restrained gameplay sound effects and haptics to Pyxis and expose the two persisted feedback preferences through one minimal settings modal available from Battle, Country Map, and Building View.

The feature enriches the existing casual one-thumb loop without adding gameplay rules, mandatory interaction, or information available only through sound or haptics.

The player-facing settings controls are exactly:

- `Sound Effects` on/off.
- `Haptics` on/off.
- `Close`.

Music is not part of this feature.

## Scope

HPA-389 owns:

- Concrete semantic-event-to-sound/haptic mapping.
- Bundled sound assets and their provenance/license manifest.
- Attack sound categories.
- Automatic-combat coalescing, priority, anti-starvation, and deterministic rate limits.
- Asynchronous audio preparation, bounded playback, activation, interruption handling, and voice-preemption policy.
- One reusable SpriteKit settings modal.
- One reusable settings gear control.
- Narrow VoiceOver accessibility for the settings gear and modal controls.
- Gear placement, Z-order, and input priority in all three scenes.
- Scene integration for successful actions, rejected actions, combat, rewards, conquest, and completion.
- Automated coverage and merge-gating manual device smoke.

HPA-389 does not own:

- The reusable feedback service and persistent preference foundation defined by HPA-364.
- New gameplay rules or balance changes.
- Music, voice acting, downloadable sound packs, or per-sound volume.
- A general-purpose pause menu.
- A UIKit settings screen.
- App-wide SpriteKit accessibility outside the settings gear and modal.
- Accessibility for the existing conquest report.

## Existing Contracts and Repository State

### HPA-364 dependency

HPA-364 defines the reusable foundation:

- Scenes request semantic feedback rather than constructing platform players or haptic generators.
- Sound and haptic outputs are separate providers behind a coordinator boundary.
- Preferences persist separately from campaign progress.
- Preferences propagate immediately through one observable/update boundary.
- Tests inject a monotonic timing boundary.
- No-op and recording implementations exist for unsupported devices and tests.

HPA-389 scene integration must not begin until HPA-364 is merged and verified.

### Normative shared HPA-364/HPA-389 contract

The following sections are the normative shared contract that HPA-364 must adopt:

- `Semantic Feedback Contract`.
- `Composition and Dependency Injection`.
- `Automatic-Combat Batch Boundary`.
- The preference model containing exactly `soundEffectsEnabled` and `hapticsEnabled`.
- The injected monotonic clock and no-op/recording provider requirements.

HPA-364 may choose different type names, but it may not remove required payloads, collapse independent sound/haptic preferences, force wall-clock sleeps in tests, or require scenes to construct platform outputs. A contract change requires this design to be updated and re-approved before HPA-389 scene integration.

### Composition root

`GameViewController` constructs `BattleScene`, `CountryMapScene`, and `BuildingViewScene`. It owns one shared feedback coordinator, one shared preference manager, and the focused settings accessibility adapter. Every scene receives the same service/preference instances so changes apply immediately and survive scene replacement.

### Combat events

`BattleCombatState.TickResult` already provides authoritative typed data for:

- Tower shots.
- Soldier attacks, including soldier type.
- Damaged soldier IDs.
- Soldier losses.

Audio feedback derives from that result, not from SpriteKit animation callbacks. Animation suppression or timing never changes whether an authoritative combat event is eligible for sound.

### Conquest presentation

`BattleScene` already distinguishes fresh live, fresh idle, and restored conquest report presentations:

- Freshly finalized outcomes may emit reward and conquest/completion feedback.
- Restored pending reports are silent.
- Resize, redraw, and report reapplication are silent.

### Existing accessibility state

The repository has no reusable SpriteKit accessibility adapter for scene nodes; the existing app layout gate is UIKit-owned. The settings adapter introduced here is deliberately narrow and must not depend on nonexistent app-wide SpriteKit accessibility infrastructure.

## Product Decisions

### One shared settings surface

All three gears open the same reusable SpriteKit modal. The visible modal contains no title, explanatory copy, music row, volume control, outside-dismiss action, or secondary navigation.

Tapping outside the panel is consumed but does not close the modal. `Close` is the only normal dismissal action.

### Modal-local accessibility

The adapter exposes:

- Each scene gear as `Settings` with button traits.
- `Sound Effects` with value `On` or `Off`, button traits, and a toggle hint.
- `Haptics` with value `On` or `Off`, button traits, and a toggle hint.
- `Close` with button traits.

The modal exposes exactly three VoiceOver elements in this order:

1. Sound Effects.
2. Haptics.
3. Close.

The scrim and panel are not accessibility elements. Frames are converted from scene geometry to screen coordinates and refreshed after size, safe-area, or layout changes.

Opening hides underlying scene accessibility and focuses Sound Effects. A normal Close restores focus to the gear that opened the modal.

When a higher-priority outcome closes settings, focus follows this order:

1. Focus the outcome when it exposes a valid accessibility element.
2. Otherwise restore the opening gear only when no blocking outcome remains and the gear is visible and actionable.
3. Otherwise post a screen-change notification without a target and allow the system default.

The third path is the expected Battle conquest-report behavior until report accessibility is implemented outside HPA-389. QA must not expect focus on a blocked gear behind the report.

### Battle pause semantics

Settings visibility joins the existing Battle update guard set:

```swift
guard state.stageStatus == .battleActive,
      !isConquestReportVisible,
      !isFeedbackSettingsVisible
else {
    return
}
```

`BattleScene.update` keeps its existing `defer { lastUpdateTime = currentTime }`. Opening or closing settings does **not** clear `lastUpdateTime`. Because the timestamp continues to refresh every rendered frame while the guard blocks combat, closing naturally resumes with a one-frame delta and no catch-up.

The battlefield action layer is paused while settings is visible so soldier, projectile, and transient effect actions freeze with the simulation. The manual soldier-type menu closes before settings opens.

If the UIKit layout gate pauses the SKView, the existing layout-gate resume hook clears `lastUpdateTime` to discard wall time while frames were not rendered. This is separate from the settings guard.

Country Map transient feedback also stops advancing while settings is visible. Building View has no live simulation loop to pause.

### Country Map idle-conquest product intent

When Country Map finalizes idle progress that conquers a city, remaining on the map is intentional. The scene:

- Keeps the existing transient visible feedback.
- Emits newly awarded reward SFX followed by conquest or country-completion SFX.
- Emits the same one strong success haptic used by other fresh outcomes.
- Does not auto-route to Battle or introduce new report navigation.

Existing pending-result and stage routing remain unchanged. HPA-389 adds sensory feedback to the transition; it does not change the Country Map journey or HPA-388 report ownership.

### Immediate preference changes

Preference updates are synchronous from the UI perspective:

- Toggle visuals and accessibility values change immediately.
- The manager updates in memory, persists, and notifies observers.
- Disabling sound stops active transient SFX and suppresses future SFX.
- Re-enabling sound replays nothing.
- Haptic preference changes affect the next eligible haptic.
- Close performs no delayed save or apply step.

Settings interactions themselves emit no sound or haptic feedback.

## Semantic Feedback Contract

HPA-364 may use different concrete names, but the model must represent:

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

enum SoldierAttackSoundCategory: CaseIterable, Equatable {
    case melee
    case ranged
    case siege
}

enum SoldierDamageSoundKind: Equatable {
    case hit
    case death
}
```

`fortifiedLaneWarning` exists before HPA-362 lands. HPA-389 adds no dead lane path; HPA-362 emits the existing event when it introduces successful fortified-lane deployment.

### Attack categories

| Category | Soldier types |
|---|---|
| Melee | Infantry, Cavalry |
| Ranged | Archer, Mage |
| Siege | Siege |

These are audible semantic categories, not asset filenames.

## Feedback Mapping

| Authoritative occurrence | SFX | Haptic |
|---|---|---|
| Accepted manual deployment | Deployment | Light impact |
| Auto-spawned soldier | None | None |
| Soldier attack | Category-specific attack | None |
| Tower firing | Tower | None |
| Soldier damaged and survives | Hit | None |
| Soldier dies | Death | None |
| Successful construction or upgrade | Construction | Medium impact |
| Rejected manual transaction | Blocked | Warning notification |
| Gold newly awarded | Reward | None |
| City newly conquered | Conquest | Strong success notification |
| Country newly completed | Completion | Strong success notification |
| Successful fortified-lane deployment | Fortified warning plus normal deployment | Only the normal one light impact |

### Outcome precedence

1. Country completion replaces city conquest; never emit both for one city.
2. Gold reward emits before conquest/completion. Reward has no haptic, so the outcome still emits exactly one strong haptic.
3. Restored pending results emit no reward or outcome feedback.
4. Build/upgrade settlement that conquers before the requested mutation emits reward plus outcome only; construction success did not occur.
5. Each rejected mutation result emits at most one invalid-action event.
6. Informational taps and empty scene taps emit no feedback.

### Rejected manual transactions

`invalidAction` applies to actionable rejections including:

- Manual deployment without the required building.
- Manual squad full.
- Blocked World or Building navigation while a manual squad is active.
- Unavailable manual soldier type.
- Build/upgrade without a valid selection.
- Locked building, insufficient gold, occupied lot, type cap, invalid/missing building, or unavailable stage.
- Locked or completed map city when rejection feedback is presented.

Selecting a lot, showing an information tooltip, closing settings, or touching noninteractive background space is not invalid feedback.

## Automatic Combat Projection and Scheduling

### Pure projection

A framework-free `CombatFeedbackProjector` converts one `BattleCombatState.TickResult` into an ordered list containing at most:

- One death event.
- One tower-fire event.
- One attack event per audible category.
- One nonfatal hit event.

Killed IDs are removed from the nonfatal hit set, so death supersedes hit for those soldiers.

Default tie-break priority is:

1. Soldier death.
2. Tower fire.
3. Siege attack.
4. Ranged attack.
5. Melee attack.
6. Nonfatal soldier hit.

This order is a tie-break and initial salience rule, not an absolute rule that may starve attack sounds indefinitely.

### Global automatic-combat gate membership

Every automatic-combat SFX uses both the 150 ms global gate and its category/shared gate:

- Soldier death.
- Tower fire.
- Siege attack.
- Ranged attack.
- Melee attack.
- Nonfatal hit.

Manual deployment, construction/upgrade, invalid action, reward, conquest, completion, and fortified warning are outside the global automatic-combat gate.

### Automatic-Combat Batch Boundary

Scenes call one batch boundary per `TickResult`, equivalent to:

```swift
protocol GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent)
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent])
}
```

The exact API may use a focused coordinator wrapper, but the semantics are fixed:

1. Receive the projector's ordered event list once for the tick.
2. If the global gate is closed, emit no automatic sound and do not alter starvation state.
3. Build candidates whose own category/shared gate is open.
4. Select one candidate using the anti-starvation policy below.
5. Update the global gate and selected category/shared gate synchronously.
6. Emit at most one automatic sound and do not queue the rest.

### Attack-family anti-starvation

Maintain:

- `attackSkippedEligibleWindows`: consecutive global-open batches in which at least one attack category was eligible but a non-attack sound won.
- `lastPlayedAttackCategory`: used to rotate among siege, ranged, and melee.

Rules:

1. If no attack category is present with its own gate open, reset `attackSkippedEligibleWindows` to zero and use default priority.
2. If an attack is eligible and a non-attack candidate wins, increment `attackSkippedEligibleWindows`.
3. After two skipped eligible windows, the next global-open batch reserves its output for an eligible attack category.
4. Whenever an attack plays, reset `attackSkippedEligibleWindows` to zero.
5. Attack selection rotates `siege -> ranged -> melee -> siege`, starting after `lastPlayedAttackCategory` and skipping absent or gate-closed categories.
6. Death, tower, and nonfatal hit retain their default relative priority in non-reserved windows.
7. The reservation is category-selection state only. It does not retain, queue, or replay a past event.

This guarantees that sustained combat with continuously eligible attacks produces at least one attack-family sound every third successful global window, or approximately every 450 ms at the 150 ms global interval.

### Dense siege trace

Assume death, tower, and all attack categories remain present:

- `t = 0 ms`: death wins default priority. Attack skip count becomes 1.
- `t = 150 ms`: death's shared gate is closed; tower wins. Attack skip count becomes 2.
- `t = 300 ms`: attack reservation applies. Siege plays and resets the count.
- `t = 450 ms`: default priority resumes; the eligible non-attack winner may play.
- After the next two non-attack wins, the reserved attack rotates to ranged, then later melee.

Attack categories therefore remain audible during the steady-state busy-siege pattern that previously alternated death and tower forever.

### Shared hit/death trace

- `t = 0 ms`: death and a different soldier's nonfatal hit are present. Death wins, closes global until 150 ms and the shared hit/death gate until 300 ms.
- `t = 150 ms`: a nonfatal hit arrives. The global gate is open, but the shared gate is closed; nothing plays and timestamps do not change.
- `t = 300 ms`: another hit arrives. If no attack reservation overrides the window, both gates are open and hit may play, closing global until 450 ms and the shared gate until 600 ms.

Death blocks same-batch hit through projection/tie-break priority and blocks subsequent hit through the shared timestamp.

## Deterministic Rate Limits

Use an injected monotonic clock. Do not use wall-clock `Date` or sleeps for gate tests.

Output is allowed when elapsed time is greater than or equal to the interval. Suppressed output does not update its gate and is not queued.

### SFX intervals

| Repeated SFX category | Minimum interval |
|---|---:|
| Global automatic-combat output | 150 ms |
| Melee attack | 200 ms |
| Ranged attack | 200 ms |
| Siege attack | 200 ms |
| Tower fire | 250 ms |
| Soldier hit/death shared gate | 300 ms |
| Accepted manual deployment | 120 ms |
| Construction/upgrade | 250 ms |
| Invalid/blocked action | 500 ms |
| Fortified-lane warning | 750 ms |

Reward, conquest, and completion are deduplicated by the authoritative transition and fresh-presentation lifecycle rather than time.

### Haptic intervals

- Automatic combat never emits haptics.
- Manual-deployment light haptics use an independent 120 ms gate.
- Construction/upgrade emits one medium haptic per successful discrete mutation.
- Invalid warning haptics use a 500 ms gate.
- Conquest/completion emits one strong success haptic per fresh outcome.
- Fortified warning adds no haptic.

Sound and haptic gates are independent. Disabled output does not consume its timestamp; the first eligible event after re-enabling may fire immediately.

## Audio Assets and Playback

### Sound catalog

Use a typed catalog equivalent to:

```swift
enum GameplaySoundID: CaseIterable {
    case deployment
    case attackMelee
    case attackRanged
    case attackSiege
    case towerFire
    case soldierHit
    case soldierDeath
    case construction
    case blocked
    case goldReward
    case cityConquest
    case countryCompletion
    case fortifiedWarning
}
```

Scenes never know filenames or extensions.

### Asset manifest and offline reviewability

Add `docs/audio-assets.md`. Every entry records:

- Bundled resource name and semantic use.
- Original title/source identifier.
- Creator/publisher.
- Source reference.
- SPDX identifier when one exists.
- License reference.
- Confirmation that modification and binary app redistribution are permitted.
- Trimming, channel conversion, normalization, or resampling.
- Measured audible duration after processing.

A remote URL may supplement but may not be the only license evidence. Include applicable license text or attribution in `docs/licenses/audio/` so review can be completed offline.

### Duration budget and derived voice capacity

All automatic-combat clips must have a measured audible duration of **750 ms or less**, including their processed tail.

At one automatic start per 150 ms global window:

```text
ceil(750 ms / 150 ms) = 5 concurrent automatic voices maximum
```

Six automatic-capacity voices therefore provide one spare beyond the maximum compliant overlap. Two additional protected voices support the normal reward-plus-outcome sequence, producing the eight-voice total.

For compliant assets, automatic voice stealing is not expected during normal play. The steal branch remains a deterministic safety bound for completion-callback lag, malformed future assets, and synthetic tests. An asset test fails any automatic clip over 750 ms.

### Asynchronous preparation and readiness

`GameViewController.viewDidLoad` starts preparation but does not synchronously decode audio on the main thread.

Use a state equivalent to:

```swift
enum SoundPreparationState: Equatable {
    case unprepared
    case preparing
    case ready
    case failed
}
```

Requirements:

- File I/O and decoding into immutable `AVAudioPCMBuffer` values run on a dedicated serial audio-preparation queue or detached task.
- Engine/player graph setup and publication of the completed catalog run through one serialized audio-output boundary.
- UI presentation and initial scene creation do not wait for decoding.
- An eligible SFX received before `.ready` is dropped, not queued, and does not replay later.
- The event's independently eligible haptic may still fire.
- Preparation failure logs once per preparation attempt and leaves sound as a no-op until a later explicit retry trigger.
- Foregrounding after failure, media-services recovery, or a subsequent first-use request may call `prepareIfNeeded()` again; retries do not block the main thread.

This preserves the no-replay policy and ensures the first sound path never performs synchronous file loading or decoding.

### Audio-session ownership and activation

`GameplaySoundOutput` owns `AVAudioSession` interaction.

- Preparation configures category `.ambient`, mode `.default`, and no explicit mix option; ambient supplies the intended nonessential, mixing behavior.
- Category configuration and activation occur on the serialized audio-output boundary, not the UI thread.
- The session is not activated merely because the app launched or preparation completed.
- On the first eligible SFX after buffers are ready, the output calls `setActive(true)` and starts/prepares the engine if needed before scheduling the buffer.
- Once active and ready, later sounds do not call `setActive(true)` repeatedly.
- If activation fails because a higher-priority or nonmixable session prevents playback, drop the current SFX, queue nothing, and leave gameplay/haptics unaffected.
- After activation failure, suppress repeated activation attempts for a one-second monotonic cooldown. Foregrounding, an eligible interruption end, or media-services recovery clears the cooldown and permits an immediate retry.
- The output never changes to a nonmixable category to force activation.

On backgrounding, interruption begin, or Sound Effects being disabled:

1. Stop active voices and the engine.
2. Clear scheduled buffers and voice metadata.
3. Call `setActive(false, options: .notifyOthersOnDeactivation)` after playback objects stop.
4. Log deactivation failure without affecting gameplay.
5. Preserve no event for replay.

On foreground or an eligible interruption end, restore preparation/readiness as needed but do not activate until the next eligible sound.

### Eight-voice protection and preemption

Every voice records pool index, whether its sound is automatic combat, and monotonic `scheduledAt`.

- Six voices are automatic capacity.
- Two voices are protected non-automatic capacity.
- Automatic combat may use or replace only automatic-capacity voices.
- If all six automatic voices are active, a safety-path replacement stops the automatic voice with the smallest `scheduledAt`; ties use lower pool index.
- Non-automatic events use an idle protected voice first, then any idle voice.
- When no voice is idle, a non-automatic event may replace the oldest automatic voice.
- A non-automatic event never replaces another active non-automatic event.
- If all eight voices contain non-automatic sounds, the new non-automatic SFX is dropped rather than cutting off an existing player/outcome sound.

## Haptic Output

Semantic haptic kinds remain separate from generator choices:

```swift
enum GameplayHapticKind: Equatable {
    case lightImpact
    case mediumImpact
    case warning
    case strongSuccess
}
```

Default mapping:

- Light impact -> `UIImpactFeedbackGenerator(style: .light)`.
- Medium impact -> `UIImpactFeedbackGenerator(style: .medium)`.
- Warning -> `UINotificationFeedbackGenerator(.warning)`.
- Strong success -> `UINotificationFeedbackGenerator(.success)`.

The provider owns and reuses generators. Unsupported devices and tests use no-op output. Haptic failure never affects gameplay or persistence.

## Composition and Dependency Injection

```text
GameViewController
├── FeedbackPreferencesManaging
├── GameplayFeedbackProviding / coordinator
│   ├── GameplaySoundOutput
│   └── GameplayHapticOutput
├── FeedbackSettingsAccessibilityAdapter
└── injects shared service/preference instances into every scene
```

The feedback service and preferences are not stored in `KingdomGameState` and are not recreated during scene transitions.

## Reusable Settings Components

### SettingsGearNode

One reusable gear uses:

- SF Symbol `gearshape.fill`.
- A minimum 44 x 44 point hit frame.
- A 20-22 point glyph centered inside the target.
- Stable semantic name `feedbackSettingsGear`.
- Accessibility label `Settings`.
- No visible label, badge, or animation.

The root and transparent hit shape carry the semantic name so `nodes(at:)` finds the gear even when it is a child of the Battle panel named `goldInfo`. Battle checks the gear before `goldInfo`.

### FeedbackSettingsLayout

A CoreGraphics-only layout takes scene size and safe-area insets and computes:

- Full-scene scrim.
- Panel frame.
- Sound Effects row.
- Haptics row.
- Toggle visual/hit frames.
- Close frame.

| Value | Size |
|---|---:|
| Safe-frame horizontal margin | 16 pt minimum |
| Maximum panel width | 320 pt |
| Horizontal padding | 20 pt |
| Vertical padding | 20 pt |
| Toggle row height | 52 pt |
| Toggle-row gap | 12 pt |
| Last row to Close gap | 18 pt |
| Close height | 48 pt |
| Corner radius | 14 pt |

Panel height is exactly 222 points:

```text
20 + 52 + 12 + 52 + 18 + 48 + 20 = 222
```

All interactive frames are at least 44 points high. Layout returns nil for nonfinite or insufficient safe geometry. Every supported fixture must succeed.

### FeedbackSettingsNode

The fixed node tree contains one scrim, one panel, two full-row toggles, and Close.

```swift
enum FeedbackSettingsAction: Equatable {
    case toggleSoundEffects
    case toggleHaptics
    case close
    case consumed
}
```

Every non-control point returns `.consumed` while visible. Reapplication updates existing nodes and accessibility elements without duplication.

## Scene Integration

### Shared behavior

Open:

1. Refuse if a higher-priority scene modal or layout gate is active.
2. Read current preferences.
3. Apply layout/preferences.
4. Present settings.
5. Expose only the three modal accessibility elements and focus Sound Effects.
6. Pause relevant scene-time behavior.

Toggle updates and persists immediately, reapplies visual/accessibility state, and remains in the modal.

Close hides settings, restores scene accessibility using the focus rules, resumes without catch-up, and does not save campaign state, route, or reconstruct the scene.

### Z-order and existing conquest invariant

Preserve existing tested Battle tiers:

- Gear root/hit target: `GameUITheme.Z.hud + 2`.
- Settings scrim/panel root: `GameUITheme.Z.modal - 10`.
- Conquest report: `GameUITheme.Z.modal` unchanged.
- Gold burst: `GameUITheme.Z.modal + 0.5` unchanged and therefore above the report.
- UIKit app layout gate: outside the SKScene and above all SpriteKit content.

Settings normally closes before conquest presentation. Keeping settings below the existing report and gold burst also protects against a transient ordering race without changing HPA-388's tested gold-burst-above-report invariant.

### Layout gate while settings is open

If geometry becomes unsupported while settings is open:

1. `GameViewController` presents the UIKit gate and pauses the SKView.
2. The scene retains settings visibility; it is not auto-closed.
3. On recovery, the existing layout resume hook clears `lastUpdateTime`, reapplies current layout/preferences/accessibility frames, and keeps settings visible.
4. The next rendered frame establishes a fresh timestamp; subsequent frames remain blocked by the settings update guard.
5. No combat or transient catch-up occurs.
6. Settings closes only if a newly finalized higher-priority outcome requires it.

### Battle

#### Left-HUD gear geometry

| Constant | Value |
|---|---:|
| Gear hit size | 44 pt |
| Top inset | 4 pt |
| Trailing inset | 4 pt |
| Leading content inset | 6 pt |
| Status-to-gear gap | 4 pt |
| Icon/value gap | 6 pt |
| Compact gold/soldier icon maximum | 26 pt |
| Regular gold/soldier icon maximum | 30 pt |
| Minimum residual value width | 48 pt |

The gold and soldier icons currently use 30 pt compact and 36 pt regular maximums. Reducing them to 26/30 is an intentional HPA-389 layout tradeoff to make room for the 44 pt gear while preserving a 48 pt value column. The city-status icon is unchanged.

```text
statusColumnWidth
= leftHUDWidth - leadingInset - trailingInset - gearWidth - columnGap
= leftHUDWidth - 58

valueWidth
= statusColumnWidth - iconWidth - iconValueGap
```

The layout fails its fixture test below 48 points. Expected examples:

- 375 x 499 compact: left HUD about 146.5 pt; value width about 56.5 pt with a 26 pt icon.
- 375 x 667 regular: left HUD about 144.9 pt; value width about 50.9 pt with a 30 pt icon.

Gold and soldier rows use the leading status column rather than the current proportional positions beneath the gear.

#### Input priority

1. Layout fit failure or conquest report.
2. Settings modal.
3. Settings gear.
4. Manual soldier-type menu.
5. Manual type, Spawn, World, Build.
6. Gold/city information actions.
7. HPA-362 lane deployment when present.
8. Empty-space dismissal.

#### Event sources

- Successful manual deployment emits after creation and recording.
- Building spawns are silent.
- Rejected spawn/type/cap/navigation emits one invalid event.
- Each `TickResult` is projected and submitted as one automatic batch.
- Fresh live and mounted-scene idle outcomes emit reward then conquest/completion.
- Restored reports remain silent.

### Country Map

#### Title-control layout

Extend pure layout input with `showsCurrentCityControl`. Output includes:

- `settingsControlFrame` on the leading side.
- `currentCityControlFrame: CGRect?` on the trailing side.
- `titleTextFrame` between visible controls.

Constants:

| Value | Size |
|---|---:|
| Panel side inset | 10 pt |
| Gear hit size | 44 pt |
| Gear-to-title gap | 8 pt |
| Title-to-current-city gap | 8 pt |
| Current-city width | 82 pt |
| Minimum title text width | 160 pt |
| Minimum fitted title font | 16 pt |

With the current 375 pt minimum supported scene, the title region is approximately 335 pt wide and leaves approximately 173 pt for title text when both controls are visible. A result below 160 pt is unsupported rather than silently shrinking toward the generic 8 pt fit floor.

When the current-city action is hidden, its frame is nil and the title may extend to the trailing inset.

#### Input priority

1. Layout/map availability and routing guard.
2. Settings modal.
3. Settings gear.
4. Scout overlay/attack.
5. Scout-card body consumption.
6. Optional current-city action.
7. City nodes.

#### Event sources

- Rejected city entry with visible rejection feedback emits invalid once.
- Fresh map idle conquest follows the explicit stay-on-map behavior.
- Normal successful city entry emits no event.

### Building View

#### Title layout

Place the gear on the leading side of the title panel.

| Value | Size |
|---|---:|
| Panel side inset | 8 pt |
| Gear hit size | 44 pt |
| Gear-to-text gap | 8 pt |
| Minimum title/gold text-column width | 200 pt |

```text
textColumnWidth
= contentWidth - leadingInset - trailingInset - gearWidth - gap
= contentWidth - 68
```

At the minimum 375 pt portrait fixture, current content-width math leaves roughly 269.5 pt for the text column. A supported fixture fails if the residual column is below 200 pt; title and gold may not silently collapse to the generic 8 pt fitting floor.

#### Input priority

1. Settings modal.
2. Settings gear.
3. Building palette buttons.
4. Upgrade and Battle actions.
5. Building slots.

This intentionally replaces slot-first resolution. Audit existing slot-first tests. Control-versus-slot overlaps change to the new priority; reverse visual order among overlapping slot ellipses remains unchanged.

#### Event sources

- `.built` and `.upgraded` emit construction feedback after save.
- Rejected mutations emit invalid once.
- `.cityConqueredDuringSettlement` emits reward plus outcome and no construction/invalid event.
- Battle request and lifecycle settlement emit only fresh outcomes.

## Failure Handling

- Missing sound: DEBUG assertion; release silent skip.
- Preparation failure: log once per attempt and never block gameplay.
- Activation failure: drop current SFX, apply retry cooldown, and never block gameplay.
- Unsupported haptics: no-op.
- Corrupt preferences: HPA-364 defaults.
- Settings layout failure on supported geometry: failing test/development error; visible modal continues blocking input.
- Accessibility-frame conversion failure: visual/touch UI remains functional; DEBUG asserts and tests catch it.
- Output failure never changes mutation, reward, save, or routing.

## Test Strategy

### Scheduler and gate tests

- Every semantic mapping.
- Soldier-type attack projection.
- Tick coalescing and killed-ID subtraction.
- Global membership for death, tower, all attacks, and hit.
- All interval boundaries at minus epsilon, exact, and plus epsilon.
- One batch per TickResult and at most one automatic sound per batch.
- Attack skip count increments only on successful global-open non-attack selections while attacks are eligible.
- Attack reservation occurs after exactly two skipped eligible windows.
- Reservation resets after attack output or absence of eligible attacks.
- Attack rotation produces siege, ranged, melee without starvation.
- Dense death/tower trace produces an attack at the third successful window.
- Shared hit/death gate behavior remains deterministic.
- Suppressed output does not queue or update unrelated gates.
- Independent sound/haptic gating.

### Provider and preparation tests

- Preference defaults, encoding, corruption fallback, independent persistence, immediate observation.
- No-op and recording providers.
- Preparation returns immediately to the caller and performs decode work off the main thread.
- Pre-readiness events are dropped and never replayed; haptics remain independent.
- Exactly eight player nodes are prepared and no ninth is allocated.
- Every automatic asset is at most 750 ms.
- Five is the derived maximum compliant overlap; the sixth automatic voice is spare capacity.
- Automatic audio never uses protected voices.
- Oldest automatic replacement uses `scheduledAt`, tie-broken by index.
- Non-automatic audio may preempt oldest automatic but never another non-automatic sound.
- Activation is deferred until first ready/eligible SFX.
- Activation failure drops the event, starts the retry cooldown, and produces no replay.
- Background/interruption/disable stops output, deactivates after stopping, and replays nothing.

### Asset tests

- One catalog entry per sound ID.
- Every resource exists.
- Manifest includes source, creator, SPDX when available, redistribution confirmation, local license path, and measured duration.
- Automatic clips respect the 750 ms cap.
- No undocumented bundled sound.

### Settings and accessibility tests

- Settings layout succeeds for every supported fixture.
- Controls remain in safe frame and meet 44 pt minimum.
- Exactly two toggles and Close.
- Exact labels and On/Off states.
- Reapply creates no duplicate nodes or accessibility elements.
- Outside taps are consumed.
- Exactly three modal accessibility elements in order.
- Correct values, traits, activation, frames, and focus fallback.

### Battle tests

- Settings visibility blocks combat through the existing update guard while `lastUpdateTime` continues refreshing.
- Opening/closing settings needs no timestamp reset and produces no catch-up.
- Layout-gate recovery clears the timestamp once and preserves the open modal.
- Compact/regular HUD leaves at least 48 pt for values.
- Intentional resource-icon shrink is applied only to gold/soldier icons.
- Gear, rows, and text do not overlap.
- Named gear wins over parent `goldInfo`.
- Existing conquest report remains at `Z.modal`; gold burst remains at `Z.modal + 0.5` and above the report.
- Settings at `Z.modal - 10` remains above HUD/effects and below conquest presentation.
- Manual deployment once; building spawn silent.
- Automatic combat uses one batch from TickResult.
- Fresh outcomes once; restored/resize/redraw silent.

### Country Map tests

- Both current-city visibility states.
- Residual title width is at least 160 pt and fitted font at least 16 pt.
- Gear/title/current-city frames do not overlap.
- Gear priority and modal blocking.
- Map idle conquest stays on map, shows transient feedback, emits full fresh outcome feedback, and does not auto-route.

### Building View tests

- Residual title/gold text column is at least 200 pt.
- Gear/text do not overlap.
- Existing slot-first assumptions are audited.
- Controls win over overlapping slots.
- Slot-versus-slot reverse visual order remains.
- Modal blocks all underlying actions.
- Successful, rejected, and settlement-conquest mapping.

### GameViewController tests

- Shared service/preference identity across scenes.
- Scene creation is not blocked by audio decoding.
- Accessibility adapter swaps modal/scene exposure without duplicates.
- UIKit layout gate preserves open settings and reapplies frames after recovery.

## Manual Device Smoke

### Required before merge

Run on at least one physical iPhone with haptics and one simulator/no-haptic path:

1. First launch and scene presentation show no decode-related frame stall.
2. An SFX arriving before readiness is silently dropped and is not replayed.
3. First ready SFX activates the session without UI hitching.
4. Toggle Sound Effects and Haptics independently; verify immediate behavior and persistence.
5. Rapid manual deployment; verify independent SFX/haptic gates and no haptic buzz.
6. Dense mixed combat; verify death/tower salience and rotating attack-family sounds without continuous noise.
7. Trigger reward/conquest during dense combat; verify combat never cuts off protected one-shots.
8. Successful and rejected building actions.
9. Open settings from all scenes on smallest supported layouts; verify residual text widths remain readable.
10. Verify Battle pause/resume and layout-gate recovery without catch-up.
11. Enable VoiceOver; exercise gears, toggles, Close, and outcome-close fallback.
12. Trigger city conquest, country completion, and Country Map idle conquest.
13. Restore a pending report after relaunch and verify silence.
14. Verify Ring/Silent behavior and that other-app audio continues.
15. Exercise a higher-priority/nonmixable audio session; Pyxis drops SFX rather than interrupting or replaying it.
16. Background and exercise interruption; verify stop, deactivation, and no stale replay.

These are manual merge gates because CI cannot validate physical haptics, Silent-switch behavior, VoiceOver focus, real audio-session priority, real interruptions, or perceptible latency.

Additional iPad/Stage Manager devices and phone generations are release follow-up coverage. Pure layout fixtures remain mandatory in CI.

## Acceptance Criteria

- HPA-364 adopts the shared contract and merges before scene integration.
- Every mapping and precedence rule is implemented.
- All six automatic classes use the global gate plus their category/shared gate.
- One batch is submitted per TickResult; at most one automatic sound plays per global window.
- Continuously eligible attack sounds cannot be skipped for more than two successful global windows.
- Siege/ranged/melee selection rotates without starvation.
- Automatic combat emits no haptics.
- Manual-deployment haptic uses an independent 120 ms gate.
- Auto-spawn is silent.
- Audio decoding is asynchronous and never blocks initial scene presentation.
- Pre-readiness and activation-failed SFX are dropped and never replayed.
- Session activation is deferred to first ready/eligible SFX.
- Automatic clips are at most 750 ms; six automatic voices are sufficient by derivation, with one spare.
- Exactly eight voices are prepared; combat cannot preempt protected non-automatic one-shots.
- Existing conquest report/gold-burst Z invariant remains intact.
- Every gear uses the same icon/action, 44 pt target, named hit node, and accessible Settings element.
- Battle values retain at least 48 pt; Country Map title retains 160 pt; Building View title/gold retains 200 pt.
- The Battle gold/soldier icon reduction to 26/30 pt is intentional and tested.
- Modal contains exactly two toggles and Close, blocks input, and only Close dismisses normally.
- Modal exposes exactly three ordered VoiceOver controls with deterministic focus fallback.
- Settings pause uses the existing update guard and resumes without catch-up.
- Preferences apply and persist immediately.
- Disabling sound stops active output; re-enabling replays nothing.
- No music control/preference appears.
- Fresh outcomes emit once; restored/redraw/resize are silent.
- Country Map fresh idle conquest remains on map with full outcome feedback.
- Background/interruption stops and never replays stale sounds.
- Every sound has offline-reviewable provenance, licensing, and duration metadata.
- Required device smoke passes before merge.

## Non-Goals

- Music or adaptive soundtrack.
- Voice acting.
- Per-sound volume/mixer controls.
- Downloadable sound packs.
- Feedback-only gameplay information.
- Rewards for enabling feedback.
- General pause/settings architecture.
- UIKit settings presentation or separate settings scene.
- App-wide SpriteKit accessibility outside settings gear/modal.
- Conquest-report accessibility.
- New lane, combat, building, reward, or progression mechanics.
