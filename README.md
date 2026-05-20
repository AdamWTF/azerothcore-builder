# acore-manager

`acore-manager` is a reusable Linux server manager for AzerothCore.

It provides a practical toolkit for building, releasing, running, monitoring, backing up, and rolling back AzerothCore server deployments. The current repository keeps that scope deliberately small: it contains focused scripts for updating sources and modules, building into staging, creating timestamped releases, switching the active release, managing services, checking database connectivity, validating configuration, and viewing logs.

The default example install root is:

```text
/opt/acore-manager
```

## What this project does

`acore-manager` can:

- Clone or update the AzerothCore source tree.
- Clone or update a list of configured modules.
- Build AzerothCore locally.
- Install the build into a local staging directory.
- Deploy the staged server to a remote Linux host.
- Preserve existing runtime configuration files on the remote host.
- Deploy `.conf.dist` templates for new or updated configs.
- Deploy AzerothCore SQL files to the remote host.
- Deploy module source trees to the remote host so module SQL is available.
- Restart or check the remote `authserver` and `worldserver` systemd services.
- Follow remote server logs.
- Back up the remote `etc` directory before deployment, when configured.

## Intended Workflow

The intended setup is:

```text
Local build environment
  - Builds AzerothCore from source
  - Pulls modules listed in modules.txt
  - Stages compiled server files locally
  - Deploys to a remote Linux server over SSH

Remote server
  - Runs authserver/worldserver via systemd
  - Stores runtime config in /opt/acore-manager/server/etc
  - Stores deployed source SQL in /opt/acore-manager/source
```

## Repository Layout

```text
acore-manager/
|-- config.env
|-- config.env.example
|-- modules.txt
|-- scripts/
|   |-- build/
|   |   |-- acore-build.sh
|   |   |-- acore-create-release.sh
|   |   `-- acore-release-latest.sh
|   |-- lib/
|   |   `-- common.sh
|   |-- setup/
|   |-- source/
|   |-- runtime/
|   |-- releases/
|   |-- db/
|   |-- config/
|   `-- logs/
`-- README.md
```

### `scripts/`

Category-based helper scripts for source updates, builds, release management, runtime service control, logs, database checks, and config validation.

### `config.env`

Local environment configuration for your build/deploy setup.

This file is machine-specific and should usually not be committed.

### `config.env.example`

Example configuration showing the expected variables.

### `modules.txt`

List of AzerothCore modules to clone, build, and deploy.

Format:

```text
module-name|git-url|branch
```

Example:

```text
mod-playerbots|https://github.com/mod-playerbots/mod-playerbots.git|master
mod-individual-progression|https://github.com/ZhengPeiRu21/mod-individual-progression.git|master
mod-ah-bot|https://github.com/azerothcore/mod-ah-bot.git|master
```

## Prerequisites

On the local build environment:

```bash
sudo apt update
sudo apt install -y git cmake make rsync openssh-client
```

You will also need the normal AzerothCore build dependencies installed.

For Ubuntu/Debian-based systems, refer to the official AzerothCore installation documentation for the full dependency list.

Remote management scripts expect SSH or shell access to the target server to already work before you run them there.

Example:

```bash
ssh <your-user>@<server-host>
```

## Commands

### Full Local Release Workflow

```bash
./scripts/build/acore-release-latest.sh
```

This orchestrates config validation, database checks, source/module updates, build, release creation, optional config backup, release switch, and final status by calling the smaller scripts.

### Validate Configuration

```bash
./scripts/config/acore-validate-config.sh
```

This checks required config variables, required commands, service names, and expected paths.

### Sync AzerothCore Source and Modules

```bash
./scripts/source/acore-update-source.sh
./scripts/source/acore-update-modules.sh
```

This will:

- Clone or update AzerothCore.
- Clone or update all modules listed in `config/local/modules.txt`, or the default example if no local module list exists.

### Build Only

```bash
./scripts/build/acore-build.sh
```

This will:

- Clean the staging directory.
- Configure CMake.
- Build AzerothCore.
- Install the build into `BUILD_DIR/staging`.

It does not switch the active release or restart services.

### Create a Release

```bash
./scripts/build/acore-create-release.sh
```

This copies `BUILD_DIR/staging` into a timestamped folder under `RELEASES_DIR` and writes `metadata/release-info.txt`.

It does not switch the active release or restart services.

### List and Switch Releases

```bash
./scripts/releases/acore-list-releases.sh
./scripts/releases/acore-switch-release.sh <release-name>
```

Switching a release validates the target release, stops world, stops auth, updates `CURRENT_LINK`, starts auth, then starts world.

### Roll Back or Prune Releases

```bash
./scripts/releases/acore-rollback.sh
./scripts/releases/acore-prune-releases.sh
```

Rollback selects the previous release by sorted release directory order and delegates to the release switch script.

### Manage Runtime Services

```bash
./scripts/runtime/acore-start.sh
./scripts/runtime/acore-stop.sh
./scripts/runtime/acore-restart.sh
./scripts/runtime/acore-restart-auth.sh
./scripts/runtime/acore-restart-world.sh
```

These scripts use the configured systemd services:

```text
AUTH_SERVICE
WORLD_SERVICE
```

### Check Server Status

```bash
./scripts/runtime/acore-status.sh
```

Displays active release, service status, common listening ports, disk usage, memory usage, and source commit information.

### View Logs

```bash
./scripts/logs/acore-logs-auth.sh
./scripts/logs/acore-logs-world.sh
./scripts/logs/acore-last-errors.sh
```

### Check Database Connectivity

```bash
./scripts/db/acore-db-check.sh
```

Checks MySQL connectivity, version, and configured AzerothCore databases using local ignored credentials when present.

## Module Handling

Modules are defined in `modules.txt`.

Each non-empty, non-comment line should use this format:

```text
module-name|git-url|branch
```

The script parses `modules.txt` once into memory before running sync, build, or deploy tasks.

This avoids a common shell scripting issue where commands like `rsync`, `ssh`, or `git` can accidentally consume stdin inside a `while read` loop, causing only the first module to be processed.

The script also validates that every configured module exists locally before building or deploying.

If a module is missing, the script fails fast instead of silently deploying an incomplete module set.

## Remote Directory Structure

The remote server is expected to use a layout similar to:

```text
/opt/acore-manager/
|-- server/
|   |-- bin/
|   |   |-- authserver
|   |   `-- worldserver
|   `-- etc/
|       |-- authserver.conf
|       |-- worldserver.conf
|       `-- modules/
|           |-- playerbots.conf
|           |-- mod_ahbot.conf
|           `-- individualProgression.conf
|-- source/
|   |-- data/
|   |   `-- sql/
|   `-- modules/
|       |-- mod-playerbots/
|       |-- mod-ah-bot/
|       `-- mod-individual-progression/
`-- backups/
```

The exact paths are controlled by `config.env`.

## Systemd Services

The script assumes the remote server has systemd services for AzerothCore.

Example service names:

```bash
AUTH_SERVICE="azerothcore-auth"
WORLD_SERVICE="azerothcore-world"
```

You can manage them manually on the remote server with:

```bash
sudo systemctl start azerothcore-auth
sudo systemctl start azerothcore-world

sudo systemctl stop azerothcore-world
sudo systemctl stop azerothcore-auth

sudo systemctl status azerothcore-world
journalctl -u azerothcore-world -f
```
