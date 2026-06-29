# Battle Readability HUD Design

## Context

The battle screen currently reserves too much space for persistent HUD text and feedback copy. The three marching lanes are clustered near the center, the lane paths are narrow, and soldiers render at a small target height. This makes the battle read more like a status dashboard than a battlefield.

## Goals

- Divide the battlefield into three wide vertical lane bands that fill the available screen width.
- Increase battlefield height by removing persistent feedback text from the layout reservation.
- Render soldiers larger while preserving existing 128 px animation-frame assets and aspect ratio.
- Make the battle HUD image-led without hiding necessary labels: icons and sprites carry the primary visual signal, while short text remains where a player needs it to understand an action or scan core status.
- Redesign lanes as low-alpha terrain cues that use the existing battlefield backdrop instead of covering it with foreground lane art.
- Keep attack and hit playback from swapping to mismatched generated transient-frame characters.
- Preserve readable attack feedback with a stable-art slash cue and lunge.
- Keep gameplay/combat math unchanged.

## Design

`BattlefieldLayout` remains the owner of pure lane geometry. It will move lane centers from compact center offsets to equal thirds of the battlefield frame and size each lane path from the battlefield width, leaving a small gutter between bands. The scene will pass a wider battlefield frame than the text HUD content width so lanes visually occupy nearly the full screen.

`BattleScene` will render the lanes as battlefield terrain. Each lane gets a full-height, low-alpha dirt/grass tint, subtle borders, and small irregular decorative marks so the lanes read as ground without covering the backdrop. This remains visual-only; combat positions and lane math are unchanged.

`BattleScene` will stop treating feedback text as a permanent layout element. Feedback remains available through the existing `feedbackPanel` and `feedbackLabel`, but the panel is hidden by default and shown briefly as a tooltip after actions or when tapping info controls. The layout call will not reserve tooltip clearance while no tooltip is visible.

Soldier presentation stays in `BattleScene`. The same generated walk frames and fallback assets are used. Body target height was scoped down from the original 108-140 pt target to **54-70 pt** (roughly half scale) during implementation, because at 128 px source frames the full target would have produced a ~2.9× upscale on 3× devices once per-type cropping is applied — visibly soft without a new art pipeline. Half scale keeps soldiers crisp while still reading clearly against the wider lanes; the deviation is captured here and in the plan so docs match shipped reality. HP bars are scaled to match the body and placed close to the actor. Generated attack/hit frames are not used for playback because the current sets can visually change the actor into a different character; transient feedback keeps the stable walk-frame identity and adds a visible slash cue plus lunge until consistent transient art is regenerated.

HUD controls become mixed icon/text controls. Common actions such as World and Build can remain icon-only in compact, near-square buttons. Less obvious actions keep concise text: Spawn shows a large soldier icon plus `Spawn`, and the unit selector shows the selected soldier icon plus the unit name. The top HUD keeps concise persistent values for gold, soldier count, city title, and HP, while longer explanations remain in tooltips.

## Testing

- Add/update `BattlefieldLayoutTests` for equal-third lane centers, wide lane path bounds, and optional feedback clearance.
- Add/update `BattleSceneTests` for taller battlefield frames, low-alpha terrain lane nodes, mixed icon/text HUD behavior, compact common-action buttons, large button icons, 2x soldier body frames with close HP bars, and stable transient playback identity with visible attack feedback.
- Run targeted unit tests first, then run the broader Pyxis test target with parallel testing disabled.

## Non-Goals

- No combat balance changes.
- No new generated art pipeline; mismatched transient-frame art is bypassed rather than regenerated in this pass. Soldier source frames stay at 128 px; the 108-140 pt target was traded down to 54-70 pt to avoid an unacceptable upscale on high-DPI devices (see Design above).
- No changes to the building view. The country map backdrop was originally listed here as untouched, but a small, self-contained backdrop-polish change (aspect-fill scaling so the map art fills the screen edge-to-edge instead of letterboxing, plus authored pad-space city anchors so the route reads cleanly against the new fill) was bundled into this branch because the wider battle HUD exposed the previous letterboxed map on the adjacent screen transition. The map work has no code dependency on the battle HUD and is covered by `CountryMapSceneTests`; if a cleaner history is later desired it can be split via `git checkout main -- Pyxis/CountryMapScene.swift PyxisTests/CountryMapSceneTests.swift`.
