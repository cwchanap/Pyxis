# Forged UI visual references

The supplied redesign package contains the authoritative 393×852 visual references for the Forged gameplay UI redesign.

| Repository path | Supplied export |
| --- | --- |
| `battle.png` | `3b.png` |
| `camp.png` | `2b.png` |
| `map.png` | `2c.png` |
| `conquest.png` | `2d.png` |
| `settings.png` | `2e.png` |

These mockups are presentation references only. Shipping Swift models remain authoritative for gameplay values, unlocks, routing, persistence, and state.

The exact five source PNGs above must be present in this directory before runtime implementation begins. Do not substitute screenshots, recompressed exports, or a later redesign without explicitly updating this mapping and the planning documents.

## Task 10 parity board

Every minimum state has the canonical mock, a simulator capture, a deterministic 50% overlay, and a deliberate-discrepancy note. The board's native files are direct `simctl io screenshot` framebuffer captures and are not resized or cropped. For the Battle-normal comparison board and overlay, that native frame is downsampled to 393×852 logical pixels before comparison with the 393×852 canonical mock. The same serial UI smoke also retains XCTest screenshot attachments for test provenance. XCUITest reports its app image as 1178×2556, while the direct simulator framebuffer is 1179×2556 at 3×, which is the same logical 393×852 iPhone 15 Pro viewport.

| Minimum state | Canonical | Native capture | 50% overlay | Deliberate discrepancy |
| --- | --- | --- | --- | --- |
| Battle normal | `battle.png` | `native/battle-normal-393x852@3x.png` | `overlays/battle-normal-50-overlay.png` | The exact 393×852 fixture reads 4.2K / 20 / 0 soldiers while the prototype reads 7.4K / 320 / 6; active units and damage are deliberately runtime state, while layout/style bands are the comparison target. |
| Battle blocked | `battle.png` | `native/battle-blocked-393x852@3x.png` | `overlays/battle-blocked-50-overlay.png` | The blocked fixture keeps the same shipping battle chrome while the action is disabled by the live-soldier rule; the mock does not encode that gameplay gate. |
| Camp empty | `camp.png` | `native/camp-empty-393x852@3x.png` | `overlays/camp-empty-50-overlay.png` | The deterministic empty fixture mounts the five-option builder and selects slot 1 through the DEBUG scene seam (`selectedSlot=1; mode=builder`); the mock is a scenic reference and does not prescribe persisted prices or unlock copy. |
| Camp occupied | `camp.png` | `native/camp-occupied-393x852@3x.png` | `overlays/camp-occupied-50-overlay.png` | The deterministic occupied fixture mounts the inspector on slot 1 (`selectedSlot=1; mode=inspector`); existing buildings and authored levels intentionally differ from the generic mock. |
| Map attackable | `map.png` | `native/map-attackable-locked-393x852@3x.png` | `overlays/map-attackable-50-overlay.png` | The native route shows the current attackable City 4 and locked later cities together; shipping unlock colors and authored labels are state-driven. |
| Map locked | `map.png` | `native/map-attackable-locked-393x852@3x.png` | `overlays/map-attackable-50-overlay.png` | Attackable and locked are intentionally one route fixture/capture: the locked nodes are the later cities visible beside City 4, not a second fabricated screen. |
| Map Country 1 complete | `map.png` | `native/map-complete-393x852@3x.png` | `overlays/map-complete-50-overlay.png` | The complete campaign uses the shipping completion treatment and truthful route state while retaining the authored card and tab geometry. |
| Conquest live | `conquest.png` | `native/conquest-live-393x852@3x.png` | `overlays/conquest-live-50-overlay.png` | The report's title, gold, and rows are resolved from the live battle result and fixture catalog; the sole Settings gear is hidden while the report is visible, and the mock intentionally omits runtime values. |
| Conquest idle | `conquest.png` | `native/conquest-idle-393x852@3x.png` | `overlays/conquest-idle-50-overlay.png` | The fixture contains two Barracks and nonempty building-driven idle damage, so the report truthfully shows `+17`, the durable idle-damage tile, `100% MVP`, and `0/0 SENT/LOST`; the sole Settings gear is hidden while the report is visible. |
| Settings one-off toggle | `settings.png` | `native/settings-toggle-393x852@3x.png` | `overlays/settings-toggle-50-overlay.png` | The one-off toggle capture preserves the underlying battle scene and persisted preference transition; no additional settings are introduced. |

### Capture provenance

- Device: `Pyxis-Parity-393x852` (`iPhone 15 Pro`, type `com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro`)
- Runtime: iOS 26.5 (`23F77`); UDID `771133AB-2A09-4C6E-85FD-9D7523E8D2C7`
- Native framebuffer: 1179×2556 pixels, 3×, logical 393×852 points (`simctl io screenshot`, no resampling)
- Battle-normal capture: direct `simctl io screenshot` framebuffer at
  1179×2556 pixels (3×), corresponding to the logical 393×852 viewport.
- Live-damage capture: `native/battle-live-damage-393x852@3x.png` is an
  unfrozen battle fixture frame showing real combat damage feedback.
- Battle-normal comparison board and 50% overlay: the native framebuffer is
  downsampled to 393×852 logical pixels before comparison with the canonical
  mock.
- The simulator's Dynamic Island/system mask is unavoidable in the native
  framebuffer and is a capture difference, not a Forged styling defect.
- XCTest attachment note: XCUITest's `XCUIScreenshot` export is 1178×2556 on this runner; those files remain in the result bundle and are not mislabeled as the board's native captures.
- Dedicated result bundle: `test_sim_2026-08-30T23-42-46-973Z_pid19570_369eddfd.xcresult`
- Smoke test: `PyxisUITests/testForgedFixtureParitySmoke393x852`, serial, 1 passed / 0 failed on this device
- CI-shaped iPhone 17 smoke result bundle: `test_sim_2026-08-30T23-45-38-493Z_pid19570_5b490aa3.xcresult`
- Full serial unit/UI result bundle: `test_sim_2026-08-30T23-50-37-478Z_pid19570_ecb0f093.xcresult`
- The same capture-only test throws `XCTSkip` before its fixture loop on a
  non-393x852 destination; the CI-shaped iPhone 17 run is therefore an
  intentional 0 passed / 0 failed / 1 skipped result, not a failed capture gate.

The Camp empty/occupied and Conquest live/idle files were recaptured after the
final-review fixes from the four exact DEBUG fixture launches on this device,
then written directly with `simctl io screenshot`. The Conquest live/idle
captures and matching overlays were refreshed again after the round-2 durable
idle-damage and HP-chrome fixes; the idle report now survives relaunch with
its durable idle-damage tile intact, and neither report has a Settings gear or
orphan HP bar. The
matching overlays were regenerated from those native framebuffers and the
canonical 393x852 mock using the existing deterministic 50% blend; neither
the native files nor the canonical files were resized or cropped. Camp
selection and Conquest report semantics were checked from the same
DEBUG-derived probe used by the UI smoke.

The Map reference-phone implementation sizes the scout card from the computed
information-region budget (48pt compact floor, 133pt, or 164pt; the 393×852
layout uses 164pt) and the 82pt full-bleed tab shell while maintaining separate
safe-area hit frames. Camp uses the same visual-shell/safe-hit split. The Map,
Camp, and Conquest captures were refreshed after the final forged-style parity
pass. The overlays remain evidence for human review only; there is no
pixel-diff CI assertion.

Battle-normal comparison uses the direct 1179×2556 framebuffer (3×, logical
393×852) and its downsampled 393×852 comparison artifacts. The simulator's
Dynamic Island/system mask remains an unavoidable capture difference. The
prototype's 7.4K / 320 / 6-soldier state is not expected to match the truthful
fixture's 4.2K / 20 / 0 state; those combat totals remain deliberate fixture
differences and are excluded from the parity judgment, while layout and style
bands remain the target.
