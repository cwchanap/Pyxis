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

Add `ascensionCount: Int` and `private(set) equipmentLevelsByID: [String: Int]` to `KingdomGameState`. Expose `equipmentLevel(for itemID: String) -> Int?` (nil when unowned) instead of having callers inspect the raw levels map. Add one explicit result enum:

- `AscensionResult.ascended(newCount: Int)` on success.
- `AscensionResult.unavailable` if the campaign is not complete or any conquest result is pending; state remains exactly equal to its pre-call value.

The successful mutation is one atomic value-type transition, reusing the normal initializer/normalization for fresh per-run state and explicitly copying the permanent fields:

| Reset to a new run | Keep across Ascension |
| --- | --- |
| `gold = 0`; `countryNumber = 1`, `cityNumberInCountry = 1`, `cityLevel = 1`, `completedCityCount = 0`, `stageStatus = .battleActive` | Owned equipment IDs and selected equipment per soldier type, including deliberately empty slots |
| Empty `cityBattleStates`, `activeSiegeSession = nil`, `pendingBattleResult = nil`; fresh City 1 `siegeProgress` and `lastBackgroundedAt = nil` | Existing per-item equipment levels, `ascensionCount` incremented by one |
| `treasury = TreasuryState()` (all upgrades zero) | Feedback preferences, which already live in a separate preferences store and are never reset here |

**Zero-gold opening is intentional and differs from a fresh game (15 gold).** The first replay starts without a Barracks: City 1's infantry manual deploy remains available at level 1 (`manualSoldierLevel(for: .infantry)` fallback), but idle production is building-driven, so it cannot progress until the player can afford a building. At **Renown 1**, City 1 yields `8 × 1.25 = 10` gold, below a Barracks's 15-gold cost. Cities 1 and 2 therefore start manual-only on the first replay; later Renown counts can change when the first building becomes affordable. At City 1, early integer attack rounding may also hide the Renown improvement. This is a conscious cost of the ticket's `gold = 0` requirement, **not** a reason to silently change it to 15. Test actual manual-deploy conquest and separately log City 1/2 times in the early balance run; if unacceptable, seek an explicit gameplay decision instead of changing the requirement by inference.

`ascend()` does not call `completeCurrentCity`, replay a report, or recreate the existing city's siege. No new routing controller, persistence service, save-version table, or battle simulation is introduced.

## Renown: two shared calculation seams, no generic buff system

The unbounded gameplay factor for nonnegative count `n` is the single computed `KingdomGameState.renownMultiplier = 1.0 + 0.25 * Double(n)`; both gold and the first-round soldier multiplier consume it.

1. **Soldier attack, first round:** add one state accessor `firstRoundAttackMultiplier(for: SoldierType)` composing `TreasuryDrillYard × level-scaled equippedAttackGear × Renown`. The state-aware live spawn method and the idle batch's cached per-type projection **both** use this accessor. The pure static `traitAdjustedSoldierAttackPower(for:level:defenseTrait:multiplier:)` takes that one composite multiplier, applies `baseAttack × cityDefenseTrait × multiplier` and rounds once; update existing test/helper call sites rather than retaining competing static multiplier parameters. Preserve the existing second round for role/specialist versus objectives. Guards and the Vanguard Captain do not gain Renown attack.
2. **Conquest gold, one round:** extend the existing `goldReward(forCity:)` quote to round `baseGoldReward × TreasuryWarChest × Renown` exactly once. The report, Map, Battle HUD, live/idle/Camp conquest and settlement continue to consume that single quote. Do not apply a second bonus during `completeCurrentCity`.

Renown does not modify city HP, player soldier HP, enemy Guard/tower stats, spawn rates, equipment levels, or the price of Treasury/Camp buildings. Level-0 Renown reproduces existing values byte-for-byte. Existing live soldier attack power is snapshotted at spawn; a Kingdom-tab Ascend cannot occur while live combat is active.

## Equipment leveling / replay receipts

`EquipmentCatalog` remains the one stable 15-item authoring table; no new item IDs or rarity. Level is **owned-item state**, not an authored field. Levels are 1, 2, 3. The equipment effect's fractional bonus scales by **1 / 1.5 / 2** at those levels, and the multiplier remains `1 + (authoredBonus * levelScale)`. For example, +15% Attack becomes +15%, +22.5%, +30%; +25% Toughness becomes +25%, +37.5%, +50%; +40% Specialist becomes +40%, +60%, +80%.

**One scaling authority:** `EquipmentEffect.scaled(toLevel:)` in `EquipmentCatalog.swift` returns the typed Attack/Toughness/Specialist effect with its fractional bonus multiplied by the level's 1×/1.5×/2× scale. The state accessor `equippedEffect(for: SoldierType) -> EquipmentEffect?` reads the owned item's normalized level and returns that scaled effect. All three combat projection methods, the Armory's effect text and rounded-away disclosure, and VoiceOver must consume this **same scaled effect**—never the raw catalog fraction in the UI. The report displays item name/level from its receipt; it does not recompute an effect. Replace the existing `wholePercent` helper with a formatter preserving at most one decimal (e.g. 22.5%, 30%; no unwanted 22.5→23 rounding), rather than adding another percentage formatter.

**One reward receipt, not two:** replace the old optional `BattleResult.newEquipmentItemID` with `BattleResult.equipmentReward: EquipmentReward?`, a small Codable value with `itemID` and `level`. Level 1 means newly earned gear; levels 2/3 mean a replay upgrade. The capped level-3 repeat has no receipt. Update the existing report, tests, smoke-line readers and `CLAUDE.md` references in this **same PR**; no extra optional field or legacy-receipt migration is required for this pre-release project.

Extend the **one** `completeCurrentCity(with:)` gear-grant seam:

- First conquest of an unowned item: add the item, set level 1, preserve first-ever-soldier-type auto-equip semantics, and set `equipmentReward = EquipmentReward(itemID: item.id, level: 1)`. Never level up a newly obtained item.
- Repeat conquest of an owned item: increment its level up to 3, but never add a second owned ID or override the chosen/explicitly-None slot. A capped level-3 repeat is a no-op for gear.
- On an actual increase, set `equipmentReward = EquipmentReward(itemID: item.id, level: newLevel)`; clear any caller-supplied receipt before computing the award. A rejected/duplicate completion never modifies gold, equipment or the stored receipt. Only this single typed field represents either kind of gear reward.
- Reuse the existing optional, fail-open conquest-report gear line: `New gear: <name> · Lv 1` on first drop; `Gear upgraded: <name> · Lv 2` / `Lv 3` after repeat; omit it at the cap. This must survive save/relaunch, never make `ConquestReportLayout.compute` fail, and never hide Continue.
- Armory line/effect and full VoiceOver value display `Lv N` and the **effective fractional percentage** through `equippedEffect(for:)`, including 22.5% rather than rounding it to 23%. Live spawns, idle projection, and the existing rounded-away disclosure use the same scaled effect. Toughness remains live-only; Specialist keeps its existing target/objective and second-round semantics.

## Persistence / normalization

Existing `KingdomGameState` default memberwise initialization and `init(from:)` normalize the two added fields:

- A missing/malformed `ascensionCount` becomes 0; a negative count clamps to 0.
- A missing/malformed equipment-level map means all currently **owned** catalog items are level 1. For every valid owned item, normalize `levels[itemID] = min(3, max(1, decodedLevel ?? 1))`. Drop unknown or unowned item IDs. New drops establish level 1.
- Encode the normalized level map and Ascension count using the existing save. No schema/versioning framework; existing pre-HPA-672 saves remain readable through the normal optional-field defaults.
- Do not touch `FeedbackPreferencesStore`, which persists separately. Avoid adding levels to `EquipmentCatalog` or to a second account-scoped state object.

## Kingdom section / compact layout ownership

`KingdomSection` gains `.ascend`, selected section stays transient. Modify **only** `KingdomLayout` pure geometry and `KingdomScene` scene presentation:

- Put three ≥44pt section selector hit targets in the existing top 44pt header row and **remove the visible `Kingdom` title** (the selected tab identifies the screen). Retain a constant `Kingdom` accessibility header label. Delete the unused title frame, `minimumTitleWidth`, `titleSpareWidth`, and their width-fallback ladder. Distribute the free width among readable Treasury/Armory/Ascend selectors, with compact adaptive spacing and measured 9pt-floor text fit; at 320pt width the 288pt content column can give each selector roughly 72pt rather than an unreadable 44pt. Preserve the already-supported narrow width at the Treasury row floor (e.g. 264pt scene) with tested text fit or an accessible compact visible label fallback. Leave the 88pt header, 82pt four-tab bar, original Treasury row/Buy frames and five Armory row hit frames unchanged. No new stacked row or scrolling; fail closed only on truly unsupported geometry.
- Add a two-label gold/Renown bottom-header layout when count is positive. Text may shrink within tested bounds but may not collide with Settings, selectors or controls; the full Renown value is accessible. Delete `KingdomLayout.futureSectionFrame` and the old tests for it: Ascend uses the same content band, and the reservation is zero height at the smallest supported viewport.
- Ascend content renders within the **same** existing Treasury/Armory content band: current/next bonus, reset/keep summary, and one actionable confirmation area with ≥44pt hit targets. Confirm/Cancel are mutually unambiguous. Only this section probes `ascension-renown` with a vector fallback. Keep one Settings gear and existing four-tab navigation.
- Follow `KingdomScene`'s existing store-load, scene-local idle-settlement, layout-gate, accessibility adapter and routing patterns. A section-only switch never saves or settles; Ascension is stage-gated and has no pending active-idle work to credit.
- **DEBUG/evidence decision:** skip changing the city-jump picker (`DevJumpState`). Seed **only** the existing `map-country-complete` visual fixture with all 15 catalog items at Lv1 via a `KingdomGameState` constructor (ownership is `private(set)`), leaving other map fixtures untouched. From that state, capture the real Kingdom → Ascend → confirm → City 1 conquest → Lv2 gear report/Armory flow. Do not invent a new fixture framework or runtime debug control.

## Acceptance / balance evidence

Swift Testing proves blocked/mid-campaign/pending/second-call gates, exact reset-vs-permanent fields, save round-trip/clamping, grant-once and Lv1→2→3 cap, slot preservation, new-vs-upgrade report restoration/fail-open, all three level-scaled effects, and exact first/second-round live/idle parity including zero-Renown regressions. Kingdom layout/scene tests cover 320×454, compact phones with insets, portrait iPad, Settings/selector/confirm hit isolation, VoiceOver, absent art and pending-first routing. A fresh Ascension must allow free infantry manual deployment from zero gold.

Run the existing opt-in **seed-582** chained 15-city campaign rail **immediately after the stat-seam step and before the UI work**. Record matched ascension-0 vs ascension-1 runs with identical initial zero gold, all 15 items owned at level 1, empty Treasury, and the same test-only buyer/loadout policy; both level their gear through the same real repeat-conquest seam. The test-only greedy candidate scoring must use each candidate's **leveled** effect and Renown inside the same integer attack calculation, rather than its old raw level-1 bonus. Verify 15/15 and clearly lower total elapsed on Renown 1; log City 1/2 individually, plus per-city times, Treasury/gear levels, stalls and wall-clock. Stop/tune and rerun this checkpoint if it fails rather than completing the UI first. Separately verify a real Country-1 complete → acknowledge finale → ascend → City 1 → second conquest transition. Starting every matched run at level 1 isolates Renown from a pre-existing level advantage (both runs still upgrade the same gear as they replay).

Full serial unit/UI suite, SwiftLint, Debug+Release simulator builds, Codecov project/patch ≥90%, and visual evidence on compact phone/iPad belong on this same PR. No tests or measured balance numbers are claimed at the documentation-only stage.

## Out of scope

Prestige currency/shop, Renown caps, difficulty scaling, another country, generic combat-modifier or save architecture, separate implementation PR, icon production or SFX. HPA-673 supplies the final 20 art assets in its own art PR; HPA-672 remains one gameplay implementation PR.
