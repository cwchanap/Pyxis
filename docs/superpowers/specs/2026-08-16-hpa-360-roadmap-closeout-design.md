# HPA-360 Roadmap Closeout Design

## Summary

Close the active HPA-360 roadmap at the current shipped Country 1 baseline instead of activating an evidence-gated mechanic without evidence.

The committed player-visible sequence is already complete: HPA-366 (city identity), HPA-365 (Recommended Camp), and HPA-390 (milestone presentation) are done. The required HPA-567 casual City 1→15 validation was then attempted and explicitly canceled because the methodology cost was not affordable. Its closing note also records that the partial run produced no subjective friction evidence and therefore cannot justify HPA-362, HPA-369, or HPA-367.

The smallest correct next action is therefore a roadmap decision, not gameplay code: update HPA-360 so the canceled validation no longer leaves the roadmap indefinitely open, keep all evidence-gated ideas deferred, and mark the roadmap complete at the shipped scope.

## Context

HPA-360 intentionally separates committed low-complexity enrichment from speculative mechanics:

- HPA-366 adds authored identity without new gameplay rules.
- HPA-365 adds one explicit, deterministic preparation recommendation without an optimizer platform.
- HPA-390 adds presentation-only milestones without persistence or combat changes.
- HPA-362 and HPA-369 are optional disposable experiments that require recorded playtest evidence before they start.
- HPA-367 is a durable campaign subsystem and requires explicit history demand before it starts.

All three committed player-visible slices are complete.

HPA-567 was the evidence gate for the remaining optional work. Its final Linear note says the strict human casual-run methodology was too expensive under current constraints, that a cheaper DEBUG jump substitute cannot produce the intended casual-friction evidence, and that the partial City 1 attempt contains no subjective evidence supporting Prototype/Activate decisions. HPA-567 is therefore Canceled rather than Done.

HPA-618 subsequently added a DEBUG-only jump-to-city tool for developer smoke testing, but that tool is explicitly not a replacement for casual validation. HPA-620 stabilized intermittent accessibility diagnostics and is also complete. Neither changes the product-evidence gate.

## Problem

The roadmap is now structurally stalled:

- HPA-362 is Backlog and blocked by HPA-567.
- HPA-369 is Backlog and blocked by HPA-567.
- HPA-367 is Backlog, explicitly deferred for history-demand evidence, and blocked by HPA-567 plus already-completed prerequisites.
- HPA-360 itself remains Backlog even though its committed player-value sequence shipped and its remaining children are intentionally optional.

Starting any child now would violate the roadmap's own evidence gate. Reopening HPA-567 without appetite for its full methodology would recreate the cost problem that caused cancellation. Treating HPA-618 smoke testing as equivalent evidence would weaken the product standard without actually observing casual friction.

Leaving HPA-360 open indefinitely has a different cost: it makes a finished bounded roadmap look unfinished and encourages future work to treat deferred ideas as the next queue instead of optional hypotheses.

## Decision

Treat the canceled HPA-567 validation as a reason to **stop expanding**, not as permission to lower the evidence bar.

Update HPA-360 so that:

1. The shipped HPA-366 → HPA-365 → HPA-390 sequence is recorded as the completed active scope.
2. HPA-567 remains Canceled with its existing methodology-cost rationale and preserved partial evidence.
3. HPA-362 and HPA-369 remain Backlog evidence-gated experiments.
4. HPA-367 remains Backlog/deferred until concrete completed-city history demand exists.
5. HPA-360 can move to Done without implementing any of those optional items.
6. Future evidence may reopen/re-scope validation or activate one deferred child, but roadmap completion does not imply those ideas were permanently rejected.

This is a product-scope closeout, not a substitute validation result. No `ship`, `drop`, or `activate` verdict is manufactured for HPA-362, HPA-369, or HPA-367.

## Considered approaches

### A. Close HPA-360 at the shipped baseline — recommended

**Shape**

- Keep the existing delivered code unchanged.
- Revise only the roadmap wording and completion criteria in Linear.
- Leave HPA-567 canceled and the three evidence-gated children in Backlog.
- Mark HPA-360 Done after the roadmap text clearly distinguishes "roadmap complete" from "hypothesis rejected."

**Why**

This follows the existing KISS/YAGNI contract exactly: when evidence for a new mechanic or durable subsystem is absent, do not build one. It also removes a zombie roadmap state without inventing replacement work.

### B. Re-scope HPA-567 into targeted DEBUG-jump smoke testing

**Rejected as roadmap evidence.** HPA-618 makes targeted smoke cheaper, but HPA-567's own cancellation note explicitly says a skip-to-city dev tool cannot produce the intended casual-friction evidence. This can verify presentation or routing defects, not justify a new gameplay mechanic or Chronicle.

A future targeted smoke ticket may still be useful for a concrete visual bug, but it should not become the roadmap gate by semantic relabeling.

### C. Start HPA-362 or HPA-369 as a cheap disposable prototype anyway

**Rejected.** Both issues explicitly say not to start merely because the infrastructure exists. Starting either without observed friction would turn the evidence gate into ceremony and increase the number of systems a casual player must evaluate.

HPA-367 is even less appropriate because it adds durable state and another map interaction.

## Target Linear state

### HPA-360

Move from Backlog to Done after revising the description.

Keep the Goal, Product principles, Delivery contract, Product gates, and delivered-baseline history. Replace the stale execution framing with a closeout framing:

- Rename the former active sequence as **Delivered Country 1 enrichment**.
- Record HPA-366, HPA-365, and HPA-390 as completed compact player-visible slices.
- Replace the campaign-validation section with **Deferred evidence gate** explaining that HPA-567 was attempted and canceled for methodology cost, not completed and not replaced by HPA-618.
- Keep HPA-362/HPA-369/HPA-367 explicitly deferred until new evidence exists.
- Update completion criteria so HPA-360 is complete when the committed slices are shipped and unsupported optional work remains unactivated.

### HPA-567

No status, description, or methodology change. It remains Canceled. Its final comment remains the authoritative explanation of why the run stopped and why its partial evidence cannot justify child activation.

### HPA-362 and HPA-369

No status change. Both remain Backlog.

Their existing start gates remain authoritative. A future activation must cite new human evidence that satisfies the relevant gate; closing HPA-360 is not that evidence.

### HPA-367

No status change. It remains Backlog/deferred.

A future activation still requires explicit completed-city history demand. Existing battle-result infrastructure is not sufficient justification.

## Repository impact

The roadmap closeout implementation changes **no production code, tests, assets, persistence, Xcode project configuration, CI, or runtime behavior**.

This planning PR contains only this design document and its implementation plan. The eventual execution is a Linear metadata/description update only.

Do not add a repo-level roadmap framework, decision registry, feature flag, telemetry, playtest harness, or new development tool for this closeout.

## Future work contract

Closing HPA-360 does not forbid future Pyxis work. It changes the default from "pick the next deferred child" to "start from a newly observed player problem."

Future work should follow one of these paths:

- A real casual validation run becomes affordable: reopen or replace HPA-567 with an evidence-preserving human validation ticket, then reconsider the relevant child.
- A concrete bug or polish issue appears during normal development/smoke testing: file that narrow issue directly.
- Independent player feedback demonstrates lane-choice, active-moment, or history demand: record the evidence on HPA-362, HPA-369, or HPA-367 before moving it out of Backlog.
- A new product direction supersedes HPA-360: create a new bounded roadmap rather than silently expanding the old one.

## Risks and mitigations

### Closing the roadmap may look like the deferred ideas were rejected

Mitigation: the closeout wording must say they remain hypotheses in Backlog and may be reconsidered with new evidence. Do not mark them Canceled or Done.

### A canceled blocker relation may look odd

Mitigation: keep it intentionally. The relation communicates that the original start condition was not satisfied. The issue descriptions already explain the evidence gate; do not remove the blocker merely to make the graph look cleaner.

### Future contributors may treat HPA-618 smoke results as product evidence

Mitigation: preserve the explicit boundary in HPA-360: DEBUG jump testing can find functional/presentation defects but cannot replace the casual-play evidence required by HPA-362/HPA-369/HPA-367.

### Roadmap completion could hide a real progression problem

Mitigation: HPA-567's cancellation record stays intact. Closing HPA-360 makes no claim that Country 1 passed the canceled validation; it only says no further speculative scope is justified today.

## Acceptance criteria

- HPA-360 clearly distinguishes delivered scope, canceled validation, and deferred hypotheses.
- HPA-360 no longer requires an unaffordable validation run as a prerequisite to closing the already-shipped roadmap.
- HPA-567 remains Canceled and unchanged.
- HPA-362, HPA-369, and HPA-367 remain Backlog and are not given unsupported Prototype/Activate/Drop decisions.
- HPA-360 moves to Done only after the revised description preserves all start gates and future-evidence semantics.
- No production/test/project/runtime file changes are made.
- The final HPA-360 comment links the planning PR and states that roadmap completion is a scope decision, not a validation result.