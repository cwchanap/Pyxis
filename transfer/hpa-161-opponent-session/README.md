# Temporary transfer: HPA-161 opponent-session → Procyon

This branch exists only so these files can be downloaded from GitHub.
**Delete this branch after you have applied the work to `cwchanap/procyon`.**

## Download

From this repo on branch `cursor/hpa-161-procyon-transfer-4f8c`:

- `hpa-161-opponent-session.bundle` (preferred)
- `hpa-161-opponent-session.patch` (fallback)

Raw URLs (replace if needed):

```
https://raw.githubusercontent.com/cwchanap/pyxis/cursor/hpa-161-procyon-transfer-4f8c/transfer/hpa-161-opponent-session/hpa-161-opponent-session.bundle
https://raw.githubusercontent.com/cwchanap/pyxis/cursor/hpa-161-procyon-transfer-4f8c/transfer/hpa-161-opponent-session/hpa-161-opponent-session.patch
```

Or:

```bash
curl -L -o hpa-161-opponent-session.bundle \
  https://raw.githubusercontent.com/cwchanap/pyxis/cursor/hpa-161-procyon-transfer-4f8c/transfer/hpa-161-opponent-session/hpa-161-opponent-session.bundle
```

## Apply to Procyon

```bash
cd /path/to/procyon
git fetch origin main && git checkout main && git pull

git fetch ./hpa-161-opponent-session.bundle \
  refs/heads/cursor/hpa-161-opponent-session-4f8c:refs/heads/cursor/hpa-161-opponent-session-4f8c

git checkout cursor/hpa-161-opponent-session-4f8c
git push -u origin cursor/hpa-161-opponent-session-4f8c
```

Fallback:

```bash
git checkout -b cursor/hpa-161-opponent-session-4f8c origin/main
git am ./hpa-161-opponent-session.patch
git push -u origin cursor/hpa-161-opponent-session-4f8c
```

PR title: `feat(chess): add local and language-model opponents`  
PR body: see `hpa-161-pr-body.md`
