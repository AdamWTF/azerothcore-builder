# Build and Release

The build workflow is split into small scripts. You can run them individually or use the high-level release workflow.

## Update Source

```bash
./bin/acore-manager update-source
```

This clones or updates `ACORE_REPO` at `ACORE_BRANCH` into `SOURCE_DIR`.

## Update Modules

```bash
./bin/acore-manager update-modules
```

This clones or updates configured modules into `MODULES_DIR`.

## Build

```bash
./bin/acore-manager build
```

Build output is installed into:

```text
BUILD_DIR/staging
```

`BUILD_THREADS="auto"` uses `nproc` when available.

## Create Release

```bash
./bin/acore-manager create-release
```

This copies `BUILD_DIR/staging` into:

```text
RELEASES_DIR/<timestamp>
```

It also writes:

```text
RELEASES_DIR/<timestamp>/metadata/release-info.txt
```

The metadata includes build date, AzerothCore commit, module commits, build type, and paths.

Creating a release does not change `CURRENT_LINK` and does not restart services.

## Full Workflow

```bash
./bin/acore-manager release-latest
```

This orchestrates validation, DB check, source/module updates, build, release creation, optional config backup, release switch, and final status. It calls the smaller scripts rather than duplicating their logic.
