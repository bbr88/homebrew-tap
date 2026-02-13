# homebrew-tap

Homebrew tap for TabDump.

## Install and Bootstrap

```bash
brew tap bbr88/tap
brew install tabdump
tabdump init --yes --vault-inbox ~/obsidian/Inbox/
```

After initialization:

```bash
tabdump status
tabdump now
tabdump mode auto
```

Uninstall runtime:

```bash
tabdump uninstall --yes
brew uninstall tabdump
```

## Formula Bump Helper

Use the helper script to update `Formula/tabdump.rb` from a release tag.

### Option A: auto-fetch checksum from release (recommended)

```bash
scripts/bump-tabdump-formula.sh --tag v0.0.5-test --from-release
```

If you omit checksum flags, the script also defaults to fetching checksum from release:

```bash
scripts/bump-tabdump-formula.sh --tag v0.0.5-test
```

### Option B: pass checksum directly

```bash
scripts/bump-tabdump-formula.sh --tag v0.0.5-test --sha256 <64hex>
```

### Option C: pass `.sha256` file

```bash
scripts/bump-tabdump-formula.sh --tag v0.0.5-test --sha256-file /path/to/tabdump-homebrew-v0.0.5-test.tar.gz.sha256
```

### Dry run

```bash
scripts/bump-tabdump-formula.sh --tag v0.0.5-test --from-release --dry-run
```

### Full release bump flow

```bash
scripts/bump-tabdump-formula.sh --tag vX.Y.Z --from-release
ruby -c Formula/tabdump.rb
git add Formula/tabdump.rb
git commit -m "chore(formula): bump tabdump to vX.Y.Z"
git push
```

Notes:
- The script validates that the release asset URL is reachable.
- Use `--skip-url-check` only if your environment cannot reach GitHub from CI/dev machine.
