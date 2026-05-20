# Rollback

Releases are timestamped directories under:

```text
RELEASES_DIR
```

The active release is the `CURRENT_LINK` symlink, normally:

```text
/opt/acore-manager/current
```

## List Releases

```bash
./bin/acore-manager list-releases
```

The active release is marked clearly.

## Switch Release

```bash
./bin/acore-manager switch-release <release-name>
```

The switch script validates the release directory and binaries before changing the symlink. It then stops world, stops auth, updates `CURRENT_LINK`, starts auth, starts world, and runs status.

## Roll Back

```bash
./bin/acore-manager rollback
```

Rollback identifies the current release, selects the previous release by sorted release directory order, and delegates to `switch-release`.

If there is no previous release, rollback fails clearly and does not guess.

## Prune Releases

```bash
./scripts/releases/acore-prune-releases.sh
```

This keeps the active release plus a small number of recent releases. The default keep count is `5`, or set `ACORE_RELEASE_KEEP_COUNT`.
