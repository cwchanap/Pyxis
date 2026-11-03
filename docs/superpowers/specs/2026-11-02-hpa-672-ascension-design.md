# HPA-672 — Country 1 Ascension, Renown and equipment levels: design

**Linear:** https://linear.app/cwchanap/issue/HPA-672/gameplay-ascension-restart-country-1-for-permanent-renown  
**Baseline:** `cwchanap/Pyxis` `main` at `eff4ce7f7656360ca1c3485a922d08fd23485528`, including merged HPA-670 Treasury (#49), HPA-671 Equipment (#50) and equipment review fixes (#51).  
**Delivery:** One HPA-672 implementation PR. This document and the companion plan start that PR; implementation, tests, balance evidence and review fixes will land in **the same PR**. Do not merge documentation alone.

## Goal and product constraints

After completing Country 1 City 15, the player can explicitly Ascend to replay the *same* 15 cities with permanent Renown and collected equipment. Every repeat conquest upgrades the city's owned gear (up to level 3). No extra cities, difficulty scaling, prestige currency/shop, new audio, or new art are required. The established prepare → deploy → watch → conquer loop and existing four gameplay tabs remain intact.

HPA-673 owns all final icons, including `ascension-renown`. This ticket probes the asset by that name and falls back to a small code-owned vector emblem, as Treasury and Armory already do.

## Player interaction and stages

- The Kingdom tab gains an **Ascend** section alongside **Treasury** and **Armory**. The section is accessible even before Country 1 is complete so the player can inspect the bonus and requirements, but its action is disabled until `stageStatus == .countryComplete` **and** `pendingBattleResult == nil`.
- After the City 15 report, **Continue** still acknowledges the persisted result before Ascension becomes available. No bypass of the pending-first report route; an in-flight or restored pending result must never be discarded by Ascension.
- The Ascend section shows current Renown, the next permanent bonus, and an explicit **Resets / Keeps** preview. The first tap on **Ascend** arms an in-scene confirmation; the player must then tap a distinct **Confirm Ascension** action. **Cancel**, changing sections, leaving the scene, or reconstructing the scene disarms it. Confirmation is UI-only, never saved.
- The commit re-reads the latest `KingdomGameStore` state, checks eligibility again, calls the pure `KingdomGameState.ascend()` mutation, saves once, and uses the existing `KingdomSceneRouting` / `GameViewController` path to open **Battle, Country 1 City 1**. Failed/repeated taps change nothing and do not save.
- Header displays `Renown 2 · +50%` when `ascensionCount >= 1`, otherwise stays gold-only. No new Renown badge in Battle, Camp, Map, or conquest HUD.

## Pure model contract

Add `ascensionCount: Int` and `equipmentLevelsByID: [String: Int]` to `KingdomGameState`. Add one explicit result enum:

- `AscensionResult.ascended(newCount: Int)` on success.
- `AscensionResult.unavailable` if the campaign is not complete or any conquest result is pending; state remains exactly equal to its pre-call value.

The successful mutation is one atomic value-type transition, reusing the normal initializer/normalization for fresh per-run state and explicitly copying the permanent fields:

| Reset to a new run | Keep across Ascension |
| --- | --- |
| `gold = 0`; `countryNumber = 1`, `cityNumberInCountry = 1`, `cityLevel = 1`, `completedCityCount = 0`, `stageStatus = .battleActive` | Owned equipment IDs and selected equipment per soldier type, including deliberately empty slots |
| Empty `cityBattleStates`, `activeSiegeSession = nil`, `pendingBattleResult = nil`; fresh City 1 `siegeProgress` and `lastBackgroundedAt = nil` | Existing per-item equipment levels, `ascensionCount` incremented by one |
| `treasury = TreasuryState()` (all upgrades zero) | Feedback preferences, which already live in a separate preferences store and are never reset here |

**Zero-gold opening is intentional.** City 1's infantry manual deploy remains available at level 1 even without a Barracks (`manualSoldierLevel(for: .infantry)` fallback). Regression tests must prove a replay's first battle can make progress without a paid building. Do not silently change the ticket's zero-gold reset into a starter grant.

`ascend()` does not call `completeCurrentCity`, replay a report, or recreate the existing city's siege. No new routing controller, persistence service, save-version table, or battle simulation is introduced.

## Renown: two shared calculation seams, no generic buff system

The unbounded gameplay factor for nonnegative count `n` is `renownMultiplier = 1.0 + 0.25 * Double(n)`.

1. **Soldier attack, first round:** extend `KingdomGameState.traitAdjustedSoldierAttackPower` so the single existing integer rounding includes `baseAttack × cityDefenseTrait × TreasuryDrillYard × equippedAttackGear × Renown`. Both live spawn paths already call the state-aware instance method. The idle `applyAbstractBuildingSpawnDamage` path currently calls the static helper directly with cached Treasury/gear factors; extend its cached first-round multiplier to include Renown in the **same** rounding, then preserve the existing second round for role/specialist versus objectives. Guards and the Vanguard Captain do not gain Renown attack.
2. **Conquest gold, one round:** extend the existing `goldReward(forCity:)` quote to round `baseGoldReward × TreasuryWarChest × Renown` exactly once. The report, Map, Battle HUD, live/idle/Camp conquest and settlement continue to consume that single quote. Do not apply a second bonus during `completeCurrentCity`.

Renown does not modify city HP, player soldier HP, enemy Guard/tower stats, spawn rates, equipment levels, or the price of Treasury/Camp buildings. Level-0 Renown reproduces existing values byte-for-byte. Existing live soldier attack power is snapshotted at spawn; a Kingdom-tab Ascend cannot occur while live combat is active.

## Equipment leveling / replay receipts

`EquipmentCatalog` remains the one stable 15-item authoring table; no new item IDs or rarity. Level is **owned-item state**, not an authored field. Levels are 1, 2, 3. The equipment effect's fractional bonus scales by **1 / 1.5 / 2** at those levels, and the multiplier remains `1 + (authoredBonus * levelScale)`. For example, +15% Attack becomes +15%, +22.5%, +30%; +25% Toughness becomes +25%, +37.5%, +50%; +40% Specialist becomes +40%, +60%, +80%.

Extend the **one** `completeCurrentCity(with:)` gear-grant seam:

- First conquest of an unowned item: add the item, set level 1, preserve first-ever-soldier-type auto-equip semantics, set existing `BattleResult.newEquipmentItemID`. Never level up a newly obtained item.
- Repeat conquest of an owned item: increment its level up to 3, but never add a second owned ID or override the chosen/explicitly-None slot. A capped level-3 repeat is a no-op for gear.
- Use one small optional `BattleResult.equipmentLevelUp` receipt (item ID, new level) **only** when a repeat actually increases the level. Clear any incoming/spoofed reward receipts at the grant seam. A rejected/duplicate completion never modifies gold, equipment or receipt.
- Reuse the existing optional, fail-open conquest-report gear line: `New gear: <name> · Lv 1` on first drop; `Gear upgraded: <name> · Lv 2` / `Lv 3` after repeat; omit it at the cap. This must survive save/relaunch, never make `ConquestReportLayout.compute` fail, and never hide Continue.
- Armory line/effect and full VoiceOver value display `Lv N` and the **effective fractional percentage** (including 22.5% rather than rounding it to 23%). Live spawns, idle projection, and the existing rounded-away disclosure use that level-aware effect. Toughness remains live-only; Specialist keeps its existing target/objective and second-round semantics.

## Persistence / normalization

Existing `KingdomGameState` default memberwise initialization and `init(from:)` normalize the two added fields:

- A missing/malformed `ascensionCount` becomes 0; a negative count clamps to 0.
- A missing/malformed equipment-level map means all currently **owned** catalog items are level 1. For every valid owned item, normalize `levels[itemID] = min(3, max(1, decodedLevel ?? 1))`. Drop unknown or unowned item IDs. New drops establish level 1.
- Encode the normalized level map and Ascension count using the existing save. No schema/versioning framework; existing pre-HPA-672 saves remain readable through the normal optional-field defaults.
- Do not touch `FeedbackPreferencesStore`, which persists separately. Avoid adding levels to `EquipmentCatalog` or to a second account-scoped state object.

## Kingdom section / compact layout ownership

`KingdomSection` gains `.ascend`, selected section stays transient. Modify **only** `KingdomLayout` pure geometry and `KingdomScene` scene presentation:

- Place three minimum-44pt section selector hit targets in the existing top 44pt header row. Compress selector widths, fitting and title together on the established **320×454, zero-inset** boundary; leave the 88pt header, 82pt four-tab bar, original Treasury row/Buy frames and five Armory row hit frames unchanged. Do not stack an additional section below Treasury or add scrolling. Test previously supported narrow safe-area widths and fail closed if genuinely unsupportable.
- Add a two-label gold/Renown header layout when count is positive. Text may shrink within tested bounds but may not collide with Settings, selectors or controls; the full Renown value is accessible.
- Ascend content renders within the **same** existing Treasury/Armory content band: current/next bonus, reset/keep summary, and one actionable confirmation area with ≥44pt hit targets. Confirm/Cancel are mutually unambiguous. Only this section probes `ascension-renown` with a vector fallback. Keep one Settings gear and existing four-tab navigation.
- Follow `KingdomScene`'s existing store-load, scene-local idle-settlement, layout-gate, accessibility adapter and routing patterns. A section-only switch never saves or settles; Ascension is stage-gated and has no pending active-idle work to credit.

## Acceptance / balance evidence

Swift Testing proves blocked/mid-campaign/pending/second-call gates, exact reset-vs-permanent fields, save round-trip/clamping, grant-once and Lv1→2→3 cap, slot preservation, new-vs-upgrade report restoration/fail-open, all three level-scaled effects, and exact first/second-round live/idle parity including zero-Renown regressions. Kingdom layout/scene tests cover 320×454, compact phones with insets, portrait iPad, Settings/selector/confirm hit isolation, VoiceOver, absent art and pending-first routing. A fresh Ascension must allow free infantry manual deployment from zero gold.

Extend the existing opt-in **seed-582** chained 15-city campaign rail, rather than writing another simulator. Record matched ascension-0 vs ascension-1 runs with identical initial zero gold, all 15 items owned at level 1, empty Treasury, equal loadout/buyer policies; both level their gear through the same real repeat-conquest seam. Verify 15/15 and lower total elapsed on Renown 1; log per-city times, Treasury/gear levels, stalls and wall-clock. Separately verify a real Country-1 complete → acknowledge finale → ascend → City 1 → second conquest transition. Starting every matched run at level 1 distinguishes Renown from a pre-existing level advantage; note that **both** runs level gear as they replay.

Full serial unit/UI suite, SwiftLint, Debug+Release simulator builds, Codecov project/patch ≥90%, and visual evidence on compact phone/iPad belong on this same PR. No tests or measured balance numbers are claimed at the documentation-only stage.

## Out of scope

Prestige currency/shop, Renown caps, difficulty scaling, another country, generic combat-modifier or save architecture, separate implementation PR, icon production or SFX. HPA-673 supplies the final 20 art assets in its own art PR; HPA-672 remains one gameplay implementation PR.
