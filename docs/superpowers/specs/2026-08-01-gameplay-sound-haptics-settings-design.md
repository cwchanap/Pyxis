# Gameplay Sound, Haptics, and Settings Design

**Issue:** HPA-389  
**Dependency:** HPA-364  
**Related:** HPA-362, HPA-388  
**Status:** Written and self-reviewed; awaiting user review  
**Date:** 2026-08-01

## Goal

Add restrained gameplay sound effects and haptics to Pyxis and expose the two persisted feedback preferences through one minimal settings modal available from Battle, Country Map, and Building View.

The feature must enrich the existing casual one-thumb loop without adding gameplay rules, mandatory interaction, or information available only through sound or haptics.

The player-facing controls are exactly:

- `Sound Effects` on/off.
- `Haptics` on/off.
- `Close`.

Music is not part of this feature.

## Scope

HPA-389 owns:

- The concrete semantic-event-to-sound/haptic policy.
- Bundled sound assets and their provenance/license manifest.
- Attack sound categories.
- Deterministic coalescing and rate limits.
- Runtime audio preparation, bounded playback, and interruption handling.
- One reusable SpriteKit settings modal.
- One reusable settings gear control.
- Gear placement and input priority in all three scenes.
- Scene integration for successful actions, rejected actions, combat, rewards, conquest, and completion.
- Automated coverage and manual device smoke for the integrated behavior.

HPA-389 does not own:

- The feedback service and persistent preference foundation defined by HPA-364.
- New gameplay rules or balance changes.
- Music, voice acting, downloadable sound packs, or per-sound volume.
- A general-purpose pause menu.
- A UIKit settings screen.
- App-wide SpriteKit accessibility infrastructure.

## Existing Contracts and Repository State

### HPA-364 dependency

HPA-364 defines the required foundation:

- Scenes emit semantic feedback events rather than constructing platform players or haptic generators.
- Sound and haptic output are separate providers behind a composite service.
- Preferences are persisted separately from campaign progress.
- Preferences propagate immediately through one observable/update boundary.
- Tests can inject a deterministic timing boundary.
- No-op and recording implementations exist for unsupported devices and tests.

HPA-389 must not begin scene integration until that contract is merged and verified. At the time this design was written, HPA-364 was not present on `main`.

### Composition root

`GameViewController` constructs `BattleScene`, `CountryMapScene`, and `BuildingViewScene`. It is therefore the composition root for one shared feedback service and one shared preference manager. New scenes must receive the same instances so preference changes affect the active scene immediately and remain effective across scene replacement.

### Combat events

`BattleCombatState.TickResult` already provides authoritative typed data for:

- Tower shots.
- Soldier attacks, including soldier type.
- Damaged soldiers.
- Soldier losses.

Audio feedback must derive from that result, not from SpriteKit animation callbacks. Visual animation suppression or timing must never change whether an authoritative combat event is eligible for sound.

### Conquest presentation

`BattleScene` already distinguishes fresh live, fresh idle, and restored conquest report presentations. HPA-389 extends the same lifecycle rule:

- Freshly finalized outcomes may emit reward and conquest/completion feedback.
- Restored pending reports are silent.
- Resize, redraw, and report reapplication are silent.

### Input handling

The current scenes use different hit-test structures:

- Battle has an explicit named-node priority list.
- Country Map has an ordered sequence of frame checks.
- Building View currently resolves slots before buttons.

The settings integration must preserve explicit, testable priority rather than relying on SpriteKit child order.

## Product Decisions

### One shared settings surface

All three gear controls open the same reusable SpriteKit modal. The modal contains no title, explanatory copy, music row, volume control, outside-dismiss action, or secondary navigation. This keeps the content literally limited to the two required toggles and Close.

Tapping anywhere outside the panel is consumed but does not close the modal. `Close` is the only close action.

### Battle pauses while settings are open

Opening settings during Battle pauses live combat and battlefield actions without mutating campaign or combat state:

- `BattleScene.update` does not advance combat while the modal is visible.
- The battlefield layer is paused so soldier, projectile, and effect actions freeze with the simulation.
- `lastUpdateTime` is cleared on open and close so closing does not apply a large catch-up delta.
- The manual soldier-type menu closes before the modal opens.

This avoids conquest or unit loss occurring behind a settings panel and satisfies the requirement that closing returns to the same scene and gameplay state.

Country Map transient timers also stop advancing while settings are open and resume without catch-up. Building View has no live simulation loop to pause.

Lifecycle-driven idle progress is not disabled by an open settings modal. If foreground settlement produces a conquest while settings are visible, the settings modal closes and the higher-priority conquest report or stage flow takes over.

### Audio behavior

Use `AVAudioSession.Category.ambient` for gameplay effects. Sound effects are nonessential, mix with audio from other apps, and respect the iPhone Ring/Silent switch and screen locking.

The runtime must:

- Configure and prepare the audio session/output before first combat use.
- Stop active transient sounds when the app backgrounds or an audio interruption begins.
- Clear scheduled transient playback rather than replaying it later.
- Restore output readiness after foregrounding or an eligible interruption end without replaying stale events.

Official references:

- [AVAudioSession ambient category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient)
- [AVAudioSession interruption notification](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification)

### Immediate preference changes

Preference updates are synchronous from the UI's perspective:

- The toggle visual changes immediately.
- The preference manager updates its in-memory value, persists it, and notifies observers through the HPA-364 boundary.
- Disabling sound effects immediately stops active transient SFX and suppresses future SFX.
- Enabling sound effects does not replay anything suppressed while muted.
- Haptic preference changes affect the next eligible haptic; already-fired haptics cannot be recalled.
- Close performs no delayed save or apply step.

Settings interactions themselves emit no sound or haptic feedback.

## Semantic Feedback Contract

HPA-364 may use different concrete names, but its event model must be able to represent the following without coupling event cases to asset filenames:

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

`fortifiedLaneWarning` remains available even when HPA-362 has not landed. If HPA-362 is absent when HPA-389 is implemented, no dead lane-deployment path is added; HPA-362 becomes responsible for emitting the existing semantic event when it introduces successful direct deployment into a fortified lane.

### Attack categories

Use three stable audible categories:

| Category | Soldier types |
|---|---|
| Melee | Infantry, Cavalry |
| Ranged | Archer, Mage |
| Siege | Siege |

The category is a gameplay/audible semantic value. It is not an asset name and does not require one event case per soldier type.

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

Outcome feedback follows these rules:

1. Country completion replaces city conquest. Never emit both outcome events for one city.
2. A newly awarded gold reward emits before the conquest/completion event. Reward has no haptic, so the outcome still produces exactly one strong haptic.
3. A restored `pendingBattleResult` emits no reward or outcome feedback.
4. Build/upgrade settlement that conquers the city before the requested mutation emits reward plus conquest/completion only. It does not emit construction success because the requested build or upgrade did not occur.
5. Each model mutation result emits at most one invalid-action event.
6. Informational taps and taps on empty scene space emit no feedback.

### Rejected manual transactions

`invalidAction` applies to actionable rejections, including:

- Manual deployment without the required building.
- Manual squad full.
- Attempting to open World or Building View while a manual squad is active.
- Selecting an unavailable manual soldier type.
- Building without a selected empty lot.
- Locked building, insufficient gold, occupied lot, per-type cap, invalid/missing building, or unavailable stage.
- Selecting a locked or already completed map city when the scene presents rejection feedback.

Selecting a lot, opening an information tooltip, closing settings, or touching noninteractive background space is not an invalid action.

## Combat Coalescing

### Pure projection

Add a framework-free combat feedback projector that converts one `BattleCombatState.TickResult` into a small ordered list of semantic events.

The projector coalesces a dense tick as follows:

- At most one death event.
- At most one tower-fire event.
- At most one attack event for each audible category present.
- At most one nonfatal hit event.
- Killed soldier IDs are removed from the nonfatal hit set, so death supersedes hit for those soldiers.

The fixed audible priority is:

1. Soldier death.
2. Tower fire.
3. Siege attack.
4. Ranged attack.
5. Melee attack.
6. Nonfatal soldier hit.

The projector returns events in that order. The shared global automatic-combat gate normally permits only the highest-priority eligible sound at a single timestamp, while a category whose own gate is closed does not consume the global gate and allows the next eligible event to be considered.

This priority is an audio policy only. It does not reorder or change combat results, visual animations, damage, loss recording, or persistence.

## Deterministic Rate Limits

The feedback service uses a monotonic injected clock, such as system uptime in production and a manually advanced clock in tests. It must not use wall-clock `Date` values or sleeps for rate-limit tests.

A sound is allowed when elapsed time is greater than or equal to its minimum interval. Suppressed sounds do not update any gate and are not queued for later playback.

### Sound-effect intervals

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

Gold reward, city conquest, and country completion are occurrence-deduplicated by the authoritative model transition and fresh-presentation lifecycle rather than by time. They are not queued or replayed.

### Haptic rate limits

- Automatic combat never emits haptics.
- Accepted manual deployment emits one light haptic for each successful discrete deployment.
- Successful construction/upgrade emits one medium haptic for each successful mutation.
- Invalid-action warning haptics use a 500 ms minimum interval.
- City conquest or country completion emits one strong success haptic per newly finalized outcome.
- Fortified-lane warning adds no haptic.

Sound and haptic gates are independent. Muting one output does not consume or delay the other output's gate. An event suppressed because an output is disabled does not update that output's timestamp, so the first eligible event after re-enabling may play immediately.

## Audio Assets and Playback

### Sound catalog

Use a typed sound identifier set equivalent to:

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

The catalog maps semantic output to bundled resources. Scenes never know filenames or file extensions.

### Asset manifest

Add `docs/audio-assets.md`. Every catalog entry must record:

- Bundled resource name.
- Semantic use.
- Original title or source identifier.
- Creator or publisher.
- Source reference.
- License identifier and license reference.
- Confirmation that modification and binary app redistribution are permitted.
- Modifications performed, such as trimming, channel conversion, normalization, or resampling.

Assets with unclear provenance, attribution, modification rights, or app redistribution rights may not be bundled.

### Format and preparation

Latency-sensitive effects should be short mono PCM resources, stored in an app-compatible uncompressed format such as WAV or CAF. The production provider:

- Loads and decodes all catalog buffers once during `GameViewController.viewDidLoad` composition/preparation, before presenting the first scene.
- Starts or prepares the shared audio engine before first combat output.
- Owns a fixed bounded pool of player nodes created during preparation.
- Schedules predecoded buffers without creating players, loading files, or decoding on the combat hot path.
- Reuses or steals a bounded voice when the pool is occupied; it never allocates an unbounded voice.
- Fails loudly for missing catalog resources in DEBUG.
- Skips a missing sound safely in release rather than crashing gameplay.

The fixed rate limits and short effects should keep normal playback below pool exhaustion. Voice stealing is a safety bound, not the normal scheduling path.

### Lifecycle and interruption handling

The platform sound output observes app backgrounding and `AVAudioSession.interruptionNotification`.

On background or interruption begin:

- Stop every active player node.
- Clear scheduled transient buffers.
- Mark the engine/session as requiring preparation or reactivation.
- Preserve no pending gameplay event for replay.

On foreground or eligible interruption end:

- Restore output readiness when sound effects remain enabled.
- Do not replay any sound that occurred before or during the interruption.
- Do not emit a synthetic resume sound.

Disabling Sound Effects uses the same stop-and-clear behavior immediately.

## Haptic Output

Keep semantic haptic kinds separate from UIKit generator choices:

```swift
enum GameplayHapticKind: Equatable {
    case lightImpact
    case mediumImpact
    case warning
    case strongSuccess
}
```

Default mapping:

- `lightImpact` -> `UIImpactFeedbackGenerator(style: .light)`.
- `mediumImpact` -> `UIImpactFeedbackGenerator(style: .medium)`.
- `warning` -> `UINotificationFeedbackGenerator` with `.warning`.
- `strongSuccess` -> `UINotificationFeedbackGenerator` with `.success`.

The provider owns and reuses generators, preparing them when appropriate. A provider factory returns no-op output for unit tests and hardware that reports no haptic support. Haptic unavailability or generator failure must never affect gameplay or preference persistence.

## Composition and Dependency Injection

The intended ownership graph is:

```text
GameViewController
├── FeedbackPreferencesManaging
├── GameplayFeedbackProviding
│   ├── GameplaySoundOutput
│   └── GameplayHapticOutput
└── injects the same instances into every scene
```

Scene initializers add injectable dependencies with safe production defaults only if that remains compatible with HPA-364. Tests inject recording/no-op implementations explicitly.

The feedback service and preference manager are not stored in `KingdomGameState` and are not recreated on every scene transition.

## Reusable Settings Components

### `SettingsGearNode`

Add one reusable control with:

- SF Symbol `gearshape.fill` as the shared visual.
- A 44 x 44 point minimum hit frame on every supported layout.
- A visual glyph around 20-22 points, centered in the larger transparent hit target.
- One stable semantic node/action name, such as `feedbackSettingsGear`.
- No label, badge, animation, or scene-specific behavior.

The same node implementation is used in all three scenes.

### `FeedbackSettingsLayout`

Add a CoreGraphics-only pure layout value. Inputs are scene size and safe-area insets. It computes:

- Full-scene dimming backdrop frame.
- Modal panel frame.
- Sound Effects row frame.
- Haptics row frame.
- Toggle hit/visual frames.
- Close frame.

Initial geometry:

| Value | Size |
|---|---:|
| Horizontal panel margin from safe frame | 16 pt minimum |
| Maximum panel width | 320 pt |
| Panel horizontal padding | 20 pt |
| Panel vertical padding | 20 pt |
| Toggle row height | 52 pt |
| Toggle row gap | 12 pt |
| Last row to Close gap | 18 pt |
| Close height | 48 pt |
| Panel corner radius | 14 pt |

The resulting panel height is 222 points. The panel is centered within the safe frame. All interactive row and Close frames are at least 44 points high.

The layout returns `nil` for nonfinite geometry, nonpositive safe dimensions, or a safe frame too small to contain required controls. Every currently supported app fixture must compute successfully.

### `FeedbackSettingsNode`

The reusable node owns a fixed node tree:

- One dimming scrim.
- One panel.
- Two full-row toggle controls with labels and explicit `On`/`Off` state.
- One Close button.

It exposes behavior equivalent to:

```swift
enum FeedbackSettingsAction: Equatable {
    case toggleSoundEffects
    case toggleHaptics
    case close
    case consumed
}

func apply(layout: FeedbackSettingsLayout, preferences: FeedbackPreferences)
func action(at scenePoint: CGPoint) -> FeedbackSettingsAction
```

`action(at:)` returns `.consumed` for every point while the modal is visible that does not hit a toggle or Close. This is the central input-blocking guarantee.

Reapplying layout or preferences updates the existing node tree and does not duplicate rows, labels, hit targets, or controls.

## Scene Integration

### Shared scene behavior

Every scene owns:

- A gear node.
- A settings node.
- `isFeedbackSettingsVisible`.
- The injected preference manager and feedback service.

Open behavior:

1. Reject opening if a higher-priority scene modal or layout gate is active.
2. Read the preference manager's current value.
3. Apply current layout and preferences.
4. Present the settings node.
5. Pause relevant scene-time behavior without persisting gameplay changes.

Toggle behavior:

1. Update the preference through the HPA-364 manager immediately.
2. Reapply the returned/current preference value to the node.
3. Remain on the same modal.

Close behavior:

1. Hide the settings node.
2. Resume scene-time behavior without catch-up.
3. Do not save campaign state, route, or reconstruct the scene.

### Battle

#### Gear placement

Place the 44 x 44 gear hit target in the upper-right corner of the left status panel. The visual glyph remains small and distinct from the panel's existing information action.

Reserve the gear width plus spacing from the left-panel text fit width so gold and soldier counts cannot render beneath it. The gear frame must remain entirely inside the left panel and scene safe content on every supported fixture.

#### Input priority

Battle input order becomes:

1. Layout fit failure or conquest report.
2. Settings modal.
3. Settings gear.
4. Manual soldier-type menu items.
5. Manual type selector, Spawn, World, and Build.
6. Existing gold/city information panel actions.
7. HPA-362 lane deployment, when present.
8. Empty-space dismissal behavior.

The gear name appears before `goldInfo` in the named-node priority list. One touch performs at most one action.

#### Event sources

- A successful manual spawn/deployment emits `manualDeployment` after the soldier is created and recorded.
- Building-produced spawns emit no deployment event.
- A rejected spawn, unavailable type, squad-full action, or blocked navigation request emits `invalidAction` once.
- `CombatFeedbackProjector` derives automatic combat events from `TickResult` before/alongside visual application without depending on animation success.
- Fresh live conquest emits gold reward and then city conquest or country completion.
- Fresh idle conquest resolved by this mounted scene emits the same outcome sequence.
- Restored report presentation remains silent.

When HPA-362 exists:

- A successful fortified-lane direct deployment emits `fortifiedLaneWarning` and `manualDeployment`.
- The default Spawn action targets the standard lane and emits only `manualDeployment`.
- Rejected lane deployment emits only `invalidAction`.

### Country Map

#### Gear placement and layout

Extend `CountryMapLayout` with a `settingsControlFrame` inside the leading side of `titleControlRegionFrame`.

The existing `currentCityControlFrame` remains on the trailing side. Compute an explicit title text frame between:

- The settings control's trailing edge plus spacing.
- The current-city control's leading edge minus spacing when it is visible, or the title panel's trailing inset when it is hidden.

The title text fits and centers within that remaining frame rather than using a hard-coded x offset. Layout validation must prove that settings, title, and current-city frames do not overlap and remain inside horizontal safe content.

#### Input priority

Country Map input order becomes:

1. Layout/map availability gate and routing transaction guard.
2. Settings modal.
3. Settings gear.
4. Scout-card overlay and attack action.
5. Scout-card body consumption.
6. Current-city action.
7. City nodes.

#### Event sources

- Locked, already-completed, or otherwise rejected city entry that presents rejection feedback emits `invalidAction` once.
- Idle progress newly finalized while this scene is mounted emits reward and conquest/completion according to the outcome rules.
- Normal successful city entry emits no feedback event in this ticket.

### Building View

#### Gear placement

Place the settings gear on the leading side of the title panel. Reserve a leading control column and center the title/gold text within the remaining text frame so neither label overlaps the 44 x 44 hit target at compact or standard heights.

#### Input priority

Building View input order becomes:

1. Settings modal.
2. Settings gear.
3. Building palette buttons.
4. Upgrade and Battle actions.
5. Building slots.

This intentionally replaces the current slot-first resolution. A title-panel tap and an action-panel button can never fall through into lot selection.

#### Event sources

- `.built` and `.upgraded` emit `buildingChanged` after saving the successful mutation.
- Insufficient gold, no selection, locked type, occupied lot, type cap, missing building, invalid slot, or unavailable stage emits `invalidAction` once.
- `.cityConqueredDuringSettlement` emits newly awarded reward plus city conquest/country completion and does not emit `buildingChanged` or `invalidAction`.
- `requestBattle` and lifecycle settlement emit outcome feedback when their returned idle result newly conquers a city.

## Modal and Outcome Priority

The priority across Battle overlays is:

1. UIKit app layout gate.
2. Conquest report or report-fit failure.
3. Feedback settings modal.
4. Manual type menu and HUD.
5. Battlefield interaction.

Settings cannot open while the conquest report is visible. If a fresh idle conquest is finalized while settings are visible after a lifecycle transition, close settings before presenting or routing to the outcome flow. No settings close sound or haptic is emitted.

## Failure Handling

- A missing sound asset asserts in DEBUG and becomes silent no-op output in release.
- Audio engine/session preparation failure logs once, disables production sound output for the current readiness cycle, and never blocks gameplay.
- Haptic unavailability uses no-op output.
- Corrupt or missing preferences fall back through the HPA-364 defaults.
- A settings layout failure on geometry that the app otherwise claims to support is a development error and must fail the relevant layout test. Runtime input remains blocked if an already-visible modal cannot be safely reapplied.
- Preference toggling never mutates `KingdomGameState`.
- Output failure never changes model mutations, rewards, routing, or save behavior.

## Test Strategy

### Pure policy tests

Add tests for:

- Every semantic event's SFX and haptic mapping.
- Melee/ranged/siege soldier-type projection.
- Combat tick coalescing.
- Death superseding hit for killed IDs.
- Fixed audible priority.
- Global combat gate plus every category interval.
- Exact boundaries at interval minus epsilon, exactly interval, and interval plus epsilon.
- Suppressed events not updating gates or queuing.
- Muted outputs not consuming their output-specific gates.
- Sound and haptic preferences operating independently.
- Country completion replacing city conquest.
- Fortified warning adding no second haptic.

### Preference and output tests

HPA-364 and HPA-389 together cover:

- Defaults, encoding, corruption fallback, and independent persistence.
- Immediate observer propagation.
- Disabling sound stopping active transient output.
- Enabling sound not replaying muted events.
- No-op haptic output.
- Fixed player-pool construction during preparation rather than per playback.
- Background/interruption stop and no replay.
- Foreground/interruption-end readiness without synthetic output.

### Asset tests

- Every `GameplaySoundID` has exactly one catalog entry.
- Every catalog resource exists in the application bundle.
- Every manifest entry has nonempty source, creator, license, and redistribution fields.
- No bundled sound exists outside the typed catalog without documentation.

### Settings component tests

- `FeedbackSettingsLayout` succeeds for every supported app fixture.
- Panel and all controls remain inside the safe frame.
- Interactive rows and Close are at least 44 points high.
- The node has exactly two toggle controls and one Close action.
- Labels are exactly `Sound Effects`, `Haptics`, `On`/`Off`, and `Close` as applicable.
- Reapplication does not duplicate nodes.
- Outside taps return `.consumed`.
- Toggle state reflects current preferences after immediate updates.

### Battle scene tests

- Gear frame is inside the left status panel and does not overlap fitted status text.
- Gear wins over the panel information action.
- Modal blocks Spawn, manual type, World, Build, info actions, and future lane taps.
- Opening settings pauses combat and battlefield actions.
- Closing clears frame timing so no catch-up tick occurs.
- Manual successful deployment emits one event.
- Auto-spawn emits no deployment feedback.
- Rejected actions emit one rate-limited invalid event.
- Combat projection comes from `TickResult` and is independent of animation suppression.
- Fresh live/idle outcomes emit once; restored reports and redraws are silent.
- Country completion emits no city-conquest event.

### Country Map tests

- Settings, title, and current-city frames remain nonoverlapping across supported fixtures.
- Gear wins before scout/current-city/city hit regions.
- Modal blocks every underlying map action.
- Rejected city entry emits invalid feedback.
- Newly finalized idle outcome emits once.

### Building View tests

- Gear remains inside the title panel and does not overlap title/gold text.
- Gear and action buttons resolve before overlapping lot frames.
- Modal blocks palette, upgrade, Battle, and lot selection.
- Successful build/upgrade emits construction feedback once.
- Every rejected mutation emits invalid feedback once.
- Settlement conquest emits reward plus one outcome and no construction/invalid event.

### GameViewController tests

- Every scene receives the same feedback service and preference manager instances.
- Preference changes survive scene replacement without polling storage per event.
- Feedback output is prepared before first scene combat use.

## Manual Device Smoke

Run on at least one physical iPhone with haptics and one simulator/no-haptic path:

1. First launch into Battle and open settings before any combat sound.
2. Toggle Sound Effects off/on and verify immediate stop/no replay.
3. Toggle Haptics off/on and verify independent behavior.
4. Rapidly deploy manual soldiers.
5. Observe dense mixed-unit combat for continuous-noise prevention.
6. Build and upgrade successfully; exercise insufficient-gold and no-selection rejection.
7. Open settings from Battle, Country Map, and Building View on the smallest supported layout.
8. Verify Battle pauses and resumes without catch-up.
9. Trigger city conquest and final-country completion.
10. Verify restored pending report after relaunch is silent.
11. Verify Ring/Silent mode silences SFX.
12. Verify other app audio continues while Pyxis SFX plays.
13. Background during active sounds and confirm they stop.
14. Exercise an audio interruption and confirm no stale replay.
15. Relaunch and verify both preferences persisted.
16. Confirm first combat output introduces no visible frame stall.

## Acceptance Criteria

- HPA-364 is merged and provides the required semantic, preference, no-op, recording, and monotonic-clock boundaries.
- Every concrete event follows the mapping and precedence in this design.
- Dense combat emits at most one automatic-combat SFX per 150 ms global window and respects every category interval deterministically.
- Automatic combat never emits haptics.
- Auto-spawned soldiers never emit deployment feedback.
- Gear access exists in Battle, Country Map, and Building View with one icon, one semantic action, and a minimum 44 x 44 hit target.
- Gear controls remain inside supported safe layouts and do not overlap primary controls or required text.
- The modal contains exactly two toggles and Close, consumes all underlying input, and uses Close as its only dismissal action.
- Battle gameplay and battlefield actions pause while settings are visible and resume without catch-up.
- Preference changes apply and persist immediately without Close or relaunch.
- Disabling sound stops active transient SFX; re-enabling does not replay stale events.
- No music control or music preference appears.
- Fresh outcomes emit once; restored reports, resize, and redraw are silent.
- Country completion replaces city-conquest feedback and produces one strong haptic.
- Backgrounding and interruption stop transient sounds and never replay them on return.
- Unsupported haptic paths and tests use no-op output.
- Every bundled sound has documented app-distribution-compatible provenance and licensing.
- First combat use has no visible frame stall in simulator/device smoke testing.

## Non-Goals

- Music or adaptive soundtrack systems.
- Voice acting.
- Per-sound volume or mixer controls.
- Downloadable sound packs.
- Gameplay information available only through feedback.
- Rewards for enabling feedback.
- A general pause/settings architecture beyond these two preferences.
- UIKit presentation or a separate settings scene.
- New lane, combat, building, reward, or progression mechanics.
