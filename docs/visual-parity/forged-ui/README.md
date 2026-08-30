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

Every minimum state has the canonical mock, a native simulator capture, a deterministic 50% overlay, and a deliberate-discrepancy note. The board's native files are direct `simctl io screenshot` framebuffer captures; they are not resized or cropped. The same serial UI smoke also retains XCTest screenshot attachments for test provenance. XCUITest reports its app image as 1178×2556, while the direct simulator framebuffer is 1179×2556 at 3×, which is the same logical 393×852 iPhone 15 Pro viewport.

| Minimum state | Canonical | Native capture | 50% overlay | Deliberate discrepancy |
| --- | --- | --- | --- | --- |
| Battle normal | `battle.png` | `native/battle-normal-393x852@3x.png` | `overlays/battle-normal-50-overlay.png` | Frozen live combat keeps the authored HUD and lane geometry stable; soldier positions, counters, and terrain details are runtime state rather than mock pixels. |
| Battle blocked | `battle.png` | `native/battle-blocked-393x852@3x.png` | `overlays/battle-blocked-50-overlay.png` | The blocked fixture keeps the same shipping battle chrome while the action is disabled by the live-soldier rule; the mock does not encode that gameplay gate. |
| Camp empty | `camp.png` | `native/camp-empty-393x852@3x.png` | `overlays/camp-empty-50-overlay.png` | An empty city uses the shipping slot grid and current build affordances; the mock is a scenic reference and does not prescribe persisted prices or unlock copy. |
| Camp occupied | `camp.png` | `native/camp-occupied-393x852@3x.png` | `overlays/camp-occupied-50-overlay.png` | Existing buildings and their authored levels come from the fixture state, so lot contents intentionally differ from the generic mock. |
| Map attackable | `map.png` | `native/map-attackable-locked-393x852@3x.png` | `overlays/map-attackable-50-overlay.png` | The native route shows the current attackable City 4 and locked later cities together; shipping unlock colors and authored labels are state-driven. |
| Map locked | `map.png` | `native/map-attackable-locked-393x852@3x.png` | `overlays/map-locked-50-overlay.png` | Attackable and locked are intentionally one route fixture/capture: the locked nodes are the later cities visible beside City 4, not a second fabricated screen. |
| Map Country 1 complete | `map.png` | `native/map-complete-393x852@3x.png` | `overlays/map-complete-50-overlay.png` | The complete campaign uses the shipping completion treatment and route state; the map mock's taller card is not a geometry contract. |
| Conquest live | `conquest.png` | `native/conquest-live-393x852@3x.png` | `overlays/conquest-live-50-overlay.png` | The report's title, gold, and rows are resolved from the live battle result and fixture catalog; the mock intentionally omits those values. |
| Conquest idle | `conquest.png` | `native/conquest-idle-393x852@3x.png` | `overlays/conquest-idle-50-overlay.png` | Idle catch-up reports use the same report shell but authored offline-progress values and copy. |
| Settings one-off toggle | `settings.png` | `native/settings-toggle-393x852@3x.png` | `overlays/settings-toggle-50-overlay.png` | The one-off toggle capture preserves the underlying battle scene and persisted preference transition; no additional settings are introduced. |

### Capture provenance

- Device: `Pyxis-Parity-393x852` (`iPhone 15 Pro`, type `com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro`)
- Runtime: iOS 26.5 (`23F77`); UDID `771133AB-2A09-4C6E-85FD-9D7523E8D2C7`
- Native framebuffer: 1179×2556 pixels, 3×, logical 393×852 points (`simctl io screenshot`, no resampling)
- XCTest attachment note: XCUITest's `XCUIScreenshot` export is 1178×2556 on this runner; those files remain in the result bundle and are not mislabeled as the board's native captures.
- Result bundle: `test_sim_2026-08-30T20-41-44-811Z_pid81865_82c9f692.xcresult`
- Smoke test: `PyxisUITests/testForgedFixtureParitySmoke393x852`, serial, 1 passed / 0 failed

The Map implementation deliberately uses a computed 164pt card, not the taller presentation mock card. At 393pt width, the 164pt card leaves the authored 44pt node interactions and the required route spacing/headroom viable; this is a deliberate geometry-contract difference, not a capture defect. The overlays are evidence for human review only; there is no pixel-diff CI assertion.
