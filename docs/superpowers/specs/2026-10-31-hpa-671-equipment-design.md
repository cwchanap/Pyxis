# HPA-671 — Deterministic conquest equipment and Armory: design

**Ticket:** https://linear.app/cwchanap/issue/HPA-671/gameplay-equipment-conquest-gear-for-each-soldier-type  
**Repository baseline:** `main` at `7ecbdfdc59cebc7806a47310426860ba792facdc` (HPA-670 / PR #49 merged).  
**Delivery:** One implementation PR for HPA-671, starting with this design and its companion plan. Do not merge a docs-only feature.

## Goal and guardrails

Each Country 1 conquest awards a predictable piece of equipment. The player may equip **one** of three earned items per soldier type, choosing attack, survivability, or a situational structure counter. The gear survives city resets. No rarity, random drops, currencies, crafting, inventory grids, loot animations, Captain slot, new SFX, or new illustration is introduced. HPA-673 owns final icons; HPA-672 owns Ascension and equipment levels.

The existing prepare → deploy → watch → conquer loop stays intact. No new state owner, persistence framework, or general-purpose modifier pipeline.

## Player contract

- After each successful **Country 1** City 1–15 conquest, grant that city's fixed gear exactly once. Auto-equip it **only if this is the first item ever acquired for its soldier type** (no prior owned item of that type), not merely when the equip slot is empty. Later drops never silently replace either the selected item or an intentional `None` choice.
- The persisted conquest report may display “New gear: <name>” when the reward is newly acquired. The message is decorative: a missing/failing fit never hides the normal report or prevents Continue. On a report restored after relaunch, show the same new-gear line if it fit before.
- The Kingdom tab gains an **Armory** section with five type rows, alongside the existing Treasury. Each row shows current equipment/effect and next unearned drop (“Drops at City N”). Still-locked types are visually dimmed. Tap a row to cycle `None → owned items in city order → None`, with the next choice following the current selection. `None` means an explicitly unequipped type, represented by an **absent entry** in `equippedItemBySoldierType`; the prior-owned check on the next reward preserves that choice across further drops and save/reload. Rows with no owned items do nothing.
- Use an in-scene **Treasury / Armory section switcher**, not a fifth gameplay tab. On compact phones, three existing 80pt+ Treasury rows plus five Armory rows cannot fit simultaneously. Show one section at a time. **Place both section controls inside the existing header's upper 44pt title line, alongside a width-fitted “Kingdom” title, never below the header.** On a 320pt-wide, zero-inset viewport the header content is 288pt wide; 44pt Settings plus an 8pt gap leaves 236pt for the title/selector. A 100pt (font-shrunk) title + 8pt gap + two 60×44pt section controls fits in 228pt, preserving the original 88pt header, 82pt tabs, and three 80pt Treasury rows even at 320×454. The lower 44pt gold line and Settings hit frame stay unchanged. The selected section is ephemeral scene UI state, not a save field. HPA-672 can extend this header control later.
- A row's icon attempts `equipment-<itemID>` first and uses one simple vector fallback for its soldier type if absent. The art-only HPA-673 PR must not require Swift integration edits. Test UIImage-present and fallback paths.

## Authored catalog — one item per city

`EquipmentCatalog` is a compile-time pure Swift table, with stable `id`, city, `SoldierType`, short name, flavor, and typed effect. Names/flavor never enter the save. Choose stable slug IDs now so HPA-673 can create the exact art names after implementation.

| City | City identity | Item ID | Soldier | Effect |
| --- | --- | --- | --- | --- |
| 1 | Willowford | `c01-infantry-attack` | Infantry | Attack +15% |
| 2 | Pinewatch | `c02-archer-attack` | Archer | Attack +15% |
| 3 | Falconridge | `c03-infantry-toughness` | Infantry | Max HP +25% |
| 4 | Bramblegate | `c04-archer-tower` | Archer | vs Arrow Tower +40% |
| 5 | Highcrest | `c05-cavalry-attack` | Cavalry | Attack +15% |
| 6 | Granite Pass | `c06-infantry-gate` | Infantry | vs Gate +40% |
| 7 | Emberford | `c07-cavalry-toughness` | Cavalry | Max HP +25% |
| 8 | Greywall | `c08-mage-attack` | Mage | Attack +15% |
| 9 | Runewatch | `c09-archer-toughness` | Archer | Max HP +25% |
| 10 | Ironthorn Gate | `c10-cavalry-barracks` | Cavalry | vs Barracks +40% |
| 11 | Kingshield Keep | `c11-siege-attack` | Siege | Attack +15% |
| 12 | Ashbridge | `c12-mage-barracks` | Mage | vs Barracks +40% |
| 13 | Starveil Citadel | `c13-siege-toughness` | Siege | Max HP +25% |
| 14 | Stonecrown | `c14-mage-toughness` | Mage | Max HP +25% |
| 15 | Crownspire Keep | `c15-siege-keep` | Siege | vs Keep +40% |

In implementation author a short city-appropriate item name and flavor for each ID, such as “Falconridge Bulwark”; do not derive user-facing names from slugs. Catalog validation tests enforce 15 distinct cities/IDs, exactly three effect kinds per type, and drops no earlier than the building unlocks (Barracks 1, Archery Range 2, Stable 5, Mage Tower 8, Siege Workshop 11). The numbers above are **starting** values; tune only from measured campaign results.

## Pure state and one completion transaction

- Add `ownedEquipmentIDs: [String]` and `equippedItemBySoldierType: [String: String]` to `KingdomGameState` (string keys are `SoldierType.rawValue`). Initial values are empty. Keep the owned list unique in catalog/city order, never allowing noncatalog IDs; the five-slot map contains at most one owned, matching-type ID per raw soldier key. `None` is a **missing slot entry**, not an item ID or third save field. Distinguish first-ever acquisition from intentional `None` by checking whether that type already has **any owned item before the grant**; do not add a boolean for prior user selection.
- Normalize in the existing state initializer and `init(from:)`: unknown/duplicate owned IDs are dropped; malformed/unknown type keys, unowned item IDs, and type-mismatched slots are dropped. Missing or malformed top-level equipment fields default empty. No versioned migration or separate store.
- Add `equip(itemID:)` and `unequip(soldierType:)` as pure mutations with explicit success/rejected/unchanged outcomes; both are available in every stage. Validate item existence, ownership, matching slot, and do not mutate on rejection. UI saves on actual changes. A locked soldier type does not require a second model-level gate: it cannot naturally own equipment before its first unlock in the first run; HPA-672 will add replay semantics.
- Extend `BattleResult` with an **optional** new-item ID receipt (default nil in constructed results; ignored if not recognized by the catalog), including its existing explicit encode/decode. Only `KingdomGameState.completeCurrentCity(with:)` sets this receipt on its stored pending result, **if and only if** that conquest awarded a previously unowned item. This is needed because the result survives process death and might be presented again after restart. Keep the existing `CompletionResult` and gold awarding contract unchanged.
- `completeCurrentCity` already rejects non-active or mismatched-city results before paying gold. **In addition**, award gear only when `currentCityKey.countryNumber == 1` and that country's City 1–15 catalog entry exists; other countries keep their normal completion behavior without a Country 1 item or new-gear receipt. Under the existing completion guard, inspect the type's ownership **before** inserting the new ID; auto-equip only if it had zero previously owned items. Live, background-idle, and Camp settlement all converge here. Repeat/concurrent presentation cannot double-drop because the next invocation is stage-gated.
- Conquest report resolves the receipt into current authored name through `EquipmentCatalog`. No new presentation state or random reward.

## Combat integration — keep two-round math

Existing HPA-582/HPA-670 math has exactly two rounds. Preserve it.

1. **Attack gear:** `KingdomGameState.traitAdjustedSoldierAttackPower(for:level:)` combines `trait × (1 + 0.05 × drillYard) × (1 + 0.15 if equipped attack)` and rounds **once**. This is shared by live manual/building spawns and abstract building-spawn damage. Without gear, exactly preserve HPA-670 outputs. Guard damage naturally receives attack gear through the cached base attack; no new Guard multiplier.
2. **Toughness gear:** `BattleCombatState.spawnSoldier` accepts the active type's max-HP multiplier (default 1.0), and `maxHP(for:level:)` multiplies it before the existing final rounding. Only new ordinary soldiers get the bonus; not the Captain or Guards. Idle does not model soldier HP and must not receive an arbitrary abstract-damage boost.
3. **Specialist gear:** extend the **existing** `SoldierType.roleAdjustedDamage` seam with a matching-target modifier. Against the equipped `ObjectiveKind`, use `max(1, round(cachedPower × inherentRoleMultiplier × 1.40))` in the **second** round; use neutral `1.0` if the target doesn't match. Do not multiply or round a completed role-adjusted integer again. Applies to objective attacks only, not Guard/Captain damage. The idle first-live-objective budget takes the same second-round formula; preserve its existing one-target-then-raw-spill approximation.

New-spawns-only must be literal: ordinary soldiers already have cached `attackPower` and `maxHP`; capture specialist target/multiplier **at spawn**, on the transient `BattleCombatState.Soldier`, so later equip changes cannot retroactively change structure hits by live soldiers. Manual and building spawns pass the same equipment snapshot. The Captain has no equipment.

## UI/layout and report fail-open

- Extend the pure `KingdomLayout` (CoreGraphics-only) with **two 60×44pt (or wider) header selector hit frames** inside the existing upper title line; shrink the title font/frame on compact widths. Never reserve extra vertical space between the header and Treasury cards: at **320×454 (zero insets)**, the existing height budget is exactly 88 header + 82 tab bar + 24 outer gaps + 20 row gaps + 3×80 Treasury rows = 454. Preserve the three Treasury row/Buy frames and their 44pt targets. An alternative five-row Armory layout uses that same 260pt content band with four 6pt gaps, yielding 47.2pt-high whole-row tap targets; each row renders compact **two-line** text (type/current item, effect/next drop) and a small icon. Keep the existing four-tab/safe-area and Settings geometry; no scrolling/crop framework. Test the 320×454 boundary explicitly, larger compact phones with insets, iPad, and unsupported-height recovery. Fail closed only for genuinely unsupported viewport dimensions.
- `KingdomScene` owns the ephemeral selected section, uses the existing `imageLoader` test seam, stable SpriteKit nodes, `PanelNode` forged visuals, model-only cycle action, and current scene-local settlement/routing behavior. Switching sections never settles or saves. Equipped-state changes save and redraw, but no new lifecycle router.
- Keep `ConquestReportLayout.compute`'s existing success criteria and normal stats/Continue unchanged. An optional low-priority gear label can use verified spare vertical space between reward and stat tiles on roomy layouts; on compact heights, or if text cannot fit, hide that label **without** failing the whole report. Test that no report is lost or controls obscured. Do not add a fourth stat tile or displace the two achievement chips.

## Done when

- Swift Testing proves catalog invariants, exact-once **Country 1-only** grants for live/idle/Camp, no Country 2 reward, first-item auto-equip and later intentional `None` preservation (City 1 Infantry → unequip → save/reload → City 3 Infantry), equip/rejection and normalization, first-round attack and second-round specialist math parity, cached stats, live-only HP, fail-open report and restored receipt.
- Phone/compact phone/iPad scene/layout tests prove Armory is discoverable, **320×454 zero-inset Treasury still fits** with the header selector, five Armory rows have ≥44pt targets, text/icons fit, no overlap with Treasury/Settings/four-tab routing, accessible row values/actions, and missing art fallbacks.
- The opt-in 15-city chained campaign separately runs the **three existing variants with actual gear owned but explicitly unequipped for every siege**, and a bought-Treasury-plus-greedy-equipment variant (fixed seed 582). The greedy policy evaluates exact integer damage at **soldier level 1** against the **first living objective on the entered city's default selected lane**, prefers Attack on positive-damage ties, and falls back to Toughness/`None` if damage does not improve. Verify 15 unique acquired item IDs, one new drop per conquered city, five valid equipped slots in the gear variant, and no gear active during the three control sieges. Record per-city drops/loadouts and City 15 elapsed/stall data; compare with HPA-670's no-gear 570.5s baseline and bought Treasury 383.2s (seed 582), without assuming a speed-up.
- Build, SwiftLint, serial unit/UI tests, and Codecov project/patch thresholds pass. Implementation, test changes and evidence all land in **the same PR**.
