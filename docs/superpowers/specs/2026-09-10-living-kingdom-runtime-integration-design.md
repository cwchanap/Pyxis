# Living Kingdom Runtime Integration Design

## Status

Planning contract for **HPA-478**. This draft PR is the one HPA-478 implementation PR: planning and runtime implementation stay on the same branch/PR.

Planning baseline: `main` at `10036a88911aa055a406035154dd9e181f474701`, after HPA-479 / PR #41 landed the fixed Living Kingdom production assets and CI asset checks.

HPA-479's tracked contract is `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md` plus the landed `lk-*` asset catalog entries/tests. `docs/visual-parity/living-kingdom/**` remains local-only/gitignored acceptance evidence.

## Goal

Make Country 1 visibly evolve without changing the prepare → deploy → watch → conquer mechanics:

1. fortress art follows real city HP;
2. Ember/Arcane/Royal cities use their approved identities;
3. conquered map territory gains secured decoration, one repaired crossing, and light caravan motion;
4. offline return shows truthful positive damage or the existing pending conquest report.

This is presentation integration plus one intentional journey correction; it does not add a gameplay system.

## Core architecture

Keep the design concrete:

- `Country1CityCatalog` remains the single authored source of Country 1 city identity.
- `LivingKingdomPresentation` is one pure derived projection for HP stage, asset names, FX metadata/selection, and map decoration.
- `BattleScene`, `CountryMapScene`, and `BuildingViewScene` remain scene-local runtime owners.
- `GameViewController.presentSceneForCurrentStage(in:preferredTab:)` remains the only pending/stage router.
- no persisted visual stage, caravan state, VFX manager, runtime manifest, content registry, replay system, or second settlement owner.

## Authored visual family

A city visual family is authored identity, not a runtime presentation guess. Add a framework-free enum alongside `CityDefinition`:

```swift
enum CityVisualFamily: String, CaseIterable, Equatable {
    case frontier
    case ember
    case arcane
    case royal
}
```

Add `visualFamily: CityVisualFamily` to `CityDefinition`, then author the 15 values in `Country1CityCatalog.definitions`:

| Family | Cities |
| --- | --- |
| Frontier | 1–6, 8, 10, 11, 14 |
| Ember | 7 Emberford, 12 Ashbridge |
| Arcane | 9 Runewatch, 13 Starveil Citadel |
| Royal | 15 Crownspire Keep |

City 11 remains Frontier even though it shares `.reinforcedKeep` with City 15. Never derive the visual family from `CityDefenseTrait`.

`LivingKingdomPresentation` reads `Country1CityCatalog.definition(for: cityNumber).visualFamily`; it does not duplicate this table.

## Pure Living Kingdom projection

`LivingKingdomPresentation` owns only deterministic derived values:

```swift
enum LivingKingdomPresentation {
    enum FortressStage: String, CaseIterable, Equatable {
        case intact, damaged, breached, conquered
    }

    enum TransitionEffect: Equatable {
        case breach, collapse

        var frameNames: [String] { ... }
        var secondsPerFrame: TimeInterval { ... }
    }

    struct Battle: Equatable {
        let family: CityVisualFamily
        let stage: FortressStage

        var fortressAssetName: String { ... }
        var battlefieldTreatmentAssetName: String? { ... }
    }

    struct Map: Equatable {
        let securedCityNumbers: [Int]
        let caravanSegmentStartCityNumbers: [Int]
        let routeSixToSevenAssetName: String
    }
}
```

### Exact HP stage math

Use integer comparisons against `max(1, maxHP)` so real city maxima do not drift at 60%/25% boundaries:

```text
pending result or remaining <= 0 -> conquered
remaining * 5 > maximum * 3      -> intact
remaining * 4 > maximum          -> damaged
otherwise                         -> breached
```

This produces the required `>60%`, `>25%...60%`, `>0%...25%`, `0/pending` policy without floating-point rounding. Tests use real `KingdomGameState.cityMaxPower(for:)` values, including City 1 = 20 and City 3 = 92.

### Transition contract

Only a newly observed **live combat mutation** selects a Living Kingdom effect:

- new stage `.breached` → `.breach`;
- new stage `.conquered` → `.collapse`;
- all other transitions → none.

Skipped stages do not queue intermediate effects. `.breach` owns `lk-fx-breach-01...06` at `0.05 s/frame`; `.collapse` owns `lk-fx-collapse-01...06` at `0.07 s/frame`. These names/timings live on `TransitionEffect`, not as BattleScene magic strings.

Restore, relaunch, foreground reconstruction, and resize only apply the static final texture.

## Battle integration

### Keep one semantic fortress node

`BattleScene` keeps the existing `enemyCityNode` and semantic node name exactly `enemy-city`. All 16 HPA-479 fortress assets use the same 512×540 canvas, so changing `SKSpriteNode.texture` is safe without rebuilding/replacing the node or changing its `size`. Existing `fitBattleNode`, HP-bar measurement, milestone accents, hit/conquest colorize actions, Settings pause, and test lookups continue to target the same node.

The projected asset name is exposed only through DEBUG readback when tests need it.

### Battlefield treatment

Add one optional treatment sprite at:

```text
backdrop                 GameUITheme.Z.background
Living Kingdom treatment GameUITheme.Z.background + 0.5
Forged atmosphere        GameUITheme.Z.background + 1
```

Frontier hides it; Ember/Arcane/Royal use their `lk-battlefield-*` texture. Reuse the backdrop position/aspect-fill transform.

### Transition FX belongs in `effectsLayer`

Do not parent breach/collapse FX under the colorized fortress. `BattleScene` already owns one-shot visual effects in `effectsLayer`, and that layer is already below `battlefieldActionLayer`, so Settings pauses it automatically.

For a selected transition:

- remove an existing `livingKingdomTransitionFX` from `effectsLayer`;
- create the selected six-frame sprite there;
- anchor `(0.5, 0)`;
- position at the current `enemyCityNode.position`, the fortress bottom-center;
- compute the displayed fortress canvas height from the current sprite (`sprite.size.height * abs(sprite.yScale)`), then size FX to `512 * displayedFortressHeight / 540` square;
- play `TransitionEffect.frameNames` using its `secondsPerFrame` and remove the node.

If layout changes while the short FX is active, update its position/size to the newly laid-out fortress; do not restart or append playback. `redraw(shouldLayout:false)` and texture swaps never create an effect.

With Reduce Motion enabled, the static fortress stage still updates but optional breach/collapse frame playback is skipped.

## Living conquered map

`LivingKingdomPresentation.map(completedCityCount:)` clamps completion to `0...15` and derives:

```text
secured cities             = 1...completed
eligible primary segments  = n -> n+1 where both endpoints are completed
visible caravan segments   = first two eligible starts
6->7 patch                 = worn before City 7 completion; repaired at completed >= 7
```

This is valid because Country 1 primary routes are already the fixed `1→2→...→15` chain.

`CountryMapScene` adds one `livingKingdomLayer` between `routeLayer` and `cityLayer`. All children are unnamed/noninteractive with respect to `countryMapCity-*` hit lookup.

- secured overlay: `lk-map-secured-city`, `96×96` canonical pixels scaled by `displayedBackdropFrame.width / 1024`;
- crossing: one `lk-map-route-6-7-{worn|repaired}` at runtime City 6/7 midpoint, `192×192 * mapScale`;
- caravans: at most two `lk-map-caravan`, `128×64 * mapScale`, oriented from runtime `n` to `n+1`.

A tiny `(completedCityCount, displayedBackdropFrame)` render key prevents ordinary selection/transient redraws from restarting caravan actions.

With Reduce Motion enabled, eligible caravan sprites remain static at their segment starts; do not run `repeatForever` movement. Without Reduce Motion, use one deterministic repeated move with an optional fixed stagger. No random speeds, pathfinding, economy, collision, collection, or persisted caravan position.

## Offline-return presentation

The model remains the only settlement/reward authority. Every scene keeps its existing `returnFromBackground(at:)` call sites.

### Positive non-conquest damage

Show:

```text
Buildings dealt <CompactNumberFormatter value> idle damage.
```

Map uses a new `.idleSummary` `CountryMapTransientFeedback.Kind`. `.idleSummary` is nonblocking like `.flavor` but semantically distinct. It never displays gold or a claim action.

### Zero progress means silent, not stale

A genuine return with credited elapsed time but zero damage clears stale transient result text rather than showing `No building damage while away.` or preserving an old action message:

- Battle: clear `feedbackText` to `""`;
- Camp: reset `feedbackText` to the existing hidden sentinel `"Select a city lot."`;
- Map: clear/no idle transient (`nil`).

A zero-elapsed no-op may leave the current scene untouched because no return was actually resolved.

### Governing conquest journey rule

Use one rule instead of independent exceptions:

> **Conquest that happens while the player was not looking routes to the pending report. Conquest caused by a deliberate in-place Camp action stays in place.**

Concretely:

- Battle foreground idle conquest: existing pending report behavior stays.
- Map foreground idle conquest: save + emit outcome once, then request existing `.battle` route.
- Map current-city RETURN/Attack settlement that becomes conquest: same pending-report route.
- Map/Camp layout-gate pause: may settle and create pending state, but never route reentrantly; gate resume may route once.
- Camp foreground/gate-resume idle conquest: route to the pending report.
- Camp `buildSelectedSlot` / `upgradeSelectedSlot` conquest: do **not** auto-route. Save/emit once and show the short pointer `City conquered. Open Battle for the report.`. The later explicit Battle/tab request hits the existing pending-first router.

The pending `BattleResult` report remains the only detailed conquest acknowledgment and the only Continue action. No reward is awarded again by presentation.

## Repository documentation supersession

HPA-478 intentionally changes historical journey wording. The implementation PR must update the docs of record in the same Task 5 commit:

- `CLAUDE.md` Building View/lifecycle guidance;
- `docs/superpowers/specs/2026-08-01-gameplay-sound-haptics-settings-design.md`;
- `docs/superpowers/specs/2026-07-30-compact-conquest-report-design.md`.

The older specs should get a concise “superseded by HPA-478 for idle foreground/gate-resume routing” note rather than broad rewrites. Keep the governing rule above explicit in `CLAUDE.md`.

## Scout card scope

`CountryMapScoutCardNode` keeps its generic `enemy-city` thumbnail. Landmark-family visual acceptance is Battle-focused. Do not introduce a second visual-family consumer merely for this ticket.

## Risks and controls

1. **Journey inversion:** current Map tests/docs explicitly encode no auto-route. Rewrite the named expectations first, then production routing.
2. **Layout-gate reentrancy:** never route during `layoutGateWillPause`; pending state is the deferral signal and resume is the routing seam.
3. **Threshold rounding:** integer comparisons plus real City 1/City 3 maxima lock exact boundaries.
4. **Perpetual motion:** caravans honor Reduce Motion; optional one-shot destruction FX also skip when Reduce Motion is enabled.
5. **Scene-consumer regressions:** focused gates include test suites that actually instantiate the modified scene, not only the scene's primary unit suite.
6. **Visual evidence drift:** tracked HPA-479 art spec + landed assets/tests are authoritative; local screenshots/clips are evidence only.

## Testing and acceptance

Pure tests cover catalog family values, exact HP boundaries, all generated fortress/treatment/FX names, FX timing/selection, map clamping, max-two caravan policy, and 6→7 repair cutoff.

Scene tests cover stable `enemy-city` identity, texture/treatment state, live-only FX requests, effects-layer placement/replace behavior, no replay on resize/static redraw, Reduce Motion, map hit-target preservation, idle summary semantics, zero-return clearing, routing deferral, and Camp build/upgrade stay-in-place behavior.

Focused commands must include actual consumers:

- Battle changes: `BattleSceneTests`, `BattleSceneCoverageTests`, `GameViewControllerTests`, `SoldierRuntimeGeometryTests`.
- Map changes: `CountryMapSceneTests`, `CountryMapScoutCardAcceptanceTests`, and `GameViewControllerTests` where routing is involved.
- `CountryMapScoutCardNodeTests` is not added solely for Map scene changes because it constructs the node directly and that node remains unchanged.

DEBUG fixtures add only missing damaged/breached/landmark/return states. The fixed-time return fixture explicitly defines `ForgedVisualFixture.foregroundReturnDate` and calls the existing `BattleScene.enterForegroundForTesting(at:)` seam.

Final evidence stays at 393×852 plus compact-phone/portrait-iPad smoke and a short clip showing live threshold FX, eligible caravan behavior, and offline return. Existing 90% project/patch Codecov gates remain unchanged.

## Out of scope

No new art generation, save/schema migration, combat/economy balance, route topology, Country 2, Scout redesign, runtime asset manifest, generic VFX/content service, replay system, telemetry, new report/claim flow, or production `GameViewController` routing change.
