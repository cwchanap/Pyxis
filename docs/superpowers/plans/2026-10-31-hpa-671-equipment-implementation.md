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
- `KingdomScene` already supports Treasury purchases, asset-loader injection, scene-local idle settlement and pending-first navigation; `KingdomLayout` places three ≥80pt Treasury rows and only reserves *noninteractive* future space. Five more rows need a local section switcher, not stacking.
- `CLAUDE.md`: new pure model/test files autoinclude via `PBXFileSystemSynchronizedRootGroup`; write Swift Testing first, run xcodebuild tests serially, use the opt-in chain for balance-impacting work. Do not hand-edit `project.pbxproj`.

## Work sequence — all in this same PR

### 1. Catalog + persistence + equip API (tests first)

**Files:** `Pyxis/EquipmentCatalog.swift` (new), `Pyxis/KingdomGameState.swift`, `PyxisTests/EquipmentCatalogTests.swift` and `PyxisTests/KingdomEquipmentStateTests.swift` (new).

1. Author the 15 IDs/effects from the design, with one short name/flavor per city. Define tiny typed `EquipmentItem`/`EquipmentEffect` records and catalog lookups (`byCity`, `byID`, `forType`); don't add loot services or a general buff registry.
2. Add the two explicitly named save fields, empty defaults, and catalog-based normalization on construction/decode. Verify missing keys, duplicate/unknown IDs, mismatched slot owner, unowned equips, malformed raw keys and a store round trip. Preserve existing fields, Treasury, pending result and stage invariants.
3. Implement `equip(itemID:)` / `unequip(soldierType:)` with explicit mutation result and stable per-type order. Test every type's three choices, unchanged/no-op and rejection paths, and allowed stages.
4. Add `BattleResult.newEquipmentItemID: String?` with optional explicit encode/decode; default nil in existing test constructors and session-finalized results. No stored names or visual receipt flags.

**Checkpoint:** All existing zero-equipment model tests stay unchanged; no UI or new drops yet.

### 2. Grant exactly once at the existing completion seam

**Files:** `Pyxis/KingdomGameState.swift`, `Pyxis/BattleResultModels.swift`, `PyxisTests/KingdomEquipmentStateTests.swift`, relevant live/idle/Camp tests.

1. After the existing conquest stage/city guard, resolve the one catalog item, add to owned IDs if missing, and auto-equip only when its type's slot is empty. Copy the incoming `BattleResult`, setting the optional new-item receipt **only** on a newly acquired reward; assign that copy to `pendingBattleResult`.
2. Preserve gold reward, city-state removal, stage transition and `CompletionResult` exactly. Out-of-order, duplicate, mismatched-city, or paused completions must not mutate equipment/gold.
3. Test live `applyLiveSoldierAttacks` completion, background-idle `returnFromBackground`, and Camp build/upgrade-settlement conquest. Confirm each route saves a pending result whose receipt survives encode/decode; acknowledgment clears only the result, not gear.

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

1. Add a `Treasury / Armory` selector with ≥44pt controls below the existing header, and a pure five-row Armory alternative layout in the same available content region. Compute both without changing the shared four-tab geometry. Verify 320/375/393pt-class compact phones and portrait iPad with insets; keep Treasury rows and Buy hit frames intact after the new selector.
2. Add five stable row nodes keyed by `SoldierType`, per-type fallback glyphs, and `equipment-<itemID>` lookup via the injected image loader. Display owned/equipped effect, `None`, next drop city, and visually dim locked types. A row tap cycles the stable owned choices; no drag scroll, inventory subscene, or persistence of section selection.
3. On a real equip/unequip: read latest state, preserve scene's existing settle-before-mutation behavior for elapsed idle time if relevant (settle old loadout first, then save/rearm), apply the pure mutation, save and redraw. If settlement produced a pending result, preserve pending-first routing exactly as Treasury does. No gameplay feedback/SFX extension.
4. Expose accessible section controls and per-type rows with current name/effect and action traits; include enabled/locked and absent-art tests. Retain the Settings gear and all existing tab/foreground/gate regressions.

**Checkpoint:** Test header/tab/buy touch isolation, node-tree stability, unsupported-geometry recovery, and layout-failure handling.

### 5. New-gear report line — optional, never a layout dependency

**Files:** `Pyxis/ConquestReportContent.swift`, `Pyxis/ConquestReportLayout.swift` (optional pure geometry only if necessary), `Pyxis/ConquestReportNode.swift`, `Pyxis/BattleScene.swift`; focused content/node/report tests.

1. Project `newEquipmentItemID` from the persisted `BattleResult` to authored name; unknown ID or no receipt produces no line.
2. Reuse existing optional spare space between reward and stat tiles on roomy layouts, and add one low-priority label. If the space or text fit is insufficient (especially compact heights), hide only that label. Do **not** add a required stat tile/chip, change the success guard, or block Continue. Always clear the label when a subsequent report has no new reward.
3. Test compact failure-to-fit and normal fit, relayout/resizing, restored report, unchanged core metrics/Continue, and the City 15 finale.

**Checkpoint:** Report fit cannot regress merely because an item dropped.

### 6. End-to-end balance, tests and PR completion evidence

**Files:** `PyxisTests/Country1SiegeSmokeTests.swift`, existing campaign helper tests, this PR body/evidence notes.

1. Add one opt-in chained-campaign equipment run using the existing fixed seed (582) and greedy Camp purchases. Use an **explicit, deterministic, simple** equipment selection at each city entry: evaluate owned attack/specialist choices against the next city's default first objective at a representative level; tie prefers the broad attack item, choose toughness only if no damage choice. This is test harness logic, not runtime AI or a user-facing recommendation system. Use actual `equip(itemID:)` changes, not seeded free gear.
2. Log city number, newly owned ID, equipped IDs by type, Treasury levels (if bought variant), elapsed time and stall/outcome. Keep existing baseline/free/bought Treasury variants runnable, and assert exactly one drop per conquered city, five final owned-type slots, and 15/15 completion within existing time bounds. Reference measured merged-PR baseline (570.5s zero Treasury; 383.2s bought 4/4/4) as context; record actual new numbers rather than assuming improvement.
3. Run SwiftLint, Debug/Release build, focused Swift Testing, full `PyxisTests`, `PyxisUITests`, and the opt-in chain, with `-parallel-testing-enabled NO`. Review Codecov project/patch ≥90%, complete screenshot/UI evidence on compact phone/iPad and record environment, command, result and relevant deviations in the **same PR**.
4. Mark this **same** PR ready only once code, tests, actual measured evidence and review responses are included. Keep HPA-671 linked; do not open implementation follow-up PRs.

## Explicitly out of scope

- HPA-672: Ascension, Renown, replay, upgrading items/levels, persistent new stat factors.
- HPA-673: Generate/install 20 final image assets (a separate dedicated art PR). HPA-671 implements the lookup and fallbacks only.
- Random gear, a backpack UI, crafting, salvage, rarity, Captain equipment, audio or haptic assets.
- Lifecycle/router refactors, new combat simulator, generic modifier engine, broad persistence migration, new schema versions.

## Risk checkpoints for review

- **Persistent receipt:** a new-gear report must still be truthful after relaunch, and never double award after Continue.
- **Rounding:** no second attack round or third specialist round; cached live stats don't change after equip.
- **Compact geometry:** old Treasury's three-row fit and new Armory five-row fit are both mandatory at supported sizes; the switcher must not cover 44pt tab/Settings controls.
- **Idle parity:** specialist uses the first live objective and preserves the existing spill rule; toughness doesn't leak into idle damage.
- **Scope:** one ticket, one PR, no art in code work.

## Planning-only status

This initial commit changes **docs only**. No simulator, build, SwiftLint, tests or balance runs have been performed for HPA-671. Those are implementation acceptance steps, not claimed results.
