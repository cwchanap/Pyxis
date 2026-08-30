# Forged Gameplay UI Redesign Design

## Status

Approved planning design for replacing Pyxis's current gameplay chrome with the supplied **Forged** mobile UI direction while preserving shipping game rules, persistence, scene ownership, routing, lifecycle, feedback, accessibility behavior, and layout gates.

The 393×852 mockups define presentation. Shipping Swift remains authoritative for gameplay. When the mock conflicts with a real gameplay or geometry contract, the real contract wins and the implementation parity board records the deliberate difference.

## Goal

Make Battle, Camp, Map, Conquest, and Settings read like one coherent Forged mobile game UI without turning the redesign into a combat-runtime or navigation rewrite.

The result uses dark iron surfaces, restrained gold edging and rivets, amber primary actions, image-forward unit/building affordances, shared Battle/Camp/Map tabs, a radial Camp builder, a selected-city Map card, adaptive Conquest stat tiles, and a Settings bottom sheet.

## Canonical visual source of truth

The intended canonical 393×852 reference set is:

- Battle: `docs/visual-parity/forged-ui/battle.png` — source export `3b.png`
- Camp: `docs/visual-parity/forged-ui/camp.png` — source export `2b.png`
- Map: `docs/visual-parity/forged-ui/map.png` — source export `2c.png`
- Conquest: `docs/visual-parity/forged-ui/conquest.png` — source export `2d.png`
- Settings: `docs/visual-parity/forged-ui/settings.png` — source export `2e.png`

The implementation must not begin from a different export without explicitly changing those references. Other supported portrait phone/iPad geometries must remain usable and contained; exact mock parity is judged only at 393×852.

## Gameplay source of truth

Existing production ownership does not move:

- `KingdomGameState` owns progression, economy, building state/mutations, unlocks, normalized persistence, and stage status.
- `BattleCombatState` owns the transient living roster, lane assignment, movement, attacks, tower damage, and losses.
- `Country1CityCatalog` owns city identity, traits, lane profiles, and flavor copy.
- `RecommendedCampRecommendation` remains the only Camp recommendation policy.
- `BattleResult` remains persisted/finalized conquest evidence.
- `FeedbackPreferencesManaging`, `FeedbackSettingsController`, and `FeedbackSettingsAccessibilityAdapter` remain Settings behavior/accessibility owners.
- `GameViewController.presentSceneForCurrentStage` remains the stage/pending-result routing authority.

No mock reward, cost, unit count, timer, unlock, multiplier, income rate, or result statistic becomes shipping data.

## Non-goals

This redesign does not add a shared combat runtime across tabs, one all-purpose gameplay scene, new save fields/migration, balance changes, new building/unit/city content, Country 2, landscape support, SwiftUI, third-party UI/state packages, custom fonts, a generated-asset pipeline, a router/component/fixture registry, broad gameplay accessibility expansion, or pixel-difference CI.

A future requirement for Battle combat to continue while Camp or Map is visible needs a separate design for transient roster ownership, tick/lifecycle ownership, conquest while another surface is mounted, effects, and recovery. The tab bar does not imply that feature.

## Existing scene architecture remains

Pyxis keeps three code-owned SpriteKit scenes:

- `BattleScene` owns transient combat and battlefield rendering.
- `BuildingViewScene` owns the current city's 25-lot building interaction.
- `CountryMapScene` owns the authored 15-city route and entry flow.

Leaving Battle with living manual soldiers remains blocked. Those soldiers live only in `BattleCombatState`; replacing the scene would discard them. Tabs are shared presentation over the existing router, not a common simulation owner.

## Shared material: extend `PanelNode`

The existing `PanelNode` in `GameUIComponents.swift` becomes the shared Forged surface primitive. Do not add `ForgedSurfaceNode` beside it.

The style enum represents **state only**, not migration history:

```swift
final class PanelNode: SKNode {
    enum Style: Equatable {
        case normal
        case selected
        case primaryAction
        case disabled
    }

    func apply(size: CGSize, style: Style, showsRivets: Bool)
    func update(size: CGSize)
}
```

There is no `.standard`/`.forged` compatibility seam and no unused `.danger` style. Existing panel consumers receive the Forged normal treatment as their owning screen task migrates them. Success/danger may remain color tokens where actual badges/switches use them; they are not panel styles until a panel consumer needs them.

The node builds one fixed shadow/plate/highlight/four-rivet tree and only reapplies paths/colors/visibility. `GameUITheme` gains only constants with multiple consumers.

## Shared tabs and truthful availability

Add one `GameplayTabBarNode` with a closed `GameplayTab` enum and `Content(selected:enabledTabs:showsCampAttention:)`. Disabled cells remain visually present but have no hit frame; `tab(at:)` returns nil. Conquest omits the tab bar entirely.

The policy is fixed:

| Mounted state | Selected | Enabled |
| --- | --- | --- |
| Battle, no manual living soldiers | Battle | Battle, Camp, Map |
| Battle, one or more manual living soldiers | Battle | Battle only |
| Camp, active and no pending result | Camp | Battle, Camp, Map |
| Map while an active city exists | Map | Battle, Camp, Map |
| Map after city conquest pending next entry | Map | Map only |
| Map at country completion | Map | Map only |
| Conquest visible/fit-failed | no bar | none; March On only |

Battle derives the enabled set from the same authoritative predicate already used by routing: `combat.livingSoldierCount(source: .manual) == 0`. The route guard remains as defense in depth for state changes between redraw and touch handling, but the persistent navigation affordance no longer looks enabled when it cannot succeed.

The Camp attention dot comes only from `RecommendedCampRecommendation`: visible from Battle/Map for `.ready`/`.saveFor`, hidden in Camp and `.noAction`.

## Routing: extend the existing pending-first authority

Do not create a second pending/stage switch in `presentGameplayTab`.

Extend the existing method instead:

```swift
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
        case .battle: presentBattleScene(in: view)
        case .camp: presentBuildingViewScene(in: view)
        case .map: presentCountryMapScene(in: view)
        }
    case .cityConqueredPendingMap, .countryComplete:
        presentCountryMapScene(in: view)
    }
}
```

`presentGameplayTab(_:,in:)` is only a forwarding convenience into `presentSceneForCurrentStage(in:preferredTab:)` or can be omitted entirely.

Scene behavior remains explicit:

- Battle→Camp/Map checks the manual-living-squad guard before forwarding.
- Any Camp exit first runs the same `state.returnFromBackground(at:)`, save, idle feedback, and redraw sequence current `requestBattle()` owns. If settlement creates a pending result, the controller lands on Battle regardless of the requested tab.
- Map tab selection never calls `startCityFromMap(_:)`; only the selected-city card March action starts an unlocked city.
- Country-complete Battle/Camp tabs are non-hit.

Old World/Build/Battle buttons are removed when tabs cover them; no compatibility chrome remains.

## Battle redesign

### Pure chrome layout and explicit battlefield budget

Extract the current private/impure Battle HUD geometry into `BattleChromeLayout`, a pure CoreGraphics value. `BattlefieldLayout` remains the sole authority for castle/enemy/lane geometry and consumes the field bounds returned by the chrome layout.

`BattleChromeLayout` must expose a numeric field budget instead of accepting any non-overlapping rectangle.

`BattlefieldLayout` currently uses:

- structure cap: 144 pt;
- enemy-city height: `structureHeight * 1.04 + 14`;
- hard minimum lane: 60 pt.

For the reference/regular layout, reserve 48 pt of visual lane headroom beyond that hard minimum:

```text
144 + (144 × 1.04 + 14) + (60 + 48) = 415.76
```

Therefore:

```swift
static let minimumBattlefieldHeight: CGFloat = 416
```

At 393×852 the authored layout must produce a `battlefieldFrame.height` in the **424...440 pt** range; otherwise Task 4 stays RED. That keeps the real lane materially above `BattlefieldLayout`'s collapse threshold instead of ~5 pt from it.

For the existing 375×667 compact fixture, use a compact field floor of 340 pt, derived from ~130 pt structures plus the existing 60 pt lane minimum:

```text
130 + (130 × 1.04 + 14) + 60 = 339.2
```

The compact layout is allowed to reduce gaps/type and use 44 pt medallion hits. It must still make `BattlefieldLayout.isVisible == true`.

To pay for the 416 pt reference field without deleting required information:

- manual `N / 10` lives inside the Deploy surface rather than taking its own vertical row;
- lane OPEN/HELD chips are HUD overlays inside the upper battlefield and do not consume separate field height;
- tab background may extend visually through the bottom safe area, while tab hit frames remain safe;
- five medallions remain outside the lane path and do not cover soldier interaction space.

If the required field floor cannot be met, `BattleChromeLayout.compute` returns nil and Battle fails closed through `isBattleChromeFitFailed`.

### Real unit availability

`BattleHUDContent` projects exactly five medallions in this order:

1. `state.manualSoldierLevel(for: type)` returns a level → `.available(level:)`.
2. Otherwise matching building is unlocked → `.unbuilt`.
3. Otherwise → `.locked(unlocksAtCity:)`.

This preserves the shipping Infantry starter fallback: Infantry with no Barracks is `.available(level: 1)`, never `.unbuilt`.

Reference gates:

- City 1 empty: Infantry L1 available; Archer/Cavalry/Mage/Siege locked at 2/5/8/11.
- City 5 empty: Infantry L1 available; Archer/Cavalry unbuilt; Mage/Siege locked at 8/11.

Trait multiplier badges display existing 1.25×/0.80×/1.00× values only. Combat formulas stay unchanged.

### Settings gear stays outside `BattleHUDNode`

`BattleChromeLayout.settingsFrame` positions the existing `FeedbackSettingsController.gear`. `BattleHUDNode` neither draws nor hit-tests Settings. Camp and Map follow the same ownership rule.

### Battle layout gate is scene state

Add `private(set) var isBattleChromeFitFailed = false` to `BattleScene`. Success clears it; required chrome failure sets it, hides/disables required Forged controls, and notifies the router only to trigger controller refresh. `GameViewController.refreshLayoutSupport` checks `isBattleChromeFitFailed || isConquestReportFitFailed` as the Battle source of truth.

## Camp redesign

Keep the countryside backdrop, all 25 scenic lot positions, real slot state, existing build/upgrade mutations, settlement-before-mutation, persistence, feedback, and conquest-during-settlement behavior.

Selecting an empty lot opens one five-option radial/arc builder in `BuildingType.allCases` order. Each option is available, unaffordable, locked(unlock city), or capped(maximum). Edge lots may use two arcs/rows; every option remains ≥44×44 and no type disappears.

Selecting an occupied lot shows an inspector with building art/name, level pips, lot number, produced soldier, and one real-cost Upgrade action.

`RecommendedCampRecommendation` remains the only recommendation policy and drives the Battle objective, Camp attention dot, recommended lot, and matching build/upgrade emphasis. The prose recommendation row is removed only after those consumers exist.

## Map redesign

Keep the authored backdrop, 15 city anchors/routes, status computation, feedback kinds, flavor behavior, safe-area validation, and one layout gate.

### Selected-city content

Add scene-local `selectedCityNumber`. Selection redraws only; it does not mutate `KingdomGameState`.

Extend the existing scout-card content for attackable/current/completed/locked/country-complete states. It shows authored city identity, meaningful future reward, trait/short description, favorable/disadvantaged unit portraits with real multipliers, exposed lane, and state action. The current-city action returns to Battle without restarting. Flavor remains non-blocking.

### Computed Map budget — no 236/300 guess

The previous 236/300 pt exclusive reservation is rejected. With current Country 1 anchors, 44×44 city targets, a 72 pt tab bar, and the 393×852 safe area, that budget cannot satisfy the existing containment contract.

The new broad-layout invariants are:

```swift
static let tabBarHeight: CGFloat = 72
static let preferredPhoneInformationHeight: CGFloat = 164
static let preferredPadInformationHeight: CGFloat = 140
static let minimumCompactInformationHeight: CGFloat = 48
static let minimumIllustratedMapHeight: CGFloat = 431
static let minimumCityCenterDistance: CGFloat = 45
```

`CountryMapLayout.compute` resolves information height from **remaining vertical budget**, not only layout class:

1. Reserve top title/resource chrome and its 8 pt gap.
2. Reserve bottom safe inset + 72 pt tabs.
3. Require at least 431 pt for the illustrated phone map.
4. The card gets `min(preferredInformationHeight, remainingCardBudget)`.
5. If the remaining card budget is below 48 pt, fail closed.

For current phone fixtures this resolves to:

- 375×667: **48 pt** compact card + 431 pt illustrated map;
- 375×812: **133 pt** card + 431 pt illustrated map;
- 393×852: **164 pt** card + 431 pt illustrated map.

Pad uses a preferred 140 pt horizontal/multi-column card; existing pad fixtures have enough map height for that reservation.

### Explicit backdrop transform

Do not use centered full-scene aspect-fill and do not aspect-fit the map into a narrow letterbox.

The illustrated-map transform is **aspect-fill with authored interaction-envelope alignment**:

1. Preserve backdrop aspect ratio.
2. Scale by the maximum of:
   - illustrated-region width / canonical width;
   - illustrated-region height / canonical height;
   - scale required for the closest authored city centers to remain at least 45 pt apart.
3. Keep the backdrop horizontally centered.
4. Compute the complete vertical interaction envelope after scaling: all city centers ±22 pt plus route-stroke extents.
5. Vertically translate the backdrop so that interaction envelope, not the bitmap's geometric center, is centered inside `illustratedMapRegionFrame`.
6. Re-run the existing city/route containment guards.

Using current Country 1 anchors this gives, at 393×852 with 59/34 insets and a 164 pt card:

- illustrated map height: **431 pt**;
- closest city-center distance: **45.0 pt**;
- minimum city-target headroom: **~8.3 pt**;
- minimum route-stroke headroom: **~27.3 pt**.

Those numbers become pure layout tests. The full mock-height card is deliberately not used because preserving all 15 authored 44 pt interactions is a shipping constraint. That vertical difference must be visible in the parity board rather than hidden as a late implementation surprise.

The 48 pt short-phone card uses a horizontal compact projection (city identity/status plus primary action). Detailed trait/counter information remains reachable through the existing informational/flavor overlay; no scrolling/panning framework is added only for the short fixture.

### Remove duplicate current-city control

Delete `showsCurrentCityControl`, `currentCityControlFrame`, and `currentCityButton`. The selected-city card owns Return/March; tabs own global Battle/Camp/Map navigation.

## Conquest redesign — atomic display cutover

Keep `BattleResult` coding/finalization and pending-result persistence unchanged. Replace `summaryLines`, `goldLineIndex`, and the layout's 3...4 row contract in the same slice with:

- dedicated `rewardText` / `rewardFrame`;
- two or three typed `StatTile`s;
- zero to two achievement chips;
- existing country-complete reservation;
- existing Continue action, visually `MARCH ON`.

Tile shapes remain:

- live + MVP → MVP, battle time, sent/lost;
- live without MVP → battle time, sent/lost;
- idle + MVP → MVP, Buildings, sent/lost;
- idle without MVP → Buildings, sent/lost.

No filler tile/achievement is invented. Gold feedback anchors to `rewardFrame` rather than a positional summary-row index. Conquest has no tab bar.

## Settings redesign — no rename churn

Keep `FeedbackSettingsController`, preferences, adapter, action enum, focus restoration, modal precedence, and Battle pause behavior.

`FeedbackSettingsLayout` keeps its existing public value names:

- `scrimFrame`;
- `panelFrame`;
- `soundRowFrame`;
- `hapticsRowFrame`;
- `closeFrame`.

Add only `handleFrame`. The node renders the existing `panelFrame` as a bottom sheet and `closeFrame` with visible copy `Done`. Do not rename them to `sheetFrame` / `doneFrame`; that would be test churn with no behavior change.

## Deterministic visual fixtures before screen cutovers

Add `ForgedVisualFixture` immediately after routing. Keep its launch trigger separate from the five-tap dev tool, but reuse `DevJumpState.make(city:)` as the DEBUG state baseline for battle/camp/map cases, then mutate only fixture-specific gold/buildings/stage/result fields. This avoids a second Country 1 state-construction recipe.

Fixture cases remain battle, battle-blocked, camp-empty, camp-occupied, map, map-country-complete, conquest-live, conquest-idle. `-pyxis-forged-fixture <value>` is DEBUG-only; unknown/no argument leaves the store untouched. Final capture may also use a DEBUG-only freeze-combat marker. Both markers must be absent from Release strings.

## Real gameplay versus mock parity contract

Every reviewed surface passes both visual and semantic parity:

| Surface | Visual target | Real-gameplay gates |
| --- | --- | --- |
| Battle | top bands, lane chips, five medallions, Deploy, tabs | real gold/HP/recommendation/lane/unit states; Infantry L1; tabs disabled with manual squad; ≥416 pt reference field |
| Camp | scenic lots, builder, inspector, tabs | 25 lots; 5 building types; unlock/afford/cap; settlement; pending conquest |
| Map | pips, selected card, March/Return, tabs | computed card/map budget; 15 authored 44 pt targets/routes; current/completed/locked/complete |
| Conquest | reward, stat tiles, chips, March On | live/idle; optional MVP; zero achievements; restored/finale behavior |
| Settings | bottom sheet, icons, switches, Done | two persisted toggles; one gear; accessibility/focus/pause semantics |

The implementation PR includes canonical mock / real 393×852 / 50%-alpha overlay comparisons. Deliberate geometry differences such as the 164 pt Map card are documented with their real constraint.

## Risks and fallbacks

### 1. Map geometry

**Risk:** Enlarged card/tabs can make the authored 15-city route impossible at 44 pt target size.

**Control:** pure arithmetic is pinned before Map rendering: minimum illustrated height 431, center distance 45, reference headroom ~8.3. If a supported fixture fails, reduce information height through the existing budget calculation; never shrink hit targets, drop cities, or silently re-author anchors.

### 2. Battle battlefield collapse

**Risk:** New chrome can leave `BattlefieldLayout` at its 60 pt lane minimum.

**Control:** regular minimum field 416 and 393 reference target 424...440; compact floor 340. Failure sets `isBattleChromeFitFailed` and gates the scene rather than rendering a collapsed field.

### 3. Render-node patch coverage

**Risk:** SpriteKit path/color/sprite assembly can miss the repository's blocking 90% patch status.

**Control:** value-producing decisions stay in pure projections/layouts; render nodes have fixed trees and thin `apply`/hit-test bodies. Node tests exercise every style/state/action branch. If Codecov reports <90% patch, add focused tests for the reported uncovered lines; do not exclude files or weaken `codecov.yml`.

### 4. Large single runtime PR

**Risk:** five connected surfaces create a large review diff.

**Control:** this task remains one PR per project delivery policy. Use task commits and explicit review checkpoints after foundation/fixtures, Battle, Camp+Map, and Conquest+Settings. Do not split into multiple PRs unless the product owner explicitly approves that exception.

## Delivery shape

The complete runtime redesign is one PR. Tasks are logical TDD commits with intermediate review checkpoints, not independently merged PRs. This avoids temporary compatibility chrome and honors the project's one-PR-per-task planning rule.

No runtime PR leaves Draft until full tests/lint/diff, Codecov ≥90% project/patch, Release marker scans, and the parity board are complete.
