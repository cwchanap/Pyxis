# Gameplay audio assets

All 13 gameplay sounds are derived from the official **Kenney RPG Audio v1.0** archive. The downloaded archive's `License.txt` identifies its creator as Kenney Vleugels (Kenney.nl) and marks the pack as Creative Commons Zero (CC0). The source archive and its bundled provenance notice were inspected before processing; the original selected files are Vorbis OGG, 48 kHz stereo, and non-silent.

Source page: <https://www.kenney.nl/assets/rpg-audio>  
Official archive: <https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip>

Each asset was decoded from the listed original OGG to an intermediate WAV, then converted with:

```sh
afconvert source.wav output.caf -f caff -d LEI16@44100 -c 1
```

The resulting CAF files are 44.1 kHz, mono, signed 16-bit little-endian PCM. No normalization was applied and none of the selected automatic-combat clips required trimming: their complete measured tails are all within the 0.750 s budget. `afinfo` verified the final container, channel count, sample rate, sample format, and durations; FFmpeg `astats` verified a non-zero peak/RMS level for every final CAF.

## Asset manifest

| Bundled resource | Semantic use | Original source file | Source pack | Creator | Source reference | SPDX | Local license | Redistribution | Processing | Measured duration |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `deployment.caf` | Manual soldier deployment | `drawKnife3.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.476576 s |
| `attack-melee.caf` | Automatic melee attack | `knifeSlice.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.599546 s |
| `attack-ranged.caf` | Automatic ranged or magic attack | `drawKnife2.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.445850 s |
| `attack-siege.caf` | Automatic siege attack | `chop.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.240249 s |
| `tower-fire.caf` | Automatic enemy-tower shot | `metalClick.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.445850 s |
| `soldier-hit.caf` | Automatic soldier-damage hit | `cloth2.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.415079 s |
| `soldier-death.caf` | Automatic soldier-damage death | `dropLeather.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.415102 s |
| `construction.caf` | Building constructed or upgraded | `metalPot3.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.907007 s |
| `blocked.caf` | Invalid or unaffordable action | `metalLatch.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.261338 s |
| `gold-reward.caf` | Gold reward | `handleCoins.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.845533 s |
| `city-conquest.caf` | City-conquest outcome | `doorOpen_1.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.918957 s |
| `country-completion.caf` | Country-completion outcome | `doorOpen_2.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 1.413333 s |
| `fortified-warning.caf` | Fortified-lane warning | `creak2.ogg` | Kenney RPG Audio v1.0 | Kenney | [Official archive](https://www.kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip) | CC0-1.0 | `docs/licenses/audio/CC0-1.0.txt` | Yes — CC0 permits modification and binary-app redistribution. | Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim. | 0.830159 s |

The in-app automatic-combat set is `attack-melee`, `attack-ranged`, `attack-siege`, `tower-fire`, `soldier-hit`, and `soldier-death`; each is at or below 0.750 s after conversion. Non-automatic outcome and UI clips intentionally have no automatic voice-duration cap.

## Offline licensing and provenance

- Complete CC0 1.0 Universal legal code: `docs/licenses/audio/CC0-1.0.txt`, obtained from <https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt>.
- Archive-bundled provenance notice: `docs/licenses/audio/Kenney-RPG-Audio-LICENSE.txt`.
- Local review guide: `docs/licenses/audio/README.md`.

The CC0 waiver and fallback license permit the modification and distribution needed for these processed CAF files and their inclusion in a binary application. Attribution is not required by CC0; the manifest retains Kenney attribution and original filenames for traceability.
