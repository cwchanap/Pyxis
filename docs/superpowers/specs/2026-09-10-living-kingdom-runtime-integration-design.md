# Living Kingdom Runtime Integration Design

## Status

Planning contract for **HPA-478**. This draft PR is the one HPA-478 implementation PR: planning and runtime implementation stay on the same branch/PR.

Planning baseline: `main` at `10036a88911aa055a406035154dd9e181f474701`, after HPA-479 / PR #41 landed the Living Kingdom production asset pack and CI asset checks.

HPA-479's tracked source of truth is `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md` plus the installed `lk-*` asset catalog entries/tests. `docs/visual-parity/living-kingdom/**` is intentionally local-only/gitignored; HPA-478 may regenerate local evidence there but does not add a runtime manifest or commit the large capture set.

## Goal

Make Country 1 visibly evolve without changing the prepare → deploy → watch → conquer mechanics:

1. show fortress damage state during battle;
2. give Emberford, Runewatch, and Crownspire their approved visual families;
3. make conquered territory on the map feel occupied/repaired;
4. show truthful offline-return outcomes, with the existing pending conquest report remaining the single conquest acknowledgment.

This is presentation integration, not a new gameplay system.

## Review resolution

The latest review was checked against current `main` before changing this contract.

Adopted:

- explicitly supersede the historical Country Map rule that fresh idle conquest stays on Map;
- **do not** auto-route Camp build/upgrade settlement conquest — Building View still stays until the player explicitly chooses Battle;
- keep the enemy fortress node semantic name `enemy-city`; only its texture changes;
- put Living Kingdom FX frame names/timings on `TransitionEffect` instead of hard-coding them in `BattleScene`;
- use integer ratio comparisons for the 60%/25% boundaries and test real `cityMaxPower(for:)` values;
- add explicit journey/FX/layout risks and name the legacy tests whose expectations must change;
- keep the Scout thumbnail generic `enemy-city` in this ticket to avoid a second presentation call site.

No extra PR, router service, VFX manager, save field, map route model, or Scout redesign is added.

## Existing ownership to reuse

- `KingdomGameState` owns city HP/max HP, progression, idle settlement, rewards, and `pendingBattleResult`.
- `BattleScene` owns live combat/rendering, enemy-city node, city hit/conquest feedback, idle foreground settlement, and pending conquest report.
- `CountryMapScene` owns map layout/routes/city hit targets, transient Scout-card feedback, idle settlement, and Map routing.
- `BuildingViewScene` owns Camp settlement, build/upgrade actions, feedback text, and Camp routing.
- `GameViewController.presentSceneForCurrentStage(in:preferredTab:)` is pending-first: once `pendingBattleResult != nil`, any accepted scene routing request presents `BattleScene` regardless of preferred tab.
- `ForgedVisualFixture` already provides deterministic Battle/Map/Camp/conquest states, including HPA-479's `map-partial` fixture.

## Architecture

Use **one pure `LivingKingdomPresentation` projection plus scene-local rendering**.

Rejected alternatives:

- generic Living Kingdom/VFX/content service — one country, four fixed families, two fixed FX sequences, one fixed repaired route;
- persisted visual stages/caravans — all state is derivable from existing save data;
- route metadata added to `CountryMapLayout` — Country 1 primary routes are already the fixed `1→2→...→15` chain;
- new routing protocol/service — existing scene routing plus pending-first controller behavior is sufficient;
- Scout thumbnail family integration — useful later, but not required to satisfy the Battle-focused landmark showcase and would widen this task.

## Pure presentation contract

Create `Pyxis/LivingKingdomPresentation.swift`.

```swift
enum LivingKingdomPresentation {
    enum FortressFamily: String, CaseIterable, Equatable {
        case frontier, ember, arcane, royal
    }

    enum FortressStage: String, CaseIterable, Equatable {
        case intact, damaged, breached, conquered
    }

    enum TransitionEffect: Equatable {
        case breach
        case collapse

        var frameNames: [String] { /* six HPA-479 names */ }
        var secondsPerFrame: Double { /* 0.05 or 0.07 */ }
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

No protocol, dependency injection, manifest parser, content registry, or scene-independent renderer.

## Fortress stage math

Do not convert HP to a floating percentage. Use exact integer ratio comparisons after `maxHP = max(1, maxHP)`:

```text
remaining <= 0 or pending result -> conquered
remaining * 5 > maxHP * 3       -> intact      (>60%)
remaining * 4 > maxHP           -> damaged     (>25%...60%)
otherwise                        -> breached    (>0%...25%)
```

Country 1 maxima are small enough that these products are comfortably inside `Int` range. This avoids rounding drift for real city maxima such as City 3's 92 HP.

Boundary examples:

- City 1 max 20: 13 intact, 12 damaged, 6 damaged, 5 breached;
- City 3 max 92: 56 intact, 55 damaged, 24 damaged, 23 breached.

A pending result always forces `.conquered` even if a malformed caller supplies positive remaining HP.

## Fortress family

Family is fixed by city number, never `CityDefenseTrait`:

| Family | Cities |
| --- | --- |
| Frontier | 1–6, 8, 10, **11**, 14 |
| Ember | 7, 12 |
| Arcane | 9, 13 |
| Royal | 15 |

City 11 intentionally remains Frontier although it shares `.reinforcedKeep` gameplay identity with City 15.

## Transition effect contract

`TransitionEffect` owns the HPA-479 playback contract:

- `.breach`: `lk-fx-breach-01...06`, `0.05` seconds/frame;
- `.collapse`: `lk-fx-collapse-01...06`, `0.07` seconds/frame.

Selection is based only on a newly observed **live mutation** old→new stage:

```text
new stage == breached  -> breach
new stage == conquered -> collapse
otherwise               -> none
```

Skipped stages do not queue history. `intact→conquered` plays collapse only. Restore, resize, relaunch, or foreground static reapplication never calls this selector as a playback trigger.

## BattleScene integration

### Semantic node identity

Keep the existing enemy fortress node name permanently:

```swift
enemyCityNode.name = BattleAssetName.enemyCity // "enemy-city"
```

The node name is semantic and already used by tests/debugging. HP-stage changes update the sprite texture, never the node name. DEBUG readbacks expose the projected `lk-city-*` asset name separately.

### Static fortress and battlefield treatment

`buildBattlefield()` creates the enemy node through the existing `makeBattleSprite` path using the projected fortress asset. Preserve:

- bottom-center anchor `(0.5, 0)`;
- `fitBattleNode` sizing;
- existing gate/impact coordinates;
- HP bar and milestone accent ownership;
- `enemy-city` semantic name.

Add one optional treatment sprite at:

```text
battlefield backdrop       GameUITheme.Z.background
Living Kingdom treatment   GameUITheme.Z.background + 0.5
Forged atmosphere          GameUITheme.Z.background + 1
```

The treatment mirrors the existing backdrop position/aspect-fill scale. Frontier hides it.

`redraw()` reapplies only static texture/treatment state. Layout refresh therefore cannot replay historical FX.

### Live FX

In `applyCombatResult(_:)`:

1. project old stage immediately before `state.applyLiveSoldierAttacks`;
2. run the existing mutation/save/redraw transaction unchanged;
3. project the new stage;
4. select at most one `TransitionEffect`;
5. start the optional child animation after the static terminal texture is applied.

Playback stays a temporary child of the enemy fortress sprite:

- fixed name `livingKingdomTransitionFX`;
- anchor `(0.5, 0)`;
- local position `.zero`;
- size `512×512` source points before inherited fortress scale;
- replace an existing same-name child rather than stack;
- Reduce Motion skips frames but keeps the static stage swap.

Because existing `playCityHitFeedback` / `playCityConquestFeedback` colorize the parent fortress sprite, tests must prove changing the parent texture during the hit transaction does not strand color blend state or duplicate the FX child. `redraw(shouldLayout: false)` must update the static texture without rebuilding the fortress node.

Saving, reward feedback, report presentation, Continue, and routing never wait for FX completion.

## Living conquered map

The map projection clamps `completedCityCount` to `0...15` and derives:

```text
secured cities: 1...completed
eligible caravan segments: n→n+1 where both are completed
visible caravans: first two eligible segments
6→7 patch: worn for completed < 7, repaired for completed >= 7
```

Country 1's authored primary route is exactly `1→2→...→15`, so returning the segment start city number is sufficient. `CountryMapScene` resolves runtime endpoints from `layout.cityPositions[n]` / `[n + 1]`.

Add one noninteractive `livingKingdomLayer` with z between `routeLayer` and `cityLayer`:

```text
routeLayer          0
livingKingdomLayer  5
cityLayer          10
```

Render:

- `lk-map-secured-city` at each completed city, `96×96 * mapScale`;
- `lk-map-route-6-7-worn` or `...repaired` at the 6→7 midpoint, `192×192 * mapScale`;
- at most two `lk-map-caravan` sprites, `128×64 * mapScale`, oriented with `atan2` and moving along eligible primary segments.

`mapScale = layout.displayedBackdropFrame.width / 1024`.

A tiny private render key `(completedCityCount, displayedBackdropFrame)` prevents ordinary Scout redraws from restarting caravans. No persistence, pathfinding, economy, collision, branch travel, or repair timer.

All existing city circles/numbers/markers/hit targets remain on `cityLayer` and unchanged.

## Offline-return summary semantics

All scenes keep their existing `returnFromBackground(at:)` ownership. No shared settlement service or timer is added.

### Positive non-conquest

When `elapsedSeconds > 0 && damageDealt > 0 && conqueredCities == 0`, show exactly:

```text
Buildings dealt <CompactNumberFormatter value> idle damage.
```

No duration line, gold line, claim button, or required tap.

### Zero progress

Do not create a new `No building damage while away.` return reveal. Leave prior/default feedback untouched.

### Map summary

Add `CountryMapTransientFeedback.Kind.idleSummary` with `blocksScoutEntry == false`. `idle(result:state:)` becomes positive-nonconquest-only and returns nil for zero progress or conquest.

Do not reuse `.flavor`; Scout flavor and an offline result are different semantics.

### Camp summary

Camp uses the same compact positive-damage copy and no zero-result assignment.

## Journey contract supersession

HPA-478 intentionally changes one historical journey rule so the ticket's "existing conquest report remains the single conquest acknowledgment" requirement is actually true.

The following historical contracts are **superseded for Country Map idle/current-city settlement conquest**:

- `docs/superpowers/specs/2026-08-01-gameplay-sound-haptics-settings-design.md`: Map idle conquest "does not auto-route to Battle";
- `docs/superpowers/specs/2026-07-30-compact-conquest-report-design.md`: Map idle conquest stays on Map without opening the report;
- current `CountryMapSceneTests` expectations that fresh foreground/current-city lethal idle settlement leaves the pending result on Map.

New HPA-478 contract:

- Map foreground idle conquest saves/emits once, then requests existing `.battle` routing so pending-first controller routing presents the one report;
- Map current-city RETURN/Attack settlement that becomes conquest does the same;
- a normal Map tab request already routes after settlement and needs no new path;
- Map layout-gate pause may create a pending result but must not route reentrantly while the gate is being installed; `layoutGateWillResume` requests Battle once if the pending result remains.

This is a deliberate journey change, not merely a visual implementation detail.

### Camp behavior stays narrower

HPA-478 does **not** supersede the existing Building View "stay until explicit Battle" contract for build/upgrade settlement conquest.

- Camp foreground idle conquest routes to Battle so an offline return immediately shows the pending report;
- Camp layout-gate pause defers the same route until resume;
- Camp `buildSelectedSlot` / `upgradeSelectedSlot` settlement conquest **does not auto-route**;
- those build/upgrade paths save and emit the existing fresh outcome once, clear the duplicate conquest/gold sentence, keep `pendingBattleResult`, and let the player's next explicit Battle/tab request hit the existing pending-first router.

No new routing protocol method or shared routing service.

## Scout thumbnail boundary

`CountryMapScoutCardNode` continues to load the generic `enemy-city` thumbnail in HPA-478. Landmark family identity is demonstrated in the Battle scene/treatment captures; Scout-family thumbnails are explicitly out of scope rather than silently expected by the visual matrix.

## DEBUG capture strategy

Reuse `ForgedVisualFixture`; do not add a snapshot framework.

Existing cases cover Frontier intact/conquered and early/partial/complete Map states. Add only:

- `battle-damaged` — Frontier City 1 at exact 60% (`12/20`);
- `battle-breached` — Frontier City 1 at exact 25% (`5/20`);
- `battle-emberford` — City 7 intact;
- `battle-runewatch` — City 9 intact;
- `battle-crownspire` — City 15 intact;
- `return-damage` — fixed-time Battle positive non-conquest idle return.

The DEBUG installer may invoke the existing `sceneWillEnterForegroundForTesting(at:)` seam for `return-damage`. No Release clock/routing change.

Fixture accessibility semantics expose only enough to prove projected family/stage/map-decoration/idle-summary state.

Local captures/clips remain ignored under `docs/visual-parity/living-kingdom/` and are attached/linked in the PR conversation before merge.

## Risks and mitigations

1. **Journey-test inversion.** Existing Map tests intentionally assert no auto-route. Mitigation: Task 5 explicitly rewrites those named tests before production routing changes.
2. **Layout-gate routing reentrancy.** `layoutGateWillPause` is called while the controller is installing the gate. Mitigation: never route there; use persisted `pendingBattleResult` as the deferral signal and request Battle only from resume.
3. **FX vs existing city colorize actions.** Hit/conquest feedback colorizes the same semantic enemy-city sprite. Mitigation: keep one persistent node, swap only texture, attach FX as one replaceable child, and test colorize/action coexistence.
4. **Resize/redraw during FX.** Static reapplication must not recreate the node or replay history. Mitigation: `redraw` changes texture/treatment only; test `redraw(shouldLayout:false)` and layout refresh while/after a transition.
5. **Integer boundary drift.** Real city maxima are not all divisible by threshold denominators. Mitigation: integer ratio math plus City 1 and City 3 parameterized cases; fixtures derive HP from `cityMaxPower(for:)`.
6. **Visual evidence drift.** HPA-479 large reference files are local-only. Mitigation: tracked art spec + landed assets/tests are authoritative; runtime captures are PR evidence, not production inputs.
7. **Coverage.** Existing 90% project/patch gates remain blocking. Mitigation: add focused tests for reported uncovered new code, never exclusions/lower thresholds.

## Testing contract

### Pure projection

Cover:

- integer 60%/25% boundaries using City 1 and City 3 real maxima;
- pending result forcing conquered;
- all 15 city-family mappings, especially City 11;
- exact fortress/treatment names;
- both `TransitionEffect.frameNames` arrays, seconds/frame, and all 12 `UIImage(named:)` resolutions;
- skipped-stage transition selection;
- completed-count clamping, secured cities, max-two caravans, and 6→7 repair threshold.

### Battle

Cover:

- static texture selection while `enemyCityNode.name == "enemy-city"` at every stage/family sample;
- treatment visibility/order/transform;
- live damaged/breached/conquered transitions;
- direct conquest plays collapse only;
- restored pending result/static resize plays no Living Kingdom FX;
- `redraw(shouldLayout:false)` after hit leaves one enemy node and at most one FX child;
- existing city hit/conquest colorize and Settings pause remain functional;
- positive/zero/conquest foreground return behavior.

### Map

Cover:

- secured/repair/caravan states and unchanged 44pt city hit targets;
- `.idleSummary` is nonblocking and compact-formatted;
- zero/conquest return produces no Map idle summary;
- foreground and current-city settlement conquest route once to Battle;
- normal tab settlement remains one existing route;
- gate pause never routes; gate resume routes pending once;
- existing fresh reward/outcome feedback remains exactly once even though the scene now routes afterward.

### Camp

Cover:

- positive compact copy and zero no-op;
- foreground idle conquest routes once;
- gate pause/resume deferral;
- build/upgrade settlement conquest saves/emits but does **not** auto-route and does not add duplicate conquest/gold text;
- an explicit later Battle/tab request reaches pending-first report.

## Final acceptance

- all four Living Kingdom concepts run in real gameplay with HPA-479 production assets;
- no gameplay/economy/save/schema/route-topology/art changes;
- `enemy-city` semantic node name remains stable;
- Scout thumbnail remains generic by explicit scope decision;
- Battle restore/resize does not replay historical FX;
- Map city hit targets/Scout/Attack and Camp/Settings remain usable;
- idle conquest has exactly one report/Continue acknowledgment;
- Camp build/upgrade conquest does not unexpectedly navigate away;
- 393×852 capture matrix plus compact phone/portrait iPad smoke is complete;
- 90% project/patch coverage gates, tests, lint, Debug/Release builds, and diff checks pass.
