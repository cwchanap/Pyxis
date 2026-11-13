# HPA-812 visual evidence

These are simulator captures, not physical-device screenshots. All use the
iPhone 16 simulator, iOS 26.5, logical 393×852 pt. The baseline production and
tests are identical to `main@bb390f0`; the final captures use code at
`07410b2`. The original result bundles, full-resolution PNGs, manifests and
video are retained in the ignored task workspace, not committed here.

The six side-by-side images preserve the original captures, resized to 590 px
wide and labelled; no artwork was added or removed. They are comparisons, not
pixel-diff tests. The baseline and final fixture screenshots come from the
serial `testForgedFixtureParitySmoke393x852` and
`testHPA672AscensionFlowEvidence` runs. The former freezes combat; it is not
evidence of live combat.

| Image | Baseline → final source |
| --- | --- |
| `camp-empty.png` | parity `camp-empty` → parity `camp-empty` |
| `map.png` | parity `map` → parity `map` |
| `map-complete.png` | parity `map-country-complete` → same fixture |
| `armory.png` | HPA-672 `05-kingdom-renown-armory-lv2` → same flow stage |
| `conquest.png` | parity `conquest-live` → same fixture; despite its name, this parity fixture freezes combat |
| `treasury.png` | Task 0 live Treasury capture → Task 3 Treasury capture after its changes, before the final chevron-frame correction; later checkpoints did not change Treasury |

The parity and HPA-672 attachments are in `baseline-ui.xcresult` and
`task-5-full-serial.xcresult` respectively. `xcresulttool export attachments`
was used to produce the original PNGs and manifests; in the ignored task
workspace their directories are `baseline-attachments/`,
`task-5-parity-attachments/`, and `task-5-ascension-attachments/`. The Treasury
sources are `supplemental-captures/kingdom-treasury-live-iphone16-393x852.png`
and `task-3-attachments/treasury-393.png`.

`live-assault-contact-sheet.png` is a cropped, resized contact sheet of the
**final** unfrozen Falconridge fixture: the first 14 seconds starting at 3 s,
sampled every 0.5 s in row-major order, from
`task-5-live-captures/falconridge-unfrozen.mp4`. Physical simulator taps
deployed soldiers; the recording ran at approximately 6.6 actual fps. It
shows a few soldiers and individual damage labels, not a crowded durable
gate, nor does it prove transient-label non-overlap by itself.

`dense-gate-static.png` is the final suite's
`BattleFormationVisualEvidenceTests/testDenseGateAtReferencePortrait()`
attachment, resized to 590 px wide. It is a **static offscreen SKView render**
of nine infantry against a durable gate after controlled combat; tower fire is
disabled and the Captain is recovering. It is not a live busy-gate capture.

The follow-up phone check adds two captures from a newly created, isolated
iPhone 16 simulator running iOS 26.5 at 393×852, using code at `f2f9dfc`:

- `camp-no-selection.png`: launched the existing `camp-empty` fixture, switched
  to Battle and back to Camp, and captured the grid before selecting a lot.
- `camp-unaffordable.png`: built a Barracks and upgraded it to level 8 through
  the Camp UI. With 388 gold, the recommended 400-gold upgrade is dimmed;
  tapping it shows the insufficient-gold message without changing the gold or
  level. This capture shows the message after the tap.

The follow-up also found the phone Scout card's troop portraits substantially
smaller than in the baseline comparison: the ordinary-phone icon metric fell
from 30pt to 14pt. Their legibility merits review.

`dense-gate-live.png` and `dense-gate-live-contact.png` are from a new
unfrozen Crownspire run on the same isolated simulator. Five level-1 Barracks
were built through the Camp UI. To create the scenario without altering game
code, the disposable simulator's test save was seeded with the Arrow Tower
destroyed and the right lane selected; both gates and the Keep were initially
intact. Soldiers then spawned and fought using the running game. At high
density, HP bars and bodies overlap near the back of the lane, forming solid
green blocks. The 47-second source recording averaged approximately 3.2 fps
under heavy host load; the contact sheet samples it every eight seconds. The
full video and pre-seeding test save are retained in the ignored task
workspace, not committed here.

The baseline Confirm was already contained at 393×852. The narrow Confirm
evidence is an offscreen SKView render, not a physical compact-device capture.
iPad was skipped for the follow-up. The simulator's Accessibility settings
did not offer a VoiceOver control, so real VoiceOver traversal remains
unverified and needs a supported device.

## Forged mock-up comparison

HPA-812 has no mock-up attached, but the earlier HPA-479 Linear issue links
the existing [Forged UI references](../../docs/visual-parity/forged-ui/README.md).
They are the original 393×852 Battle, Camp, Map and Conquest presentation
mock-ups, not a new HPA-812 design. HPA-812 deliberately changes some of those
layouts; later features also added a fourth Kingdom tab, Captain and siege
objectives. There is no Kingdom mock-up in this set.

`mockup-comparison.png` pairs those four original mock-ups with phone captures.
The Battle result is the seeded, unfrozen Crownspire run described above; the
Camp result is the live level-1 Barracks capture; the Map and Conquest results
are the final fixture captures from the earlier before/after boards. Game
state, scenery and system chrome differ, so the board supports visual review,
not pixel-perfect or feature parity claims.

- Battle keeps the forged HUD language, but the crowded live formation still
  merges bodies and health bars, as noted above.
- Camp keeps the inspector and forged controls; its background is much brighter
  than the mock-up, and its upgrade control has a stronger gold treatment.
- Map intentionally fits the Scout card into less vertical space to expose
  Cities 1 and 2. Troop portraits are considerably smaller than in the mock-up.
  A dark area above the map remains; the HPA-812 design calls for a subdued
  treatment rather than remapping the illustration.
- Conquest keeps the ring and report hierarchy, but the timer and sent/lost
  glyphs appear black against the dark tiles rather than light as in the mock-up.
  This is also visible in the HPA-812 baseline capture, so it is not a newly
  introduced regression.

## Mock-up follow-up: Map and Conquest

The original mock-up comparison above predates the following corrections.
The three-column images preserve the Forged reference, the HPA-812 fixture
before follow-up, and the updated simulator result; the columns are resized
to 393×852 and the reference does not use the same game state.

| Image | Follow-up result |
| --- | --- |
| `map-scout-mockup-followup.png` | Scout portraits use 24pt slots on the 393×852 fixture, up from 14pt, while keeping the card and Attack in their existing regions. At the tighter 133pt card height the slots remain 14pt. |
| `conquest-icons-mockup-followup.png` | Timer and sent/lost glyphs are cream; achievement glyphs use green and gold. The MVP soldier retains its colored artwork. |

The final columns are iPhone 16 simulator captures of the `map` and
`conquest-live` fixtures, respectively; these do not establish physical
device, VoiceOver, or iPad behavior. The updated Scout node and layout suites
passed; four Map scene accessibility tests also failed in the same way as
the previously recorded intermittent baseline failures, with cause unresolved.

## Round 2 — bounded dense formation presentation

The round-2 change (the scoped commit on the PR #55 branch above `f9eff6a1`)
reworks `syncSoldierNodes` so rendered soldier footprints — body plus HP bar —
are reserved ground: members march, re-slot and spawn only into swept
footprints clear of every rendered reservation, pending casualties keep the
actual ground they died on through the authored fade, folded overflow is
counted truthfully in the lane's `+N` badge, and a battlefield-frame change
re-places every root in the new coordinates immediately.

Verified numbers (all serial, dedicated iPhone 16 simulator `6577F3F4`,
iOS 26.5, 393×852 pt, derived data `/tmp/pyxis-hpa812-build`):

- **RED vs old implementation** (temporary HEAD `f9eff6a1` checkout, same
  4-test selection): `denseGateRenderedFootprintsStayDisjointThroughGlide…`
  failed with 77 issues, `denseGateGenuinelyStaggeredSpawnsStayDisjoint…`
  failed with 91 issues, `pausedResizeReplacesSoldierGroundInNewCoordinates`
  failed with 8 issues (176 issues across the three); the perf smoke
  `denseGateHiddenRosterSyncCostStaysRepresentative` passed under both. The
  other new tests could not run against HEAD — they use DEBUG seams that
  only exist in the round-2 build, so the old tree does not compile them;
  no RED is claimed for those tests.
- **Targeted GREEN** (round-2 build): all 7 new/strengthened tests pass —
  disjoint rendered footprints through glide/march/deploy, casualty actual
  footprint through the authored fade, paused-resize remapping, genuinely
  staggered spawns, mixed-type Captain + tower-target truthfulness with a
  real Rally accent check, truthful huge-count badge containment
  (`+123`, `+4567`, `+98765`, `+Int.max` inside lane and field), and the
  hidden-roster perf smoke (30 sync ticks under the 2.5 s bound — a bound
  check, not a microbenchmark).
- **Full-suite regression**: the first full `BattleSceneTests` run on the
  round-2 build exposed two genuine regressions (83 issues): a lone
  survivor's sprite canvas drifted outside the battlefield after tower
  casualties, and an unseeded member re-snapping to a shifting ideal
  produced an 18.27 pt node step in `denseFormationDoesNotTeleport…`.
  Both are fixed (exact lone placement gated on a free in-field landing
  ordered by smallest lateral drift; seed-on-first-placement bounding all
  later motion to `presentationStep`). Final serial run: **329 tests,
  0 failures, ~40 s**.
- **Live capture** (`round2/`): the retained Crownspire seed
  (`crownspire-task3-seed.plist`: city 15, `selectedLane=2`, five level-1
  Barracks, Arrow Tower pre-destroyed at 6286) was installed into the app
  container's defaults after `simctl terminate` + `launchctl kickstart -k
  …/cfprefsd.xpc.daemon`, then the app was launched normally — no fixture
  launch args, combat unfrozen. `dense-gate-round2-early.png` (~19 s) shows
  ten distinct soldiers with individual HP bars and a `+1` pill;
  `dense-gate-round2-dense.png` (~68 s) shows the pile bounded with a `+25`
  pill and a hit flash visible on one soldier. The Arrow Tower is destroyed
  in this scenario, so that flash is not tower fire — its source is not
  independently established.
  `crownspire-round2-after-capture.plist` confirms live combat
  (`east-gate` damage 2404 — absent from the seed — `arrow-tower` still at
  its seeded 6286, i.e. destroyed; `battleActive`, 333 s; 30 infantry
  deployed on lane 2, 870 soldier damage applied, 1420 idle damage) — not
  a staged render.

Round-3 note: the reserved-footprint path mechanism described in this
section was subsequently replaced by a bounded stable-seat presentation —
disjoint seats on a per-lane grid pitched on the readable body∪bar unit,
with overflow folded truthfully into the same `+N` badge. The captures
above remain valid evidence of the desired end state; the described
mechanism is historical. The later two-rail implementation and its current
captures are documented below.

Limitations: simulator-only captures; no physical device, VoiceOver, iPad,
or real-device performance claims. Seat/fade/corpse reservations are a
presentation invariant — combat, targeting, spawning, economy and
persistence are unchanged. Audio/CoreSimulator warnings seen during runs
are environmental and not test failures.

## Two-Rail Follow-Up

The user chose a smaller representative formation: up to two visible soldiers
per lane, with a `+N` count for other living soldiers. These current-code
captures use `95e3c3e`, the existing 393×852 iPhone 16 simulator and separate
synthetic app bundle IDs, leaving the original app's save untouched. Both
apps launched normally, without fixture or freeze arguments.

- `two-rail-live-early.png` and `two-rail-live-dense.png` show an unfrozen
  Crownspire battle with five level-1 Barracks on the right lane and the
  Arrow Tower pre-destroyed. The dense frame has two distinct soldier HP
  bars and `+29`. `two-rail-live-seed.plist` and `two-rail-live-after.plist`
  retain the synthetic starting and evolved saves: the latter records 50
  building infantry deployments and 2,634 east-gate damage. The seed had no
  east-gate damage. Background and building timestamps were refreshed before
  launch to avoid loading an old offline interval.
- `two-rail-live-tower.png` and `two-rail-tower-contact.png` show a separate
  unfrozen left-lane run with the Arrow Tower initially undamaged, a
  20-HP Captain, no remaining guards and five level-1 Barracks seeded near
  their spawn interval. The contact sheet crops 12 screenshots over
  approximately 14.5 seconds; capture intervals are not uniform. The evolved
  `two-rail-tower-after.plist` records 60 building infantry deployments,
  59 infantry losses, Captain recovery and 166 tower damage. The seed is
  `two-rail-tower-seed.plist`; it had no siege damage or losses. The save
  also records 5 idle infantry damage after launch.

Compared with the earlier Forged Battle mock-up, the current captures retain
the illustrated battlefield and gold-framed HUD but show different siege
art, Captain and tab content from later game features. The two-soldier
representative group and `+N` indicator are an intentional deviation from
the mock-up's individually drawn soldiers, chosen to keep crowded lanes
readable. These screenshots show different city and combat states and are
not pixel-parity evidence.

The tower remains alive in the captured scenario, but the stills alone do
not identify a projectile or prove its endpoint, nor do they verify the exact
duration or completion of a SpriteKit action. Video recording was unavailable
because the simulator reported another recording already in progress. No
iPad or physical-device/VoiceOver check was performed.
