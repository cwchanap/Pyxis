# Forged UI visual references

These five PNGs are the canonical 393×852 visual references for the Forged gameplay UI redesign planning and implementation work.

| Surface | Canonical file | Original redesign export |
| --- | --- | --- |
| Battle | `battle.png` | `3b.png` |
| Camp | `camp.png` | `2b.png` |
| Map | `map.png` | `2c.png` |
| Conquest | `conquest.png` | `2d.png` |
| Settings | `settings.png` | `2e.png` |

The PNGs are cropped to the phone canvas from the supplied redesign boards. They are presentation references only: shipping Swift models remain authoritative for gameplay values, unlocks, routing, and state.

Implementation parity evidence must compare a real 393×852 simulator capture against these files and include a 50% alpha overlay. Do not replace these source files with a later ad-hoc export during implementation; revise the planning reference explicitly if the visual target changes.