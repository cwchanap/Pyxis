## Summary

Implements HPA-161 opponent-session runtime (Plan B) on top of merged packaging PR A (#34).

Players can choose an **On-device computer** (Stockfish) or **Language model** opponent, pick their side, Start an immutable rival session, and finish games without opponent/side drift or stale async moves.

### Architecture

- `useChessRivalSetup` — device preferences, cheap preflight, LLM usability, editable pre-game selection
- `useChessRivalSession` — atomic Start, frozen `ActiveRivalSession`, provider lifecycle, stale-result protection, disposal
- Both providers share one typed `RivalMoveResult` contract; LLM adapter preserves debug/export metadata; Stockfish uses packaged assets from PR A

### Key behaviors

- No Stockfish `/vendor/stockfish/*` request before explicit Start
- Signed-out default = on-device computer; configured signed-in untouched default = LLM
- All Play previews are `human-vs-ai` with derived rival side (no `human-vs-human` fallback)
- Board orientation resolves without White→Black flash
- Engine Skill Level 0; 60s Start load deadline; no mid-game engine same-position retry
- Engine sessions survive auth/config changes; LLM identity reset retained
- Engine history: Unrated + `{ kind: 'engine', id: 'stockfish' }` only when same starting user
- Xiangqi / Shogi / Jungle call sites unchanged

### Deferred (documented)

- HPA-162 difficulty presets
- HPA-163 responsive/recoverable local-rival turns
- HPA-164 / HPA-166 / HPA-187 release verification & compliance

### Dependency

Requires packaging PR A (Stockfish 18.0.8 assets) — already on `main` via #34.

## Validation

- Focused rival matrix: **258 pass / 0 fail**
- Cross-variant harnesses: **63 pass / 0 fail**
- `e2e/chess-rival.spec.ts`: **7/7 pass** (fake Worker; no real WASM)
- `test:e2e:stockfish-assets`: **4/4 pass** (real production Worker smoke)
- `bunx turbo run typecheck --filter=web`: pass
- `bunx turbo run lint --filter=web`: 0 errors (61 pre-existing warnings)
- production build: pass
- `bun run test` monorepo: **1602 pass / 0 fail**

## Test plan

- [x] Signed-out engine journey without eager download
- [x] Configured LLM journey + export
- [x] Failure/fallback journeys (unsupported, load-failed, remembered fallbacks, sticky explicit choice)
- [x] Cross-variant shared controls unchanged
- [x] Typecheck / lint / build / full unit suite
