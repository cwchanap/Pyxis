# Forged Gameplay UI Redesign Design

## Status

Approved planning design for replacing Pyxis's current gameplay chrome with the supplied **Forged** mobile UI direction while preserving shipping game rules, persistence, scene ownership, routing, lifecycle, feedback, accessibility behavior, and layout gates.

The 393×852 mockups define presentation. Shipping Swift remains authoritative for gameplay. When a mock sample conflicts with a real model contract, the real contract wins and the implementation parity board documents the deliberate visual difference.

## Goal

Make Battle, Camp, Map, Conquest, and Settings read like one coherent Forged mobile game UI without turning the redesign into a combat-runtime or navigation rewrite.

The result should use dark iron surfaces, restrained gold edging and rivets, amber primary actions, image-forward unit/building affordances, a shared Battle/Camp/Map tab presentation, a radial Camp builder, a large selected-city Map card, adaptive Conquest stat tiles, and a Settings bottom sheet.

## Canonical visual source of truth

The planning branch carries the exact reference set used by implementation:

- Battle: `docs/visual-parity/forged-ui/battle.png` — source export `3b.png`
- Camp: `docs/visual-parity/forged-ui/camp.png` — source export `2b.png`
- Map: `docs/visual-parity/forged-ui/map.png` — source export `2c.png`
- Conquest: `docs/visual-parity/forged-ui/conquest.png` — source export `2d.png`
- Settings: `docs/visual-parity/forged-ui/settings.png` — source export `2e.png`

All five are canonical 393×852 phone canvases. The interactive HTML remains supporting context only and is not required in the repository. Other supported portrait phone and iPad sizes must remain contained and usable; exact visual parity is required only at 393×852 because there is no authored iPad mock.

## Gameplay source of truth

Existing production ownership does not move:

- `KingdomGameState` owns progression, economy, building state/mutations, unlocks, normalized persistence, and stage status.
- `BattleCombatState` owns the transient living roster, lane assignment, movement, attacks, tower damage, and losses.
- `Country1CityCatalog` owns city identity, traits, lane profiles, and flavor copy.
- `RecommendedCampRecommendation` remains the only Camp recommendation policy.
- `BattleResult` remains the persisted/finalized conquest evidence.
- `FeedbackPreferencesManaging`, `FeedbackSettingsController`, and `FeedbackSettingsAccessibilityAdapter` remain the Settings behavior/accessibility owners.
- `GameViewController` remains the only production scene router and feedback-runtime composition root.

No mock reward, cost, unit count, timer, unlock, multiplier, income rate, or result statistic becomes shipping data.

## Non-goals

This redesign does not add a shared combat runtime across tabs, a replacement all-in-one gameplay scene, new save fields or migration, balance changes, new building/unit/city content, Country 2, landscape support, SwiftUI, third-party UI/state packages, custom fonts, a generated-asset pipeline, a router/component/fixture registry, broad gameplay accessibility expansion, or pixel-difference CI.

A future requirement for Battle combat to continue while Camp or Map is visible needs a separate design for transient roster ownership, tick/lifecycle ownership, conquest while another surface is mounted, effects, and recovery. The Forged tab bar does not imply that feature.

## Existing scene architecture remains

Pyxis keeps three code-owned SpriteKit scenes:

- `BattleScene` owns transient combat and battlefield rendering.
- `BuildingViewScene` owns the current city's 25-lot building interaction.
- `CountryMapScene` owns the authored 15-city route and entry flow.

Leaving Battle with living manual soldiers remains blocked. Those soldiers live only in `BattleCombatState`; scene replacement would silently discard them. Tabs are shared presentation over the existing router, not a new common simulation owner.

## Shared material: extend `PanelNode`, do not add another panel type

The existing `PanelNode` in `GameUIComponents.swift` becomes the single shared panel/material primitive. Do not add `ForgedSurfaceNode` beside it.

Extend `PanelNode` with a closed style:

```swift
final class PanelNode: SKNode {
    enum Style: Equatable {
        case standard
        case forged
        case selected
        case primaryAction
        case disabled
        case success
        case danger
    }

    func apply(size: CGSize, style: Style, showsRivets: Bool)
    func update(size: CGSize)
}
```

The node owns one fixed shadow/plate/highlight/four-rivet tree built once. `apply` changes paths, colors, visibility, and sizes only. Existing `update(size:)` preserves the current style so intermediate implementation commits stay compiling while old consumers migrate. This is an incremental implementation seam, not a backward-compatibility promise.

`GameUITheme` receives only shared color/metric constants that have multiple consumers. There is no theme dictionary, component registry, or generic button class.

## Shared tabs and closed availability policy

Add:

```swift
enum GameplayTab: CaseIterable, Hashable {
    case battle
    case camp
    case map
}

final class GameplayTabBarNode: SKNode {
    struct Content: Equatable {
        let selected: GameplayTab
        let enabledTabs: Set<GameplayTab>
        let showsCampAttention: Bool
    }

    func apply(content: Content, frame: CGRect)
    func tab(at point: CGPoint) -> GameplayTab?
}
```

The tab bar always uses the same three-cell geometry when it is visible. Disabled tabs remain visually present but have no hit target; `tab(at:)` returns nil. Conquest omits the tab bar entirely rather than inventing disabled-overlay behavior.

The policy is fixed:

| Mounted state | Selected | Enabled |
| --- | --- | --- |
| Battle, active and no Conquest report | Battle | Battle, Camp, Map; Camp/Map still pass the living-squad guard |
| Camp, active and no pending result | Camp | Battle, Camp, Map |
| Map while an active city exists | Map | Battle, Camp, Map |
| Map after a conquered city is waiting for the next entry | Map | Map only |
| Map at country completion | Map | Map only |
| Conquest report visible or required report fit failed | no bar | none; Continue/March On is the only navigation action |

The Camp attention dot comes only from `RecommendedCampRecommendation`: visible from Battle or Map for `.ready` / `.saveFor`, hidden in Camp and for `.noAction`.

## Routing is pending-first

All accepted tab requests end in a controller helper that preserves the existing pending-result priority:

```swift
private func presentGameplayTab(_ tab: GameplayTab, in view: SKView) {
    let state = store.load()

    if state.pendingBattleResult != nil {
        presentBattleScene(in: view)
        return
    }

    switch tab {
    case .battle:
        state.stageStatus == .battleActive
            ? presentBattleScene(in: view)
            : presentCountryMapScene(in: view)
    case .camp:
        state.stageStatus == .battleActive
            ? presentBuildingViewScene(in: view)
            : presentCountryMapScene(in: view)
    case .map:
        presentCountryMapScene(in: view)
    }
}
```

Scene-specific behavior remains explicit:

- Battle→Camp/Map runs the current living-manual-squad guard before routing. A blocked request shows the existing feedback and keeps the roster.
- Battle→Battle is a no-op.
- Any Camp request leaving Camp first performs the same `state.returnFromBackground(at:)`, save, idle-result feedback, and redraw handoff that current `requestBattle()` owns. If that settlement creates `pendingBattleResult`, the controller presents Battle regardless of whether the requested tab was Battle or Map.
- Map tab selection never calls `startCityFromMap(_:)`. Map→Battle returns to the already active city; Map→Camp opens that active city's Camp. The selected-city card's March action remains the only path that starts an unlocked city.
- Country-complete Battle/Camp tabs are disabled and cannot reach `startCityFromMap(_:)`.

Old World/Build/Battle navigation buttons are removed after the tab paths cover them; there is no compatibility chrome.

## Battle redesign

### Pure chrome layout

Add `BattleChromeLayout` for resource, city title/progress/HP, objective, lane chips, five medallions, Deploy/manual-count, tab, Settings frame, and battlefield reservation. `BattlefieldLayout` remains the sole battlefield geometry authority and consumes the safe bounds produced by the chrome layout.

At 393×852, the layout follows the reference with 16-point side margins, five 56-point medallions, one full-width Deploy action, and the shared tab bar. Every primary/control hit frame remains at least 44×44.

### Real unit availability, including the Infantry starter exception

`BattleHUDContent` projects exactly five medallions. Availability is determined in this order:

1. `state.manualSoldierLevel(for: type)` returns a level → `.available(level:)`.
2. Otherwise the matching building type is already unlocked → `.unbuilt`.
3. Otherwise → `.locked(unlocksAtCity:)`.

This deliberately preserves the shipping starter fallback: Infantry with no Barracks is still `.available(level: 1)`. It is never turned into `.unbuilt` by presentation code. `.unbuilt` applies only to non-Infantry types whose building is unlocked but absent.

The reference projection gates are:

- City 1 empty grid: Infantry available L1; Archer/Cavalry/Mage/Siege locked at Cities 2/5/8/11.
- City 5 empty grid: Infantry available L1; Archer and Cavalry unbuilt; Mage and Siege locked at Cities 8/11.

The multiplier badge is presentation from the existing trait multiplier: 1.25× favorable, 0.80× disadvantaged, otherwise 1.00×. Combat still calls the existing damage APIs.

Tapping available selects; tapping unbuilt shows build-first feedback without auto-routing; tapping locked shows the real unlock city. Deploy delegates to the current spawn path and preserves stage/manual-cap/report gates.

### Settings gear is not part of `BattleHUDNode`

`BattleChromeLayout.settingsFrame` positions the existing `FeedbackSettingsController.gear` through `applyGearFrame`. `BattleHUDNode` neither draws nor hit-tests Settings and has no `openSettings` action. This preserves the existing `SettingsGearNode` semantic identity, 44-point hit behavior, accessibility adapter, focus restoration, and Battle pause behavior.

Camp and Map follow the same ownership rule: their layouts provide a gear frame, but the gear remains controller-owned.

### Battle required-layout failure is scene state

Add `private(set) var isBattleChromeFitFailed = false` to `BattleScene`.

- Successful required chrome layout resets it to false.
- Nil/failed required chrome layout sets it true, hides/disables required Forged controls, and notifies the router with `.unsupportedGeometry` only to trigger a refresh.
- `GameViewController.refreshLayoutSupport` treats `battle.isConquestReportFitFailed || battle.isBattleChromeFitFailed` as the Battle fail-closed source of truth.

This matches the existing Conquest pattern; the router callback is not itself the persisted gate state.

## Camp redesign

Keep the countryside backdrop, all 25 authored scenic lot positions, real slot state, existing build/upgrade mutations, settlement-before-mutation, persistence, feedback, and conquest-during-settlement behavior.

Selecting an empty lot opens one five-option radial/arc builder in `BuildingType.allCases` order. Each option is exactly one of available, unaffordable, locked(unlock city), or capped(maximum). All five types appear even though the mock visually samples four. Edge lots may use two arcs/rows as long as every hit frame remains at least 44×44 and no type disappears.

Selecting an occupied lot shows an inspector with building art/name, level pips, lot number, produced soldier, and one real-cost Upgrade action.

`RecommendedCampRecommendation` remains the only recommendation policy and drives the Battle objective strip, Camp attention dot, recommended lot highlight, and matching radial/upgrade emphasis. The current prose recommendation row is removed only after those consumers exist.

Any tab action leaving Camp runs the current `returnFromBackground` settlement/save path first; pending conquest restores Battle rather than opening Map.

## Map redesign

Keep the authored backdrop, 15 city anchors/routes, map status computation, feedback kinds, flavor behavior, safe-area validation, and one layout gate.

### Selected-city content

Add scene-local `selectedCityNumber`. Selection redraws only; it does not mutate `KingdomGameState`.

Extend the existing scout-card projection to represent attackable, current active, completed, locked, and country-complete content. The card shows authored city identity, meaningful future reward, trait/short description, favorable/disadvantaged unit portraits with real multipliers, exposed lane, and state-specific action. The current active-city action returns to Battle without restarting it. Locked/completed actions remain non-mutating. Flavor stays non-blocking and excludes an enabled March action frame.

### The large card changes the broad map budget explicitly

The current 64/112-point information reservation is replaced, not stretched implicitly:

```swift
enum CountryMapLayoutClass: Equatable {
    case phone
    case pad

    var informationRegionHeight: CGFloat {
        self == .phone ? 236 : 300
    }
}
```

`CountryMapLayout` reserves, in order, safe bottom/tab bar, large information card, illustrated map region, and top resource/title chrome. It recomputes `displayedBackdropFrame` for the illustrated region and remaps all authored anchors through that frame; it does not keep the old full-scene backdrop transform and hope the enlarged card fits. The existing fail-closed checks still require every 44-point city target and every route stroke to remain inside the illustrated region and horizontal safe content.

`CountryMapScoutCardLayout` remains the only card-interior authority. No second large-card layout type is added.

### Remove the duplicate current-city button

Delete `showsCurrentCityControl` from `CountryMapLayoutConstraints`, `showsCurrentCityControl` / `currentCityControlFrame` from layout output, and the separate `currentCityButton` node/touch/layout from `CountryMapScene`. The selected-city card owns `RETURN` / `MARCH`; the tab bar owns global Battle/Camp/Map navigation.

Phone 393×852 and existing phone/iPad fixtures must prove the enlarged card plus tabs still leave all 15 city targets/routes valid. If a supported geometry cannot satisfy those existing invariants, Map continues to fail closed rather than dropping cities or shrinking hit targets.

## Conquest redesign is one atomic display-contract cutover

Keep `BattleResult` coding/finalization and pending-result persistence unchanged. Replace the old row-oriented display APIs together:

```swift
struct ConquestReportContent: Equatable {
    enum StatKind: Equatable { case mvp, battleTime, buildings, sentLost }

    struct StatTile: Equatable {
        let kind: StatKind
        let title: String
        let value: String
        let soldierType: SoldierType?
    }

    enum AchievementChip: Equatable { case favorableUnit, exposedLane }

    let title: String
    let rewardText: String
    let statTiles: [StatTile]
    let achievementChips: [AchievementChip]
}
```

In the same implementation commit remove `summaryLines`, `goldLineIndex`, and the layout's `(3...4)` summary-row contract. `ConquestReportLayout.Input` becomes `statTileCount` 2...3 plus `achievementChipCount` 0...2 and existing country-completion flag. Layout output has a dedicated `rewardFrame`, centered two/three `statTileFrames`, zero/two chip frames as needed, `continueFrame`, and optional country-complete frame.

`ConquestReportNode.goldEffectAnchor` comes from `rewardFrame.midX/midY`, not a positional summary-row index.

Tile rules are fixed:

- live + MVP: MVP, battle time, sent/lost;
- live without MVP: battle time, sent/lost;
- idle + MVP: MVP, Buildings, sent/lost;
- idle without MVP: Buildings, sent/lost.

No filler MVP/stat/achievement is invented. Zero achievements reserve no chip strip. Continue is visually `MARCH ON` but keeps the existing acknowledge-save-route behavior, disabled transition window, fresh/restored semantics, and finale reservation.

Conquest omits the tab bar entirely.

## Settings redesign

Keep `FeedbackSettingsController`, `FeedbackPreferencesManaging`, `FeedbackSettingsAccessibilityAdapter`, `FeedbackSettingsAction`, focus restoration, independent persistence, modal touch precedence, and Battle action pausing.

Only `FeedbackSettingsLayout` and `FeedbackSettingsNode` change presentation: safe-area-aware bottom sheet, dim scrim, decorative non-draggable handle, two icon/title/switch rows, and one full-width Done action. SpriteKit switch graphics still activate the existing row actions; do not introduce `UISwitch` or new accessible controls.

## Deterministic visual fixtures arrive before screen cutovers

Add a closed DEBUG-only `ForgedVisualFixture` immediately after tab routing is implemented, before Battle/Camp/Map/Conquest/Settings visual tasks.

Fixture cases are:

```text
battle
battle-blocked
camp-empty
camp-occupied
map
map-country-complete
conquest-live
conquest-idle
```

The explicit `-pyxis-forged-fixture <value>` launch argument overwrites the development/test save through normal model initializers only when present in DEBUG. Unknown/no argument does nothing. This fixture is intentionally separate from `DevJumpState`; the existing jump tool has a different trigger/ownership contract and deliberately does not become a launch-argument harness.

The initial fixture slice includes parsing, deterministic `makeState()`, and normal scene routing only. A separate final DEBUG freeze-combat argument is added with UI smoke/parity capture, after there is a Battle screen worth freezing.

Every later visual task must launch its relevant fixture at 393×852 while it is being implemented rather than waiting for the final acceptance task.

## Real gameplay versus mock parity contract

Parity has two simultaneous columns:

| Surface | Visual parity | Real gameplay parity |
| --- | --- | --- |
| Battle | Forged top bands, lane chips, five medallions, Deploy, tabs | Real gold/city/HP/recommendation/lane profile; Infantry L1 starter; unbuilt vs locked; multipliers; manual cap; blocked routing; Settings and Conquest precedence |
| Camp | Scenic lots, radial builder, inspector, tabs | 25 lots; all five building types; affordability/unlocks/caps; recommendation; settlement; pending Conquest routing |
| Map | Progress pips, large selected-city card, March/Return, tabs | Current/unlocked/locked/completed/country-complete; authored route; flavor/feedback; all 15 44-point targets; no duplicate current-city control |
| Conquest | Crest/reward, two/three stat tiles, chips, March On | Live/idle; optional MVP; real counts/time; zero achievements; restored/finale; no tabs |
| Settings | Bottom sheet, icon rows, switch visuals, Done | Existing independent toggles; same gear/accessibility adapter; focus restoration; Battle pause; modal touch priority |

The implementation PR must attach, for every required state, the canonical mock, a real 393×852 simulator screenshot, a 50% alpha overlay, and a short note for each deliberate gameplay-grounded discrepancy.

Minimum evidence: Battle normal; Battle locked/unbuilt; Battle blocked navigation; Camp radial; Camp inspector; Camp unavailable option; Map attackable; Map locked/completed; Map country complete; Conquest live with MVP; Conquest idle without MVP; Settings with one toggle off.

Review order is geometry/safe areas → hierarchy → typography/material → semantic values → mock-omitted states → interactions/hit targets. Automated tests do not replace this board.

## Testing and release gates

Pure layout/projection tests cover 393×852, the smallest supported phone fixture, and current iPad fixtures; exact five-medallion/three-tab counts; 44-point targets; Infantry fallback; Camp option states; all Map city/route containment after card growth; two/three Conquest tiles; and bottom-sheet geometry.

Scene/controller tests cover one-shot mutation/routing, living-squad preservation, Camp settlement before either exit, pending-first result restoration, Battle chrome gate flags, modal precedence, lifecycle behavior, and no duplicate nodes after redraw/resize.

The final XCUITest smoke uses the DEBUG fixtures for route viability and screenshot attachments only; it does not compare pixels.

Full verification runs all tests with parallel testing disabled, SwiftLint, `git diff --check`, a Release simulator build, and a binary-string scan proving the unique Forged fixture marker is absent. Codecov project and patch statuses remain at the repository's current 90% target with zero threshold.

## Delivery shape

The runtime redesign is one implementation PR. Tasks/commits are logical TDD slices, not separate PRs. The planning PR itself remains non-runtime: design/plan documentation plus the five canonical visual reference PNGs.
