# Build and Release

The build workflow is split into small scripts. You can run them individually or use the high-level release workflow.

## Update Source

```bash
./bin/acore-manager update-source
```

This clones or updates `ACORE_REPO` at `ACORE_BRANCH` into:

```text
/opt/acore-manager/source/azerothcore
```

## Update Modules

```bash
./bin/acore-manager update-modules
```

This clones or updates configured modules into:

```text
/opt/acore-manager/source/azerothcore/modules
```

## Build

```bash
./bin/acore-manager build
```

Build output is installed into:

```text
/opt/acore-manager/build/staging
```

`BUILD_THREADS="auto"` uses `nproc` when available.

The build step does not switch the active release and does not restart services.

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

It also does not guarantee the server is ready to run. A running server still needs prepared data files, runtime config files, reachable databases, installed systemd services, and firewall/client checks. See [Full Server Setup](full-server-setup.md).

## Switch Release

```bash
./bin/acore-manager list-releases
sudo ./bin/acore-manager switch-release <release-name>
```

Switching validates the release, updates:

```text
/opt/acore-manager/current
```

and restarts services in the safe order: stop world, stop auth, start auth, start world.

On a first server, prepare data files and configs before switching, because `switch-release` starts services.

## Full Workflow

```bash
./bin/acore-manager release-latest
```

This orchestrates validation, DB check, source/module updates, build, release creation, optional config backup, release switch, and final status. It calls the smaller scripts rather than duplicating their logic.

Use the high-level workflow only after the manual flow is understood and the server already has working data, configs, databases, and services.
