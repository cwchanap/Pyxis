# Forged UI visual references

The supplied redesign package contains the authoritative 393×852 visual references for the Forged gameplay UI redesign:

| Surface | Supplied export |
| --- | --- |
| Battle | `3b.png` |
| Camp | `2b.png` |
| Map | `2c.png` |
| Conquest | `2d.png` |
| Settings | `2e.png` |

These mockups are presentation references only. Shipping Swift models remain authoritative for gameplay values, unlocks, routing, persistence, and state.

## Planning asset gate

The five source PNGs must be committed here as `battle.png`, `camp.png`, `map.png`, `conquest.png`, and `settings.png` before implementation begins. The GitHub connector used for this planning session truncates binary blob writes at the source image sizes, so broken/truncated placeholders were removed instead of being accepted as canonical assets.

Until the exact PNGs are present in this directory, PR #39 must remain Draft and the runtime implementation must not start from ad-hoc screenshots or re-exports.

The intended mapping is:

| Repository path | Supplied export |
| --- | --- |
| `battle.png` | `3b.png` |
| `camp.png` | `2b.png` |
| `map.png` | `2c.png` |
| `conquest.png` | `2d.png` |
| `settings.png` | `2e.png` |

Once committed, implementation parity evidence must compare a real 393×852 simulator capture against those exact files and include a 50% alpha overlay. If the visual target changes later, revise these source files explicitly rather than silently substituting a new export.