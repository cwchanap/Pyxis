# HPA-364 Shared Contract Clarification

**Applies to:** HPA-389 design and implementation plan in PR #19  
**Draft source:** HPA-364 design in PR #20  
**Post-merge authority:** `docs/superpowers/specs/2026-08-02-semantic-gameplay-feedback-foundation-design.md` on `main`  
**Date:** 2026-08-02

## Purpose

PR #19 originally showed an abbreviated `FeedbackPreferences` declaration containing only its two stored properties. That declaration correctly described persisted fields but under-specified the construction/default API required by HPA-364 and consumed by HPA-389 test doubles and composition.

This clarification supersedes the abbreviated `FeedbackPreferences` snippets in the HPA-389 design and implementation plan. All other shared signatures remain unchanged.

While PR #20 remains a draft, PR #19 and PR #20 must be updated together when a shared signature changes. After PR #20 merges, the HPA-364 design on `main` is authoritative. HPA-389 may narrow mapping and output policy but may not redefine the shared event, provider, preference-manager, or clock contracts.

## Exact preference contract

```swift
struct FeedbackPreferences: Codable, Equatable {
    static let defaultValue = FeedbackPreferences()

    var soundEffectsEnabled: Bool
    var hapticsEnabled: Bool

    init(
        soundEffectsEnabled: Bool = true,
        hapticsEnabled: Bool = true
    ) {
        self.soundEffectsEnabled = soundEffectsEnabled
        self.hapticsEnabled = hapticsEnabled
    }
}
```

Required semantics:

- The only stored and encoded fields are `soundEffectsEnabled` and `hapticsEnabled`.
- Both fields default to `true`.
- `FeedbackPreferences()` is valid and returns the enabled defaults.
- `FeedbackPreferences.defaultValue` returns the same enabled defaults.
- `FeedbackPreferences` uses custom field-tolerant `init(from:)` and synthesized `encode(to:)`.
- Plain `JSONEncoder()` and `JSONDecoder()` key strategies preserve the exact camel-case keys.
- HPA-364 owns field-tolerant decoding and independent persistence; HPA-389 consumes the model and manager without redefining them.

## Automatic-combat batch invariant

HPA-364 preserves an ordered array but does not inspect or validate membership. HPA-389's projector and scene integration own the invariant that `emitAutomaticCombat(_:)` receives only automatic-combat-eligible events:

- `soldierAttack`
- `towerFire`
- `soldierDamage`

Discrete deployment, building, invalid-action, reward, conquest, completion, and fortified-warning events must use `emit(_:)` instead.

## Implementation gate

Before HPA-389 production work begins:

- Task 1 test doubles and later composition must compile against the exact HPA-364 preference model.
- No parallel preference type, extension-only substitute, or alternate default source may be introduced.
- Automatic-combat projection tests must verify that no discrete-only event enters the batch.
- HPA-364 must be merged to `main` and PR #19 must consume that merged contract.