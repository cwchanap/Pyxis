# Gaming UI Layout Redesign Design

## Context

Pyxis is a SpriteKit + UIKit iOS idle kingdom game. The current battle screen works mechanically, but the UI is still a centered vertical stack of labels, a compressed battlefield band, two broad action buttons, and simple text feedback. The country map also works mechanically, but it reads as a route diagram rather than a polished campaign screen.

The redesign should make Pyxis feel more attractive and responsive while preserving the established rules: the player spawns soldiers, soldiers fight automatically, city conquest grants gold, attack-power upgrades remain the only upgrade axis, offline progress stays abstract, and the country map remains a linear 15-city Country 1 chapter.

## Goals

- Improve battlefield visibility.
- Make progression and status easier to read at a glance.
- Make spawn and upgrade controls easier to use.
- Give the game a stronger kingdom-fantasy identity.
- Add more satisfying player feedback through generated art and SpriteKit animation.
- Redesign both `BattleScene` and `CountryMapScene` as one coherent UI pass.
- Keep gameplay rules, persistence, and campaign progression unchanged.

## Non-Goals

- Adding troop types.
- Adding new upgrade categories.
- Adding branching country-map gameplay.
- Adding city modifiers, side routes, bosses, or multiple countries.
- Persisting live soldiers.
- Simulating live tower combat while backgrounded.
- Replacing SpriteKit scene presentation with a separate UIKit overlay system.
- Reworking `KingdomGameState`, `BattleCombatState`, or save data for visual-only needs.

## Visual Direction

Use a `Bright Kingdom Siege` style:

- colorful chibi fantasy presentation
- readable silhouettes at phone scale
- warm gold UI accents
- blue-green friendly kingdom tones
- orange-red enemy city and tower tones
- soft dark backing panels for HUD readability
- reward and combat effects that are bright, short, and legible

The UI should feel like a polished mobile kingdom game, not a generic app dashboard. Persistent information should stay compact, while feedback appears near the action and then clears.

## Battle Scene Design

Use the `Commander HUD` layout direction.

### Persistent Layout

`BattleScene` should be split into three visual zones:

- Top HUD: compact status clusters.
- Battlefield: castle, city, lane, soldiers, HP bars, tower shots, hit effects.
- Action bar: spawn and upgrade controls near the bottom.

The top HUD replaces the current centered vertical label stack.

The left HUD cluster shows:

- gold
- normal soldier attack power
- live soldier count

The right HUD cluster shows:

- `Country N - City M`
- city HP text
- city HP bar

The middle of the screen should belong to combat. The lower-middle playfield should stay mostly clear except for transient feedback.

The bottom action zone keeps two primary actions:

- `Spawn Soldier`
- `Upgrade`

`Spawn Soldier` should remain the dominant action. `Upgrade` should stay readable but visually communicate whether it is affordable. An affordable upgrade can glow or pulse subtly; an unaffordable upgrade should remain tappable so the player can still receive the existing insufficient-gold feedback.

### Battlefield Presentation

The battlefield should feel larger and less squeezed than the current implementation. It should include:

- generated or image-backed battlefield backdrop
- friendly castle on the left
- enemy city on the right
- visible road or lane between them
- live soldiers with small HP bars
- tower shots from the enemy city toward targeted soldiers
- floating damage numbers near city hits
- brief soldier death pop or fade
- city hit flash or shake
- stronger conquest flash and gold burst

The scene must still derive layout from the available safe vertical band. On compact heights, it is better to reduce visual density or hide decorative elements than to overlap HUD, feedback, battlefield, or buttons.

### Transient Feedback

Text-only feedback should no longer carry the whole experience. Keep one short feedback string for clarity, but pair it with visual effects:

- damage numbers when soldiers hit the city
- projectile streaks for tower attacks
- small impact flashes for hits
- soldier death fade/pop when HP reaches zero
- upgrade success sparkle or button pulse
- insufficient-gold button shake or red flash
- conquest gold burst and reward banner

Effects should be short and state-driven. Avoid continuous animation on every HUD element.

### Conquest Modal

The conquest popup should become a reward banner-style modal:

- title: conquered city or country completion
- reward: gold earned
- primary continue button
- optional brief gold burst behind the banner

It should continue to block spawn and upgrade input while visible and route to the country map when closed.

## Country Map Design

Use the `Illustrated Region Map` direction.

`CountryMapScene` should become a campaign screen with a generated-looking region backdrop instead of a plain dark route. The current 15-city linear progression remains unchanged.

### Persistent Layout

The map should include:

- illustrated Country 1 terrain backdrop
- top compact title/status band
- all 15 city nodes
- roads connecting the cities
- conquered, unlocked, and locked city states
- bottom feedback/status strip

The title band shows the current country. The bottom strip gives one-line feedback such as selecting the unlocked city, city locked, city complete, or country conquered.

### City States

Completed cities should read as conquered:

- gold fill or gold ring
- small conquered marker where practical
- subdued but proud styling

The unlocked city should be the strongest map signal:

- green or blue glow
- subtle pulse
- clear tappable state

Locked cities should remain visible:

- dim fill
- lower-contrast label
- no glow

Tapping behavior remains the same:

- unlocked city enters battle
- locked city gives feedback and no mutation
- completed city gives feedback and no mutation
- country-complete state gives completion feedback and no mutation

## Assets And Image Generation

Generated image assets are in scope. Prefer transparent PNG assets for foreground objects and effects, and use full-scene or tileable image assets only where scaling stays clean.

Likely generated assets:

- refined friendly castle
- refined enemy city with tower silhouette
- normal soldier
- battlefield backdrop
- country map backdrop
- hit flash
- tower projectile
- gold burst
- reward banner or HUD plate elements
- small conquered marker or banner

Existing asset names can remain when the visual meaning is unchanged. New files can be added under `Pyxis/` or asset catalogs without editing `project.pbxproj`, because the project uses file-system-synchronized groups.

## Architecture

Keep the current architecture boundary.

`KingdomGameState` remains the durable rules model for:

- gold
- city/country progress
- city HP
- attack-power upgrades
- idle catch-up
- stage status

`BattleCombatState` remains the pure live-combat model for:

- transient soldiers
- live HP
- movement
- repeated attacks
- tower targeting and shots
- city damage events

`BattleScene` owns:

- HUD layout
- buttons
- battlefield nodes
- soldier nodes
- visual effects
- conquest modal
- routing to the country map

`CountryMapScene` owns:

- illustrated map presentation
- city node layout
- city-state styling
- city tap feedback
- routing back to battle

Small SpriteKit helpers are acceptable if they reduce duplication, such as reusable rounded HUD panels, labeled bars, floating feedback labels, or button state styling. These helpers should stay presentation-only.

No save-schema changes are needed.

## Responsive Layout

The redesign must work across portrait phone sizes and compact simulator sizes.

Battle layout rules:

- keep top HUD clusters inside readable margins
- cap HUD width so labels do not run into each other
- keep battlefield center clear
- keep action buttons reachable at the bottom
- shrink or simplify decorative elements before overlapping core UI
- fit labels to their containers instead of letting text overflow

Country map layout rules:

- keep all 15 city nodes visible
- preserve minimum touch size for city nodes
- keep title and feedback strips clear of the city path
- allow the route shape to adapt to available height
- keep locked/unlocked/completed states distinguishable even at compact sizes

## Testing And Verification

Automated tests should cover stable behavior rather than exact animation frames.

Battle scene tests should cover:

- HUD layout anchors stay within scene bounds
- action buttons still route to spawn and upgrade
- conquest modal visibility blocks input
- feedback text still updates for upgrade success and insufficient gold
- live soldier HP bars remain readable above scaled bodies

Country map tests should cover:

- city nodes stay tappable after the layout change
- locked city taps do not mutate state
- completed city taps do not mutate state
- unlocked city taps route to battle
- compact layout keeps city labels and feedback visible

Manual or simulator verification should cover:

- generated assets render without missing-resource crashes
- battle screen is visually readable on phone-sized simulator
- spawn, tower shots, deaths, city hits, and conquest effects are understandable
- upgrade affordance is clear
- country map states are distinguishable
- map route into battle still works

## Implementation Boundaries

The first implementation should focus on the visual redesign and feedback polish only. It can add presentation helpers and generated assets, but it should not change combat math, progression rules, idle catch-up, country unlock rules, or persistence format.

Future work can add richer city identities, route branches, multiple countries, or deeper upgrade surfaces after this UI foundation lands.
