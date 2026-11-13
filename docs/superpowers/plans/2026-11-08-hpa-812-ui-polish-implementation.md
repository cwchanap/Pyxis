# HPA-812 — Cross-scene UI polish: single-PR implementation plan

**Linear:** https://linear.app/cwchanap/issue/HPA-812/polish-ui-rough-edges-across-camp-map-kingdom-and-battle  
**Design:** [HPA-812 UI polish design](../specs/2026-11-08-hpa-812-ui-polish-design.md)  
**Baseline:** cwchanap/Pyxis main@bb390f08fa68c5c4ce6e349fad3d67dbe791b144 (after the HPA-811 merge).  
**UAT reference:** main@98c9d35, iPhone 17 simulator, per Linear issue.  
**Delivery:** One HPA-812 PR, beginning as a draft with these two planning documents. Continue all implementation, tests, screenshots and review fixes **on this same PR**, and do not merge docs alone or open a second implementation PR. No production code has changed in this planning checkpoint.

## Architectural decisions

Keep SpriteKit scenes as presentation owners and the current pure geometry helpers as the only layout authorities: CampChromeLayout, CountryMapLayout, KingdomLayout, BattlefieldLayout and ConquestReportLayout. Reuse existing GameUITheme, PanelNode, GameplayTabBarNode, Settings controller, gold icon assets and forged treatment; do not introduce a new design system, event bus, animation-pool abstraction, scroll framework or new saved fields.

HPA-812 changes only rendering/interaction affordances. Preserve KingdomGameState/BattleCombatState calculations, gold, equipment cycles, the exact map authored anchors, idle catch-up, stage routing, the pending conquest report, Ascension's two-tap confirmation and existing 44pt accessibility hit targets. No new image art, music, SFX or haptics. Any genuinely needed new art/SFX is a *separate* task outside HPA-812.


## Checkpoint 0 — Targeted baseline and existing screenshot rigs

**Code provenance checked:** Between UAT `main@98c9d35` and planning `main@bb390f0`, the only changed production files under `Pyxis/` are `KingdomGameState.swift` and `KingdomScene.swift` (HPA-811); the other scenes' presentation owners are unchanged. **Do not manually reproduce all 17 historical issues again** before work. The original HPA-812 UAT report, backed by code inspection, is the baseline for #1–#10 and #15–#17. **Re-verify #11–#14 on a simulator** because KingdomScene changed. This is source provenance, not new visual proof of the unresolved bugs.

1. On unchanged baseline main, run existing `PyxisUITests.testForgedFixtureParitySmoke393x852` for `camp-empty`, `camp-occupied`, Map variants, `map-country-complete`, `conquest-live` and related captures; run `testHPA672AscensionFlowEvidence` for Kingdom Ascend/Confirm and Armory. Preserve the XCTest attachments as the baseline. The parity smoke skips viewports other than logical **393×852**.
2. Identify the few visual coverage gaps: **unfrozen busy Battle** for repeated gate hits/formation (#15/#16), and optionally **Camp with no selection**. Capture by hand or add at most one focused screenshot fixture **on this same PR branch**; do not modify the baseline branch merely to capture before images.
3. Run relevant focused baseline tests and record existing geometry constraints; in particular, `CountryMapSceneTests` currently *expects* the City 2/card overlap in multiple tests. Those assertions must be revised when #6 removes the overlap, while city-selection precedence and blocking/nonblocking overlays remain guarded.
4. List the 17 outcomes as **historical UAT confirmed by unchanged presentation source**, **Kingdom rechecked**, or **needs post-fix visual confirmation**. Do not claim a new simulator run from source inspection or docs-only commits.

**Gate:** Existing visual evidence is collected where available, Kingdom's four observations are rechecked, and any truly new capture fixture is narrowly scoped.


## Checkpoint 1 — Camp stability, affordability and feedback (#1–#5)

**Production:** `Pyxis/CampChromeLayout.swift`, `CampSelectionNode.swift`, `BuildingViewScene.swift`. **Tests:** `CampChromeLayoutTests.swift`, `CampSelectionNodeTests.swift`, `BuildingViewSceneTests.swift`.

1. **Red layout tests for #1/#2:** At the same size/insets, compute `.none`, `.emptyLot` and `.occupiedLot` and assert all 25 lot centers/hit frames are identical. **First compact the palette to 114pt** (the existing inspector height), then replace the 0/174/114 selection-height switch with one `selectionBudget = 114` regardless of selection; the panel is still hidden when nothing is selected. Pin reference 393×852 (59/34 insets) lot-region height to **469pt**, and assert **320×568 with zero insets** still fits above the 180pt region floor. This is a 21% reference-grid shrink rather than a needless 31% shrink from reserving 174pt.
2. **#2 five cards:** Remove staggered `yOffsets`; fit all options (≥44pt hit targets) within the 114pt builder region. Place name and status/cost above the panel's bottom border, remove excess top whitespace, and test text/visual containment with longer prices/locked labels and recommended badges.
3. **#3 both sites:** Add one small `CampSelectionNode.actionStyle(isRecommended:isActionable:actionableStyle:)` mapping **disabled first**, then selected/recommended, then the caller's actionable fallback. Call with `.normal` for builder option cards and **`.primaryAction` for occupied-lot inspector Upgrade**. A two-boolean helper without the fallback would silently flatten the inspector's primary action to an ordinary card. Keep a visible recommendation marker for unaffordable `saveFor` actions, and assert both unavailable variants look disabled and cannot mutate the state.
4. **#4/#5:** Give transient status text a compact high-contrast backplate or shadow on grass (no new notification service). Use the existing **`gold-burst`** asset for Camp's gold HUD (Map and conquest report already use it; Battle's procedural texture is private), fitting image and formatted count inside the current panel.
5. Run focused Camp tests and visually check no-selection → empty-lot builder → occupied-lot inspector → upgrade without any lot movement.

**Gate:** Constant 114pt selection budget, invariant lot hit frames, 320×568 support, aligned/unclipped cards, disabled recommended cards *and* upgrade button, legible status/gold.


## Checkpoint 2 — Map city clearance, progress geometry and completion copy (#6–#9)

**Production:** `Pyxis/CountryMapScoutCardLayout.swift` (**primary owner of #6**), `CountryMapScoutCardNode.swift` (fit/repack its phone content), `CountryMapLayout.swift` (**owner of #8**), `CountryMapScene.swift` (application only). **Tests:** `CountryMapScoutCardLayoutTests`, `CountryMapScoutCardNodeTests`, `CountryMapScoutCardAcceptanceTests`, `CountryMapLayoutTests`, `CountryMapSceneTests`.

1. **#6 fix the true overlap source:** `CountryMapScoutCardLayout.phone` currently creates `cardFrame` at **`informationRegionFrame.minY - 24`** with **`informationRegionFrame.height + 72`**, so the card top bleeds **48pt above** the region into the illustrated map. Change ordinary-phone card geometry to fit **inside the existing `informationRegionFrame`** (compact phone/pad already do), rather than shrinking the map or moving City 1/2 anchors. At 393×852 the 236pt rendered card becomes a **164pt** reserved phone card. **Do not simply change the outer CGRect:** reflow its currently height-236-dependent Scout content and actions so title, trait/tactical info, reward and 44pt Attack all fit inside the contained card; compact spacing and optional decoration rather than hiding required Scout information. Preserve existing measured text-fit/fail-closed rules. Adjust `CountryMapScoutCardLayoutTests.referencePhoneMatchesAuthoredForgedCardGeometry` (currently pins `CGRect(x:16,y:90,width:361,height:236)`) and dependent offset/layout tests to the new card. Assert `informationRegionFrame.contains(cardFrame)` and its required children, and City 1/2 hit frames disjoint from card/overlay on the 393×852 fixture. Leave `CountryMapLayout`'s map envelope, route transform and portrait gates intact.
2. **#6 preserve touch priority, then #7 copy:** Current `CountryMapSceneTests` tests explicitly tap a City 2/card or City 2/overlay intersection on the reference fixture. Replace those **ordinary 393×852** overlap assertions with no-intersection geometry, **but keep one intentional overlapped test setup** via a tiny test-only card/overlay frame seam (or a demonstrably reachable supported compact overlap) that actually executes the existing city-over-card/overlay branch. Confirm Attack still has priority over ordinary card flavor and blocking/nonblocking feedback does not re-enable a forbidden action. Do not build a general test-layout injection framework. Then render the country-complete card's fitted second line **“Next: Kingdom → Ascend to begin again.”** with no new navigation/button or Attack hit target.
3. **#8 pure geometry owner:** Move the progress-pip/label split from `CountryMapScene` into `CountryMapLayout`. Add `progressLabelFrame` and `progressSegmentFrames` (15), reserve a constant for the widest 11pt bold `15/15` plus **≥4pt separation**, and fit pips into the remaining available width. A **36pt label reservation, 4pt gap, and compact 1.5pt segment spacing** is a starting fit for the ~93pt progress width at 375pt phone widths; test rendered font width rather than assuming. Keep ≥2pt pip widths, allow padding/gap tuning inside this pure owner, and test no intersection at 0/15, 9/15 and 15/15; one scene test proves actual `15/15` fits the reserved label frame.
4. **#9:** Replace visible flat bands with existing theme/background blending, strictly scene decoration. Do not resize/stretch the map art or change hit frames.
5. Run Map/scout tests and compare existing `map` / `map-partial` / `map-country-complete` fixture screenshots at 393×852.

**Gate:** The first two cities are visibly unobstructed, completed state points to Kingdom → Ascend, pure progress geometry doesn't overlap, existing map route/overlay contracts still hold.


## Checkpoint 3 — Shared tabs and Kingdom (#10–#14)

**Production:** `Pyxis/GameplayTabBarNode.swift`, `KingdomLayout.swift`, `KingdomScene.swift`. **Tests:** `GameplayTabBarNodeTests`, `KingdomLayoutTests`, `KingdomSceneTests`, `GameViewControllerTests`.

1. **#10:** The forged `GameplayTabBarNode.applyForgedCell` currently treats disabled and enabled-unselected alpha almost identically. Distinguish muted disabled icon/title/**tile** from enabled-unselected, keep the selected state strong and locked hits omitted. Test pending/complete/active stages in the shared node, without scene-specific copies.
2. **#11:** Reproduce overflow in the existing forged header on device before editing. Inset pills/Settings visible bezel and give `goldLabel` a real leading inset while retaining 44pt targets, one Settings control, adequate gold/renown widths, and layout-gate behavior. Verify visible nodes, not only container `CGRect`s.
3. **#12 in *both* row bands:** `KingdomLayout.treasuryBandFrames` and `armoryBandFrames` each currently stack from `rowsTop`. Center the existing three/five-row groups vertically in their respective available bands when rows cap below maximum height, rather than leaving a giant lower blank. Preserve current row heights, gaps, 44pt actions and compact-phone fit. No filler, scrolling or extra layout owner. Test both sections at tall and compact sizes.
4. **#13 chevron without HPA-811 text regression:** Add a **separate trailing chevron frame** in `KingdomLayout` entirely in the existing ~10pt row trailing margin **outside** the current `armoryTextFrames` (small ~8pt marker). Do **not** subtract marker width from the text frames: HPA-811 already drops `(atk X → Y)` on text overflow. Test **identical text-frame widths to the baseline** across compact/tall layouts. In `KingdomScene`, show chevron only when gear is owned, retain the existing whole-row cycle and attach a concise VoiceOver cycling hint to its existing action element — not a new accessible control.
5. **#14:** Inset only the *visual* armed Confirm Ascension fill/glow so it stays inside the panel border while preserving the existing action's ≥44pt tap frame, two-tap flow and Cancel. Check the narrowest supported Kingdom layout and screenshots.
6. Re-run tab/Kingdom/controller tests; use `testHPA672AscensionFlowEvidence` for the Ascend prompt, armed/Cancel and Armory before/after screenshots.

**Gate:** Locked tabs look disabled, both sections use tall-screen space, Kingdom header/actions are contained, Armory visibly conveys cycling without narrowing text.


## Checkpoint 4 — Battle-only presentation clarity (#15–#17)

**Production:** `Pyxis/BattleScene.swift`, `ConquestReportNode.swift`, optionally current `BattlefieldLayout.swift` if necessary. **Tests:** `BattleSceneTests`, `BattleSceneCoverageTests`, `ConquestReportNodeTests`, `BattlefieldLayoutTests`.

1. **#15 one label per objective, no animation drift:** Same-tick `SoldierAttackEvent`s are already grouped by `objectiveID`; repeated later ticks currently spawn overlapping labels and existing SKActions use relative `moveBy(0,14)` and `moveBy(0,50)`. Add scene-local `[String: SKLabelNode]` for **damage-only** labels. When updating an attached objective label, cancel the current action, **replace text with the latest tick's aggregated damage** (do not accumulate indefinitely across ticks), then reset to the existing authored *initial* transform **before restarting the same action**: `position = CGPoint(x: impactPoint.x, y: impactPoint.y - 20)`, `alpha = 0`, `setScale(reduceMotion ? 1 : 0.7)`. Using the bare impactPoint or keeping the animated y would shift the label or compound upward drift. Treat detached labels as stale; clear references on combat/effect teardown. Keep independent structure-fall labels and damage/event/SFX semantics unchanged. Add a synchronous repeated-gate-hit test asserting a single visible objective damage label, latest per-tick text, and the reset origin/alpha/scale after each restart; ensure separate objective IDs each have their own label. Do not rely on SKAction timers advancing or the request counter `floatingFeedbackTextsForTestingStorage`.
2. **#16:** Tune `SoldierFormation` visual spacing and overflow placement *in BattleScene only*, compress/wrap visual formation rows within a lane before they all clamp to the same battlefield-floor Y. Check dense-lane soldier body/HP visibility and gate overlap on representative portrait layouts. **Never** change combat positions/lanes, HP, tower targets, spawn counts, damage or saved state. A small private geometry helper is fine; a new combat-layout subsystem is not.
3. **#17:** Replace fixed 32×32 `takenMedallionIcon.size` with a proportional size based on `takenMedallionFrame`'s 96/118pt diameter while preserving the ring, “TAKEN” and safe-area clearances. Add compact/reference presentation tests.
4. Capture **unfrozen** repetitive-hit/busy-soldier screenshots separately from the frozen parity fixtures; exercise Reduce Motion and conquest completion.

**Gate:** Repeated gate hits display one reused label per objective without upward drift or unbounded accumulation, overcrowding is visibly improved without simulation changes, and the conquest crest has balanced proportions.

### Crowded-lane follow-up

The phone mock-up review found a live, five-Barracks pile beyond the original
nine-soldier fixture. Replace the unpushed formation-only experiments with
the approved representative presentation: show a readable bounded group,
count omitted living soldiers in a per-lane `+N`, prioritize the Captain and
actual combat-selected target, and allow folded deaths to finish without an
on-screen animation. Retain the earlier damage-label work and all unrelated
scene changes. Do not rewrite commit history or create another worktree.

1. Write failing behavioral regressions for genuine crowded production,
   truthful live overflow, target/Captain priority, a pending casualty and a
   paused resize; verify the failures execute for the intended reasons.
2. Simplify the existing formation presentation to a small bounded visual
   selection/geometry policy. Keep gameplay, model positions, targeting,
   spawns, saves, damage, feedback, routing and existing controls untouched.
   Keep visible soldier bodies and individual HP bars readable; do not
   require transparent sprite canvases or transient weapon reach to be
   disjoint. Do not introduce a general collision/path solver.
3. Run focused Battle and related suites serially; run SwiftLint without
   errors. Capture an unfrozen crowded phone battle and a live-tower case,
   with seed and evolved-save provenance, and review against the mock-up.
4. Review the resulting implementation and report any remaining visual or
   test limitations. iPad visual validation is explicitly skipped; real
   VoiceOver traversal remains unverified without a supported device.


## Checkpoint 5 — Focused tests, existing screenshot rigs, final CI

1. Do TDD at each pure layout/scene checkpoint, then run the full Swift Testing unit suite and XCTest UI suite serially (`-parallel-testing-enabled NO`) plus SwiftLint and GitHub CI:
   
       xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
       swiftlint lint

   Check `xcodebuild -showdestinations` and record the actual installed device if iPhone 17 is unavailable.
2. **One screenshot viewport**, not four redundant suites: use `testForgedFixtureParitySmoke393x852` + `testHPA672AscensionFlowEvidence` at baseline and final branch for before/after evidence. Supplement only an **unfrozen combat** capture for #15/#16 and, if needed, **Camp no-selection**. Other supported viewport coverage belongs in **pure layout tests** at 320×568 for Camp/Kingdom; 375×667 and 393×852 for supported Map; and iPad portrait (e.g. 834×1194), with resize/gate recovery.
3. Validate action semantics: Camp build/upgrade affordability and distinct normal builder vs primary Upgrade styling, Map City 1/2 entry **and intentional synthetic-overlap touch precedence** over Scout card/overlays, Scout Attack priority, finished-run Map→Kingdom, locked tabs, Armory cycling/accessibility, two-tap Ascension and pending report, idle/background progression and scene reconstruction. These are visual fixes; the optional 15-city *balance* campaign isn't necessary unless implementation unexpectedly changes a balance constant (out of scope).
4. Post one **17-item disposition table** in this PR: source-confirmed versus Kingdom device-rechecked baseline, specific code/test changes, screenshot before/after when applicable, remaining uncertainty. Don't mark all items “fixed” just because code landed.
5. Review the final diff, address all valid follow-up comments **on this same branch**, and mark ready only after the tests, app screenshots and review are complete. CLAUDE.md needs updating only for a true persistent architecture convention, not minor layout polish.

**Gate:** All changed visuals and existing interactions are verified, no unreviewed code churn, draft is ready only with measured test and screenshot evidence.

## Guardrails and stop conditions

- **One ticket → one PR:** Do not merge planning documents alone; continue implementation, tests and review revisions here.
- Do not change saved format, gameplay/economy formulas, combat/event semantics, map source-city coordinates, launch/router contracts or accessibility hit minima.
- If a fix makes the accepted 320×568/portrait iPad layouts unsupported or causes a hard geometry conflict, record the failing fixture and revise this same design/plan rather than bypassing guards.
- Distinguish an originally reported visual problem from an actual reproduced issue on today's main. Keep no-op/unchanged cases explicitly noted and avoid speculative fixes.
- No art or SFX generation in this coding ticket. If new assets become truly necessary, create a separate asset task using an available Graveyard placeholder and leave the visual issue pending that dependency.

**Current checkpoint (second review pass):** Planning files only, updated for the eight initial and four follow-up design-review findings; no simulator, Xcode build, tests, UAT or production implementation occurred in this planning revision. Checkpoints 0–5 remain follow-on work **on this same PR**.
