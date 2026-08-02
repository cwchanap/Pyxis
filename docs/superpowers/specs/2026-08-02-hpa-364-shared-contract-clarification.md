# HPA-364 Shared Contract Clarification

**Applies to:** HPA-389 design and implementation plan in PR #19  
**Source of truth:** HPA-364 design in PR #20  
**Date:** 2026-08-02

## Purpose

PR #19 originally showed an abbreviated `FeedbackPreferences` declaration containing only its two stored properties. That declaration correctly described persisted fields but under-specified the construction/default API required by HPA-364 and consumed by HPA-389 test doubles and composition.

This clarification supersedes the abbreviated `FeedbackPreferences` snippets in the HPA-389 design and implementation plan. All other shared signatures remain unchanged.

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
- Plain `JSONEncoder()` and `JSONDecoder()` key strategies preserve the exact camel-case keys.
- HPA-364 owns field-tolerant decoding and independent persistence; HPA-389 consumes the model and manager without redefining them.

## Implementation gate

Before HPA-389 production work begins, its Task 1 test doubles and later composition must compile against this exact HPA-364 model. No parallel preference type, extension-only substitute, or alternate default source should be introduced in HPA-389.
