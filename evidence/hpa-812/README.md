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
