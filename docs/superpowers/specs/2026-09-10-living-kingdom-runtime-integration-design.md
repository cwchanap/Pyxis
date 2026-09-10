# Living Kingdom Runtime Integration Design

## Status

Planning contract for **HPA-478**. This draft PR is the one HPA-478 implementation PR: it starts with the design and implementation plan, then implementation commits land on the same branch. Do not open a second runtime PR for this ticket.

Planning baseline: `main` at `10036a88911aa055a406035154dd9e181f474701`, after HPA-479 / PR #41 landed the Living Kingdom production asset pack and its CI asset checks.

HPA-479's tracked source of truth is `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md` plus the installed `lk-*` asset catalog entries and their tests. `docs/visual-parity/living-kingdom/**` is intentionally local-only/gitignored after PR #41; HPA-478 may regenerate local capture evidence there, but must not add a runtime manifest or commit the large visual-parity image set.

## Goal

Make Country 1 visibly evolve while preserving the current prepare → deploy → watch → conquer game loop:

1. show the current fortress damage state during battle;
2. give Emberford/Runewatch/Crownspire their approved visual families;
3. make conquered territory on the map feel occupied and repaired;
4. make offline return reveal the real result, with the existing conquest report remaining the single conquest acknowledgment.

This is a presentation integration. It does not add a gameplay system.

## Current code survey

The existing runtime already owns the hard parts that HPA-478 should reuse:

- `KingdomGameState` owns city HP, max HP, completion state, idle settlement, rewards, and `pendingBattleResult`.
- `BattleScene` already owns the enemy-city node, battlefield backdrop/atmosphere ordering, combat damage application, live hit/conquest feedback, idle foreground settlement, and pending conquest report.
- `CountryMapScene` already owns canonical map layout, routes, city positions/hit targets, completed/unlocked/locked appearance, transient Scout-card feedback, idle settlement, and routing.
- `BuildingViewScene` already owns Camp idle settlement and transient feedback text.
- `GameViewController.presentSceneForCurrentStage(in:preferredTab:)` is already pending-first: when `pendingBattleResult != nil`, any existing Map/Camp routing request lands in `BattleScene` and presents the report.
- `ForgedVisualFixture` already provides deterministic Battle/Map/Camp/conquest states, including `map-partial` from HPA-479.

Important existing behavior to preserve:

- Battle foreground return already uses `CompactNumberFormatter` for positive idle damage and presents the existing report for idle conquest.
- Map currently turns idle results into a blocking `CountryMapTransientFeedback.status` message.
- Camp currently shows inline idle result text and can remain on Camp after an idle conquest.
- Map/Camp layout-gate pause paths may settle idle progress, so a pending conquest can be created while a geometry gate is active.

## Design choice

Use **one small pure presentation projection plus scene-local rendering**.

Rejected alternatives:

1. **Generic Living Kingdom/VFX/content service.** Rejected because there is one country, four fixed art families, two fixed transition sequences, and one fixed repaired route. A registry/manifest/service adds indirection without a second consumer.
2. **Duplicate HP/theme/map rules directly inside scenes.** Rejected because exact 60%/25% thresholds and City 11's Frontier exception are easy to drift. One pure projection is cheaper to test and maintain.
3. **Persist visual stages/caravan state.** Rejected because every visual result is derivable from existing save data; persistence would create migration and replay bugs for no player-facing value.

## New production abstraction

Create `Pyxis/LivingKingdomPresentation.swift` as a pure, Foundation/CoreGraphics-free presentation projection.

```swift
enum LivingKingdomPresentation {
    enum FortressFamily: String, CaseIterable, Equatable {
        case frontier
        case ember
        case arcane
        case royal
    }

    enum FortressStage: String, CaseIterable, Equatable {
        case intact
        case damaged
        case breached
        case conquered
    }

    enum TransitionEffect: Equatable {
        case breach
        case collapse
    }

    struct Battle: Equatable {
        let family: FortressFamily
        let stage: FortressStage

        var fortressAssetName: String {
            "lk-city-\(family.rawValue)-\(stage.rawValue)"
        }

        var battlefieldTreatmentAssetName: String? {
            family == .frontier ? nil : "lk-battlefield-\(family.rawValue)"
        }
    }

    struct Map: Equatable {
        let securedCityNumbers: [Int]
        let caravanSegmentStartCityNumbers: [Int]
        let routeSixToSevenAssetName: String
    }
}
```

The exact implementation may keep computed properties/functions on the namespace rather than create additional structs if that is smaller, but it must keep the rules pure and independently testable. Do not create protocols, dependency injection, a manifest parser, or a generic scene-decoration model.

## Battle projection

### Fortress stage

Use current city remaining HP divided by that city's existing maximum HP. `pendingBattleResult != nil` or remaining HP `<= 0` always projects `.conquered`.

| Remaining HP | Stage |
| --- | --- |
| `> 60%` | `.intact` |
| `> 25% ... 60%` | `.damaged` |
| `> 0% ... 25%` | `.breached` |
| `0` / pending conquest | `.conquered` |

Boundary behavior is exact: 60% is damaged; 25% is breached.

No stage is written to a save. A scene created at 24% HP immediately shows breached art without replaying breach FX.

### Fortress family

Family is fixed by Country 1 city number and never inferred from defense traits:

| Family | Cities |
| --- | --- |
| Frontier | 1–6, 8, 10, 11, 14 |
| Ember | 7, 12 |
| Arcane | 9, 13 |
| Royal | 15 |

City 11 remains Frontier even though it shares a reinforced-keep gameplay identity with City 15.

### Transition selection

Transitions are selected from the old projected stage and the new projected stage only for a **live combat mutation**:

```text
new stage == breached  -> breach FX
new stage == conquered -> collapse FX
otherwise               -> no Living Kingdom FX
```

A skipped-stage hit does not queue intermediate effects. Examples:

- intact → breached: play breach only;
- intact → conquered: play collapse only;
- damaged → conquered: play collapse only;
- breached → conquered: play collapse only;
- intact → damaged: no special FX.

This selector stays pure so skipped-stage behavior is unit-tested without a SpriteKit timing harness.

## BattleScene integration

### Static fortress and theme

`BattleScene.buildBattlefield()` should create the enemy fortress from the current `LivingKingdomPresentation.Battle` instead of `enemy-city`. Preserve the existing bottom-center anchor and `fitBattleNode` layout path; HPA-479 deliberately authored every fortress against that contract.

Add one optional battlefield-treatment sprite. For Ember/Arcane/Royal it uses the projected `lk-battlefield-*` asset; Frontier hides/removes the treatment. Its ordering is fixed by the HPA-479 contract:

```text
battlefield backdrop       GameUITheme.Z.background
Living Kingdom treatment   GameUITheme.Z.background + 0.5
Forged atmosphere          GameUITheme.Z.background + 1
lane terrain               -1 within environment content
```

The treatment mirrors the existing `battlefieldBackdropNode` position and aspect-fill scale. Do not create another backdrop-layout abstraction just for this node.

`redraw()`/layout refresh always reapplies the static projected fortress texture and treatment. That makes scene entry, resize, restored pending reports, and foreground restore immediately correct without any historical animation.

### Live breach/collapse FX

In `applyCombatResult(_:)`, project the old battle stage immediately before `state.applyLiveSoldierAttacks(...)`, apply the existing state mutation, then project the new stage. After the existing save/redraw path applies the terminal static texture, play at most one effect selected by the pure transition selector.

Use the HPA-479 sequences exactly:

- `lk-fx-breach-01...06`, `0.05 s/frame`;
- `lk-fx-collapse-01...06`, `0.07 s/frame`.

The simplest correct placement is a temporary child sprite of the enemy fortress:

- anchor `(0.5, 0)`;
- local position `.zero`;
- source size `512×512`;
- inherits the fortress's `512×540`-canvas scale, automatically satisfying the required `512 × enemyCityDisplayHeight / 540` display height;
- inherits city shake and Settings pause behavior;
- removes itself when the six-frame action completes.

Use one fixed action/node key so duplicate playback replaces rather than stacks. If Reduce Motion is enabled, keep the static stage change and skip the extra frame animation.

Do not delay saving, the conquest report, Continue, or routing while FX plays.

### Conquest report

The report remains unchanged as the one conquest acknowledgment. Because `BattleScene.didMove`, live conquest, and idle conquest already call `redraw()` before/around report presentation, the new static projection makes `.conquered` fortress art visible underneath the existing report for both fresh and restored results.

Do not add reward logic or another Continue action.

## Living map projection

The map projection derives only from `completedCityCount`, clamped to `0...15`.

```text
secured cities: 1...completedCityCount
eligible caravan segments: primary routes whose start/end cities are both secured
visible caravans: first two eligible segments in authored primary-route order
6→7 patch: worn while completedCityCount < 7, repaired once completedCityCount >= 7
```

The primary route is already the fixed 1→2→...→15 chain, so the projection can return only each caravan segment's start city number. `CountryMapScene` can obtain runtime endpoints from `layout.cityPositions[start]` and `[start + 1]`; there is no need to add endpoint metadata to `CountryMapRouteLayout`.

No caravan state is persisted. Relaunch may restart a decorative caravan at its route start; this is acceptable because it has no gameplay meaning.

## CountryMapScene integration

Add a single `livingKingdomLayer` between the existing route and city layers. All children are noninteractive.

### Secured city overlays

For every projected secured city, render `lk-map-secured-city` centered at the existing runtime city position and behind the current circle/number/conquered marker.

Size from HPA-479's canonical contract:

```swift
let mapScale = layout.displayedBackdropFrame.width / 1024
secured.size = CGSize(width: 96 * mapScale, height: 96 * mapScale)
```

Do not replace or rename existing hit targets.

### 6→7 route patch

Render exactly one of `lk-map-route-6-7-worn` or `lk-map-route-6-7-repaired` at the midpoint between runtime City 6 and City 7 positions. Size is `192×192 * mapScale`. The asset is already authored in the canonical map orientation, so placement/scaling is enough; do not add a repair animation or route mutation.

### Caravans

Render at most two `lk-map-caravan` sprites using projected eligible route starts:

- size `128×64 * mapScale`;
- start/end from existing city positions;
- rotate the +X-facing sprite with `atan2(end.y - start.y, end.x - start.x)`;
- use a fixed-duration `SKAction.move(to:duration:)` and repeat forever;
- a short deterministic stagger between the two is allowed;
- no randomization, speed economy, collision, income, pathfinding, or off-map branch travel.

Avoid restarting the actions on ordinary Scout-card/city-selection redraws. A tiny private render key containing the completed-city count plus displayed-backdrop frame is sufficient; rebuild decoration only when progress or layout changes. Reset the key when layout geometry is cleared.

## Offline return behavior

### Shared rules

Every scene keeps calling the existing `KingdomGameState.returnFromBackground(at:)` owner exactly where it already does. HPA-478 does not add a timer, settlement coordinator, save wrapper, or new result model.

Positive non-conquest result:

- require `elapsedSeconds > 0` and `damageDealt > 0`;
- display `Buildings dealt <formatted> idle damage.` using `CompactNumberFormatter`;
- do not display gold when no gold was awarded;
- do not add a claim/Continue action;
- do not invent elapsed-time text just because `elapsedSeconds` is available.

Zero-damage result:

- do not synthesize a success/reward reveal;
- leave the scene's prior/default feedback state alone rather than displaying a new "reward" message.

Idle conquest:

- existing model mutation/reward/save remains authoritative;
- emit the existing fresh conquest/gold feedback once;
- route to `BattleScene` through the scene's existing routing protocol;
- `GameViewController.presentSceneForCurrentStage` sees `pendingBattleResult` and therefore presents Battle regardless of the requested preferred tab;
- Battle shows the existing pending conquest report over `.conquered` fortress art;
- no second reward or report is generated.

Restored pending result:

- `BattleScene` continues to project only fields retained in `BattleResult`;
- no new duration/history field is persisted;
- restored presentation does not replay breach/collapse, gold burst, or fresh outcome feedback.

### Map transient feedback

`CountryMapTransientFeedback.idle` should become positive-nonconquest-only and nonblocking. Add a semantic kind such as `.idleSummary` whose `blocksScoutEntry` is `false`, alongside `.flavor`.

It returns nil for conquest (because the pending report owns that outcome) and zero damage (because there is no return reveal to show). It formats damage through `CompactNumberFormatter`.

Do not reuse `.flavor` for this result just to avoid one enum case; Scout flavor and an offline result are different semantics even though both are nonblocking.

### Map routing cases

Use the existing `CountryMapSceneRouting.countryMapSceneDidRequestGameplayTab` path; do not add a protocol method.

- foreground idle conquest: save/emit/redraw, then request `.battle`;
- current-city `requestEntry` that settles into conquest: request `.battle` instead of remaining on Map;
- normal tab request already routes after settlement and therefore naturally hits the pending-first controller path;
- layout-gate pause must not re-enter scene routing while the controller is applying the gate; if it creates a pending result, route on `layoutGateWillResume` after geometry is usable again.

### Camp routing cases

Use the existing `BuildingViewSceneRouting.buildingViewSceneDidRequestGameplayTab` path; do not add a protocol method.

- foreground idle conquest: save/emit/redraw, then request `.battle`;
- build/upgrade returning `.cityConqueredDuringSettlement`: save/emit, then request `.battle`;
- normal tab request already routes after settlement and naturally hits the pending-first controller path;
- layout-gate pause follows the same defer-until-resume rule as Map.

Camp positive damage uses the same formatted copy as Battle/Map. Zero damage creates no new return message.

## DEBUG capture strategy

Reuse `ForgedVisualFixture`; do not add a snapshot framework.

Existing cases already cover:

- Frontier intact Battle: `battle`;
- Frontier conquered/pending report: `conquest-live` / `conquest-idle`;
- Map early/partial/complete: `map`, `map-partial`, `map-country-complete`.

Add only the missing deterministic visual states:

- `battle-damaged` — Frontier at exactly/inside damaged range;
- `battle-breached` — Frontier in breached range;
- `battle-emberford` — City 7 intact;
- `battle-runewatch` — City 9 intact;
- `battle-crownspire` — City 15 intact;
- `return-damage` — fixed-time Battle foreground-return fixture producing positive non-conquest damage.

For `return-damage`, reuse the existing `sceneWillEnterForegroundForTesting(at:)` seam after presenting the fixture state. Do not add a production launch mode or new clock service.

Update the fixture's accessibility probe with the minimum semantic fields needed to prove family/stage/map decoration/idle summary selection. Do not encode animation frame-by-frame output into accessibility text.

Generated 393×852 captures and short clips remain local under ignored `docs/visual-parity/living-kingdom/`. Before merge, attach or link the final evidence in the PR conversation rather than force binary evidence into git.

## Testing strategy

### Pure projection tests

Create `PyxisTests/LivingKingdomPresentationTests.swift` and cover:

- 61/60/26/25/1/0 percent boundaries;
- pending result forcing conquered;
- all 15 exact city-family mappings, especially City 11;
- exact fortress/treatment asset names;
- skipped-stage transition effect selection;
- completed-city clamping;
- zero/one/two/many completed-city caravan eligibility;
- at-most-two caravan invariant;
- worn → repaired 6→7 threshold at completed City 7.

### Scene integration tests

Add focused tests beside the current scene suites rather than a broad new framework:

- Battle static texture/treatment follows state and survives layout refresh without effect replay;
- a live transition into breached/conquered creates only the selected FX sequence;
- restored pending report uses conquered art with zero Living Kingdom transition playback;
- Map decoration counts/asset names/positions derive from existing layout and do not change city hit targets;
- Map idle summary is formatted and nonblocking;
- Map/Camp idle conquest requests existing Battle routing exactly once;
- Map/Camp zero idle result does not create a new return reveal;
- build/upgrade settlement conquest routes to the pending report without double reward;
- current save/economy/8-hour cap/1/10 idle rate tests remain unchanged and green.

Keep the existing 90% project/patch coverage gates. Add focused coverage for new branches; do not lower thresholds or add exclusions.

## Expected production file map

Create:

- `Pyxis/LivingKingdomPresentation.swift`
- `PyxisTests/LivingKingdomPresentationTests.swift`

Modify:

- `Pyxis/BattleScene.swift`
- `Pyxis/CountryMapScene.swift`
- `Pyxis/CountryMapTransientFeedback.swift`
- `Pyxis/BuildingViewScene.swift`
- `Pyxis/ForgedVisualFixture.swift` (DEBUG only)
- existing Battle/Map/Camp/fixture test files as needed
- `PyxisUITests/PyxisUITests.swift` only for the new deterministic capture cases/semantics

Expected **no change**:

- `KingdomGameState.swift`
- `BattleCombatState.swift`
- `GameViewController.swift`
- `CountryMapLayout.swift`
- `CountryMapLayoutDefinition.swift`
- persistence/schema code
- economy/balance data
- HPA-479 `lk-*` production PNGs
- `project.pbxproj`
- CI/Codecov configuration

If implementation proves one of these expected-no-change files truly must change, document why in the PR before expanding scope; do not silently refactor around the feature.

## Out of scope

- wall/gate HP or destructible physics;
- gameplay fire/wards/shields;
- map income, collection, rebuild timers, caravan simulation, pathfinding, or inspection;
- new currencies/resources;
- new save fields or migrations;
- new battle replay/history;
- new report/claim flow;
- generic VFX manager, asset manifest, content plugin system, service locator, or DI layer;
- Country 2, prestige, campaigns, or HPA-360's evidence-gated Rally/direct-lane/Chronicle experiments;
- new image/animation generation or correction. Asset defects go back to HPA-479/art scope rather than being painted around in runtime code.

## Done definition

HPA-478 is done when one implementation PR proves all of the following:

1. all four HP states render the correct HPA-479 fortress family without persisted presentation state;
2. Cities 7/9/15 show Ember/Arcane/Royal identity while all other mappings, including City 11, remain exact;
3. live breach/collapse effects play only on newly observed live transitions, skipped stages play only the final relevant effect, and restore/resize/relaunch never replays them;
4. the conquered map derives secured decoration, the fixed 6→7 repair, and no more than two noninteractive caravans from existing completion state;
5. positive idle return shows compact formatted damage without blocking gameplay; zero damage produces no fabricated reward reveal;
6. idle conquest from Battle/Map/Camp reaches the existing pending report over conquered art with one Continue and no duplicate gold/reward;
7. existing navigation restrictions, three lanes, hit targets, milestone Cities 5/10/15, Camp, Settings, economy, idle cap/rate, saves, and routing semantics remain intact;
8. deterministic fixtures cover the missing visual matrix, local 393×852 captures and a short live FX/caravan/return clip are reviewed, and a supported compact phone plus portrait iPad smoke without clipping or hit-target regressions;
9. unit/UI tests, SwiftLint, Debug/Release builds, CI, and unchanged 90% coverage gates pass;
10. the PR contains no new art authoring, generic framework, schema, or second-ticket/second-PR scope drift.
