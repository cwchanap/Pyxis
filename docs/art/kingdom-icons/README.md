# Kingdom icons — HPA-673

Twenty transparent 128×128 PNGs are installed in `Pyxis/Assets.xcassets` under the existing Kingdom, Treasury, equipment catalog, and Renown lookup names. No gameplay code or asset lookup changed.

## Generation

Each icon was generated individually with the built-in image-generation tool using `conquered-marker.png` as a style reference. The tool did not expose a model identifier or seed. Source images remain in the local Codex generated-images directory; the runtime PNGs are tracked in the asset catalog. Square sources were resized to 128×128; landscape sources were center-cropped to a square and resized, except the City 11 siege engine, which was fitted to a transparent square to retain its full silhouette. Alpha was preserved.

The Kingdom tab prompt requested a simple three-point gold crown, polished forged gold with warm highlights and a dark outline, centered on transparency and legible at 28 pt. The other icons used this common prompt with the subjects below:

> Create one medieval fantasy game UI icon: [subject]. Match the supplied image's polished dimensional forged game-art treatment, warm gold highlights, clear dark edges, restrained jewel colors. One isolated centered object, bold readable silhouette at 28–44 pt, generous transparent padding. No frame, tile, letters, numbers or watermark.

| Asset | Subject | Generated source |
| --- | --- | --- |
| `tab-kingdom` | Gold crown | `exec-572ba9bf-cf78-4445-91da-f6f879cf4e1d.png` |
| `treasury-war-chest` | Wooden treasure chest with gold bands and coins | `exec-f47edd89-d8b1-4d3d-aea5-5d38964d84c7.png` |
| `treasury-drill-yard` | Crossed practice sword and training shield | `exec-b90f66df-191f-4076-93d4-9ea00b4f9b2e.png` |
| `treasury-quartermaster` | Leather supply satchel | `exec-18649579-80f3-4210-a8b7-81aab47a332b.png` |
| `ascension-renown` | Crown and upward laurel wreath | `exec-2f3700e7-7451-4134-aa01-56eef32687d1.png` |
| `equipment-c01-infantry-attack` | Infantry sword | `exec-da56ee98-f111-477e-819d-29264102f769.png` |
| `equipment-c02-archer-attack` | Longbow and arrow | `exec-70af9134-de3a-4941-9394-6f9eb1b038f8.png` |
| `equipment-c03-infantry-toughness` | Infantry shield | `exec-17670c16-40bd-42fc-a3f8-3c1eae6f373a.png` |
| `equipment-c04-archer-tower` | Broadhead arrow | `exec-51a60d71-a8df-42c9-9c93-65211ff67633.png` |
| `equipment-c05-cavalry-attack` | Cavalry lance and pennant | `exec-aebbee13-cad5-4695-9ad2-4a8c0b800f55.png` |
| `equipment-c06-infantry-gate` | Iron-tipped battering ram | `exec-b8d94da3-ba98-4420-b7d8-d843e57a704d.png` |
| `equipment-c07-cavalry-toughness` | Horse head armor | `exec-57155b77-44e3-48f8-9714-4982dfc77cb5.png` |
| `equipment-c08-mage-attack` | Blue crystal focus | `exec-f91849fa-c0a4-4858-b850-cad7cec7726d.png` |
| `equipment-c09-archer-toughness` | Rune-marked archer bracer | `exec-368a6dcd-22ac-41cc-bc35-ad341718b935.png` |
| `equipment-c10-cavalry-barracks` | Cavalry war hammer | `exec-202cb1b5-5cb6-4d35-9847-1dd37a164093.png` |
| `equipment-c11-siege-attack` | Siege ram head and beam | `exec-122ff2a6-5271-4639-b283-9e7f8761c38a.png` |
| `equipment-c12-mage-barracks` | Magical ember in a brazier | `exec-fc3112fe-00a3-4df2-8213-c201bb3923ed.png` |
| `equipment-c13-siege-toughness` | Reinforced siege armor plate | `exec-5472b48d-bd3f-4d78-8e11-cec3058d8d63.png` |
| `equipment-c14-mage-toughness` | Crowned stone ward | `exec-5207035a-65e2-4cc8-bd5a-b3aa191fb332.png` |
| `equipment-c15-siege-keep` | Siege breaker ram head | `exec-f6704491-e570-4f5b-a4e1-b78624a9ffab.png` |
