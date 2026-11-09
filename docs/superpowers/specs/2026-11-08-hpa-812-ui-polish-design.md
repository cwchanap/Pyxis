# HPA-812 — Camp, Map, tab bar, Kingdom and Battle UI polish: design

**Linear:** https://linear.app/cwchanap/issue/HPA-812/polish-ui-rough-edges-across-camp-map-kingdom-and-battle  
**Planning baseline:** cwchanap/Pyxis main@bb390f08fa68c5c4ce6e349fad3d67dbe791b144 (after merged HPA-811).  
**UAT reference:** iPhone 17 simulator at main@98c9d35, as described in HPA-812.  
**Delivery:** This specification and the [paired implementation plan](../plans/2026-11-08-hpa-812-ui-polish-implementation.md) start **the one HPA-812 PR**. Implementation, tests, screenshots, and review fixes remain in that same PR. Do not merge a docs-only draft.

## Problem and approach

UAT logged 17 usability/presentation problems across existing gameplay screens. They are mostly layout, affordance, contrast or transient feedback problems; the current game flows work. This is **not** a screen redesign. First reproduce each item on the planning baseline: the UAT build predates HPA-811, and some observations may already be stale. For an item that no longer reproduces, capture the verification and avoid an unnecessary code edit.

Use the existing SpriteKit scene and pure layout owners. Prefer small changes to geometry, text, colors and visual feedback over new widgets or frameworks. Reuse current art and forged UI components. Preserve game rules, saved-state format, idle/campaign transitions, routing, Settings accessibility, combat damage, soldier positions in the simulation, map-city anchors and the portrait layout gate.

## Player-facing decisions and file ownership

### Camp — findings 1–5

| UAT # | Desired behavior | Minimal owning change |
| --- | --- | --- |
| 1. Moving lots | Lot centers and hit frames do not move when selecting no lot, an empty lot or an occupied lot at the same viewport. Keep selection panels in a stable reserved bottom region; the player must not lose the tapped target beneath their finger. | CampChromeLayout: selection-independent lot-region budget; BuildingViewScene continues applying its single computed layout. |
| 2. Uneven/clipped palette | Five option cards share a baseline and consistent height; all name/cost text stays inside their visual panels, with no oversized blank strip above. Every 44pt minimum hit target remains usable. | CampChromeLayout: remove staggered yOffsets and fit a compact builder panel; CampSelectionNode: inset name/cost lines rather than lowering text into the border. |
| 3. Unaffordable upgrade | Insufficient-gold or capped upgrade appears visually disabled even if the recommendation algorithm chose it. Existing explicit “Need N gold” feedback on tap may remain, but no purchase happens. | CampSelectionNode: disabled/affordability styling takes precedence over isRecommended. Keep CampSelectionContent and existing KingdomGameState mutation guard as authorities. |
| 4. Low-contrast status | Short transient messages remain legible over grass; use a restrained forged/dark backplate or shadow with existing theme text colors, not a new notification service. | BuildingViewScene feedback label/presentation. |
| 5. Missing gold icon | Camp gold HUD uses the same existing gold icon convention as Battle/Map, fitted inside the existing gold panel with a readable count. | BuildingViewScene, existing asset/theme; no new art. |

**Layout tradeoff:** reserving panel space even before a lot is selected gives the scenic grid a slightly smaller but *stable* envelope. Prefer one shared budget sized to the actual compact palette/inspector over different 0/114/174pt allocations. Ensure compact-phone support is not traded away to preserve exact positions on the reference phone.

### Map — findings 6–9

| UAT # | Desired behavior | Minimal owning change |
| --- | --- | --- |
| 6. Scout card obscures early cities | At the initial run, cities 1 and 2, current-city marker and their 44pt hit frames are fully visible and reachable, separated from the card. Preserve the authored relative city/route positions on the backdrop; do not patch individual anchors. | CountryMapLayout envelope/card spacing and CountryMapScene application, only if still reproducible on current main. |
| 7. Empty country-complete card | Use existing country-complete card to show a compact two-line outcome and clear next step: “Kingdom → Ascend to begin again.” No new navigation or Ascension rule; the Kingdom tab already exists. | CountryMapScoutCardNode complete-state copy/layout; keep its Attack target absent. |
| 8. Progress pips hit 15/15 | The 15 pips and the complete-count label have a measured non-overlapping horizontal allocation, including 15/15, on compact/reference layouts. | CountryMapScene progress geometry, using the current progressFrame allocation. |
| 9. Hard dark bands | Replace abrupt empty flat-color bands above/below the art with a subdued treatment from the existing theme or texture; do not stretch or remap the interactive illustration and do not generate a new background asset. | CountryMapScene visual background layers only; geometry and hit testing unchanged. |

**Map contract:** CountryMapLayout is the sole source for the portrait map's interaction envelope. Its existing support/fail-closed behavior, source-art registration, route checks, card overlays and feedback action gating are requirements; do not bypass them to make a screenshot appear correct. Validate actual rendered overlap as well as model frames.

### Shared tab bar — finding 10

The locked Battle/Camp tabs during post-conquest Map/Kingdom navigation must look *meaningfully* disabled, unlike the current forged treatment that gives enabled unselected and disabled icons almost the same opacity. Use a distinct muted icon/label and disabled tile appearance in **GameplayTabBarNode**. Keep the existing disabled hit-frame omission and the controller's pending-report routing. No toast or new event bus is necessary. If an accessibility action is exposed, its enabled status must agree with the visual state.

### Kingdom — findings 11–14

| UAT # | Desired behavior | Minimal owning change |
| --- | --- | --- |
| 11. Header overflow | Selector pills, Settings visual bezel and gold count fit *visually* inside the header (not merely mathematically inside hit frames). Gold gains a real leading inset; selector and gear hit targets still meet 44pt. | KingdomLayout positions plus KingdomScene panel/label insets; retain one Settings control. |
| 12. Empty lower Treasury/Armory | Center or distribute the existing three/five rows through the available content band on tall screens rather than leaving a large bottom void. Do not invent filler features, add scroll/pagination or sacrifice the compact layout minimum. | KingdomLayout row-band placement only. |
| 13. Armory appears static | Rows with owned gear show a small chevron or “tap to change” affordance; unowned rows remain clearly inert. Preserve existing full-row tap-to-cycle behavior and add a concise accessibility hint rather than lengthening the packed effect line. | KingdomScene row presentation and existing accessible action, no new equipment controller. |
| 14. Confirm glow leaks | Armed “Confirm Ascension” visuals remain inside the Ascend panel border on the narrowest supported frame. Preserve two-tap confirmation, Cancel and full 44pt hit targets. | KingdomLayout or KingdomScene visual inset for the primary panel; no change to ascend() logic. |

### Battle — findings 15–17

| UAT # | Desired behavior | Minimal owning change |
| --- | --- | --- |
| 15. Overlapping damage labels | Repeated hits on one objective do not produce an unreadable vertical pile. Use a small bounded display budget and deterministic stagger/coalescing per impact location, with old cosmetic labels retired when necessary. Damage, event values, sound/haptics and conquest timing remain unchanged. Respect Reduce Motion. | BattleScene playObjectiveAttackFeedback/playFloatingFeedback visual layer only. |
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
5. Preserve compact 320×568 and 375×667 geometries, reference 393×852 iPhone with safe insets, and supported iPad portrait (e.g., 834×1194); validate resize/layout-gate recovery. Favor the current test fixture matrix where it already covers more cases.
6. Run focused Swift Testing/layout/scene suites plus full macOS Xcode unit/UI CI, SwiftLint and visual iPhone 17 smoke captures. Capture before/after reference screenshots for Camp selection states, fresh/completed Map, locked tabs, all Kingdom sections, busy Battle and conquest report. Do **not** claim visual or simulator verification from docs-only planning.

An item verified **already fixed on current main** may close through recorded evidence without forcing a code edit. If geometry conflicts with a hard existing constraint, record the failing fixture and adjust the plan on this PR before implementation, rather than weakening guards.
