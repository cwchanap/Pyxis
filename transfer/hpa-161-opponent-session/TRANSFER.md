# Transfer HPA-161 opponent-session work to Procyon

Branch: `cursor/hpa-161-opponent-session-4f8c`
Base: `main` @ `5918eacb7795c64e006913b2d67d9dcc011bd8de`
Head: see `HEAD` below after you download

## Preferred: git bundle

```bash
cd /path/to/procyon
git fetch origin main
git checkout main
git pull origin main

git fetch ./hpa-161-opponent-session.bundle \
  cursor/hpa-161-opponent-session-4f8c:cursor/hpa-161-opponent-session-4f8c

git checkout cursor/hpa-161-opponent-session-4f8c
git log --oneline main..HEAD | head
git push -u origin cursor/hpa-161-opponent-session-4f8c
```

Then open a draft PR titled **feat(chess): add local and language-model opponents** using `hpa-161-pr-body.md`.

## Alternative: single patch

```bash
cd /path/to/procyon
git checkout -b cursor/hpa-161-opponent-session-4f8c origin/main
git am hpa-161-opponent-session.patch
git push -u origin cursor/hpa-161-opponent-session-4f8c
```

## Alternative: patch series directory

```bash
git am hpa-161-patches/*.patch
```

## Files in this artifact set

| File | Purpose |
|------|---------|
| `hpa-161-opponent-session.bundle` | Full branch commits (preferred) |
| `hpa-161-opponent-session.patch` | Combined `git am` mailbox |
| `hpa-161-patches/` | Per-commit patches |
| `hpa-161-pr-body.md` | PR description |
| `chess_rival_engine_journey.webm` | E2E demo |
| `WALKTHROUGH.md` | Summary |
Recorded HEAD: 3356fd929b1652ec469972fb3b07cb38a5bad433
Commit count: 23
