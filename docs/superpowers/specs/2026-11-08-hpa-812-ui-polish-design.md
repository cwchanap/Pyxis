# HPA-812 — Camp, Map, tab bar, Kingdom and Battle UI polish: design

**Linear:** https://linear.app/cwchanap/issue/HPA-812/polish-ui-rough-edges-across-camp-map-kingdom-and-battle  
**Planning baseline:** cwchanap/Pyxis main@bb390f08fa68c5c4ce6e349fad3d67dbe791b144 (after merged HPA-811).  
**UAT reference:** iPhone 17 simulator at main@98c9d35, as described in HPA-812.  
**Delivery:** This specification and the [paired implementation plan](../plans/2026-11-08-hpa-812-ui-polish-implementation.md) start **the one HPA-812 PR**. Implementation, tests, screenshots, and review fixes remain in that same PR. Do not merge a docs-only draft.

## Problem and approach

UAT logged 17 usability/presentation problems across existing gameplay screens. They are mostly layout, affordance, contrast or transient feedback problems; the current game flows work. This is **not** a screen redesign. Review the existing UAT evidence against the planning baseline rather than reproducing all 17 screens twice. Comparison of `98c9d35...bb390f0` shows only `KingdomGameState.swift` and `KingdomScene.swift` changed under `Pyxis/`; re-verify **#11–#14 on device** because they can have changed since UAT. Other presentation-owner source is unchanged: retain the original UAT observations, cite the responsible current code, and visually confirm the *fix* after implementation. Do not label code inspection as a new visual smoke pass.

Use the existing SpriteKit scene and pure layout owners. Prefer small changes to geometry, text, colors and visual feedback over new widgets or frameworks. Reuse current art and forged UI components. Preserve game rules, saved-state format, idle/campaign transitions, routing, Settings accessibility, combat damage, soldier positions in the simulation, map-city anchors and the portrait layout gate.

## Player-facing decisions and file ownership

### Camp — findings 1–5

| UAT # | Desired behavior | Minimal owning change |
| --- | --- | --- |
| 1. Moving lots | Lot centers and hit frames do not move when selecting no lot, an empty lot or an occupied lot at the same viewport. First compact the builder palette to **114pt**, matching the existing inspector, then reserve the same `selectionBudget = 114` across all selection states. This leaves a **469pt** lot region on 393×852 (rather than the original 593pt unselected or 409pt with a permanently reserved 174pt panel), and keeps room above the 180pt layout floor on 320×568 without top insets. | CampChromeLayout: a single selection-independent budget; BuildingViewScene continues applying its layout. Test the exact reference-region height and 320×568 support. |
| 2. Uneven/clipped palette | Five option cards share a baseline and consistent height **inside the 114pt builder panel**; all name/cost text stays within the panel border, with reduced unused top whitespace. Every 44pt minimum hit target remains usable. | CampChromeLayout: remove staggered `yOffsets`; CampSelectionNode: inset/fitted name and cost lines. |
| 3. Unaffordable recommended actions | **Both** builder-palette cards (including `saveFor` recommended builds) and occupied-lot upgrade buttons render as disabled when locked, capped or unaffordable, even when recommended; keep the recommendation marker visible. Existing explicit “Need N gold” feedback on tap may remain, but no purchase happens. | CampSelectionNode: one small `actionStyle(isRecommended:isActionable:)` function with **disabled → recommended → normal** precedence, applied in both palette and inspector. Keep CampSelectionContent and KingdomGameState as action authorities. |
| 4. Low-contrast status | Short transient messages remain legible over grass; use a restrained forged/dark backplate or shadow with existing theme text colors, not a new notification service. | BuildingViewScene feedback label/presentation. |
| 5. Missing gold icon | Camp gold HUD uses the existing **`gold-burst`** image asset (as on the Map; Battle uses a private procedural texture), fitted inside the current gold panel without clipping the count. | BuildingViewScene; no new art or duplicated BattleHUD texture helper. |

**Layout tradeoff:** a shared **114pt** selection budget shrinks the reference-phone scenic lot region from 593pt unselected to 469pt (−21%), but removes the 60–120pt movement when changing selection. A 174pt always-reserved panel would unnecessarily shrink it to 409pt (−31%) and leave the 320×568 case perilously close to its 180pt floor; do not choose it. Require invariant lot centers and 44pt hit frames across `.none`, `.emptyLot` and `.occupiedLot`, plus explicit compact-phone geometry tests.

### Map — findings 6–9

| UAT # | Desired behavior | Minimal owning change |
| --- | --- | --- |
| 6. Scout card obscures early cities | At the initial run, cities 1 and 2, current-city marker and their 44pt hit frames are fully visible and reachable, separated from the card. Preserve the authored relative city/route positions on the backdrop; do not patch individual anchors. | CountryMapLayout envelope/card spacing and CountryMapScene application, only if still reproducible on current main. |
| 7. Empty country-complete card | Use existing country-complete card to show a compact two-line outcome and clear next step: “Kingdom → Ascend to begin again.” No new navigation or Ascension rule; the Kingdom tab already exists. | CountryMapScoutCardNode complete-state copy/layout; keep its Attack target absent. |
| 8. Progress pips hit 15/15 | The 15 pips and 0/15…15/15 labels have non-overlapping **pure-value** frames. Reserve fixed width for the widest closed-set label (`15/15`, 11pt bold) **plus a nonzero gap**, and fit the 15 segments in the remainder (adjust segment spacing as needed for the narrowest supported Map viewport). | CountryMapLayout owns new `progressLabelFrame` and `progressSegmentFrames` derived from the existing `progressFrame`; CountryMapScene only applies them. A scene test verifies rendered `15/15` fits its reserved frame. |
| 9. Hard dark bands | Replace abrupt empty flat-color bands above/below the art with a subdued treatment from the existing theme or texture; do not stretch or remap the interactive illustration and do not generate a new background asset. | CountryMapScene visual background layers only; geometry and hit testing unchanged. |

**Map contract:** CountryMapLayout is the sole source for the portrait map's interaction envelope. Its existing support/fail-closed behavior, source-art registration, route checks, card overlays and feedback action gating are requirements; do not bypass them to make a screenshot appear correct. Validate actual rendered overlap as well as model frames.

### Shared tab bar — finding 10

The locked Battle/Camp tabs during post-conquest Map/Kingdom navigation must look *meaningfully* disabled, unlike the current forged treatment that gives enabled unselected and disabled icons almost the same opacity. Use a distinct muted icon/label and disabled tile appearance in **GameplayTabBarNode**. Keep the existing disabled hit-frame omission and the controller's pending-report routing. No toast or new event bus is necessary. If an accessibility action is exposed, its enabled status must agree with the visual state.

### Kingdom — findings 11–14

| UAT # | Desired behavior | Minimal owning change |
| --- | --- | --- |
| 11. Header overflow | Selector pills, Settings visual bezel and gold count fit *visually* inside the header (not merely mathematically inside hit frames). Gold gains a real leading inset; selector and gear hit targets still meet 44pt. | KingdomLayout positions plus KingdomScene panel/label insets; retain one Settings control. |
| 12. Empty lower Treasury/Armory | Center or distribute the existing **three Treasury rows and five Armory rows**, in **both independent bands**, on tall screens rather than leaving a large bottom void. Do not invent filler features, add scroll/pagination or sacrifice the compact minimum. | KingdomLayout `treasuryBandFrames` **and** `armoryBandFrames`, each currently top-anchored from `rowsTop`. |
| 13. Armory appears static | Rows with owned gear show a small trailing chevron for “tap to change”; unowned rows remain inert. The chevron must occupy a **separate frame in the existing trailing row margin**, **not** reduce `armoryTextFrames` or make the HPA-811 `(atk X → Y)` suffix disappear more often. Preserve full-row tap-to-cycle and put a concise accessibility hint on the **existing** accessible row. | KingdomLayout exposes a trailing chevron frame with unchanged text-frame widths; KingdomScene renders it only for owned rows and updates the existing VoiceOver action. |
| 14. Confirm glow leaks | Armed “Confirm Ascension” visuals remain inside the Ascend panel border on the narrowest supported frame. Preserve two-tap confirmation, Cancel and full 44pt hit targets. | KingdomLayout or KingdomScene visual inset for the primary panel; no change to ascend() logic. |

### Battle — findings 15–17

| UAT # | Desired behavior | Minimal owning change |
| --- | --- | --- |
| 15. Overlapping damage labels | Same-tick attacks are already aggregated per objective. For **later-tick** hits, retain **at most one live floating damage label per objective ID** in a scene-local `[String: SKLabelNode]`: update its displayed text and restart its existing fade/float action instead of spawning another. Remove/ignore stale detached nodes; reset the registry with transient combat/effects. Do **not** coalesce unrelated structure-fall labels. Damage/event values, sound/haptics, conquest timing and Reduce Motion remain unchanged. | BattleScene `playObjectiveAttackFeedback` / `playFloatingFeedback`: synchronous one-label-per-objective presentation, not stagger/budget/pooling machinery. |
| 16. Soldier crowding / HP behind gate | Make the existing formation's visual offsets readable for typical simultaneous soldiers; avoid the current floor-clamped tail piling at one coordinate. HP strips stay above gate artwork and inside the battlefield when near the enemy gate. Never change soldier combat lane, position, HP, targeting or collision logic. | BattleScene SoldierFormation/syncSoldierNodes/HP presentation and, if needed, BattlefieldLayout's existing frame constraints. |
| 17. Tiny crest in medallion | Scale the existing conquered-marker proportionally to the 96/118pt medallion while keeping “TAKEN”, ring and safe-area clearance intact. | ConquestReportNode renderTakenMedallion; retain ConquestReportLayout as geometry owner. |

## Non-goals and boundary decisions

- No combat/economy rebalance, save migration, persistence field, new gameplay system, scene rewrite, new art, music, sound or haptics. An asset requiring creation belongs in its own future art ticket, not this PR.
- No HPA-367 Campaign Chronicle or direct Ascension shortcut; the Map text points to the already-present Kingdom tab.
- The DEBUG five-tap city jump was listed as **not tested**, not as a reproduced defect. Verify it using a real supported simulator gesture if convenient, but do not silently expand HPA-812 into a dev-tool repair. File a separate issue if it actually fails.
- No new generalized layout engine, notification coordinator, snapshot framework or animation pooling service. Existing geometry/presentation owners are sufficient.
- Do not weaken current portrait-safe-area and unsupported-layout gates, map-route containment, 44pt touch targets, settings/VoiceOver support or pending-conquest routing.

## Acceptance and evidence

1. At the **same scene dimensions and insets**, Camp lot centers and hit frames are identical across .none/.emptyLot/.occupiedLot; palette content is visually contained, unaffordable recommended upgrades look disabled, and Camp gold/status remain readable.
2. On fresh City 1 and City 2 and on the 15/15 country-complete fixture, Map's rendered card, marker/44pt city targets, progress pips/label and tab area do not overlap. The complete card tells the player to use Kingdom → Ascend. No changes to authored map anchor definitions.
3. Locked tabs are visibly distinct without routing, while unlocked tabs still navigate. Kingdom header and Ascend action treatments remain within their visible panels; Armory cycle feedback and accessibility are clear.
4. With repeated gate hits and busy lanes, damage labels and soldier/HP presentation are discernible, without changing game state or the number/values of combat outcomes. Conquest medallion icon fills the ring appropriately.
5. Use **pure layout/scene tests** across the existing supported fixture matrix (Camp/Kingdom 320×568; Map's supported phone viewports such as 375×667 and 393×852; iPad portrait), plus resize/layout-gate recovery. For screenshot parity use the existing **393×852** UI capture fixture; it intentionally skips other sizes.
6. Run focused Swift Testing/layout/scene suites plus full macOS Xcode unit/UI CI and SwiftLint. Reuse `testForgedFixtureParitySmoke393x852` and `testHPA672AscensionFlowEvidence` for before/after screenshot evidence, supplementing only a **real unfrozen busy-battle** capture for #15/#16 and a Camp no-selection capture if missing. These runs **have not yet happened**; do not claim visual verification from planning.

Where the UAT visual owner is unchanged, source inspection is sufficient to preserve the reported baseline problem; do not demand a second manual reproduction before implementing a focused test. Re-verify Kingdom #11–#14 on device because that scene changed under HPA-811. Update old Map scene tests that currently **expect** City 2/card overlap to the new visible/no-overlap behavior without weakening city-over-card touch precedence or the blocking/nonblocking feedback contracts. If a geometry constraint conflicts, record the failing fixture and revise this PR rather than weakening the portrait layout gates.
