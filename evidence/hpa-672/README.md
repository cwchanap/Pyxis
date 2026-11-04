# HPA-672 evidence captures

Real-routing Ascension flow screenshots from the seeded DEBUG
`map-country-complete` fixture (every catalog item owned at Lv1 through the
`KingdomGameState` initializer; `.map`/`.mapPartial` untouched). Captured by
`PyxisUITests/testHPA672AscensionFlowEvidence` — one run per device:

```
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:PyxisUITests/PyxisUITests/testHPA672AscensionFlowEvidence \
  -parallel-testing-enabled NO -resultBundlePath <bundle>.xcresult
xcrun xcresulttool export attachments --path <bundle>.xcresult \
  --output-path <dir>
```

| Directory | Device | Viewport (pt) |
| --- | --- | --- |
| `iphone-17/` | iPhone 17 (iOS 26.5) | 402×874 |
| `iphone-se/` | iPhone SE (3rd generation) (iOS 26.5) — compact | 375×667 |
| `ipad-pro-11/` | iPad Pro 11-inch (M4) (iOS 26.5) — portrait | 834×1194 |

Stages (same flow in every directory):

1. `hpa672-01-kingdom-ascend-prompt` — Kingdom, Ascend section selected,
   unarmed prompt (requirement met after the finale was acknowledged).
2. `hpa672-02-kingdom-ascend-armed` — the armed two-tap confirmation
   (Confirm Ascension + Cancel visible).
3. `hpa672-03-battle-city1-zero-gold` — after committing: City 1
   `battleActive`, zero gold, empty Treasury/camp, Lv1 gear preserved.
4. `hpa672-04-city1-replay-lv2-reward` — a real manual-infantry replay
   conquest report; the owned City 1 blade levels to Lv 2 with the truthful
   `Gear upgraded: Willowford Blade · Lv 2` line (the line never renders on
   compact report heights by HPA-671 design, so the SE capture shows the
   report without it).
5. `hpa672-05-kingdom-renown-armory-lv2` — post-ascension Kingdom: Renown 1
   · +25% header, and the Armory infantry row equipping the Lv 2 blade
   (`Attack Lv 2 · +22.5%`).
