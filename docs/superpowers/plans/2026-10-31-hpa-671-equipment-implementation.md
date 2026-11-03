# HPA-671 — Conquest Equipment: single-PR implementation plan

**Ticket:** https://linear.app/cwchanap/issue/HPA-671/gameplay-equipment-conquest-gear-for-each-soldier-type  
**Companion design:** [2026-10-31-hpa-671-equipment-design.md](../specs/2026-10-31-hpa-671-equipment-design.md)  
**Starting main SHA:** `7ecbdfdc59cebc7806a47310426860ba792facdc` (merged HPA-670).  
**Delivery rule:** This draft becomes the **one implementation PR**. Do not open a second PR for code or merge docs alone.

## Main-branch audit / technical constraints

- `KingdomGameState.swift` already owns stage-gated `completeCurrentCity(with:)`, which pays the passed reward, removes city buildings, and stores the durable pending `BattleResult`. All live/idle/Camp conquest paths funnel through it. This is the only gear-grant seam.
- `KingdomGameState.traitAdjustedSoldierAttackPower` is already shared by both `BattleScene` spawn paths and `applyAbstractBuildingSpawnDamage`. Preserve its Treasury/trait single round.
- `SoldierType.roleAdjustedDamage` is the existing second-round per-objective role adjustment used by live `BattleCombatState.tick` and idle first-objective damage. Specialist belongs here; its live modifier must be captured on the Soldier at spawn.
- `BattleCombatState.spawnSoldier` creates soldiers with cached attack/HP; `spawnCaptain` is a separate path and stays unequipped.
- `ConquestReportContent.project`/`ConquestReportNode.apply` use the persisted `BattleResult`; the fixed-size `ConquestReportLayout` can fail and blocks gameplay if mandatory content does not fit. Gear must never become mandatory.
- `KingdomScene` already supports Treasury purchases, asset-loader injection, scene-local idle settlement and pending-first navigation; `KingdomLayout` places three ≥80pt Treasury rows and only reserves *noninteractive* future space. Five more rows need a local section switcher **in the existing header title line**, not stacking or a new vertical band. Existing 320×454 zero-inset geometry leaves no height below the header for a 44pt selector.
- `CLAUDE.md`: new pure model/test files autoinclude via `PBXFileSystemSynchronizedRootGroup`; write Swift Testing first, run xcodebuild tests serially, use the opt-in chain for balance-impacting work. Do not hand-edit `project.pbxproj`.

## Work sequence — all in this same PR

### 1. Catalog + persistence + equip API (tests first)

**Files:** `Pyxis/EquipmentCatalog.swift` (new), `Pyxis/KingdomGameState.swift`, `PyxisTests/EquipmentCatalogTests.swift` and `PyxisTests/KingdomEquipmentStateTests.swift` (new).

1. Author the 15 IDs/effects from the design, with one short name/flavor per city. Define tiny typed `EquipmentItem`/`EquipmentEffect` records and catalog lookups (`byCity`, `byID`, `forType`); don't add loot services or a general buff registry.
2. Add the two explicitly named save fields, empty defaults, and catalog-based normalization on construction/decode. Represent `None` as the absence of an equipped slot, using the prior-owned-item check on conquest to preserve an intentional unequip with **no additional save field**. Verify missing keys, duplicate/unknown IDs, mismatched slot owner, unowned equips, malformed raw keys and a store round trip. Preserve existing fields, Treasury, pending result and stage invariants.
3. Implement `equip(itemID:)` / `unequip(soldierType:)` with explicit mutation result and stable per-type order. Test every type's three choices, unchanged/no-op and rejection paths, and allowed stages.
4. Add `BattleResult.newEquipmentItemID: String?` with optional explicit encode/decode; default nil in existing test constructors and session-finalized results. No stored names or visual receipt flags.

**Checkpoint:** All existing zero-equipment model tests stay unchanged; no UI or new drops yet.

### 2. Grant exactly once at the existing completion seam

**Files:** `Pyxis/KingdomGameState.swift`, `Pyxis/BattleResultModels.swift`, `PyxisTests/KingdomEquipmentStateTests.swift`, relevant live/idle/Camp tests.

1. After the existing conquest stage/city guard, require `currentCityKey.countryNumber == 1` before resolving a catalog item. If the item is new, snapshot **whether any item of that type was owned before the award**; add the new ID once, and auto-equip it **only if there was no previously owned item**. An explicitly empty slot (`None`) after earlier ownership must stay empty. Copy the incoming `BattleResult`, setting the optional new-item receipt **only** on a newly acquired Country 1 reward; assign that copy to `pendingBattleResult`.
2. Preserve gold reward, city-state removal, stage transition and `CompletionResult` exactly. A valid non-Country-1 conquest still completes and earns gold, but adds **no Country 1 equipment/receipt**. Out-of-order, duplicate, mismatched-city, or paused completions must not mutate equipment/gold.
3. Test live `applyLiveSoldierAttacks` completion, background-idle `returnFromBackground`, and Camp build/upgrade-settlement conquest. Confirm each route saves a pending result whose receipt survives encode/decode; acknowledgment clears only the result, not gear. Pin **Country 1 City 1 Infantry Attack → choose None → save/reload → Country 1 City 3 Infantry Toughness**: the new item is owned and reported but Infantry remains unequipped. Include a synthetic valid Country 2 completion with no Country 1 reward.

**Checkpoint:** One shared drop path and no second award path in a scene.

### 3. Three stat effects at existing seams (tests first)

**Files:** `Pyxis/KingdomGameState.swift`, `Pyxis/SoldierType.swift`, `Pyxis/BattleCombatState.swift`, `Pyxis/BattleScene.swift`; tests in `TreasuryEffectSeamTests`, `SoldierRoleDamageTests`, `BattleCombatStateTests` and a new focused equipment effect suite.

1. Attack: multiply trait × Treasury Drill Yard × equipped attack factor and round once. Both manual/building spawn sites and idle damage already use that method. Test neutral/counter/favorable traits, low integer levels, and no-gear exact regression; ensure Guard hits use only cached base attack.
2. Toughness: add a default-1.0 multiplier to `spawnSoldier`, apply it before maxHP's final round, populate both spawn callers from the current loadout. Test each soldier type, cached max/current HP, no Captain/Guard effect and no idle HP bonus.
3. Specialist: pass a snapshotted target and factor into the transient `Soldier`; extend `roleAdjustedDamage` to combine the inherent role × matching specialist × cached attack in its existing second round. `BattleCombatState.tick` passes each soldier's snapshot, and `applyAbstractBuildingSpawnDamage` passes the currently equipped item for each resolved spawn. Keep nonmatching objectives, Guard combat and first-objective/raw-spill behavior unchanged.
4. Explicit live/idle parity matrix across five types × all four ObjectiveKinds × matching/nonmatching gear where meaningful; test the two-round difference from erroneously rounding role and specialist separately. Equip changes after a live spawn must not affect that soldier's existing cached stats.

**Checkpoint:** No generic stat modifier pipeline; all sources use the three authoritative seams.

### 4. Armory UI with a compact section switcher

**Files:** `Pyxis/KingdomLayout.swift`, `Pyxis/KingdomScene.swift`, `PyxisTests/KingdomLayoutTests.swift`, `PyxisTests/KingdomSceneTests.swift`.

1. Place the two `Treasury / Armory` selector controls **inside the existing header's top 44pt line**, adjacent to a width-fitted `Kingdom` title (not below the header). At **320×454 with zero insets**, 288pt content width minus 44pt Settings minus 8pt gap = 236pt: allocate **100pt title + 8pt gap + two 60×44pt controls = 228pt**, leaving 8pt spare, and keep the bottom 44pt gold line unchanged. With the selector consuming **zero new height**, retain `KingdomLayout`'s 88pt header, 82pt tabs, existing three 80pt Treasury rows, 10pt row gaps, 12pt outer gaps, and all Buy hit frames. Use a pure alternative five-row Armory layout in the **same** 260pt band: five **47.2pt** rows + four 6pt gaps, whole-row hit targets and two-line compact labels. Do not change shared four-tab geometry or introduce scrolling. Test 320×454 boundary, 320×568, 375/393pt compact phones with applicable insets, iPad, and unsupported-size recovery.
2. Add five stable row nodes keyed by `SoldierType`, per-type fallback glyphs, and `equipment-<itemID>` lookup via the injected image loader. On the 320pt boundary show **two compact fitted lines** per row (type + equipped short name/`None`, then effect + next drop), with fuller flavor in accessible value rather than additional stacked text. Dim locked types. A row tap cycles the stable owned choices; no drag scroll, inventory subscene, or persistence of section selection.
3. On a real equip/unequip: read latest state, preserve scene's existing settle-before-mutation behavior for elapsed idle time if relevant (settle old loadout first, then save/rearm), apply the pure mutation, save and redraw. If settlement produced a pending result, preserve pending-first routing exactly as Treasury does. No gameplay feedback/SFX extension.
4. Expose accessible Treasury/Armory header controls with full labels and per-type rows with current name/effect and action traits; include enabled/locked and absent-art tests. Test that the selector, fitted `Kingdom` title and Settings hit frames do not overlap on a 320pt-wide header. Retain the existing four-tab, foreground/gate, and purchase regressions.

**Checkpoint:** Test **320×454 zero-inset** boundary math/label fit, header selector vs Settings and Treasury Buy touch isolation, Armory five-row ≥44pt targets, node-tree stability, unsupported-geometry recovery, and layout-failure handling.

### 5. New-gear report line — optional, never a layout dependency

**Files:** `Pyxis/ConquestReportContent.swift`, `Pyxis/ConquestReportLayout.swift` (optional pure geometry only if necessary), `Pyxis/ConquestReportNode.swift`, `Pyxis/BattleScene.swift`; focused content/node/report tests.

1. Project `newEquipmentItemID` from the persisted `BattleResult` to authored name; unknown ID or no receipt produces no line.
2. Reuse existing optional spare space between reward and stat tiles on roomy layouts, and add one low-priority label. If the space or text fit is insufficient (especially compact heights), hide only that label. Do **not** add a required stat tile/chip, change the success guard, or block Continue. Always clear the label when a subsequent report has no new reward.
3. Test compact failure-to-fit and normal fit, relayout/resizing, restored report, unchanged core metrics/Continue, and the City 15 finale.

**Checkpoint:** Report fit cannot regress merely because an item dropped.

### 6. End-to-end balance, tests and PR completion evidence

**Files:** `PyxisTests/Country1SiegeSmokeTests.swift`, existing campaign helper tests, this PR body/evidence notes.

1. **Preserve no-gear controls.** Keep the three HPA-670 chained variants (`baseline`, `freeSeeded`, `bought`) numerically comparable to their original results: on **every city entry after `startCityFromMap` and before the Camp purchases/siege**, call the real `unequip(soldierType:)` for all five soldier types (no new production flag, no bypass of the award). They still **own** every earned item, but every control siege has **zero active equipment**. Assert that loadout is empty before running each control city; report the policy as `equipment=none`.
2. **Separate bought-Treasury+equipment variant.** Add one opt-in chained run with the same fixed seed **582** and existing greedy Camp purchases, but use a test-only `equipment=greedy` policy. After entering each city and before Camp actions, get the **first live objective on that city's freshly reset default `siegeProgress.selectedLane`** from `currentSiegeLayout.firstLiveObjectiveID`; the initial objective HP/damage maps come from the entered state's normal siege snapshot. For **each soldier type independently at fixed level 1**, evaluate `None`, each owned Attack item and each owned Specialist item using the **exact integer** first-round trait/Treasury/attack formula and second-round inherent-role/specialist formula at that target kind. Choose the best **strictly positive integer damage increase** over `None`; if equal, prefer the general Attack item over Specialist. If no damage option improves the integer result, equip owned Toughness; if unavailable select `None`. Use the actual `equip`/`unequip` mutations and log the selected IDs. This is a bounded deterministic test policy, **not** runtime AI or a recommendation feature.
3. Record each city, newly owned item ID, **all owned IDs**, each equipped slot, Treasury levels, elapsed and stall/outcome. Assert exactly one new item per **Country 1** conquest and that a completed 15-city run owns **all 15 unique catalog IDs, including unequipped rewards**. Assert the gear variant has **five valid equipped slots** after its final pre-siege selection (each owned and matching its type); the three control variants have **zero equipped slots at every siege entry**. Keep 15/15 completion bounds. Compare measured no-gear results to HPA-670's 570.5s zero-Treasury and 383.2s bought-Treasury baseline (seed 582), then compare new `bought+gear` vs `bought`; don't assume a speedup or tune without evidence.
4. Run SwiftLint, Debug/Release build, focused Swift Testing, full `PyxisTests`, `PyxisUITests`, and the opt-in chain, with `-parallel-testing-enabled NO`. Review Codecov project/patch ≥90%, complete screenshot/UI evidence on compact phone/iPad and record environment, command, result and relevant deviations in the **same PR**.
5. Mark this **same** PR ready only once code, tests, actual measured evidence and review responses are included. Keep HPA-671 linked; do not open implementation follow-up PRs.

## Explicitly out of scope

- HPA-672: Ascension, Renown, replay, upgrading items/levels, persistent new stat factors.
- HPA-673: Generate/install 20 final image assets (a separate dedicated art PR). HPA-671 implements the lookup and fallbacks only.
- Random gear, a backpack UI, crafting, salvage, rarity, Captain equipment, audio or haptic assets.
- Lifecycle/router refactors, new combat simulator, generic modifier engine, broad persistence migration, new schema versions.

## Risk checkpoints for review

- **Persistent receipt:** a new-gear report must still be truthful after relaunch, and never double award after Continue.
- **Rounding:** no second attack round or third specialist round; cached live stats don't change after equip.
- **Compact geometry:** old Treasury's three-row fit **at 320×454** and alternative Armory's five ≥44pt rows are both mandatory; the selector stays within the existing 88pt header and does not cover title, gold, 44pt Settings, tab or Buy hit areas.
- **Equipment vs no-gear regression:** all owned drops still occur in legacy campaign variants, but every control siege must explicitly unequip before fighting; the `bought+gear` variant uses a fixed level-1/default-lane integer-damage policy.
- **Idle parity:** specialist uses the first live objective and preserves the existing spill rule; toughness doesn't leak into idle damage.
- **Scope:** one ticket, one PR, no art in code work.

## Completion status

Implementation is complete on this PR: catalog, once-per-conquest grant seam, three stat effects, Armory UI, optional report line and the four-variant chained campaign all landed on this branch. Simulator, build, SwiftLint, unit/UI test and balance evidence is recorded in PR #50's **Implementation evidence** section. Design-review clarifications (kept for the record): header-integrated selector at 320×454, first-owned-only auto-equip preserving `None`, Country 1-only rewards, fixed level-1/default-lane selection, and explicit no-gear campaign controls.
