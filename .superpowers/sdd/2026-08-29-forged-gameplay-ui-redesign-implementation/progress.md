# SDD ledger — plan: docs/superpowers/plans/2026-08-29-forged-gameplay-ui-redesign-implementation.md

Baseline: `50f6d65` on `codex/forged-gameplay-ui-redesign`; XcodeBuildMCP iPhone 17 full suite passed 843 tests, 0 failed, 0 skipped with parallel testing disabled.

Spec: `docs/superpowers/specs/2026-08-29-forged-gameplay-ui-redesign-design.md` is reachable and binding.

Ruling: Treat exact 393×852 element exports from the user-supplied `Pyxis 1b.dc.html` sections `3b`, `2b`, `2c`, `2d`, and `2e` as the canonical source PNGs — the current attachment is the authoritative prototype but contains no separate 393×852 PNG exports — if wrong, replace the five mock files and regenerate parity overlays; runtime semantics are unaffected.

## Pre-flight conflict scan

| Tasks | Producer → consumer / self-check | Finding |
| --- | --- | --- |
| 1 | Panel fixed tree + tab hit policy vs its specified tests | Consistent; tests exercise idempotent apply, four rivets, disabled hits, and 44 pt minimums. |
| 2 | Pending-first routing + Camp settlement vs its specified tests | Consistent; one routing authority and settlement-before-route are explicit. |
| 3 | DEBUG fixtures vs parser/state/controller tests | Consistent; exact fixture values and compile guards are specified. |
| 4 | Battle projection/layout/HUD vs pure/node tests | Consistent; 416/340 floors and 424...440 reference output are numerically pinned. |
| 5 | BattleScene cutover vs fit/gear/interaction tests | Consistent; production ownership remains in existing scene/controller. |
| 6 | Camp builder/inspector vs projection/geometry/mutation tests | Consistent; five types, mutation delegation, and pending-conquest handoff are explicit. |
| 7 | Map computed budget/transform/card vs layout/content/scene tests | Consistent; 48/133/164 card outputs, 431 map floor, 45 spacing, and control deletion align. |
| 8 | Conquest atomic cutover vs four result-shape/layout/anchor tests | Consistent; old rows and gold index are removed in the same compiling slice. |
| 9 | Settings presentation vs layout/node/controller/accessibility tests | Consistent; only `handleFrame` is added and ownership remains unchanged. |
| 10 | Freeze/UI smoke/parity/release/coverage proof vs final gates | Consistent; UI assertions remain semantic and no pixel CI framework is introduced. |
| 1 → 2 | `GameplayTab`/`GameplayTabBarNode` → routing and enabled-tab use | Compatible; Task 2 consumes Task 1's closed enum and disabled-hit behavior. |
| 1 → 4 | shared panel/tab components → Battle HUD | Compatible; Task 4 renders through Task 1 without adding another surface primitive. |
| 1 → 6 | shared panel/tab components → Camp chrome | Compatible; Camp reuses the fixed primitives. |
| 1 → 7 | shared panel/tab components → Map chrome | Compatible; Map reuses the fixed primitives. |
| 2 → 3 | extended `presentSceneForCurrentStage` → fixture launch routing | Compatible; Task 3 installs state before forwarding through Task 2's authority. |
| 2 → 5 | Battle tab routing/gate seams → BattleScene cutover | Compatible; Task 5 retains Task 2's defense-in-depth route guard. |
| 2 → 6 | Camp settlement/tab handoff → Camp cutover | Compatible; Task 6 delegates through Task 2 rather than adding a route path. |
| 2 → 7 | Map tab routing → selected-city March/Return | Compatible; Task 7 separates selection from progression and routes through Task 2. |
| 3 → 4 | deterministic Battle state → Battle projection/layout visual check | Compatible; fixture values feed real projections rather than mock literals. |
| 3 → 5 | Battle fixtures → scene cutover visual/blocked checks | Compatible; Task 5 consumes both battle fixture states. |
| 3 → 6 | Camp fixtures → builder/inspector checks | Compatible; empty and occupied fixtures cover both flows. |
| 3 → 7 | Map fixtures → selected-card/complete checks | Compatible; Task 7 consumes map and country-complete states. |
| 3 → 8 | Conquest fixtures → live/idle typed reports | Compatible; both result shapes are planned. |
| 3 → 9 | Battle fixture → Settings presentation check | Compatible; Settings remains modal over the fixture-backed Battle scene. |
| 3 → 10 | fixture parser/state → UI smoke and capture | Compatible; Task 10 adds only freeze behavior and capture coverage. |
| 4 → 5 | `BattleChromeLayout`/`BattleHUDNode` → `BattleScene` | Compatible; Task 5 is the consumer cutover and keeps battlefield ownership separate. |
| 5 → 8 | `BattleScene` report integration → Conquest typed report | Compatible; Task 8 changes report projection/rendering without changing result persistence. |
| 5 → 9 | one Settings gear/modal ownership → bottom-sheet presentation | Compatible; Task 9 changes only settings layout/node rendering. |
| 5 → 10 | Battle update seam → DEBUG freeze marker | Compatible; Task 10 short-circuits advancement only. |
| 6 → 10 | Camp UI → fixture smoke/parity evidence | Compatible; Task 10 verifies both Camp variants without new behavior. |
| 7 → 10 | Map UI → fixture smoke/parity evidence | Compatible; Task 10 records the intentional 164 pt mock difference. |
| 8 → 10 | Conquest UI → fixture smoke/parity evidence | Compatible; live/idle are both required. |
| 9 → 10 | Settings UI → fixture smoke/parity evidence | Compatible; one-off toggle stays within existing behavior. |

Task 1: fix round 1/5 (1 addressed, 0 open — full-suite short-landscape PanelNode accumulated-frame regression; commits 71cad50..8e10b0d)
Task 1: complete (commits 50f6d65..8e10b0d, review clean)
Task 2: fix round 1/5 (2 addressed, 0 open — stale Battle tab projection after manual spawn and Map tab interception of authored city targets; commits 3b3040d..20e68c1)
Task 2: fix round 2/5 (1 addressed, 0 open — loss-only tick failed to refresh tabs after the final manual soldier died; commits 20e68c1..c2bcd94)
Task 2: complete (commits 8e10b0d..c2bcd94, review clean)
Task 3: fix round 1/5 (2 addressed, 0 open — blocked Battle fixture lacked a transient manual soldier and occupied Camp assertions did not pin authored lots; commits 40ea103..d5dd086)
Task 3: complete (commits c2bcd94..d5dd086, review clean)
Task 2: fix round 3/5 (1 addressed, 0 open — pending Camp settlement exposed Map although pending-first routing opens Battle; commits d5dd086..2bd024f)
Task 1: fix round 2/5 (1 addressed, 0 open — two single-use panel colors were exposed as shared theme tokens; commits 2bd024f..e3a16b4)
Checkpoint A: complete (Tasks 1–3 foundation slice, commits 50f6d65..e3a16b4, integration and architecture review clean)
Task 4: fix round 1/5 (2 addressed, 0 open — lane chips ignored authored defense profile and unused medallion hit-frame cache; commits 0497bcf..4b8868f)
Task 4: complete (commits e3a16b4..4b8868f, review clean; current-run full verification 882/882)
Task 5: fix round 1/5 (3 addressed, 0 open — missing canonical top bands/image-first medallions, blocked feedback overlap, and retained hidden legacy Battle chrome; commits e3c2bfd..e0657f8)
Task 5: fix round 2/5 (1 addressed, 0 open — income panel was untappable and city progress retained legacy split hit semantics; commits e0657f8..d4eafa1)
Task 5: complete (commits 4b8868f..d4eafa1, behavior, visual scope, and code-quality review clean; native 393×852 overlay evidence deferred to Task 10)
Task 2: fix round 4/5 (1 addressed, 0 open — pending Camp selected disabled Camp while only Battle was available; commits d4eafa1..387b174)
Task 5: fix round 3/5 (3 addressed, 0 open — debug counters, unframed gear, and dead HUD/test-only compatibility state; commits 387b174..38a79db)
Checkpoint B: complete (Tasks 1–5 foundation plus Battle, commits 50f6d65..38a79db, integration, architecture, and Battle visual review clean)
Task 6: fix round 1/5 (4 addressed, 0 open — inspector feedback/tab overlap, missing mounted builder evidence, deleted current-contract coverage, and unused Camp API; commits da7f590..8f7943c)
Task 6: fix round 2/5 (2 addressed, 0 open — removed final no-caller Camp layout/projection aliases; commits 8f7943c..7b048c9)
Task 6: complete (commits 38a79db..7b048c9, spec, visual, coverage, and code-quality review clean)
Task 7: fix round 1/5 (5 addressed, 0 open — RETURN idle settlement, card/tab order, incomplete Map chrome/card hierarchy, false diff-check, and unused compatibility API; commits e8cb24d..0dd7bae)
Task 7: fix round 2/5 (1 addressed, 0 open — resource tile overlapped Country title; commits 0dd7bae..aa3ba5c; native 393×852 capture remains Task 10 gate)
Task 7: complete (commits 7b048c9..aa3ba5c, spec, geometry, visual, coverage, and code-quality review clean; native 393×852 proof deferred to Task 10)
Checkpoint C: fix round 1/5 (2 open — Battle tab glyph renders as an opaque white block; occupied Camp evidence lacks the reserved bottom tab bar; scoped fixes and fresh captures required before acceptance)
Checkpoint C: fix round 1/5 complete (1 addressed — Battle tab now uses a deterministic crossed-swords vector glyph; 1 dismissed — fresh and prior occupied-Camp evidence both visibly contain the bottom tab bar; commit 86c9dce)
Checkpoint C: complete (Tasks 4–7 Battle/Camp/Map geometry, commits e3a16b4..86c9dce, integration, geometry, multi-screen visual, coverage, and architecture/YAGNI review clean; exact native 393×852 proof remains Task 10)
Task 8: fix round 1/5 (2 open — mounted report lacks canonical Taken/city victory header and uses a blue CTA instead of Forged dark/gold treatment; tile value size is measured twice; commit 6664de4 under review)
Task 8: fix round 1/5 complete (2 addressed — canonical Taken/city hierarchy and dark-gold CTA restored; duplicate tile measurement removed; commit d1b8181)
Task 8: fix round 2/5 (1 open — constrained Country Complete layout reports fit while decorative medallion overlaps required title/reward content; decoration must fail open or reserve space)
Task 8: fix round 2/5 complete (1 addressed — optional Taken medallion now fails open when it would overlap required title/reward/country-complete content; commit 69f0b6e)
Task 8: complete (commits 86c9dce..69f0b6e, spec, mounted visual parity, coverage, and code-quality/YAGNI review clean; native 393×852 proof remains Task 10)
Task 9: complete (commits 69f0b6e..da563d3, spec, mounted visual parity, coverage, and code-quality/YAGNI review clean; native 393×852 proof remains Task 10)
Checkpoint D: complete (Tasks 8–9 plus current whole UI, commits 86c9dce..da563d3, integration, whole-UI visual, geometry/accessibility, coverage, and architecture/YAGNI review clean; exact native 393×852 overlays, stable UI smoke, and final parity board remain Task 10)
Task 10: fix round 1/5 (3 open — capture-only smoke hard-fails CI's iPhone 17 destination; fixture loop asserts a literal label instead of derived scene/state and duplicates the unchanged Map attachment; byte-identical Map locked overlay duplicates 2.9 MB; commit cc865b3 under review)
Task 10: fix round 1/5 complete (3 addressed — capture smoke skips before fixture loop on non-393×852; semantic probe derives routed scene and persisted state for all fixtures; shared Map attachment/overlay replaces duplicates; commit ca30be8)
Task 10: complete (commits da563d3..ca30be8, spec, native evidence/parity board, UI smoke/accessibility, Release/coverage, and code-quality/YAGNI review clean; remote Codecov remains pending CI publication)
Final whole-branch review: fix round 1/5 (4 open — Map Battle-tab exit drops accumulated building progress/pending idle conquest; idle Conquest labels soldier-type count as buildings and fixture is unrealistic; Conquest shows an untappable Settings gear; final Camp evidence omits builder/inspector selection states)
Final whole-branch review: fix round 1/5 complete (4 addressed — Map Battle-tab settles before central routing; same-process idle report uses occupied slots and realistic fixture; Conquest gear hidden; Camp builder/inspector states captured; commit a228398)
Final whole-branch review: fix round 2/5 (3 open — transient idle building count is lost on process relaunch after conquered grid deletion; short idle report exposes defeated-city HP bar; rejected Map tab route does not re-arm idle tracking)
Final whole-branch review: fix round 2/5 complete (3 addressed — idle building count persists in `BattleResult`; Conquest clears both HP-bar nodes; rejected nonlethal Map routing re-arms idle tracking; commit cfd15d1)
Final whole-branch review: fix round 3/5 (1 addressed — zero-elapsed rejected Map routing now re-arms and persists idle tracking; commit bdd33cc)
Final whole-branch review: complete (commits 50f6d65..bdd33cc; plan/spec, runtime semantics, visual parity, architecture/YAGNI, and code quality approved with no open P0–P3 findings)
Final verification: current compiled product passed the repository's CI-shaped boundaries serially — PyxisTests 859/859 and PyxisUITests 3/3 with 1 intentional 393x852 capture-geometry skip. The first combined build-and-run produced six accessibility-element failures before the unchanged affected product reran 139/139; a second combined run passed all 859 unit assertions before the UI runner timed out waiting for Apple AX initialization. The unchanged split targets then passed, so no retry or accessibility workaround was added.
Final verification: SwiftLint exited 0 with 70 existing warnings and 0 serious violations; `git diff --check origin/main...HEAD` passed; Release build succeeded from fresh derived data and contains neither DEBUG fixture marker. Current Pyxis.app line coverage is 94.61% (15,012/15,868), above the 90% project gate. Remote Codecov project/patch publication remains pending until the branch is pushed and hosted CI runs.

User visual acceptance reopened Battle after the first uncommitted styling pass: palette changes alone did not match the canonical 393×852 reference.

| Tasks | Producer → consumer / self-check | Finding |
| --- | --- | --- |
| 11 | exact Battle bands/materials/hierarchy vs focused geometry/render tests and fresh native capture | Consistent; the correction stays inside existing owners and preserves behavior/accessibility. |
| 4 → 11 | `BattleChromeLayout` field floor and HUD projection → exact reference bands | Compatible; Task 11 retains the 416 minimum and 424...440 reference field while pinning the canonical surrounding bands. |
| 5 → 11 | mounted Battle cutover/one-gear ownership → corrected rendering | Compatible; Task 11 changes presentation only and keeps the same interaction owners. |
| 10 → 11 | deterministic capture fixture → refreshed comparison evidence | Compatible; Task 11 replaces stale Battle evidence after runtime pixel inspection. |

Ruling: The canonical HTML-derived 393×852 Battle positions and visible hierarchy supersede the rejected palette-only interpretation while the existing 416 minimum and 424...440 reference field remain binding — if wrong, only the Battle presentation/tests/evidence need rework; gameplay semantics remain unchanged.

Task 11: fix round 1/5 (1 addressed, 0 open — canonical top-row safe-area containment rejected the authored y=750...796 resource/gear frames; commits 4d1a388..b519f5c)
Ruling: Update the legacy BattleScene gear-size expectation from 44×44 to the canonical 46×46 Task 11 value — the production hit remains above the 44×44 accessibility minimum — if wrong, only the reference-size assertion and gear frame need rework.
Task 11: fix round 2/5 (3 addressed, 0 open — modal probe overlapped Done, tall gear expectation was stale, multiplier rounded 1.25 to 1.2; commits b519f5c..d37fd40; affected suites 223/223)
Task 11: fix round 3/5 (6 addressed, 0 open — centered header/deploy cluster, outline gear/tab glyphs, shield/lock markers, warm selected tab; commits d37fd40..7a4dd2f; affected suites 227/227)
Task 11: minor (deferred): remove orphaned `gameUISymbolImage` raster helper and obsolete vector-era color-blend testing hooks; final whole-branch review must triage.
Task 11: fix round 4/5 (2 addressed, 0 open — forged gradients were modulated by dark fallback fill; orphaned raster/vector-era hooks removed; commits 7a4dd2f..4700f3e; affected suites 227/227)
Task 11: fix round 5/5 (1 addressed, 0 open — fresh exact-logical-393×852 runtime capture, overlay, side-by-side, and honest resampling/state notes packaged; commits 4700f3e..6dece6b)
Task 11: complete (commits eae222c..6dece6b, task review and five scoped fix re-reviews clean; focused/affected suites 227/227; runtime visual evidence inspected)

Consolidated final-fix: fix round 1/5 (4 addressed — Battle interaction now consumes authoritative safe-area tab hit frames; Scout footer projects CityDefenseTrait multipliers; presentation-only idleBuildingCount removed and idle reports use durable total idle damage; fixed Forged gradient, atmosphere, and coin textures are reused; serial unit/UI checks green).
Ruling: Exact idle building count is not representable from BattleResult without reintroducing the forbidden presentation-only persistence seam. Idle reports therefore show durable total IDLE DAMAGE, and legacy/current results with no durable idle rows show “—” rather than a false BUILDINGS 0.

## Task 12 — remaining Battle material parity

Status: root-cause audit, implementation, and review complete.

Ruling: Task 11's blanket external-pill interpretation is superseded for locked medallions by the exact canonical HTML: available multipliers remain external bottom pills, while locked city requirements sit inside the lower hex with no gray capsule. This is presentation-only and does not change unlock semantics or hit frames.

Ruling: Prototype combat totals, costs, lane roles, and live soldier positions are fixture/game-state data, not style tokens. Task 12 must match material and hierarchy without falsifying those values; simulator Dynamic Island/system masking is also documented rather than hidden.

Task 12: implementation complete, review clean — corrected forged panel/HP/tab materials, one-line recommendation hierarchy, selected/locked medallion states, filled lane-role markers, 70 pt rendered lane chips, and the field-edge vignette. Fresh direct 1179×2556 simulator evidence and deterministic side-by-side/overlay were regenerated; affected suites pass 219/219 plus the final lane-chip rerun 15/15.
Task 12: fix round 1/5 (1 addressed, 0 open — stale Battle-normal transport provenance replaced with direct 1179×2556 `simctl io screenshot` evidence, 393×852 comparison downsampling, the unavoidable Dynamic Island/system mask, and truthful fixture-state differences).
Task 12: fix round 1/5 complete (review clean — documentation-only correction; production, tests, and images untouched).
