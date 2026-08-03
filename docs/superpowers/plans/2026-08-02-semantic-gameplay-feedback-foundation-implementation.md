# Semantic Gameplay Feedback Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Foundation-only semantic gameplay-feedback, persistent two-toggle preference, synchronous observation, production no-op, and monotonic-clock contracts approved for HPA-364 and consumed by HPA-389.

**Architecture:** Three focused production files form the handoff. `GameplayFeedback.swift` owns semantic events, the provider/no-op boundary, and monotonic time; `FeedbackPreferences.swift` owns the exact two-field Codable model and public manager protocols; `FeedbackPreferencesStore.swift` owns explicitly injected `UserDefaults`, corruption recovery, domain-specific setters, and versioned synchronous observation. HPA-389 remains responsible for `TickResult` projection, automatic-batch membership, mapping, scheduling, platform output, composition, settings UI, and scene wiring.

**Tech Stack:** Swift 5, Foundation, `UserDefaults`, Swift Testing, Xcode/xcodebuild, SwiftLint.

**Design authority:** `docs/superpowers/specs/2026-08-02-semantic-gameplay-feedback-foundation-design.md` after PR #20 merges to `main`.

**Execution precondition:** Merge PR #20 first, then use `superpowers:using-git-worktrees` to create an isolated implementation branch/worktree from the resulting `main`. Do not implement HPA-364 on the documentation branch. HPA-362 is not a prerequisite; `fortifiedLaneWarning` remains a valid but unreachable case until HPA-362 lands.

## Global Constraints

- Production foundation files import Foundation only.
- Do not import SpriteKit, UIKit, AVFAudio/AVFoundation, CoreHaptics, Combine, Observation, or SwiftUI.
- Do not modify `BattleScene.swift`, `CountryMapScene.swift`, `BuildingViewScene.swift`, `GameViewController.swift`, CI configuration, assets, or `Pyxis.xcodeproj/project.pbxproj`.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`; new files are discovered automatically.
- Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`) rather than XCTest.
- Disable parallel xcodebuild testing for every test command.
- If `iPhone 17` is unavailable, run `xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations` and substitute an available supported iPhone simulator.
- `FeedbackPreferences` has exactly two stored fields: `soundEffectsEnabled` and `hapticsEnabled`.
- Both preference fields default to `true`.
- Use custom field-tolerant `init(from:)`, compiler-synthesized `encode(to:)`, and plain `JSONEncoder()` / `JSONDecoder()` key strategies.
- Persist under `pyxis.feedbackPreferences`; never read, write, remove, or migrate `pyxis.kingdomGameState`.
- `FeedbackPreferencesStore.init` requires an explicit `UserDefaults`; only `.shared` passes `.standard`.
- Store tests use unique suites and keys, never access `.shared`, and prove isolated construction/mutation does not write the unique test key to `UserDefaults.standard`.
- `<key>.corrupt` is one retained latest-corruption slot: later root corruption overwrites it; valid loads and writes do not clear it.
- Field-level decode failure intentionally fails open to `true` for only the malformed field.
- Observer delivery is synchronous, performs no queue hop, and is confined to one caller executor.
- `current` always reflects the latest committed snapshot; callback arguments remain specific to their delivery version.
- Cross-observer callback order is unspecified and must not be asserted.
- `SoldierAttackSoundCategory.allCases` is completeness-only; it does not define priority. HPA-389 owns the explicit siege → ranged → melee rotation.
- The approved audible collapse is Infantry/Cavalry → `.melee`, Archer/Mage → `.ranged`, Siege → `.siege`; magic has no distinct category.
- Production ships `NoOpGameplayFeedbackProvider`; recording providers remain test-only.
- Every task follows red → green → focused verification → commit.
- Run `git status --short` before each commit and stage only the listed task files.

## File Map

### Create

- `Pyxis/GameplayFeedback.swift` — semantic events, audible payload types, provider/no-op boundary, monotonic clock.
- `Pyxis/FeedbackPreferences.swift` — exact two-field model, tolerant decoding, observation and manager protocols.
- `Pyxis/FeedbackPreferencesStore.swift` — explicit persistence, corruption recovery, setters, observer records, token implementation.
- `PyxisTests/GameplayFeedbackTests.swift` — event contract, test-local recorder, no-op, ordered batch, manual clock.
- `PyxisTests/FeedbackPreferencesTests.swift` — defaults, exact keys, tolerant decoding, round trips, final compile-only consumer check.
- `PyxisTests/FeedbackPreferencesStoreTests.swift` — persistence isolation/recovery and observation/re-entrancy tests.

### Modify after implementation is green

- `CLAUDE.md` — document the HPA-364/HPA-389 ownership boundary and persistence key.

---

### Task 1: Define Semantic Events, Provider Boundary, and Monotonic Time

**Files:**
- Create: `Pyxis/GameplayFeedback.swift`
- Create: `PyxisTests/GameplayFeedbackTests.swift`

**Interfaces:**
- Consumes: Foundation `TimeInterval` and `ProcessInfo.processInfo.systemUptime`.
- Produces: `GameplayFeedbackEvent`, `SoldierAttackSoundCategory`, `SoldierDamageSoundKind`, `GameplayFeedbackProviding`, `NoOpGameplayFeedbackProvider`, `MonotonicClock`, and `SystemMonotonicClock`.

- [ ] **Step 1: Write the failing semantic-contract tests**

Create `PyxisTests/GameplayFeedbackTests.swift`:

```swift
//
//  GameplayFeedbackTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct GameplayFeedbackTests {
    @Test func everySemanticEventAndPayloadIsConstructibleAndEquatable() {
        let events: [GameplayFeedbackEvent] = [
            .manualDeployment,
            .soldierAttack(.melee),
            .soldierAttack(.ranged),
            .soldierAttack(.siege),
            .towerFire,
            .soldierDamage(.hit),
            .soldierDamage(.death),
            .buildingChanged,
            .invalidAction,
            .goldReward,
            .cityConquest,
            .countryCompletion,
            .fortifiedLaneWarning
        ]

        #expect(events.count == 13)
        #expect(events[0] == .manualDeployment)
        #expect(events[1] == .soldierAttack(.melee))
        #expect(events[6] == .soldierDamage(.death))
        #expect(events[12] == .fortifiedLaneWarning)
    }

    @Test func attackAllCasesIsACompleteSetWithoutOrderSemantics() {
        let categories = SoldierAttackSoundCategory.allCases

        #expect(categories.count == 3)
        #expect(categories.contains(.melee))
        #expect(categories.contains(.ranged))
        #expect(categories.contains(.siege))
    }

    @Test func recorderKeepsDiscreteAndAutomaticCallsDistinctAndOrdered() {
        let recorder = RecordingGameplayFeedbackProvider()
        let automatic: [GameplayFeedbackEvent] = [
            .soldierDamage(.death),
            .towerFire,
            .soldierAttack(.siege),
            .soldierAttack(.ranged),
            .soldierAttack(.melee),
            .soldierDamage(.hit)
        ]

        recorder.emit(.manualDeployment)
        recorder.emitAutomaticCombat(automatic)
        recorder.emitAutomaticCombat([])

        #expect(recorder.calls == [
            .discrete(.manualDeployment),
            .automatic(automatic),
            .automatic([])
        ])
    }

    @Test func noOpProviderAcceptsEveryEntryPoint() {
        let provider = NoOpGameplayFeedbackProvider()

        provider.emit(.countryCompletion)
        provider.emitAutomaticCombat([
            .towerFire,
            .soldierAttack(.melee),
            .soldierDamage(.hit)
        ])
    }

    @Test func manualClockAdvancesWithoutSleeping() {
        var clock = ManualMonotonicClock(now: 1.25)

        #expect(clock.now == 1.25)
        clock.now = 9.5
        #expect(clock.now == 9.5)
    }
}

private final class RecordingGameplayFeedbackProvider: GameplayFeedbackProviding {
    enum Call: Equatable {
        case discrete(GameplayFeedbackEvent)
        case automatic([GameplayFeedbackEvent])
    }

    private(set) var calls: [Call] = []

    func emit(_ event: GameplayFeedbackEvent) {
        calls.append(.discrete(event))
    }

    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {
        calls.append(.automatic(orderedEvents))
    }
}

private struct ManualMonotonicClock: MonotonicClock {
    var now: TimeInterval
}
```

The tests intentionally do not map `SoldierType` to sound categories; HPA-389 owns that mapping. The production file should document the approved collapse and the dormant-until-HPA-362 warning case, but should not import or reference `SoldierType`.

- [ ] **Step 2: Run the focused suite and verify the expected red state**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameplayFeedbackTests
```

Expected: build failure because the HPA-364 semantic and clock types do not exist.

- [ ] **Step 3: Implement the exact Foundation-only contract**

Create `Pyxis/GameplayFeedback.swift`:

```swift
//
//  GameplayFeedback.swift
//  Pyxis
//

import Foundation

enum GameplayFeedbackEvent: Equatable {
    case manualDeployment
    case soldierAttack(SoldierAttackSoundCategory)
    case towerFire
    case soldierDamage(SoldierDamageSoundKind)
    case buildingChanged
    case invalidAction
    case goldReward
    case cityConquest
    case countryCompletion
    case fortifiedLaneWarning
}

enum SoldierAttackSoundCategory: CaseIterable, Equatable {
    case melee
    case ranged
    case siege
}

enum SoldierDamageSoundKind: Equatable {
    case hit
    case death
}

protocol GameplayFeedbackProviding: AnyObject {
    func emit(_ event: GameplayFeedbackEvent)
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent])
}

final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {}
}

protocol MonotonicClock {
    var now: TimeInterval { get }
}

struct SystemMonotonicClock: MonotonicClock {
    var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
```

Add concise comments that state:

- `emitAutomaticCombat(_:)` is one caller-ordered batch per authoritative combat tick.
- HPA-364 preserves identity/order and performs no validation, projection, selection, throttling, queueing, or playback.
- HPA-389 maps Infantry/Cavalry to melee, Archer/Mage to ranged, and Siege to siege; magic has no separate category.
- `SoldierAttackSoundCategory.allCases` is for completeness only.
- `fortifiedLaneWarning` remains unreachable until HPA-362 supplies the producer.

- [ ] **Step 4: Run focused tests and lint**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameplayFeedbackTests

swiftlint lint
```

Expected: `GameplayFeedbackTests` passes and SwiftLint reports no violations.

- [ ] **Step 5: Commit the semantic boundary**

```bash
git status --short
git add Pyxis/GameplayFeedback.swift PyxisTests/GameplayFeedbackTests.swift
git commit -m "feat: define semantic gameplay feedback contract"
```

---

### Task 2: Add the Exact Tolerant Preference Model and Manager Protocols

**Files:**
- Create: `Pyxis/FeedbackPreferences.swift`
- Create: `PyxisTests/FeedbackPreferencesTests.swift`

**Interfaces:**
- Consumes: Foundation `Codable`, `Decoder`, and `CodingKey`.
- Produces: `FeedbackPreferences`, `FeedbackPreferencesObservation`, and `FeedbackPreferencesManaging`.

- [ ] **Step 1: Write failing model and coding tests**

Create `PyxisTests/FeedbackPreferencesTests.swift`:

```swift
//
//  FeedbackPreferencesTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct FeedbackPreferencesTests {
    @Test func defaultsEnableBothChannels() {
        #expect(FeedbackPreferences() == FeedbackPreferences(
            soundEffectsEnabled: true,
            hapticsEnabled: true
        ))
        #expect(FeedbackPreferences.defaultValue == FeedbackPreferences())
    }

    @Test func allBooleanCombinationsRoundTrip() throws {
        let values = [
            FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: false),
            FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: true),
            FeedbackPreferences(soundEffectsEnabled: true, hapticsEnabled: false),
            FeedbackPreferences(soundEffectsEnabled: true, hapticsEnabled: true)
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for value in values {
            let data = try encoder.encode(value)
            #expect(try decoder.decode(FeedbackPreferences.self, from: data) == value)
        }
    }

    @Test func encodedObjectContainsExactlyTheApprovedKeys() throws {
        let data = try JSONEncoder().encode(FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == Set([
            "soundEffectsEnabled",
            "hapticsEnabled"
        ]))
        #expect(object["soundEffectsEnabled"] as? Bool == false)
        #expect(object["hapticsEnabled"] as? Bool == true)
    }

    @Test func missingAndWrongTypedFieldsFailOpenIndependently() throws {
        let data = Data(#"""
        {
          "soundEffectsEnabled": false,
          "hapticsEnabled": "invalid",
          "futureField": 42
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(FeedbackPreferences.self, from: data)

        #expect(decoded.soundEffectsEnabled == false)
        #expect(decoded.hapticsEnabled == true)
    }

    @Test func missingSoundFieldPreservesValidHapticField() throws {
        let data = Data(#"{"hapticsEnabled": false}"#.utf8)

        let decoded = try JSONDecoder().decode(FeedbackPreferences.self, from: data)

        #expect(decoded.soundEffectsEnabled == true)
        #expect(decoded.hapticsEnabled == false)
    }
}
```

- [ ] **Step 2: Run the focused suite and verify the expected red state**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackPreferencesTests
```

Expected: build failure because `FeedbackPreferences` and the manager protocols do not exist.

- [ ] **Step 3: Implement the exact model and protocols**

Create `Pyxis/FeedbackPreferences.swift`:

```swift
//
//  FeedbackPreferences.swift
//  Pyxis
//

import Foundation

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

    private enum CodingKeys: String, CodingKey {
        case soundEffectsEnabled
        case hapticsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soundEffectsEnabled =
            (try? container.decode(Bool.self, forKey: .soundEffectsEnabled)) ?? true
        hapticsEnabled =
            (try? container.decode(Bool.self, forKey: .hapticsEnabled)) ?? true
    }
}

protocol FeedbackPreferencesObservation: AnyObject {
    func cancel()
}

protocol FeedbackPreferencesManaging: AnyObject {
    var current: FeedbackPreferences { get }

    @discardableResult
    func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences

    @discardableResult
    func setHapticsEnabled(_ enabled: Bool) -> FeedbackPreferences

    func observe(
        _ observer: @escaping (FeedbackPreferences) -> Void
    ) -> FeedbackPreferencesObservation
}
```

Do not implement `encode(to:)`. The compiler-synthesized encoder must use the two-case `CodingKeys` enum and emit both stored properties.

- [ ] **Step 4: Run focused tests and lint**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackPreferencesTests

swiftlint lint
```

Expected: `FeedbackPreferencesTests` passes and SwiftLint reports no violations.

- [ ] **Step 5: Commit the preference contract**

```bash
git status --short
git add Pyxis/FeedbackPreferences.swift PyxisTests/FeedbackPreferencesTests.swift
git commit -m "feat: define feedback preferences contract"
```

---

### Task 3: Implement Explicit Persistence, Recovery, and Domain-Specific Setters

**Files:**
- Create: `Pyxis/FeedbackPreferencesStore.swift`
- Create: `PyxisTests/FeedbackPreferencesStoreTests.swift`

**Interfaces:**
- Consumes: `FeedbackPreferences` from Task 2.
- Produces: `FeedbackPreferencesStore.shared`, `current`, explicit `init(defaults:key:)`, `setSoundEffectsEnabled(_:)`, and `setHapticsEnabled(_:)`. Observation conformance is added in Task 4.

- [ ] **Step 1: Write failing persistence and recovery tests**

Create the initial `PyxisTests/FeedbackPreferencesStoreTests.swift`:

```swift
//
//  FeedbackPreferencesStoreTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct FeedbackPreferencesStoreTests {
    @Test func missingDataLoadsEnabledDefaults() throws {
        let context = try makeStore()

        #expect(context.store.current == .defaultValue)
    }

    @Test func settersPreserveSiblingAndRoundTrip() throws {
        let context = try makeStore()

        #expect(context.store.setSoundEffectsEnabled(false) == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        #expect(context.store.setHapticsEnabled(false) == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        ))

        let reloaded = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )
        #expect(reloaded.current == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        ))
    }

    @Test func persistedPartialObjectUsesFieldLevelTolerance() throws {
        let context = try makeStore()
        context.defaults.set(
            Data(#"{"soundEffectsEnabled":false,"hapticsEnabled":"bad"}"#.utf8),
            forKey: context.key
        )

        let reloaded = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )

        #expect(reloaded.current == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == nil)
    }

    @Test func invalidRootBacksUpOriginalBytesAndDefaults() throws {
        let context = try makeStore()
        let corrupt = Data("{ invalid json".utf8)
        context.defaults.set(corrupt, forKey: context.key)

        let reloaded = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )

        #expect(reloaded.current == .defaultValue)
        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == corrupt)
    }

    @Test func nonKeyedRootUsesTheCorruptBackupPath() throws {
        let context = try makeStore()
        let nonKeyedRoot = Data(#"[true,false]"#.utf8)
        context.defaults.set(nonKeyedRoot, forKey: context.key)

        let reloaded = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )

        #expect(reloaded.current == .defaultValue)
        #expect(
            context.defaults.data(forKey: "\(context.key).corrupt") == nonKeyedRoot
        )
    }

    @Test func laterCorruptionOverwritesSingleBackupAndValidWritesKeepIt() throws {
        let context = try makeStore()
        let first = Data("first-invalid".utf8)
        let second = Data("second-invalid".utf8)

        context.defaults.set(first, forKey: context.key)
        _ = FeedbackPreferencesStore(defaults: context.defaults, key: context.key)
        context.defaults.set(second, forKey: context.key)
        let recovered = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )

        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == second)
        _ = recovered.setSoundEffectsEnabled(false)
        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == second)
        _ = FeedbackPreferencesStore(defaults: context.defaults, key: context.key)
        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == second)
    }

    @Test func preferenceWritesDoNotTouchCampaignState() throws {
        let context = try makeStore()
        let campaign = Data("campaign".utf8)
        context.defaults.set(campaign, forKey: "pyxis.kingdomGameState")

        _ = context.store.setHapticsEnabled(false)

        #expect(context.defaults.data(forKey: "pyxis.kingdomGameState") == campaign)
    }

    @Test func isolatedStoreNeverWritesItsKeyToStandardDefaults() throws {
        let defaults = try makeDefaults()
        let key = "feedback.\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: key)

        let store = FeedbackPreferencesStore(defaults: defaults, key: key)

        #expect(UserDefaults.standard.object(forKey: key) == nil)
        _ = store.setSoundEffectsEnabled(false)
        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }

    @Test func unchangedSetterSkipsEncodingAndPersistencePath() throws {
        let defaults = try makeDefaults()
        let key = "feedback.\(UUID().uuidString)"
        var encodeCount = 0
        let store = FeedbackPreferencesStore(
            defaults: defaults,
            key: key,
            encode: { value in
                encodeCount += 1
                return try JSONEncoder().encode(value)
            }
        )

        _ = store.setSoundEffectsEnabled(true)
        #expect(encodeCount == 0)
        _ = store.setSoundEffectsEnabled(false)
        #expect(encodeCount == 1)
        _ = store.setSoundEffectsEnabled(false)
        #expect(encodeCount == 1)
    }

    @Test func encodingFailureKeepsMemoryAndLastPersistedSnapshot() throws {
        let defaults = try makeDefaults()
        let key = "feedback.\(UUID().uuidString)"
        defaults.set(
            try JSONEncoder().encode(FeedbackPreferences()),
            forKey: key
        )
        let store = FeedbackPreferencesStore(
            defaults: defaults,
            key: key,
            encode: { _ in throw TestEncodingError.failed }
        )

        #expect(store.setSoundEffectsEnabled(false).soundEffectsEnabled == false)
        #expect(store.current.soundEffectsEnabled == false)

        let reloaded = FeedbackPreferencesStore(defaults: defaults, key: key)
        #expect(reloaded.current == .defaultValue)
    }

    private func makeStore() throws -> StoreContext {
        let defaults = try makeDefaults()
        let key = "feedback.\(UUID().uuidString)"
        return StoreContext(
            store: FeedbackPreferencesStore(defaults: defaults, key: key),
            defaults: defaults,
            key: key
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct StoreContext {
    let store: FeedbackPreferencesStore
    let defaults: UserDefaults
    let key: String
}

private enum TestEncodingError: Error {
    case failed
}
```

The internal `encode:` initializer exists only to exercise duplicate suppression and the defensive encoding-failure path. It is not part of the HPA-389 consumer contract.

- [ ] **Step 2: Run the focused suite and verify the expected red state**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackPreferencesStoreTests
```

Expected: build failure because `FeedbackPreferencesStore` does not exist.

- [ ] **Step 3: Implement loading, recovery, persistence, and setters without observation**

Create `Pyxis/FeedbackPreferencesStore.swift` with this structure:

```swift
//
//  FeedbackPreferencesStore.swift
//  Pyxis
//

import Foundation

final class FeedbackPreferencesStore {
    static let shared = FeedbackPreferencesStore(defaults: .standard)

    private(set) var current: FeedbackPreferences

    private let defaults: UserDefaults
    private let key: String
    private let encode: (FeedbackPreferences) throws -> Data

    convenience init(
        defaults: UserDefaults,
        key: String = "pyxis.feedbackPreferences"
    ) {
        self.init(
            defaults: defaults,
            key: key,
            encode: { try JSONEncoder().encode($0) }
        )
    }

    init(
        defaults: UserDefaults,
        key: String,
        encode: @escaping (FeedbackPreferences) throws -> Data,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.key = key
        self.encode = encode
        current = Self.load(defaults: defaults, key: key, decoder: decoder)
    }

    @discardableResult
    func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences {
        guard current.soundEffectsEnabled != enabled else {
            return current
        }

        var updated = current
        updated.soundEffectsEnabled = enabled
        commit(updated)
        return current
    }

    @discardableResult
    func setHapticsEnabled(_ enabled: Bool) -> FeedbackPreferences {
        guard current.hapticsEnabled != enabled else {
            return current
        }

        var updated = current
        updated.hapticsEnabled = enabled
        commit(updated)
        return current
    }

    private func commit(_ updated: FeedbackPreferences) {
        current = updated
        do {
            defaults.set(try encode(updated), forKey: key)
        } catch {
            NSLog(
                "[Pyxis] Failed to encode FeedbackPreferences: %@",
                error.localizedDescription
            )
        }
    }

    private static func load(
        defaults: UserDefaults,
        key: String,
        decoder: JSONDecoder
    ) -> FeedbackPreferences {
        guard let data = defaults.data(forKey: key) else {
            return .defaultValue
        }

        do {
            return try decoder.decode(FeedbackPreferences.self, from: data)
        } catch {
            NSLog(
                "[Pyxis] Failed to decode FeedbackPreferences: %@",
                error.localizedDescription
            )
            defaults.set(data, forKey: "\(key).corrupt")
            return .defaultValue
        }
    }
}
```

Keep the `encode:` initializer internal so `@testable import Pyxis` can use it. Do not add a default for the `defaults` argument. Do not delete the corrupt source data or its backup.

- [ ] **Step 4: Run focused tests and lint**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackPreferencesStoreTests

swiftlint lint
```

Expected: persistence/recovery tests pass and SwiftLint reports no violations.

- [ ] **Step 5: Commit the persistent store base**

```bash
git status --short
git add Pyxis/FeedbackPreferencesStore.swift PyxisTests/FeedbackPreferencesStoreTests.swift
git commit -m "feat: persist feedback preferences independently"
```

---

### Task 4: Add Synchronous Cancellable Re-entrant-safe Observation

**Files:**
- Modify: `Pyxis/FeedbackPreferencesStore.swift`
- Modify: `PyxisTests/FeedbackPreferencesStoreTests.swift`

**Interfaces:**
- Consumes: `FeedbackPreferencesManaging` and `FeedbackPreferencesObservation` from Task 2; persistence/setters from Task 3.
- Produces: full `FeedbackPreferencesStore: FeedbackPreferencesManaging` conformance, immediate observation, idempotent token cancellation, version-monotonic re-entrant delivery.

- [ ] **Step 1: Add failing observation and ownership tests**

Append these tests inside `FeedbackPreferencesStoreTests`:

```swift
@Test func observeImmediatelyDeliversCurrentAndDistinctUpdatesBeforeReturn() throws {
    let context = try makeStore()
    var snapshots: [FeedbackPreferences] = []
    let token = context.store.observe { snapshots.append($0) }

    #expect(snapshots == [.defaultValue])
    _ = context.store.setSoundEffectsEnabled(false)
    #expect(snapshots == [
        .defaultValue,
        FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: true)
    ])
    _ = context.store.setSoundEffectsEnabled(false)
    #expect(snapshots.count == 2)
    withExtendedLifetime(token) {}
}

@Test func explicitCancellationIsIdempotent() throws {
    let context = try makeStore()
    var count = 0
    let token = context.store.observe { _ in count += 1 }

    token.cancel()
    token.cancel()
    _ = context.store.setHapticsEnabled(false)

    #expect(count == 1)
}

@Test func selfCancellationPreventsNestedAndFutureCallbacks() throws {
    let context = try makeStore()
    var count = 0
    var token: FeedbackPreferencesObservation?

    token = context.store.observe { preferences in
        count += 1
        guard preferences.soundEffectsEnabled == false else { return }
        token?.cancel()
        _ = context.store.setHapticsEnabled(false)
    }

    _ = context.store.setSoundEffectsEnabled(false)
    _ = context.store.setSoundEffectsEnabled(true)

    #expect(count == 2)
}

@Test func tokenReleaseUnregistersObserver() throws {
    let context = try makeStore()
    var count = 0
    weak var weakToken: AnyObject?

    do {
        let token = context.store.observe { _ in count += 1 }
        weakToken = token
    }

    #expect(weakToken == nil)
    _ = context.store.setSoundEffectsEnabled(false)
    #expect(count == 1)
}

@Test func tokenDoesNotRetainStore() throws {
    let defaults = try makeDefaults()
    var store: FeedbackPreferencesStore? = FeedbackPreferencesStore(
        defaults: defaults,
        key: "feedback.\(UUID().uuidString)"
    )
    weak var weakStore = store
    var token: FeedbackPreferencesObservation? = store?.observe { _ in }

    store = nil

    #expect(weakStore == nil)
    token?.cancel()
    token = nil
}

@Test func crossCancellationCanRemoveObserverBeforeFutureUpdates() throws {
    let context = try makeStore()
    var cancelledObserverCount = 0
    let cancelledToken = context.store.observe { _ in
        cancelledObserverCount += 1
    }
    let cancellingToken = context.store.observe { _ in
        cancelledToken.cancel()
    }

    _ = context.store.setHapticsEnabled(false)

    #expect(cancelledObserverCount == 1)
    withExtendedLifetime(cancellingToken) {}
}

@Test func nestedSetterDuringInitialDeliveryDoesNotResendStaleInitialState() throws {
    let context = try makeStore()
    var snapshots: [FeedbackPreferences] = []

    let token = context.store.observe { preferences in
        snapshots.append(preferences)
        if preferences == .defaultValue {
            _ = context.store.setSoundEffectsEnabled(false)
        }
    }

    #expect(snapshots == [
        .defaultValue,
        FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: true)
    ])
    withExtendedLifetime(token) {}
}

@Test func nestedUpdatesNeverDeliverAStaleSnapshotAfterANewerOne() throws {
    let context = try makeStore()
    let versionOne = FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: true
    )
    let versionTwo = FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: false
    )
    var firstSnapshots: [FeedbackPreferences] = []
    var secondSnapshots: [FeedbackPreferences] = []

    let firstToken = context.store.observe { preferences in
        firstSnapshots.append(preferences)
        if preferences == versionOne {
            _ = context.store.setHapticsEnabled(false)
        }
    }
    let secondToken = context.store.observe { preferences in
        secondSnapshots.append(preferences)
    }

    _ = context.store.setSoundEffectsEnabled(false)

    #expect(isNondecreasing(firstSnapshots, versionOne: versionOne, versionTwo: versionTwo))
    #expect(isNondecreasing(secondSnapshots, versionOne: versionOne, versionTwo: versionTwo))
    #expect(firstSnapshots.last == versionTwo)
    #expect(secondSnapshots.last == versionTwo)
    withExtendedLifetime((firstToken, secondToken)) {}
}

@Test func callbackArgumentRemainsVersionSpecificWhileCurrentIsLatest() throws {
    let context = try makeStore()
    let versionOne = FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: true
    )
    let versionTwo = FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: false
    )
    var observedArgumentAfterNestedUpdate: FeedbackPreferences?
    var observedCurrentAfterNestedUpdate: FeedbackPreferences?

    let token = context.store.observe { preferences in
        guard preferences == versionOne else { return }
        _ = context.store.setHapticsEnabled(false)
        observedArgumentAfterNestedUpdate = preferences
        observedCurrentAfterNestedUpdate = context.store.current
    }

    _ = context.store.setSoundEffectsEnabled(false)

    #expect(observedArgumentAfterNestedUpdate == versionOne)
    #expect(observedCurrentAfterNestedUpdate == versionTwo)
    withExtendedLifetime(token) {}
}

@Test func reentrantRegistrationGetsImmediateLatestStateAndSkipsOuterCapture() throws {
    let context = try makeStore()
    let versionOne = FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: true
    )
    let versionTwo = FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: false
    )
    var outerSnapshots: [FeedbackPreferences] = []
    var innerSnapshots: [FeedbackPreferences] = []
    var innerToken: FeedbackPreferencesObservation?

    let outerToken = context.store.observe { preferences in
        outerSnapshots.append(preferences)
        if preferences == versionOne, innerToken == nil {
            innerToken = context.store.observe { innerSnapshots.append($0) }
        }
    }

    _ = context.store.setSoundEffectsEnabled(false)
    _ = context.store.setHapticsEnabled(false)

    #expect(outerSnapshots == [.defaultValue, versionOne, versionTwo])
    #expect(innerSnapshots == [versionOne, versionTwo])
    withExtendedLifetime((outerToken, innerToken)) {}
}

@Test func duplicateClosureRegistrationsAreIndependent() throws {
    let context = try makeStore()
    var callbackCount = 0
    let callback: (FeedbackPreferences) -> Void = { _ in callbackCount += 1 }

    let first = context.store.observe(callback)
    let second = context.store.observe(callback)
    _ = context.store.setHapticsEnabled(false)

    #expect(callbackCount == 4)
    first.cancel()
    _ = context.store.setSoundEffectsEnabled(false)
    #expect(callbackCount == 5)
    withExtendedLifetime(second) {}
}

@Test func encodingFailureStillDeliversNewInMemorySnapshot() throws {
    let defaults = try makeDefaults()
    let store = FeedbackPreferencesStore(
        defaults: defaults,
        key: "feedback.\(UUID().uuidString)",
        encode: { _ in throw TestEncodingError.failed }
    )
    var snapshots: [FeedbackPreferences] = []
    let token = store.observe { snapshots.append($0) }

    _ = store.setSoundEffectsEnabled(false)

    #expect(snapshots.last == FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: true
    ))
    withExtendedLifetime(token) {}
}
```

Add the order-independent helper outside the suite:

```swift
private func isNondecreasing(
    _ snapshots: [FeedbackPreferences],
    versionOne: FeedbackPreferences,
    versionTwo: FeedbackPreferences
) -> Bool {
    let ranks = snapshots.compactMap { snapshot -> Int? in
        if snapshot == .defaultValue { return 0 }
        if snapshot == versionOne { return 1 }
        if snapshot == versionTwo { return 2 }
        return nil
    }
    return zip(ranks, ranks.dropFirst()).allSatisfy { pair in
        pair.0 <= pair.1
    }
}
```

Do not assert which observer runs first. The accepted behavior is per-observer version monotonicity, not registration order.

- [ ] **Step 2: Run the focused suite and verify the expected red state**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackPreferencesStoreTests
```

Expected: build failure because the store does not conform to `FeedbackPreferencesManaging` and has no `observe(_:)` implementation.

- [ ] **Step 3: Implement versioned observer records and token ownership**

Modify `FeedbackPreferencesStore` to conform:

```swift
final class FeedbackPreferencesStore: FeedbackPreferencesManaging {
```

Add state:

```swift
private struct ObserverRecord {
    let callback: (FeedbackPreferences) -> Void
    var lastDeliveredVersion: UInt64
}

private var version: UInt64 = 0
private var observers: [UUID: ObserverRecord] = [:]
```

Add the token:

```swift
private final class ObservationToken: FeedbackPreferencesObservation {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        let action = cancellation
        cancellation = nil
        action?()
    }

    deinit {
        cancel()
    }
}
```

Add registration:

```swift
func observe(
    _ observer: @escaping (FeedbackPreferences) -> Void
) -> FeedbackPreferencesObservation {
    let id = UUID()
    observers[id] = ObserverRecord(
        callback: observer,
        lastDeliveredVersion: version
    )
    let snapshot = current
    observer(snapshot)

    return ObservationToken { [weak self] in
        self?.observers.removeValue(forKey: id)
    }
}
```

Replace Task 3's `commit(_:)` with versioned synchronous delivery:

```swift
private func commit(_ updated: FeedbackPreferences) {
    current = updated
    do {
        defaults.set(try encode(updated), forKey: key)
    } catch {
        NSLog(
            "[Pyxis] Failed to encode FeedbackPreferences: %@",
            error.localizedDescription
        )
    }

    version += 1
    let deliveryVersion = version
    let snapshot = updated
    let observerIDs = Array(observers.keys)

    for id in observerIDs {
        guard var record = observers[id],
              record.lastDeliveredVersion < deliveryVersion
        else {
            continue
        }

        record.lastDeliveredVersion = deliveryVersion
        observers[id] = record
        record.callback(snapshot)
    }
}
```

The record is marked before callback invocation. Each outer iteration re-reads the dictionary record, so nested delivery can mark later observers with a newer version and cause the stale outer delivery to skip them. New registrations are not in the captured `observerIDs` array and receive their own immediate then-current snapshot.

- [ ] **Step 4: Run focused tests and lint**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackPreferencesStoreTests

swiftlint lint
```

Expected: all persistence and observation tests pass, including nested-update and ownership cases.

- [ ] **Step 5: Commit observation semantics**

```bash
git status --short
git add Pyxis/FeedbackPreferencesStore.swift PyxisTests/FeedbackPreferencesStoreTests.swift
git commit -m "feat: observe feedback preferences synchronously"
```

---

### Task 5: Lock the HPA-389 Consumer Contract, Document the Boundary, and Verify the Full Repository

**Files:**
- Modify: `PyxisTests/FeedbackPreferencesTests.swift`
- Modify: `CLAUDE.md`
- Verify: all Task 1-4 files and repository checks.

**Interfaces:**
- Consumes: every HPA-364 type and method produced by Tasks 1-4.
- Produces: compile-only HPA-389 compatibility evidence and repository guidance for future implementation agents.

- [ ] **Step 1: Add the compile-only HPA-389 contract helper**

Append to `PyxisTests/FeedbackPreferencesTests.swift` outside the suite:

```swift
@inline(never)
private func assertHPA389ConsumerContract(
    defaults: UserDefaults,
    manager: FeedbackPreferencesManaging,
    observation: FeedbackPreferencesObservation,
    provider: GameplayFeedbackProviding,
    clock: MonotonicClock
) {
    _ = FeedbackPreferences()
    _ = FeedbackPreferences.defaultValue
    _ = FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: false
    )
    _ = FeedbackPreferencesStore(
        defaults: defaults,
        key: "compile-only.feedback"
    )

    _ = manager.current
    _ = manager.setSoundEffectsEnabled(true)
    _ = manager.setHapticsEnabled(true)
    let returnedObservation = manager.observe { _ in }
    returnedObservation.cancel()
    observation.cancel()

    let discreteEvents: [GameplayFeedbackEvent] = [
        .manualDeployment,
        .buildingChanged,
        .invalidAction,
        .goldReward,
        .cityConquest,
        .countryCompletion,
        .fortifiedLaneWarning
    ]
    discreteEvents.forEach { provider.emit($0) }

    provider.emitAutomaticCombat([
        .soldierDamage(.death),
        .towerFire,
        .soldierAttack(.siege),
        .soldierAttack(.ranged),
        .soldierAttack(.melee),
        .soldierDamage(.hit)
    ])

    _ = SoldierAttackSoundCategory.allCases
    _ = clock.now
}
```

The helper is intentionally never called. It must still compile, locking constructors, stored-property initialization, manager return values, every event/payload case, provider calls, the explicit store initializer, and the monotonic-clock property.

- [ ] **Step 2: Run all three focused HPA-364 suites**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameplayFeedbackTests \
  -only-testing:PyxisTests/FeedbackPreferencesTests \
  -only-testing:PyxisTests/FeedbackPreferencesStoreTests
```

Expected: all HPA-364-focused tests pass and the compile-only helper typechecks.

- [ ] **Step 3: Document the foundation/consumer split in `CLAUDE.md`**

Add this bullet under `## Conventions` near the pure-model guidance:

```markdown
- Gameplay feedback uses a strict foundation/consumer split. HPA-364 lives in `GameplayFeedback.swift`, `FeedbackPreferences.swift`, and `FeedbackPreferencesStore.swift`: it owns semantic events, the production no-op provider, the two enabled-by-default preferences under `pyxis.feedbackPreferences`, synchronous cancellable observation, and monotonic time. It does **not** map or play outputs, project `BattleCombatState.TickResult`, validate automatic-batch membership, schedule/rate-limit events, compose scenes, or add settings UI; those responsibilities belong to HPA-389. Keep `FeedbackPreferencesStore` single-executor-confined, pass `UserDefaults` explicitly outside `.shared`, and use callback snapshot arguments rather than `current` for delivery-version semantics during re-entrant updates.
```

Do not alter scene architecture, route ownership, or unrelated documentation.

- [ ] **Step 4: Run full verification and inspect scope**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests

swiftlint lint
git diff --check
git status --short
git diff --name-only main...HEAD
```

Expected:

- Full `PyxisTests` passes with zero failures.
- SwiftLint reports no violations.
- `git diff --check` emits no output.
- Changed production/test files are limited to the six HPA-364 files plus `CLAUDE.md`.
- No scene, controller, asset, CI, or project file appears in the diff.

Also inspect the implemented source to confirm:

```bash
grep -R "import \(SpriteKit\|UIKit\|AVFAudio\|AVFoundation\|CoreHaptics\|Combine\|Observation\|SwiftUI\)" \
  Pyxis/GameplayFeedback.swift \
  Pyxis/FeedbackPreferences.swift \
  Pyxis/FeedbackPreferencesStore.swift
```

Expected: no matches.

- [ ] **Step 5: Commit documentation and verification lock**

```bash
git status --short
git add CLAUDE.md PyxisTests/FeedbackPreferencesTests.swift
git commit -m "docs: lock gameplay feedback foundation handoff"
```

## Final Handoff Checklist

Before marking HPA-364 implementation ready for review, confirm all items:

- [ ] PR #20 design/plan is merged and the implementation branch started from the resulting `main`.
- [ ] Semantic event/provider/clock signatures exactly match the design.
- [ ] Production contains `NoOpGameplayFeedbackProvider` and no recording provider.
- [ ] `FeedbackPreferences` stores and encodes exactly two Booleans with enabled defaults.
- [ ] Missing/wrong-typed fields fail open independently; invalid roots back up under `<key>.corrupt`.
- [ ] `FeedbackPreferencesStore` has no default `.standard` initializer argument.
- [ ] Campaign persistence remains untouched.
- [ ] Duplicate setters perform no encode/write/version/callback work.
- [ ] `current` is latest-state and callback arguments remain delivery-version-specific.
- [ ] Observation is immediate, synchronous, cancellable, token-owned, re-entrant-safe, and per-observer version-monotonic.
- [ ] Cross-observer order is not relied upon.
- [ ] HPA-389 compile-only signatures typecheck.
- [ ] Full unit tests, SwiftLint, diff checks, and scope checks pass.
- [ ] HPA-389 remains blocked until this implementation merges; HPA-362 remains optional for the dormant fortified-warning producer.
