# Forged Gameplay UI Redesign Design

## Status

Approved planning design for replacing Pyxis's current gameplay chrome with the supplied **Forged** mobile UI direction while preserving the shipping game rules, persistence, scene lifecycle, and feedback behavior.

The supplied 393×852 Battle, Camp, Map, Conquest, and Settings mockups are the visual reference. They are not an alternate gameplay specification. Whenever the mock's sample values or interactions conflict with the real game, the real models and existing gameplay contracts remain authoritative.

## Goal

Make the real SpriteKit game read like the Forged mock at a glance:

- dark iron surfaces with restrained gold edging and rivets;
- molten-amber primary actions;
- clearer top-to-bottom hierarchy;
- a persistent Battle / Camp / Map navigation bar;
- compact unit medallions instead of the current dropdown-first deployment controls;
- a radial empty-lot builder and focused occupied-lot inspector;
- a larger selected-city Map card;
- a stat-tile Conquest report;
- a safe-area-aware Settings bottom sheet.

The redesign must be proved against the real running game, not only against static mock data.

## Success criteria

The implementation is successful when all of the following are true:

1. At the authored 393×852 portrait reference size, the real Battle, Camp, Map, Conquest, and Settings surfaces closely match the Forged mock's geometry, hierarchy, and material treatment.
2. Every value shown in production comes from existing game state, combat state, authored catalog content, or feedback preferences. No mock number, reward, timer, unlock, unit count, or income rate is hardcoded as shipping data.
3. Existing gameplay remains intact: combat, building production, idle catch-up, economy, unlocks, persistence, routing gates, conquest restoration, settings pause behavior, layout gates, feedback, and milestone presentation.
4. States omitted from the happy-path mock remain intentional and legible: locked, unlocked-but-unbuilt, unaffordable, capped, selected, disabled, completed, current, country-complete, live conquest, idle conquest, missing MVP, zero achievements, settings combinations, and unsupported geometry.
5. The implementation PR includes a real-simulator parity board with mock / real / 50%-overlay comparisons and documents every deliberate discrepancy.

## Non-goals

This redesign does not add:

- a shared combat runtime that continues transient Battle simulation while Camp or Map is visible;
- a single replacement scene containing Battle, Camp, and Map;
- new combat, economy, building, unlock, lane, reward, idle, or progression rules;
- a persistent gold-per-second field solely to reproduce the mock's green `+6` sample;
- new save fields or save migration;
- new Country 1 content or Country 2 support;
- landscape support;
- SwiftUI, SceneKit, a third-party UI framework, a state-management package, or a snapshot-testing dependency;
- custom bundled fonts or a new asset-generation pipeline;
- a generic design-system framework, theme registry, component registry, scene framework, or fixture framework;
- broad gameplay accessibility work beyond preserving current Settings accessibility and maintaining usable hit targets;
- pixel-difference assertions in CI.

## Sources of truth

The redesign has two different sources of truth and must not confuse them.

### Visual source of truth

The final Forged reference set is:

- Battle: `3b.png`
- Camp: `2b.png`
- Map: `2c.png`
- Conquest: `2d.png`
- Settings: `2e.png`
- Interactive reference: `Pyxis 1b.dc.html`

The reference size is 393×852. Other supported portrait phone and iPad geometries must remain responsive and non-overlapping, but exact pixel parity is required only at the reference size because no authored iPad mock exists.

### Gameplay source of truth

Shipping Swift remains authoritative:

- `KingdomGameState` owns progression, economy, building mutations, unlocks, persistence-normalized state, and stage status.
- `BattleCombatState` owns the transient live roster, lane assignment, movement, attacks, tower damage, and losses.
- `Country1CityCatalog` owns city identity, traits, lane profiles, and flavor copy.
- `RecommendedCampRecommendation` owns the current small Camp recommendation policy.
- `BattleResult` and `ConquestReportContent` own real conquest evidence.
- `FeedbackPreferencesManaging` owns Sound Effects and Haptics.
- `GameViewController` remains the production scene router and feedback-runtime composition root.

The mock is allowed to shape presentation, not invent model semantics.

## Existing architecture to preserve

Pyxis currently uses three code-owned SpriteKit scenes:

- `BattleScene` owns transient `BattleCombatState` and battlefield rendering.
- `BuildingViewScene` owns the current city's 25-lot building interaction.
- `CountryMapScene` owns the 15-city authored route and entry flow.

`GameViewController` presents those scenes through their existing routing protocols. Leaving Battle with living manual soldiers is intentionally blocked because those soldiers exist only in `BattleCombatState`; changing scenes would silently discard the roster. That rule remains.

The Forged tab bar therefore provides a common navigation presentation, not a new common simulation owner.

## Approaches considered

### 1. Scene-local redesign plus small shared chrome — selected

Keep the three scenes and their current models. Add one shared Forged surface primitive and one shared tab bar, then build scene-specific pure layouts and render nodes around existing state and mutations.

This produces the mock's visual continuity without turning a UI project into a combat-runtime extraction.

### 2. One persistent gameplay shell with embedded scene modules — rejected

A shell could keep one tab bar and switch child surfaces while retaining Battle state. In practice it would require moving combat timing, lifecycle, layout-gate, settings-pause, effects, persistence handoff, and conquest ownership out of `BattleScene`. That is a separate architectural feature, not the cheapest path to the redesign.

### 3. Rebuild all gameplay UI in SwiftUI over SpriteKit — rejected

This would duplicate touch, coordinate, safe-area, animation, accessibility, and scene lifecycle behavior across UIKit, SwiftUI, and SpriteKit. The current code already has testable CoreGraphics layout seams and substantial scene coverage. Reuse them.

## Architecture

The implementation uses four layers only:

1. **Existing domain models** remain unchanged except for presentation-only projections where real state needs a typed display shape.
2. **Pure CoreGraphics layouts** compute frames and fail closed when required content cannot fit.
3. **Small SpriteKit render nodes** own visual tree construction, styling, hit frames, and readback for tests.
4. **Existing scenes and controller** map real state into those nodes and delegate interactions to existing mutations and routing.

There is no generic component framework. A shared type is justified only when at least two production surfaces consume it.

## Shared Forged chrome

### `ForgedSurfaceNode`

Add one focused SpriteKit primitive for repeated material treatment. It owns a small fixed node tree:

- shadow/base plate;
- dark iron fill;
- restrained top highlight;
- gold, amber, neutral, success, or danger border treatment;
- optional corner rivets.

It accepts a frame, corner radius, and closed `Style` enum. It does not parse theme dictionaries, generate assets, own text, or become a generic button class.

`GameUITheme` receives the shared color and metric constants. Existing semantic colors stay available until all current consumers are migrated; this task does not delete unrelated theme APIs merely for visual purity.

### `GameplayTabBarNode`

Add one shared Battle / Camp / Map tab bar with:

- closed `GameplayTab` enum;
- selected-tab state;
- optional Camp attention dot derived from the existing recommendation projection;
- three 44-point-or-larger hit targets;
- no routing logic and no persisted state.

Each scene owns one tab-bar instance, applies its selected state, and forwards a tapped tab to its existing router.

The attention dot appears on Battle or Map when `RecommendedCampRecommendation` is `.ready` or `.saveFor`; it is hidden while Camp is selected and for `.noAction`.

## Routing contract

`GameViewController` remains the only production router. Add a private helper that presents the requested `GameplayTab` using the existing scene constructors and shared feedback runtime.

Scene-specific behavior remains explicit:

- **Battle → Camp / Map:** call the current guards first. A living manual squad blocks the request and shows the existing feedback instead of losing soldiers.
- **Battle → Battle:** no-op.
- **Camp → Battle / Map:** settle or freeze building timing exactly as current scene lifecycle requires, save through the existing store, then route.
- **Map → Battle:** retain current active/unlocked entry semantics.
- **Map → Camp:** available only during `.battleActive`; route to the current city's Camp without changing progression.
- **Conquest visible or required report fit failed:** tabs are hidden or non-actionable; Continue remains the only progression action.
- **Country complete:** Map remains the stage destination and Battle/Camp tabs are not offered.

Do not keep the old World/Build/Battle navigation buttons for compatibility after the tab paths are complete. There are no external consumers, and duplicate navigation would weaken the hierarchy.

## Battle redesign

### Layout ownership

Add `BattleChromeLayout`, a pure CoreGraphics value that computes:

- resource and settings frames;
- city progress/title/HP frames;
- recommendation objective strip;
- left/right lane verdict chips;
- five unit medallion frames;
- Deploy frame and manual count frame;
- tab-bar frame;
- the safe battlefield top and bottom bounds passed to existing `BattlefieldLayout`.

At 393×852, its constants follow the authored mock: 16-point side margins, compact top bands, 56-point medallions, one full-width primary action, and a bottom tab bar that clears the safe-area inset. On other supported portrait geometries, it may reduce gaps and type size to tested floors; it must not overlay the battlefield or silently hide required controls.

### Presentation ownership

Add `BattleHUDNode` to render the chrome. It consumes one typed `Content` value projected by `BattleScene`:

- compact gold text;
- current city progress and authored title;
- city HP progress;
- current Camp recommendation;
- lane verdicts from `currentCityLaneDefenseProfile`;
- five unit presentation states;
- selected unit;
- manual squad count and cap;
- Deploy availability;
- tab selection and Camp attention.

Each unit medallion has one of three real states:

- **available:** at least one matching current-city building exists; selecting and deploying uses the highest matching building level through the existing `manualSoldierLevel(for:)` path;
- **unbuilt:** the building type is unlocked for the current city but no matching building exists; the medallion is visible but cannot be selected for deployment and points the player toward Camp;
- **locked:** the building type has not reached its existing unlock city; the medallion shows the real unlock city.

The multiplier badge comes from the existing trait adjustment: favorable 1.25×, disadvantaged 0.80×, otherwise 1.00×. It is presentation only; combat still uses `traitAdjustedSoldierAttackPower`.

The mock's persistent green income number has no shipping equivalent. Omit it from the stable resource strip. Existing transient gold reward feedback remains responsible for earned-gold moments.

### Interaction

- Tapping an available medallion changes `selectedManualSoldierType`.
- Tapping an unbuilt medallion shows the existing build-first invalid-action feedback and may highlight the Camp tab; it does not route automatically.
- Tapping a locked medallion shows the real unlock city.
- Deploy calls the current `spawnSoldier()` path.
- Existing manual cap, state-stage, report, Settings, feedback, sound, haptic, and persistence gates remain.

The current dropdown, separate Spawn button, World button, and Build button are removed when parity tests prove the new controls cover their behavior.

## Camp redesign

Keep the countryside backdrop, 25 authored scenic lot positions, real slot state, and existing build / upgrade mutations.

### Empty lot

Selecting an empty lot opens one radial build wheel centered around that lot. Every `BuildingType` appears; the prototype's four-choice sample is not allowed to omit Siege Workshop in production.

Each option has one projected state:

- available with real cost;
- unaffordable with real cost;
- locked with real unlock city;
- capped with the existing maximum-per-type value.

A valid option calls the existing `buildSelectedSlot(_:)` path exactly once. Invalid options are consumed and use current invalid-action feedback. The wheel closes after a successful build, when another lot is selected, when Settings opens, when a tab is chosen, or when layout becomes unsupported.

### Occupied lot

Selecting an occupied lot shows a compact inspector above the tab bar with:

- real building image and name;
- current level and level pips;
- lot number;
- produced soldier identity;
- one Upgrade action with real cost and enabled state.

Upgrade delegates to `upgradeSelectedSlot()` exactly once. Existing settlement-before-mutation behavior, persistence, feedback, and conquest-during-settlement remain unchanged.

### Recommendation integration

Do not create a second recommendation policy. `RecommendedCampRecommendation` drives:

- the Battle objective strip;
- the Camp attention dot;
- a highlight on the recommended lot;
- emphasis on the recommended radial option or Upgrade action.

The current prose-heavy recommendation row can be removed after those real consumers are in place.

## Map redesign

Keep the authored backdrop, 15 city anchors, route definitions, visual-state computation, feedback kinds, flavor behavior, safe-area validation, and layout gate.

### Selection

Add scene-local `selectedCityNumber`, defaulting to the current unlocked city, current active city, or final city for country completion. Tapping any city selects it and updates the large card; selection itself does not mutate `KingdomGameState`.

### Typed card states

Extend the current map-card projection to represent the selected city explicitly:

- attackable/unlocked;
- current active city;
- completed;
- locked;
- country complete.

The large card shows authored identity and only real data:

- city number and name;
- reward where a future conquest reward exists;
- trait and short description;
- favorable and disadvantaged unit portraits with their real multipliers;
- exposed lane;
- state-specific primary action.

`March` is enabled only when existing entry rules allow entry. The current active city action returns to Battle without restarting it. Locked/completed cards keep current non-mutating feedback behavior. Tapping the informational body still surfaces flavor text as a non-blocking overlay without disabling an otherwise valid March action.

### Layout

Extend `CountryMapLayout` rather than creating a second map geometry authority. Reserve frames for:

- shared resource/settings strip;
- country title and 15 progress pips;
- illustrated map region;
- large selected-city card;
- shared tab bar.

Phone and iPad remain explicit layout classes. The 393×852 phone layout targets mock parity; iPad uses the same content hierarchy with larger spacing and tested containment.

## Conquest redesign

Keep `BattleResult` persistence and battle-finalization semantics unchanged. Replace the text-row-only display projection with typed presentation content.

`ConquestReportContent` owns:

- title and city identity;
- formatted reward;
- an ordered array of two or three typed stat tiles;
- zero to two named achievement chips;
- country-complete flag.

Tile rules:

- live with MVP: MVP, battle time, sent/lost;
- live without MVP: battle time and sent/lost, centered as two tiles;
- idle with MVP: MVP, Buildings, sent/lost;
- idle without MVP: Buildings and sent/lost, centered as two tiles.

Do not invent an MVP, neutral filler statistic, or third placeholder tile. Achievement chips are omitted when absent and the layout collapses their reservation. The existing Continue action becomes `March On` visually but keeps the same acknowledge-save-route behavior and disabled transition window.

`ConquestReportLayout` remains the single pure nil-on-required-fit authority and continues to reserve Country 1 completion content when required.

## Settings redesign

Keep `FeedbackSettingsController`, `FeedbackPreferencesManaging`, `FeedbackSettingsAccessibilityAdapter`, and the two existing settings.

Change only layout and rendering:

- safe-area-aware bottom sheet;
- dim scrim;
- optional drag-handle decoration with no drag behavior;
- Sound Effects and Haptics rows with icons and switch visuals;
- full-width Done action.

The SpriteKit switch is a visual representation of the existing row action, not a UIKit `UISwitch`. Existing accessibility elements remain the accessible controls. Opening Settings still freezes Battle actions, modal touches remain consumed, close restores focus, and unsupported geometry closes/fails through the existing controller contract.

## Visual parity fixtures

Real-versus-mock comparison requires deterministic real screens. Add one DEBUG-only, redesign-specific fixture seam rather than a general fixture framework.

`ForgedVisualFixture` is a closed enum selected by launch argument:

```text
-pyxis-forged-fixture battle
-pyxis-forged-fixture battle-blocked
-pyxis-forged-fixture camp-empty
-pyxis-forged-fixture camp-occupied
-pyxis-forged-fixture map
-pyxis-forged-fixture map-country-complete
-pyxis-forged-fixture conquest-live
-pyxis-forged-fixture conquest-idle
```

The fixture overwrites only the test/development save when the explicit DEBUG argument is present. It reuses normal `KingdomGameState`, `CityBattleState`, `ActiveSiegeSession`, and `BattleResult` initialization. It does not add a fixture file format, registry, JSON, production flag, or Release symbol.

A second DEBUG launch argument may freeze combat advancement during screenshot capture. It pauses only the Battle tick; it does not change normal DEBUG behavior without the explicit argument.

Release verification must prove the fixture marker is absent from the built binary.

## Real gameplay versus mock parity contract

Parity is not “the screenshot looks similar.” Every reviewed surface must pass both columns.

| Surface | Visual parity | Real gameplay parity |
| --- | --- | --- |
| Battle | Forged top bands, lane chips, five medallions, Deploy, tabs | Real gold, city, HP, recommendation, lane profile, unit availability, multipliers, manual cap, blocked routing, conquest and Settings behavior |
| Camp | Scenic lots, radial wheel, inspector, tabs | All 25 lots, all five building types, unlocks, affordability, caps, recommendation, settlement, upgrade/build outcomes, conquest during settlement |
| Map | Progress pips, selected-city card, March, tabs | Current/unlocked/locked/completed/country-complete states, authored route, flavor and blocking feedback, safe-area/layout gate |
| Conquest | Crest/title, reward, stat tiles, chips, March On | Live/idle mode, optional MVP, real counts/time, zero achievements, restored report, finale completion |
| Settings | Bottom sheet, icon rows, switches, Done | Persisted independent toggles, accessibility actions, focus restoration, Battle pause, modal touch precedence |

## Required parity evidence

The implementation PR must include a comparison board generated from the real simulator at 393×852. For each required state, include:

1. the supplied mock;
2. the real implementation screenshot;
3. a 50% alpha overlay;
4. a short discrepancy note only when the difference is deliberate and grounded in real gameplay.

Minimum states:

- Battle normal;
- Battle locked/unbuilt units;
- Battle blocked Camp/Map request with a living manual squad;
- Camp empty-lot radial wheel;
- Camp occupied-lot inspector;
- Camp unavailable building option;
- Map attackable city;
- Map locked or completed city;
- Map country complete;
- Conquest live with MVP;
- Conquest idle without MVP;
- Settings with one toggle off.

Review order is fixed:

1. geometry and safe areas;
2. information hierarchy and primary-action prominence;
3. typography and material treatment;
4. semantic correctness of every value;
5. omitted-mock state coverage;
6. interaction and minimum hit-target size.

The comparison board is a merge gate. Automated layout tests do not replace it.

## Testing strategy

### Pure tests

Test every new layout and presentation projection without an attached scene:

- frame containment and non-overlap at 393×852, the smallest supported phone, and current iPad fixtures;
- exact five-medallion and three-tab counts;
- 44-point minimum hit frames;
- unit locked/unbuilt/available projection;
- Camp option available/unaffordable/locked/capped projection;
- selected-city card states;
- two- and three-tile Conquest layouts;
- bottom-sheet Settings geometry.

### Scene tests

Extend the existing Battle, Building View, Country Map, Conquest, Settings, and controller suites to prove:

- state-to-content mapping;
- tap priority;
- existing mutations are called once;
- blocked navigation preserves combat;
- report and Settings modal precedence;
- lifecycle and layout-gate behavior;
- no duplicate nodes after resize or redraw.

### UI smoke

Use the DEBUG fixtures for one coordinate-based 393×852 XCUITest smoke:

`Battle -> select available unit -> Deploy -> blocked Map -> relaunch Camp fixture -> build or upgrade -> Map -> March/current Battle -> Settings toggle -> Conquest Continue`.

The UI smoke proves route viability and screenshot capture. It does not assert pixels or replace scene-level semantic tests.

### Full verification

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO

swiftlint lint --no-cache

git diff --check origin/main...HEAD
```

Codecov project and patch statuses must remain at or above the repository's current 90% target with zero threshold. Do not weaken the gate for the redesign.

## File boundaries

Expected new production files:

- `Pyxis/ForgedSurfaceNode.swift`
- `Pyxis/GameplayTabBarNode.swift`
- `Pyxis/BattleChromeLayout.swift`
- `Pyxis/BattleHUDNode.swift`
- `Pyxis/CampChromeLayout.swift`
- `Pyxis/CampSelectionNode.swift`
- `Pyxis/ForgedVisualFixture.swift` (`#if DEBUG` body)

Expected existing production files to modify:

- `Pyxis/GameUITheme.swift`
- `Pyxis/GameViewController.swift`
- `Pyxis/BattleScene.swift`
- `Pyxis/BuildingViewScene.swift`
- `Pyxis/CountryMapLayout.swift`
- `Pyxis/CountryMapScene.swift`
- `Pyxis/CountryMapScoutCardContent.swift`
- `Pyxis/CountryMapScoutCardLayout.swift`
- `Pyxis/CountryMapScoutCardNode.swift`
- `Pyxis/ConquestReportContent.swift`
- `Pyxis/ConquestReportLayout.swift`
- `Pyxis/ConquestReportNode.swift`
- `Pyxis/FeedbackSettingsLayout.swift`
- `Pyxis/FeedbackSettingsNode.swift`
- `CLAUDE.md`

New files are discovered by synchronized Xcode groups. Do not edit `project.pbxproj` merely to register them.

The implementation may keep a scene-specific renderer inside its existing scene when it remains small. It must not create parallel layout authorities or split files solely to match this estimate.

## Delivery shape

This design is implemented in one PR. The plan uses logical TDD tasks and commits, but there is no separate runtime PR per screen.

The implementation PR is expected to be large because the mock changes five connected surfaces. Splitting those surfaces across separately mergeable PRs would leave the app in a visually inconsistent half-redesigned state and would duplicate temporary compatibility chrome. One branch and one final parity gate are the simpler delivery path.

## Deferred architectural follow-up

A future requirement may ask Battle combat to continue while Camp or Map is visible. That work would need an explicit design for transient roster ownership, tick/lifecycle ownership, conquest while another surface is mounted, effects, save recovery, and routing. It is not implied by the tab bar and must not be smuggled into this redesign.
