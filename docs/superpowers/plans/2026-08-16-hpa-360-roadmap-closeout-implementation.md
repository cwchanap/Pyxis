# HPA-360 Roadmap Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close HPA-360 at the already-shipped Country 1 enrichment scope while preserving the canceled HPA-567 validation record and keeping HPA-362, HPA-369, and HPA-367 evidence-gated in Backlog.

**Architecture:** This is a Linear-only roadmap metadata change. HPA-360 becomes the bounded closeout record; HPA-567 keeps the methodology-cost cancellation history; each deferred child keeps its existing start gate and blocker relation. The plan freezes both the current live HPA-360 description and the complete target description so execution is one reviewed replacement rather than a splice against mutable external text.

**Tech Stack:** Linear connector (`get_issue`, `list_comments`, `save_issue`, `save_comment`); GitHub planning documents only.

**Execution mode:** Use one inline `superpowers:executing-plans` session for the Linear work. Do not dispatch independent workers for these writes; verification, description save, closeout comment, status change, and final re-fetch stay in one session.

## Global Constraints

- Do not change production code, tests, assets, persistence, Xcode project files, CI, configuration, or runtime behavior.
- Do not reopen HPA-567.
- Do not move HPA-362, HPA-369, or HPA-367 out of Backlog.
- Do not record `Prototype`, `Activate`, `Ship`, `Revise`, or `Drop` for a deferred child; no qualifying product evidence exists.
- Do not treat HPA-618 DEBUG jump testing as casual-friction evidence.
- Do not create a replacement playtest harness, telemetry system, scoring system, repo roadmap, or new gameplay issue merely to keep the roadmap active.
- Keep HPA-567 blocker relations. They record an unmet start condition.
- Do not rewrite historical specs or `CLAUDE.md` as part of this closeout.
- Preserve HPA-360's Goal, Product principles, Delivery contract, Delivered baseline, and Product gates exactly as frozen below.
- Abort instead of guessing if the live HPA-360 description differs from the frozen source snapshot.

## File / issue map

**Planning artifacts:**

- `docs/superpowers/specs/2026-08-16-hpa-360-roadmap-closeout-design.md` — closeout decision and safety contract.
- `docs/superpowers/plans/2026-08-16-hpa-360-roadmap-closeout-implementation.md` — frozen source, complete target, and Linear execution checklist.

**Linear execution:**

- Modify: `HPA-360` description, add one closeout comment, move only HPA-360 to Done.
- Verify only: `HPA-567`, `HPA-362`, `HPA-369`, `HPA-367`, `HPA-368`, `HPA-566`.
- Verify completed prerequisites: `HPA-366`, `HPA-365`, `HPA-390`.

There is no runtime implementation or repository mutation after this planning PR.

---

## Frozen source snapshot: current HPA-360 description

Captured from live Linear on August 16, 2026 before any closeout write. Execution must normalize only CRLF to LF and then require exact string equality with this snapshot before saving the target. Do not trim whitespace or reconstruct the source from headings.

```markdown
## Goal

Make Pyxis feel richer, clearer, and more rewarding for casual players without turning it into a complex strategy, city-building, or live-service game.

The target experience remains:

1. **One preparation decision** — understand the city and choose a sensible camp action.
2. **At most one lightweight tactical decision** — only when playtesting shows it improves the battle.
3. **One rewarding outcome** — receive a concise conquest result and memorable campaign presentation.

## Product principles

* Preserve the one-thumb idle siege loop.
* Reuse gold, buildings, five soldier types, defense traits, lane roles, and building-driven offline progress.
* Prefer readable information, one-tap assistance, authored identity, and strong feedback over new systems.
* Keep every active feature understandable from an icon and one short sentence.
* The campaign must remain fully playable when optional assistance or experimental active features are ignored.
* Favor KISS, YAGNI, fast iteration, and maintainable feature boundaries over speculative platform architecture.

## Delivery contract

Every remaining child follows these engineering rules:

### Vertical slice first

Every implementation ticket must ship player-visible behavior. Foundation-only work is allowed only when it removes existing duplication or is required by the player-facing slice in the same ticket.

### Pre-release compatibility

Preserve development saves when cheap, but a save reset is acceptable when it materially simplifies a breaking internal change. Migration and malformed-data machinery become mandatory only after a public release or demonstrated user need.

### Current consumer only

Do not add a protocol, manager, scheduler, persisted field, policy layer, or extension point without a concrete shipping consumer in the same issue.

### Behavior-oriented testing

Default to:

* Pure tests for important gameplay rules.
* One representative scene-flow test for the feature.
* A manual smoke of the affected player journey.

Exhaustive corruption, concurrency, lifecycle, geometry, or implementation-order matrices require an observed failure risk. Tests should protect player behavior rather than freeze internal object structure.

### Complexity review trigger

Reduce scope before implementation when a ticket proposes more than five new production files, a new architectural layer, or roughly 1,500 added production lines. The default response is simplification, not additional design infrastructure.

### Evidence gate

New mechanics and durable campaign subsystems require a recorded playtest observation. Low-cost authored content and presentation improvements may proceed without that gate.

## Delivered baseline — keep closed and freeze scope

* <issue id="c75e8461-55f0-434f-a5ab-4da610e52cef" href="https://linear.app/cwchanap/issue/HPA-361/centralize-country-1-city-definitions-and-preserve-authored-combat">HPA-361</issue> — centralized Country 1 definitions.
* <issue id="f0af28ed-5a25-4a07-84e5-7dee913f4b2b" href="https://linear.app/cwchanap/issue/HPA-363/add-typed-battle-events-and-a-persistent-active-siege-result-model">HPA-363</issue> — battle result/session data used by the conquest report.
* <issue id="35f6157b-3f13-4d6b-b492-bfa5d5e8c4f6" href="https://linear.app/cwchanap/issue/HPA-364/add-a-semantic-gameplay-feedback-service-and-persistent-sfxhaptic">HPA-364</issue> — semantic gameplay feedback and preferences.
* <issue id="38bce27c-2f1f-4d49-af45-ef2b72a641c4" href="https://linear.app/cwchanap/issue/HPA-387/add-the-unlocked-city-scout-card-to-the-country-map">HPA-387</issue> — unlocked-city Scout Card.
* <issue id="f24d709a-2531-436d-a3a3-795c5a06ee2f" href="https://linear.app/cwchanap/issue/HPA-388/present-a-compact-conquest-report-from-battleresult">HPA-388</issue> — compact conquest report.
* <issue id="443f73a4-4604-47b8-ab52-263cbe723e78" href="https://linear.app/cwchanap/issue/HPA-389/integrate-gameplay-sound-effects-and-haptics-and-add-the-settings">HPA-389</issue> — gameplay SFX, haptics, and settings.

Do not expand these completed tickets with generic future-facing fields, additional feedback policy, more report statistics, or more Scout Card hierarchy. Feedback simplification is tracked separately by <issue id="4bb6208a-b6cd-46df-87cd-2b3bfb48f505" href="https://linear.app/cwchanap/issue/HPA-566/simplify-gameplay-feedback-architecture-through-deletion-first">HPA-566</issue> and must be deletion-first rather than a rewrite.

## Active player-visible sequence

### 1. <issue id="41e97edc-8b6c-452d-8f68-0016c15eec18" href="https://linear.app/cwchanap/issue/HPA-366/author-and-integrate-country-1-city-names-and-short-identity-content">HPA-366</issue> — city names and concise identity

Ship the reviewed 15-city identity set and reuse it across current surfaces. This is the next roadmap item because it adds perceived content without adding mechanics or persistence.

### 2. <issue id="e55f8ea2-f3f7-4633-94cc-e9e2c46a4ba5" href="https://linear.app/cwchanap/issue/HPA-365/add-a-deterministic-recommended-camp-suggestion-and-one-tap-purchase">HPA-365</issue> — Recommended Camp action

Ship one compact deterministic suggestion and one explicit purchase through the existing mutation path. Keep the implementation to one small pure decision function plus the Building View slice; do not create a recommendation framework.

### 3. <issue id="1e7723fc-9c21-41ef-8fa6-e1e4ae79a4fd" href="https://linear.app/cwchanap/issue/HPA-390/add-presentation-only-milestone-treatment-for-cities-5-10-and-15">HPA-390</issue> — milestone presentation

Add lightweight presentation-only treatment for Cities 5, 10, and 15. Same-session duplicate suppression is sufficient before release; do not add durable consumed-presentation state solely to handle unusual reconstruction or relaunch paths.

Each item must be independently shippable and must not wait for another foundation-only ticket.

## Campaign validation checkpoint

After <issue id="41e97edc-8b6c-452d-8f68-0016c15eec18" href="https://linear.app/cwchanap/issue/HPA-366/author-and-integrate-country-1-city-names-and-short-identity-content">HPA-366</issue>, <issue id="e55f8ea2-f3f7-4633-94cc-e9e2c46a4ba5" href="https://linear.app/cwchanap/issue/HPA-365/add-a-deterministic-recommended-camp-suggestion-and-one-tap-purchase">HPA-365</issue>, and <issue id="1e7723fc-9c21-41ef-8fa6-e1e4ae79a4fd" href="https://linear.app/cwchanap/issue/HPA-390/add-presentation-only-milestone-treatment-for-cities-5-10-and-15">HPA-390</issue>, play City 1 through City 15 and record where the experience is confusing, repetitive, boring, or attention-heavy.

The result determines whether either experiment is justified:

* <issue id="044e11f9-93db-4d24-8fac-628b8891b269" href="https://linear.app/cwchanap/issue/HPA-362/add-safe-versus-fast-lane-tradeoffs-and-direct-manual-deployment">HPA-362</issue> — direct lane deployment and safe-versus-fast tradeoff, only when playtesting shows battles need another tactical choice.
* <issue id="2e494dc0-23b9-40ee-a0fd-e8e374367e43" href="https://linear.app/cwchanap/issue/HPA-369/research-spike-prototype-one-once-per-city-rally-action">HPA-369</issue> — one Rally action, only when playtesting shows battles need one active emotional moment.

These are optional experiments with an explicit **ship, revise once, or drop** outcome. They are not required for roadmap completion.

## Deferred or removed

* <issue id="56129016-8561-4471-aecf-718090a7acbf" href="https://linear.app/cwchanap/issue/HPA-367/add-atomic-campaign-chronicle-records-and-completed-city-cards">HPA-367</issue> — Campaign Chronicle remains outside the active sequence until playtesting shows that players want to inspect completed-city history. Do not build durable Chronicle infrastructure speculatively.
* <issue id="ac37724b-7b5f-4542-bb3d-40a3617d8996" href="https://linear.app/cwchanap/issue/HPA-368/deferred-decision-define-non-missable-accolade-semantics-before">HPA-368</issue> — collectible accolades are removed under Option C. Positive non-persistent conquest callouts are sufficient; do not create replay, objective, badge, or empty-slot systems.
* <issue id="4bb6208a-b6cd-46df-87cd-2b3bfb48f505" href="https://linear.app/cwchanap/issue/HPA-566/simplify-gameplay-feedback-architecture-through-deletion-first">HPA-566</issue> — deletion-first feedback cleanup is maintenance work to perform after the next player-value slice or when that code is next touched. It must not block <issue id="41e97edc-8b6c-452d-8f68-0016c15eec18" href="https://linear.app/cwchanap/issue/HPA-366/author-and-integrate-country-1-city-names-and-short-identity-content">HPA-366</issue> or <issue id="e55f8ea2-f3f7-4633-94cc-e9e2c46a4ba5" href="https://linear.app/cwchanap/issue/HPA-365/add-a-deterministic-recommended-camp-suggestion-and-one-tap-purchase">HPA-365</issue>.

## Product gates

* Default Spawn and manual building remain valid through the full campaign.
* No feature adds mandatory repeated input, energy, periodic login, or timer-watching pressure.
* No new currency, inventory, randomized loot, equipment, permanent build tree, ability loadout, or production chain.
* A recommendation may explain and offer one action but never spends resources automatically.
* No lane, unit, or active action is intentionally made universally correct.
* No boss mechanic, field army, individual-unit command, PvP, leaderboard, daily chore, streak, battle pass, or branching campaign progression.

## Roadmap completion criteria

* <issue id="41e97edc-8b6c-452d-8f68-0016c15eec18" href="https://linear.app/cwchanap/issue/HPA-366/author-and-integrate-country-1-city-names-and-short-identity-content">HPA-366</issue>, <issue id="e55f8ea2-f3f7-4633-94cc-e9e2c46a4ba5" href="https://linear.app/cwchanap/issue/HPA-365/add-a-deterministic-recommended-camp-suggestion-and-one-tap-purchase">HPA-365</issue>, and <issue id="1e7723fc-9c21-41ef-8fa6-e1e4ae79a4fd" href="https://linear.app/cwchanap/issue/HPA-390/add-presentation-only-milestone-treatment-for-cities-5-10-and-15">HPA-390</issue> ship as compact player-visible slices.
* A City 1→15 campaign smoke records product evidence for or against <issue id="044e11f9-93db-4d24-8fac-628b8891b269" href="https://linear.app/cwchanap/issue/HPA-362/add-safe-versus-fast-lane-tradeoffs-and-direct-manual-deployment">HPA-362</issue> and <issue id="2e494dc0-23b9-40ee-a0fd-e8e374367e43" href="https://linear.app/cwchanap/issue/HPA-369/research-spike-prototype-one-once-per-city-rally-action">HPA-369</issue>.
* <issue id="56129016-8561-4471-aecf-718090a7acbf" href="https://linear.app/cwchanap/issue/HPA-367/add-atomic-campaign-chronicle-records-and-completed-city-cards">HPA-367</issue> remains deferred unless player evidence supports it.
* The number of systems a casual player must manage does not increase.
* New code is proportionate to the player value delivered and leaves the repository easier—not harder—to change.
```

---

## Exact target HPA-360 description

This is the complete payload for the single `Linear.save_issue` description write. Stable source sections are copied verbatim from the frozen snapshot. Only the stale active-sequence, validation, deferred-work, and completion sections are replaced.

```markdown
## Goal

Make Pyxis feel richer, clearer, and more rewarding for casual players without turning it into a complex strategy, city-building, or live-service game.

The target experience remains:

1. **One preparation decision** — understand the city and choose a sensible camp action.
2. **At most one lightweight tactical decision** — only when playtesting shows it improves the battle.
3. **One rewarding outcome** — receive a concise conquest result and memorable campaign presentation.

## Product principles

* Preserve the one-thumb idle siege loop.
* Reuse gold, buildings, five soldier types, defense traits, lane roles, and building-driven offline progress.
* Prefer readable information, one-tap assistance, authored identity, and strong feedback over new systems.
* Keep every active feature understandable from an icon and one short sentence.
* The campaign must remain fully playable when optional assistance or experimental active features are ignored.
* Favor KISS, YAGNI, fast iteration, and maintainable feature boundaries over speculative platform architecture.

## Delivery contract

Every remaining child follows these engineering rules:

### Vertical slice first

Every implementation ticket must ship player-visible behavior. Foundation-only work is allowed only when it removes existing duplication or is required by the player-facing slice in the same ticket.

### Pre-release compatibility

Preserve development saves when cheap, but a save reset is acceptable when it materially simplifies a breaking internal change. Migration and malformed-data machinery become mandatory only after a public release or demonstrated user need.

### Current consumer only

Do not add a protocol, manager, scheduler, persisted field, policy layer, or extension point without a concrete shipping consumer in the same issue.

### Behavior-oriented testing

Default to:

* Pure tests for important gameplay rules.
* One representative scene-flow test for the feature.
* A manual smoke of the affected player journey.

Exhaustive corruption, concurrency, lifecycle, geometry, or implementation-order matrices require an observed failure risk. Tests should protect player behavior rather than freeze internal object structure.

### Complexity review trigger

Reduce scope before implementation when a ticket proposes more than five new production files, a new architectural layer, or roughly 1,500 added production lines. The default response is simplification, not additional design infrastructure.

### Evidence gate

New mechanics and durable campaign subsystems require a recorded playtest observation. Low-cost authored content and presentation improvements may proceed without that gate.

## Delivered baseline — keep closed and freeze scope

* <issue id="c75e8461-55f0-434f-a5ab-4da610e52cef" href="https://linear.app/cwchanap/issue/HPA-361/centralize-country-1-city-definitions-and-preserve-authored-combat">HPA-361</issue> — centralized Country 1 definitions.
* <issue id="f0af28ed-5a25-4a07-84e5-7dee913f4b2b" href="https://linear.app/cwchanap/issue/HPA-363/add-typed-battle-events-and-a-persistent-active-siege-result-model">HPA-363</issue> — battle result/session data used by the conquest report.
* <issue id="35f6157b-3f13-4d6b-b492-bfa5d5e8c4f6" href="https://linear.app/cwchanap/issue/HPA-364/add-a-semantic-gameplay-feedback-service-and-persistent-sfxhaptic">HPA-364</issue> — semantic gameplay feedback and preferences.
* <issue id="38bce27c-2f1f-4d49-af45-ef2b72a641c4" href="https://linear.app/cwchanap/issue/HPA-387/add-the-unlocked-city-scout-card-to-the-country-map">HPA-387</issue> — unlocked-city Scout Card.
* <issue id="f24d709a-2531-436d-a3a3-795c5a06ee2f" href="https://linear.app/cwchanap/issue/HPA-388/present-a-compact-conquest-report-from-battleresult">HPA-388</issue> — compact conquest report.
* <issue id="443f73a4-4604-47b8-ab52-263cbe723e78" href="https://linear.app/cwchanap/issue/HPA-389/integrate-gameplay-sound-effects-and-haptics-and-add-the-settings">HPA-389</issue> — gameplay SFX, haptics, and settings.

Do not expand these completed tickets with generic future-facing fields, additional feedback policy, more report statistics, or more Scout Card hierarchy. Feedback simplification is tracked separately by <issue id="4bb6208a-b6cd-46df-87cd-2b3bfb48f505" href="https://linear.app/cwchanap/issue/HPA-566/simplify-gameplay-feedback-architecture-through-deletion-first">HPA-566</issue> and must be deletion-first rather than a rewrite.

## Delivered Country 1 enrichment

The committed low-complexity player-value sequence is complete:

1. **HPA-366 — city identity** — shipped authored Country 1 names, flavor, and conquest identity through existing surfaces without new gameplay or persistence.
2. **HPA-365 — Recommended Camp** — shipped one deterministic explicit preparation suggestion through the existing Building View mutation path without an optimizer platform.
3. **HPA-390 — milestone presentation** — shipped presentation-only treatment for Cities 5, 10, and 15 without combat, economy, reward, or persistent milestone-state changes.

These three slices are the completed active scope of this roadmap. Do not reopen or expand them to create work for deferred hypotheses.

## Deferred evidence gate

HPA-567 attempted the planned City 1→15 casual-player validation and was canceled on August 13, 2026 because its strict human methodology — roughly 1–3 hours of foreground play plus an 8-hour idle window, without automation or state fabrication — was not affordable under current constraints.

The cancellation is **not** a successful validation result. Its preserved partial City 1 run contains no subjective casual-friction evidence and therefore does not justify a new mechanic or durable campaign subsystem.

HPA-618's DEBUG-only jump-to-city tool may be used for developer smoke testing, but it does not reproduce normal progression, repetition, attention cost, or casual decision-making and must not be treated as a substitute for HPA-567 evidence.

Until new human evidence exists:

- **HPA-362 — direct lane deployment** remains Backlog. Start only for repeated observed desire to choose a visible battlefield lane or a clearly documented need for one additional tactical choice. Start from current code: HPA-566 deleted the historical `fortifiedLaneWarning` / `fortifiedWarning` path, so HPA-364's old reserved-warning note is not infrastructure waiting to be wired.
- **HPA-369 — Rally** remains Backlog. Start only when battles are understandable but repeatedly feel emotionally flat and one optional active moment is supported by actual play evidence.
- **HPA-367 — Campaign Chronicle** remains Backlog/deferred. Start only for concrete completed-city history demand beyond the current completion feedback. The HPA-363 `// HPA-367: Chronicle write hooks here` no-op comment in `KingdomGameState` is a historical reservation only, not authorization to start Chronicle.

Closing HPA-360 does not mark these hypotheses as `ship`, `drop`, `prototype`, or `activate`. It records that no additional scope is justified today. Future evidence may reactivate one item without reopening the entire roadmap.

## Deferred or removed

- **HPA-362** — evidence-gated direct lane deployment experiment; remains Backlog.
- **HPA-369** — evidence-gated in-memory Rally experiment; remains Backlog.
- **HPA-367** — Campaign Chronicle; remains deferred until actual completed-city history demand exists.
- **HPA-368** — persistent collectible accolades remain canceled under Option C.
- **HPA-567** — casual City 1→15 validation remains canceled for methodology cost; its partial evidence does not support child activation.
- **HPA-566** — deletion-first gameplay-feedback simplification is already complete; do not reopen it as general cleanup.

Do not replace any deferred item with a new framework, mechanic, telemetry system, or cheaper-but-non-equivalent validation surrogate merely to continue the roadmap.

## Product gates

* Default Spawn and manual building remain valid through the full campaign.
* No feature adds mandatory repeated input, energy, periodic login, or timer-watching pressure.
* No new currency, inventory, randomized loot, equipment, permanent build tree, ability loadout, or production chain.
* A recommendation may explain and offer one action but never spends resources automatically.
* No lane, unit, or active action is intentionally made universally correct.
* No boss mechanic, field army, individual-unit command, PvP, leaderboard, daily chore, streak, battle pass, or branching campaign progression.

## Roadmap completion criteria

HPA-360 is complete when:

- HPA-366, HPA-365, and HPA-390 are shipped as compact player-visible slices.
- The canceled HPA-567 attempt and its methodology-cost rationale remain recorded without being misrepresented as a successful playtest.
- HPA-362, HPA-369, and HPA-367 remain unactivated in the absence of their required human evidence.
- The number of systems a casual player must manage has not increased beyond the shipped Country 1 baseline.
- New code remains proportionate to demonstrated player value and the repository is not expanded merely to satisfy a roadmap queue.

Future player evidence can create a new bounded slice or reactivate one deferred hypothesis. It does not make this completed roadmap retroactively incomplete.
```

---

### Task 1: Fail-closed preflight against live Linear

**Linear issues:** `HPA-360`, `HPA-567`, `HPA-366`, `HPA-365`, `HPA-390`, `HPA-362`, `HPA-369`, `HPA-367`, `HPA-368`, `HPA-566`

**Interfaces:**
- Consumes: live Linear descriptions, statuses, relations, and every HPA-567 comment.
- Produces: a checked preflight in the execution session only. It performs no Linear write.

- [ ] **Step 1: Verify HPA-360 has not drifted since planning**

Call `Linear.get_issue` for HPA-360 with relations included.

Normalize only `\r\n` to `\n`. Require the returned `description` to equal the complete **Frozen source snapshot** above exactly.

Also explicitly confirm these preserved headings are present in both source snapshot and target description:

```text
## Goal
## Product principles
## Delivery contract
## Delivered baseline — keep closed and freeze scope
## Product gates
```

The text under those preserved sections must be byte-identical between source and target after CRLF/LF normalization.

If the live HPA-360 description differs from the frozen source snapshot, stop. Do not merge sections by hand. Refresh this planning PR from the new live body first.

- [ ] **Step 2: Verify HPA-567 is still a canceled, evidence-empty attempt**

Call `Linear.get_issue` for HPA-567 with relations included and `Linear.list_comments(issueId: "HPA-567", limit: 250, orderBy: "createdAt")`.

Require all of the following:

- HPA-567 status is `Canceled`, not Done.
- The comments do not claim a full City 1→15 campaign completed.
- The comments do not claim a validated 30-minute-per-city stall or ~3-hour campaign-budget stop completed HPA-567.
- No comment affirmatively records subjective friction evidence in clarity, repetition, battle engagement/passivity, attention cost, reward/memory, history demand, or progression burden.
- No comment affirmatively records `Prototype`, `Activate minimal implementation`, `Drop`, `Ship`, or `Revise once` as the outcome of HPA-362, HPA-369, or HPA-367.
- The final cancellation note still says no City 1 deep-checkpoint observations were written, the partial evidence is insufficient for Prototype/Drop, and HPA-362/HPA-369/HPA-367 remain deferred.

Negative statements that merely contain decision words — for example “insufficient for any Prototype/Drop call” or “no casual-friction evidence was gathered to support Prototype/Activate” — are expected and do **not** count as affirmative outcomes.

If any affirmative evidence or child decision exists, stop. The closeout premise is stale and HPA-360 must be reconsidered instead of closed.

- [ ] **Step 3: Verify the shipped sequence and deferred children**

Fetch HPA-366, HPA-365, HPA-390, HPA-362, HPA-369, and HPA-367.

Require:

```text
HPA-366: Done
HPA-365: Done
HPA-390: Done
HPA-362: Backlog, still evidence-gated, HPA-567 blocker relation retained
HPA-369: Backlog, still evidence-gated, HPA-567 blocker relation retained
HPA-367: Backlog/deferred, still history-demand-gated, HPA-567 blocker relation retained
```

Do not mutate any child.

- [ ] **Step 4: Verify the two additional facts written by the target description**

Fetch HPA-368 and HPA-566.

Require:

```text
HPA-368: Canceled; description still says Option C removes collectible accolades from the roadmap
HPA-566: Done / completed
```

If either fact changed, stop and revise the target description before any Linear write.

- [ ] **Step 5: Record the preflight in the execution session, not Linear**

Check off this exact session-local checklist:

```text
[ ] Live HPA-360 description exactly matches frozen source snapshot.
[ ] HPA-366/HPA-365/HPA-390 are Done.
[ ] HPA-567 is Canceled and no comment contains affirmative qualifying friction evidence, a child activation/drop decision, or a completed acceptance path.
[ ] HPA-362/HPA-369/HPA-367 remain evidence-gated Backlog items with HPA-567 blockers retained.
[ ] HPA-368 remains Canceled under Option C.
[ ] HPA-566 remains Done.
```

Proceed only when every item is true.

---

### Task 2: Execute the closeout in one Linear session

**Linear issue modified:** `HPA-360` only.

**Interfaces:**
- Consumes: successful Task 1 preflight and the pinned **Exact target HPA-360 description** above.
- Produces: HPA-360 Done with the exact reviewed body and closeout comment; all deferred children unchanged.

Do not split this task across workers.

- [ ] **Step 1: Save the complete pinned target description in one write**

Call `Linear.save_issue` exactly once for the description update:

- `id`: `HPA-360`
- `description`: the complete Markdown under **Exact target HPA-360 description** above, copied verbatim.

Do not send a partial body and do not reconstruct the payload from headings during execution.

- [ ] **Step 2: Re-fetch HPA-360 before any other write**

Call `Linear.get_issue(id: "HPA-360", includeRelations: true)`.

Normalize only CRLF to LF and require the saved description to equal the pinned target description exactly.

Also confirm all five preserved headings remain present. Because the full target is pinned, any missing or modified preserved section is a failure even if all new closeout headings are present.

If equality fails, stop. Do not post the closeout comment and do not move HPA-360 to Done until the description is corrected to the reviewed target.

- [ ] **Step 3: Post the exact closeout comment**

Call `Linear.save_comment` for HPA-360 with this body:

```markdown
## Roadmap closeout — August 16, 2026

The committed HPA-360 Country 1 enrichment sequence is complete: HPA-366, HPA-365, and HPA-390 are shipped.

HPA-567's casual City 1→15 validation was attempted and canceled for methodology cost. Its partial run contains no qualifying subjective friction evidence, so this closeout does not manufacture a validation pass or activate downstream hypotheses.

Decision:

- HPA-360 closes at the shipped baseline.
- HPA-567 remains Canceled.
- HPA-362 and HPA-369 remain evidence-gated Backlog experiments.
- HPA-367 remains deferred until concrete completed-city history demand exists.
- HPA-618 DEBUG jump testing remains developer smoke only and is not a substitute evidence source.

Historical implementation notes do not bypass those gates: the HPA-363 Chronicle no-op hook is not authorization to start HPA-367, and HPA-566 removed the old HPA-362 fortified-warning path.

Future player evidence can reopen/re-scope validation or activate one bounded hypothesis directly; it does not require keeping this roadmap permanently open.

Planning: https://github.com/cwchanap/Pyxis/pull/38
```

- [ ] **Step 4: Move only HPA-360 to Done**

Call `Linear.save_issue` with:

```text
id: HPA-360
state: Done
```

Do not mutate HPA-567, HPA-362, HPA-369, HPA-367, HPA-368, or HPA-566.

- [ ] **Step 5: Final re-fetch and invariant check**

Re-fetch HPA-360, HPA-567, HPA-362, HPA-369, and HPA-367 with relations.

Require:

```text
HPA-360: Done; description exactly equals pinned target
HPA-567: Canceled
HPA-362: Backlog; HPA-567 blocker retained
HPA-369: Backlog; HPA-567 blocker retained
HPA-367: Backlog; HPA-567 blocker retained
```

No repository-scope check belongs here: this task is complete when Linear matches those invariants.

- [ ] **Step 6: Record completion evidence in the execution-session summary**

Use this exact summary:

```text
HPA-360 closed at the shipped Country 1 enrichment scope. HPA-567 remains Canceled; HPA-362/HPA-369/HPA-367 remain evidence-gated Backlog items with their blocker semantics intact. The HPA-360 body matches the reviewed pinned target, and no runtime or repository behavior changed.
```

Do not create a follow-up gameplay ticket automatically.