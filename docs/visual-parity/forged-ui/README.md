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

Implementation parity evidence must compare a real 393×852 simulator capture against these exact files and include a 50% alpha overlay. Deliberate differences are allowed only when required by shipping gameplay or geometry contracts and must be recorded in the implementation PR parity board.
