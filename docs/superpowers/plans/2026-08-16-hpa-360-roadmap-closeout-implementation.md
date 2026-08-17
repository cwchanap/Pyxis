# HPA-360 Roadmap Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close HPA-360 at the already-shipped Country 1 enrichment scope while preserving the canceled HPA-567 validation record and keeping HPA-362, HPA-369, and HPA-367 evidence-gated in Backlog.

**Architecture:** This is a Linear-only roadmap metadata change. HPA-360 becomes the bounded closeout record; HPA-567 keeps the methodology-cost cancellation history; each deferred child keeps its existing start gate and blocker relation. No runtime or repository architecture changes are part of execution.

**Tech Stack:** Linear issue metadata/comments; GitHub planning documents only.

## Global Constraints

- Do not change production code, tests, assets, persistence, Xcode project files, CI, or runtime behavior.
- Do not reopen HPA-567.
- Do not move HPA-362, HPA-369, or HPA-367 out of Backlog.
- Do not record `Prototype`, `Activate`, `Ship`, `Revise`, or `Drop` for a deferred child; no qualifying product evidence exists.
- Do not treat HPA-618 DEBUG jump testing as casual-friction evidence.
- Do not create a replacement playtest harness, telemetry system, scoring system, or new gameplay issue merely to keep the roadmap active.
- Preserve HPA-360's Goal, Product principles, Delivery contract, Delivered baseline, and Product gates.

## File / issue map

**Planning artifacts:**

- `docs/superpowers/specs/2026-08-16-hpa-360-roadmap-closeout-design.md`
- `docs/superpowers/plans/2026-08-16-hpa-360-roadmap-closeout-implementation.md`

**Linear execution:**

- Modify: `HPA-360` description, add one closeout comment, move to Done.
- Verify only: `HPA-567`, `HPA-362`, `HPA-369`, `HPA-367`.
- Verify completed prerequisites: `HPA-366`, `HPA-365`, `HPA-390`.

---

### Task 1: Re-verify closeout preconditions

**Linear issues:** `HPA-360`, `HPA-567`, `HPA-366`, `HPA-365`, `HPA-390`, `HPA-362`, `HPA-369`, `HPA-367`

**Interfaces:**
- Consumes: current statuses, relations, and HPA-567 cancellation comments.
- Produces: a yes/no closeout precondition result.

- [ ] **Step 1: Fetch HPA-360 and HPA-567 with relations and comments**

```text
Linear.get_issue(id: "HPA-360", includeRelations: true)
Linear.get_issue(id: "HPA-567", includeRelations: true)
Linear.list_comments(issueId: "HPA-567")
```

Expected:

```text
HPA-360: Backlog
HPA-567: Canceled
HPA-567 final note: methodology cost was not affordable; partial City 1 evidence contains no subjective friction evidence; HPA-362/HPA-369/HPA-367 remain deferred.
```

- [ ] **Step 2: Verify the committed player-visible sequence is complete**

```text
Linear.get_issue(id: "HPA-366")
Linear.get_issue(id: "HPA-365")
Linear.get_issue(id: "HPA-390")
```

Expected: all three are `Done` / status type `completed`.

If any is not completed, stop. The closeout premise is false.

- [ ] **Step 3: Verify each deferred child still carries its evidence gate**

```text
Linear.get_issue(id: "HPA-362", includeRelations: true)
Linear.get_issue(id: "HPA-369", includeRelations: true)
Linear.get_issue(id: "HPA-367", includeRelations: true)
```

Expected:

- HPA-362: Backlog; requires playtest evidence for another tactical choice.
- HPA-369: Backlog; requires evidence for one active emotional moment.
- HPA-367: Backlog; requires concrete completed-city history demand.
- Existing HPA-567 blocker relations remain present.

Do not mutate any issue in Task 1.

- [ ] **Step 4: Record the verified premise**

Use this exact execution note:

```text
Closeout preconditions satisfied: HPA-366/HPA-365/HPA-390 are complete; HPA-567 is canceled for methodology cost with no qualifying product evidence; HPA-362/HPA-369/HPA-367 remain evidence-gated Backlog items.
```

---

### Task 2: Rewrite HPA-360 as a bounded closeout

**Linear issue:** `HPA-360`

**Interfaces:**
- Consumes: the current description plus Task 1 facts.
- Produces: one internally consistent roadmap description ready to close.

- [ ] **Step 1: Preserve stable sections**

Keep the current substantive content under:

```text
## Goal
## Product principles
## Delivery contract
## Delivered baseline — keep closed and freeze scope
## Product gates
```

Do not weaken the evidence gate, current-consumer-only rule, behavior-oriented testing rule, or complexity review trigger.

- [ ] **Step 2: Replace `## Active player-visible sequence` with this exact section**

```markdown
## Delivered Country 1 enrichment

The committed low-complexity player-value sequence is complete:

1. **HPA-366 — city identity** — shipped authored Country 1 names, flavor, and conquest identity through existing surfaces without new gameplay or persistence.
2. **HPA-365 — Recommended Camp** — shipped one deterministic explicit preparation suggestion through the existing Building View mutation path without an optimizer platform.
3. **HPA-390 — milestone presentation** — shipped presentation-only treatment for Cities 5, 10, and 15 without combat, economy, reward, or persistent milestone-state changes.

These three slices are the completed active scope of this roadmap. Do not reopen or expand them to create work for deferred hypotheses.
```

- [ ] **Step 3: Replace `## Campaign validation checkpoint` with this exact section**

```markdown
## Deferred evidence gate

HPA-567 attempted the planned City 1→15 casual-player validation and was canceled on August 13, 2026 because its strict human methodology — roughly 1–3 hours of foreground play plus an 8-hour idle window, without automation or state fabrication — was not affordable under current constraints.

The cancellation is **not** a successful validation result. Its preserved partial City 1 run contains no subjective casual-friction evidence and therefore does not justify a new mechanic or durable campaign subsystem.

HPA-618's DEBUG-only jump-to-city tool may be used for developer smoke testing, but it does not reproduce normal progression, repetition, attention cost, or casual decision-making and must not be treated as a substitute for HPA-567 evidence.

Until new human evidence exists:

- **HPA-362 — direct lane deployment** remains Backlog. Start only for repeated observed desire to choose a visible battlefield lane or a clearly documented need for one additional tactical choice.
- **HPA-369 — Rally** remains Backlog. Start only when battles are understandable but repeatedly feel emotionally flat and one optional active moment is supported by actual play evidence.
- **HPA-367 — Campaign Chronicle** remains Backlog/deferred. Start only for concrete completed-city history demand beyond the current completion feedback.

Closing HPA-360 does not mark these hypotheses as `ship`, `drop`, `prototype`, or `activate`. It records that no additional scope is justified today. Future evidence may reactivate one item without reopening the entire roadmap.
```

- [ ] **Step 4: Replace `## Deferred or removed` with this exact section**

```markdown
## Deferred or removed

- **HPA-362** — evidence-gated direct lane deployment experiment; remains Backlog.
- **HPA-369** — evidence-gated in-memory Rally experiment; remains Backlog.
- **HPA-367** — Campaign Chronicle; remains deferred until actual completed-city history demand exists.
- **HPA-368** — persistent collectible accolades remain canceled under Option C.
- **HPA-567** — casual City 1→15 validation remains canceled for methodology cost; its partial evidence does not support child activation.
- **HPA-566** — deletion-first gameplay-feedback simplification is already complete; do not reopen it as general cleanup.

Do not replace any deferred item with a new framework, mechanic, telemetry system, or cheaper-but-non-equivalent validation surrogate merely to continue the roadmap.
```

- [ ] **Step 5: Replace `## Roadmap completion criteria` with this exact section**

```markdown
## Roadmap completion criteria

HPA-360 is complete when:

- HPA-366, HPA-365, and HPA-390 are shipped as compact player-visible slices.
- The canceled HPA-567 attempt and its methodology-cost rationale remain recorded without being misrepresented as a successful playtest.
- HPA-362, HPA-369, and HPA-367 remain unactivated in the absence of their required human evidence.
- The number of systems a casual player must manage has not increased beyond the shipped Country 1 baseline.
- New code remains proportionate to demonstrated player value and the repository is not expanded merely to satisfy a roadmap queue.

Future player evidence can create a new bounded slice or reactivate one deferred hypothesis. It does not make this completed roadmap retroactively incomplete.
```

- [ ] **Step 6: Save the complete description atomically**

Make one call with the full merged description:

```text
Linear.save_issue(id: "HPA-360", description: <the complete merged Markdown assembled in Steps 1–5>)
```

Do not change status yet.

- [ ] **Step 7: Re-fetch and self-review HPA-360**

The final description must satisfy all of these checks:

```text
Contains "Delivered Country 1 enrichment"
Contains "Deferred evidence gate"
States HPA-567 is canceled, not completed
States HPA-618 DEBUG smoke is not substitute casual evidence
Leaves HPA-362/HPA-369/HPA-367 Backlog/deferred
Assigns no unsupported Prototype/Activate/Drop/Ship decision
Adds no new gameplay commitment
```

Fix the description before Task 3 if any check fails.

---

### Task 3: Close HPA-360 and verify nothing else moved

**Linear issues:** modify `HPA-360`; verify `HPA-567`, `HPA-362`, `HPA-369`, `HPA-367`

**Interfaces:**
- Consumes: the reviewed HPA-360 description.
- Produces: HPA-360 Done with a clear audit comment and unchanged deferred children.

- [ ] **Step 1: Add this exact HPA-360 closeout comment**

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

Future player evidence can reopen/re-scope validation or activate one bounded hypothesis directly; it does not require keeping this roadmap permanently open.

Planning: https://github.com/cwchanap/Pyxis/pull/38
```

Use:

```text
Linear.save_comment(issueId: "HPA-360", body: <the exact Markdown above>)
```

- [ ] **Step 2: Move only HPA-360 to Done**

```text
Linear.save_issue(id: "HPA-360", state: "Done")
```

Do not mutate HPA-567, HPA-362, HPA-369, or HPA-367.

- [ ] **Step 3: Verify final issue states and blockers**

Fetch the five issues and confirm:

```text
HPA-360: Done
HPA-567: Canceled
HPA-362: Backlog
HPA-369: Backlog
HPA-367: Backlog
```

Also confirm the HPA-567 blocker relation remains on each deferred child where it existed before execution.

- [ ] **Step 4: Verify the GitHub planning PR remains documentation-only**

Inspect PR #38 changed files.

Expected exactly:

```text
docs/superpowers/specs/2026-08-16-hpa-360-roadmap-closeout-design.md
docs/superpowers/plans/2026-08-16-hpa-360-roadmap-closeout-implementation.md
```

No Swift, test, asset, project, workflow, or configuration file belongs in this work.

- [ ] **Step 5: Record completion evidence**

Use this exact final execution summary:

```text
HPA-360 closed at shipped scope; HPA-567 remains canceled; HPA-362/HPA-369/HPA-367 remain deferred Backlog items; no runtime or repository behavior changed.
```

Do not create a follow-up gameplay ticket automatically.