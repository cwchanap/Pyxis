# HPA-811 — Effective early Drill Yard and attack-gear gains: design specification

**Linear:** https://linear.app/cwchanap/issue/HPA-811/early-drill-yard-and-attack-gear-give-no-damage-gain  
**Repository baseline:** cwchanap/Pyxis main at 98c9d358028d04ec8809a9e3efa5799aa1297422 (UAT baseline).  
**Delivery:** One HPA-811 implementation PR, initially containing this design and the companion plan. Add code, tests, smoke evidence, and review fixes to **this same PR**. Do not merge documentation alone.

## Problem and evidence

UAT found that the Drill Yard's first 16-gold purchase can display “2 → 2 attack (no damage change yet),” and even a level-2 +22.5% attack item can say “no gain yet.” Current attack power is an integer. The existing first round computes normal soldier attack × city-defense trait × Drill Yard (1 + 0.05 per level) × equipped attack-gear multiplier (level-scaled +15%/+22.5%/+30%) × Renown (1 + 0.25 per Ascension) and rounds once. Low attack bases therefore swallow purchased and earned bonuses. An honest “no gain yet” label does not make the purchase meaningful.

The shared state-aware attack projection powers **BattleScene** live spawns and the **KingdomScene** Drill Yard/Armory previews. In **KingdomGameState.applyAbstractBuildingSpawnDamage**, idle combat currently uses the pure static attack helper with a cached composite multiplier. The existing seed-582 campaign's test-only greedy equipment scorer also reimplements the first-round formula. These three paths must agree.

## Product decision

For ordinary soldiers, **every added Drill Yard level** and **every added level of an equipped attack item** grants at least +1 effective integer first-round attack, even when the authored percentage rounds away. Continue using the authored percentage result whenever it is stronger. This is intentionally an early-game minimum, **not** an extra flat +1 added after all percentages.

This covers the reported first Drill Yard purchase, and ensures Lv1 → Lv2 → Lv3 gear rewards are perceptible on replay. A gear item in an intentional empty slot gives no effect. A toughness or specialist item does not acquire an attack minimum. Percentages and gear-level scaling remain authored exactly as today.

This choice necessarily makes low-power buffs proportionally stronger than their displayed nominal percentage. The nominal percentage is **not** the entire effective rule at low power. The Kingdom descriptions and accessibility values must explicitly describe the minimum and show actual projected integers. Do not pretend +5% always equals the integer gain.

### Exact bounded first-round rule

For soldier type S and level L, with the current city defense trait and Renown:

- Let **d** be the current Drill Yard level (0–4).
- Let **g** be the level of the **equipped attack item** (0 when no attack item is equipped; otherwise 1–3).
- Define **raw(d,g)** as the existing one-round integer attack projection for normalSoldierAttackPower(S,L) × defenseTrait(S) × Renown × (1 + 0.05d) × gearMultiplier(g). The latter is 1 at g=0, or 1 + that item’s authored attack fraction scaled by EquipmentEffect.scaled(toLevel:g) at g=1–3. Preserve the existing minimum-1 and Swift rounding behavior.
- Define **effective(0,0) = raw(0,0)**.
- For each valid pair (d,g), define **effective(d,g)** as the maximum of: raw(d,g); effective(d−1,g)+1 when d>0; effective(d,g−1)+1 when g>0.
- Return **effective(actual d, actual g)** for the soldier being spawned/represented. Compute this tiny at-most-5×4 table on demand; it is derived from existing state and never persisted.

The two predecessor constraints prove that increasing **either** attack-upgrade rank yields at least +1 effective first-round attack, even when the other source is equipped. If normal percentage math already gives the increment, that result wins. No fractional HP, deferred damage bank, RNG, stat-upgrade registry, migration, or additional persisted state is needed.

Examples for neutral-trait, no-Renown **level-1** infantry (normal attack 1):

| Drill Yard | Attack gear | Effective first-round attack |
| --- | --- | ---: |
| 0 | none | 1 |
| 1 | none | 2 |
| 0 | Lv 1 (+15%) | 2 |
| 0 | Lv 2 (+22.5%) | 3 |
| 0 | Lv 3 (+30%) | 4 |
| 1 | Lv 1 | 3 |

These are minimum-effective integers, not promises that the nominal percentage alone produces those deltas. For sufficiently large attack bases, the unchanged percentage calculation dominates the minimum.

## Ownership and invariants

1. **KingdomGameState** remains the only rules owner. Keep the pure static trait-adjusted function as the one-round percentage primitive; add only a focused state-aware effective-first-round projection (or a small private helper) to apply this bounded rule. Read the existing Treasure/Equipment/Renown authorities rather than introducing copied constants or bonus state. Keep the public state-aware traitAdjustedSoldierAttackPower entry point the runtime source of truth.
2. **Live** spawns continue capturing the attack power once at spawn; changing loadouts or Treasury later does not rewrite active soldiers. **Idle** building-spawn damage must call the identical effective projection, not the old static percentage-only path. Keep its Guard absorption, objective-role second round, spill budget and at-most-one-conquest semantics.
3. The separate **second-round** inherent objective-role and specialist multiplier remains unchanged; neither enemy Guards nor the Vanguard Captain receives a new bonus. HP, price curves, economy, conquest gold, Renown scaling, troop spawn rates and equipment drops are out of scope.
4. **KingdomScene** Drill Yard next-level example continues projecting current and next state through the real attack API. An attainable level should no longer show “no damage change yet” for the example. An equipped attack item’s Armory description should show its effective level and truthful minimum; do not append the attack “no gain yet” note. Preserve that note for rounded-away specialist/toughness effects. Fit compact existing rows and VoiceOver labels.
5. **Country1SiegeSmoke** greedy candidate scoring must project the real state after a hypothetical equip/unequip rather than recomputing percentage-only attack. This is a **test helper** change, not player AI. Correct any tests whose old expected choice depended on attack bonuses rounding away.
6. No new art or SFX. HPA-812 owns general Camp/Map/Kingdom/Battle UI polish and must not be folded into this task. No additional Linear issue is needed for the existing, contained gameplay change.

## Alternatives deliberately not chosen

- **Gate the Drill Yard until the displayed integer rises:** leaves already-earned attack gear with ineffective levels and requires non-obvious shop state restrictions across cities/Ascension.
- **Increase attack percentages until low-level rounding changes:** cannot guarantee all +15% / +22.5% / +30% ranks change a base of 1 without extreme power inflation.
- **Fractional attack/HP or an accumulated sub-integer damage system:** preserves fine-grained percent balance, but broadens live/idle combat, objective HP, HUD and persistence for a small hobby-project bug.
- **Always add upgrade rank to a rounded total:** smaller implementation, but a large raw percentage result can mask a later rank; the bounded predecessor rule makes the ticket's guarantee testable.

## Acceptance and balance gate

- Across reachable low troop levels (at minimum 1–8), every defense trait category (neutral/advantaged/disadvantaged), Drill Yard 0–4, equipped attack item levels 0–3, and Ascension 0/1/representative later count, **effective(d+1,g) > effective(d,g)** and **effective(d,g+1) > effective(d,g)**. Check all five soldier types, with gear only for their own type.
- With Drill Yard 0 and no attack gear, the attack projection is **exactly** the current main value, including Renown. Unequipping restores it; other gear kinds, Guards, Captain and second-round role damage are unchanged.
- Live spawn and idle abstract attacks report the same effective first-round power for matching soldier level, city trait and upgrades. Existing soldiers do not retroactively change.
- Drill Yard and Armory previews and accessibility values agree with effective combat attack; all affected compact layouts remain readable.
- Run serial unit/UI suites, lint and builds, and **the required opt-in chained Country 1 campaign smoke**. Compare seed-582 bought-Treasury/gear play and matched Renown 0/1 replay runs against the current evidence. Log all 15 cities, first-replay City 1/2, stalls and total time. A 15/15 pass alone does not prove acceptable pacing; review the duration shifts and stop for a product decision if early power makes progression trivial.
- Do not alter balance constants or suppress a failing expectation just to get green tests. Record measurements and any product compromise in this same PR.
