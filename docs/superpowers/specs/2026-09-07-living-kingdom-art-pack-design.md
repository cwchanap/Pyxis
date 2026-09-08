# Living Kingdom Anime Asset Pack Design

## Status

Planning contract for **HPA-479**. This remains the single asset-production PR for the ticket. HPA-479 owns image/animation authoring, corrected visual references, and the minimum DEBUG/test tooling needed to make those assets reproducible and continuously validated. **Shipping runtime integration stays in HPA-478.**

The original four concept boards are useful mood/composition references but are **not authoritative inputs and are not a production blocker**. If `Pyxis_Living_Kingdom_Concept_References.zip` is recovered, copy the four boards unchanged into `docs/visual-parity/living-kingdom/source/`, hash them, and record the exclusions review. If it is unavailable, record that fact and continue from this self-contained contract.

## Goal

Make Country 1 feel richer without changing the prepare → deploy → watch → conquer loop:

1. visible fortress damage;
2. stronger Emberford / Runewatch / Crownspire identity;
3. a living conquered map;
4. an offline return that shows the truthful resulting state.

## Selected shape

Keep the pack small and reusable:

- **4 fortress families × 4 static stages = 16 fortress assets**;
- **3 transparent battlefield treatments** — ember, arcane, royal;
- **2 shared six-frame transition sequences = 12 FX frame assets**;
- **4 living-map overlays** — secured city, caravan, worn 6→7 crossing, repaired 6→7 crossing;
- **35 runtime image sets total**;
- no ambient smoke/ember/ward texture pack until HPA-478 has a concrete consumer;
- no separate offline-return illustration set;
- no runtime manifest, VFX manager, asset framework, or per-city content system.

The worn/repaired pair stays because HPA-479 explicitly owns a before/after repair treatment. Everything else is YAGNI.

## Authoritative inputs

Planning baseline: `main` at `41aeb806f8c4b6cdad6dede5855f90ad5a3614cd`.

Shipping code wins over every concept board:

- `Country1CityCatalog` — city identity;
- `BattlefieldLayout` + `BattleScene` — battle structure/lane geometry;
- `CountryMapLayoutDefinition.country1` + `CountryMapLayout` — map source coordinates and scale;
- `KingdomGameState`, `BattleResult`, `IdleProgressResult` — progression/outcomes;
- `docs/visual-parity/forged-ui/` — existing 393×852 chrome/composition.

No mock currency, counter, objective, timer, or reward becomes game data.

## Visual direction

Use **anime-inspired painted fantasy environment art**:

- clear mobile silhouettes;
- restrained painted stone/fire/magical-light detail;
- fixed camera and stable lighting direction;
- no character/troop redesign;
- no text, HUD, buttons, counters, phone frames, or gameplay hints baked into textures;
- foreground lanes, soldiers, city labels, Scout content, and Forged chrome remain easier to read than decoration.

## Fortress geometry contract

`BattleScene.makeBattleSprite` uses bottom-center `anchorPoint = (0.5, 0)`. `BattleScene.fitBattleNode` scales an image-backed structure from the **full sprite canvas height**, including transparent pixels. HPA-478 keeps that path; alpha bounds are an art-validation contract, not a new runtime geometry API.

Shipping reference:

- `enemy-city.png`: 1223×1286 px;
- regular Forged enemy-city canvas height: 132 pt;
- compact maximum target height: roughly 150 pt;
- shipping visible silhouette is materially narrower than its full canvas, so matching only the canvas aspect ratio is insufficient.

All 16 fortress PNGs therefore use:

- canvas: **512×540 px**, transparent;
- runtime anchor: `(0.5, 0)`;
- same horizontal gate center, camera, lighting, and structural center across family stages;
- visible silhouette centered horizontally;
- main gate centered on the canvas midpoint.

### Alpha-envelope gate

The production alpha bounding box is part of acceptance even though runtime never reads it.

For every fortress stage:

- opaque width / canvas width: **0.72...0.80**;
- opaque height / canvas height: **0.94...0.98**;
- transparent gap below the opaque box / canvas height: **0.015...0.030**;
- opaque-box horizontal center must stay within **±0.02 canvas width** of the canvas midpoint.

The intact stage should normally sit in the tighter **0.72...0.78** width band. Damage/rubble may use the wider 0.80 ceiling but must not grow into a different displayed footprint.

At a 132 pt canvas-height render this targets roughly 90–100 pt of visible fortress width, close to the shipping city rather than filling the ~125 pt full canvas width.

`PyxisTests/BattleSceneTests.swift` will extend its existing opaque-pixel helper to include Y bounds and assert these bands in CI. Do **not** add a `FortressAnimationGeometry` or body-region runtime type.

## Destruction stage contract

| Remaining city HP | Static asset |
| --- | --- |
| `> 60%` | intact |
| `> 25% ... 60%` | damaged |
| `> 0% ... 25%` | breached |
| `0%` / pending conquest | conquered |

- intact — complete silhouette;
- damaged — cracks/chips/local damage, gate still closed;
- breached — broken gate/rubble within the same footprint;
- conquered — stable ruined/secured aftermath, not an empty battlefield.

Each state must read correctly when damage skips directly to it.

## City → family mapping

This table is authoritative by **city number**; never derive family from `CityDefenseTrait`.

| Family | Cities |
| --- | --- |
| Frontier | 1–6, 8, 10, **11**, 14 |
| Ember | 7 Emberford, 12 Ashbridge |
| Arcane | 9 Runewatch, 13 Starveil Citadel |
| Royal | 15 Crownspire Keep |

City 11 Kingshield Keep intentionally remains Frontier although it shares `.reinforcedKeep` with City 15.

## Battlefield treatment contract

Assets:

- `lk-battlefield-ember`
- `lk-battlefield-arcane`
- `lk-battlefield-royal`

Each is transparent **864×1821 px**, matching `battlefield-backdrop.png`, and uses the same aspect-fill transform.

HPA-478 z-order is explicit:

```text
battlefieldBackdropNode     = GameUITheme.Z.background        // -20
Living Kingdom treatment   = GameUITheme.Z.background + 0.5  // -19.5
forgedAtmosphereNode       = GameUITheme.Z.background + 1    // -19
lane terrain               = -1
```

The overlay therefore paints over the opaque backdrop, remains under the Forged warm grade, and remains under lane terrain. It paints no second fortress and must not imply new attacks, shields, or resources.

## Transition FX contract

### Gate breach

- `lk-fx-breach-01` ... `lk-fx-breach-06`
- 512×512 transparent
- 0.30 s total, 0.05 s/frame

### Final collapse

- `lk-fx-collapse-01` ... `lk-fx-collapse-06`
- 512×512 transparent
- 0.42 s total, 0.07 s/frame

Shared rules:

- SpriteKit anchor: **`(0.5, 0)`**;
- impact origin: canvas bottom center;
- frame position never moves;
- sequence contains dust/debris/atmosphere, not an alternate fortress silhouette;
- frame 06 is **fully transparent**;
- static breached/conquered fortress owns the terminal state.

### FX display transform

Use the same pixels→points scale as the fortress canvas:

```text
fortressScale = enemyCityDisplayHeight / 540
fxDisplayHeight = 512 × fortressScale
```

At the regular 132 pt fortress height, FX render about **125 pt high**. HPA-478 must not display a 512 px FX canvas as 512 points.

## Living-map contract

Country 1 remains in the canonical **1024×1536** authored source space.

Selected repair segment: **Granite Pass (6) → Emberford (7)**.

- City 6: `(360.2432, 520.0896)`
- City 7: `(427.1104, 640.6656)`
- midpoint: `(393.6768, 580.3776)`
- segment length: `137.8760 px`
- direction: `60.9888°` from +X in authored y-up map coordinates
- in the PNG as viewed, the crossing runs **lower-left to upper-right**.

Runtime map sizing:

```text
mapScale = displayedBackdropFrame.width / 1024
runtimeOverlaySize = canonicalPixelSize × mapScale
```

Required assets:

- `lk-map-secured-city` — 96×96 canonical px, transparent;
- `lk-map-caravan` — 128×64 canonical px, transparent, faces +X;
- `lk-map-route-6-7-worn` — 192×192 canonical px, transparent;
- `lk-map-route-6-7-repaired` — 192×192 canonical px, transparent.

`lk-map-secured-city` must keep the centered number and existing upper-right conquered marker readable. All map art is noninteractive and does not change route topology or hit targets.

## Asset naming

### Fortress — 16

`lk-city-{frontier|ember|arcane|royal}-{intact|damaged|breached|conquered}`

### Battlefield — 3

`lk-battlefield-{ember|arcane|royal}`

### Transition frames — 12

`lk-fx-breach-01...06`, `lk-fx-collapse-01...06`

### Map — 4

`lk-map-secured-city`, `lk-map-caravan`, `lk-map-route-6-7-worn`, `lk-map-route-6-7-repaired`

**Total: 35 image sets.**

## Asset-catalog convention

Use one Contents.json shape for all 35 sets. Reuse the already-tested `write_contents_json(imageset: Path, filename: str)` helper in `tools/slice_soldier_animation_strips.py`, which emits:

- universal 1x filename;
- empty universal 2x/3x entries;
- Xcode version/author metadata.

The empty higher-scale entries are harmless and remove a second hand-authored catalog convention. No new asset manifest/generator framework is added.

Do not replace existing assets or edit `project.pbxproj`.

## Concept-reference handling

The written anime-fantasy brief and runtime geometry above are sufficient for production.

If the original boards are recovered:

1. copy them unchanged to `docs/visual-parity/living-kingdom/source/`;
2. record SHA-256 hashes;
3. mark them mood-only and record excluded invented mechanics.

If they are not recovered, add `source/README.md` stating that the original boards were unavailable and production used the approved written brief plus Forged native plates. **Do not block art production on them.**

## Corrected-reference strategy

Use real shipping plates and replace only new scene-art pixels; never redraw Forged chrome.

Existing plates under `docs/visual-parity/forged-ui/native/`:

- Battle/landmarks: `battle-normal-393x852@3x.png`;
- early map: `map-attackable-locked-393x852@3x.png`;
- complete map: `map-complete-393x852@3x.png`;
- offline conquest: `conquest-idle-393x852@3x.png`.

For the partial-map plate, extend the existing DEBUG `ForgedVisualFixture` with `map-partial` using `DevJumpState.make(city: 8)`, set it to the same map-stage semantics as the existing `.map` fixture, and capture it through the existing 393×852 UI fixture flow. This is test/dev tooling only; it does not alter Release behavior.

Required references:

- `battle-frontier-{intact,damaged,breached,conquered}.png`;
- `battle-emberford.png`, `battle-runewatch.png`, `battle-crownspire.png`;
- `map-early.png`, `map-partial.png`, `map-complete.png`;
- `offline-damage.png`, `offline-conquest.png`.

`offline-damage.png` changes only scene art. Do not invent elapsed-time UI. Shipping positive-damage copy uses `CompactNumberFormatter`, e.g. **`Buildings dealt 1.2K idle damage.`**, not an unformatted raw integer.

`offline-conquest.png` preserves the shipping report and its single Continue action.

## Continuous validation

HPA-479 may change test/DEBUG fixture code because that code is the production-art verification/capture seam. It must not change shipping gameplay/runtime behavior.

Extend `PyxisTests/BattleSceneTests.swift` beside `allSoldierAnimationFramesAreInstalled`:

- assert every currently landed `lk-*` asset resolves through `UIImage(named:)`;
- assert exact `cgImage` dimensions;
- assert fortress alpha-envelope bands;
- assert final breach/collapse frame is fully transparent;
- grow the expected asset contract in the same commit that adds each asset batch.

The existing unit-test CI job then protects asset names/dimensions after merge. Do not add a parallel Python validator or change CI.

For the DEBUG `map-partial` fixture, update `ForgedVisualFixtureTests` and the existing UI fixture smoke/semantic switch so the source plate is reproducible.

## Allowed scope

HPA-479 may touch:

- new `lk-*` image sets;
- `docs/visual-parity/living-kingdom/**`;
- this spec + implementation plan;
- `PyxisTests/BattleSceneTests.swift` for asset-contract validation;
- `Pyxis/ForgedVisualFixture.swift`, `PyxisTests/ForgedVisualFixtureTests.swift`, and `PyxisUITests/PyxisUITests.swift` for the DEBUG-only partial-map capture fixture.

It may **not** change non-DEBUG shipping scene behavior, models, saves, balance, routing, CI, Codecov, existing production assets, or project files.

## Done definition

The PR is ready only when:

- all **35** image sets exist;
- all 16 fortress stages pass 512×540 + alpha-envelope checks;
- battlefield treatments are 864×1821 and authored for z = background + 0.5;
- FX anchor/timing/display-size/final-transparency contracts are satisfied;
- map overlays use canonical sizing and the fixed 6→7 registration;
- City 11 remains Frontier;
- corrected references use real shipping plates and truthful formatted copy;
- CI-run Swift asset tests and DEBUG fixture tests are green;
- Xcode builds successfully;
- no shipping-runtime scope drift is present.

After merge, HPA-478 consumes this fixed contract.