# AGENTS.md

## Project Overview

`acore-manager` is a generic Linux automation toolkit for managing AzerothCore servers.

It helps operators build, release, run, monitor, back up, and roll back AzerothCore using shell scripts, config files, systemd templates, and optional integrations.

This repository must stay generic. It is not tied to a private realm, custom repack, personal environment, or curated private module set.

Default/example install root:

```text
/opt/acore-manager
```

## Core Principles

- Prefer small, reviewable changes.
- Preserve existing behavior unless the task explicitly asks for a behavior change.
- Keep scripts composable. Add focused helpers rather than large monolithic scripts.
- Avoid destructive defaults. Warn first where practical.
- Fail clearly with useful messages.
- Keep optional integrations optional.
- Do not assume a specific server, module pack, hostname, user, IP address, or database credential.

## Repository Conventions

- `bin/acore-manager` is the user-facing CLI dispatcher.
- `scripts/lib/common.sh` is the shared shell loader for config and derived paths.
- Script categories:
  - `scripts/setup/`
  - `scripts/source/`
  - `scripts/build/`
  - `scripts/runtime/`
  - `scripts/releases/`
  - `scripts/db/`
  - `scripts/config/`
  - `scripts/logs/`
- Default/example config belongs in `config/defaults/`.
- Local user config belongs in `config/local/` and should remain gitignored.
- systemd templates live in `systemd/`.
- Optional OliveTin example config lives in `olivetin/`.
- Public docs live in `README.md` and `docs/`.

## Shell Script Conventions

- Use Bash for project scripts.
- Start scripts with:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

- Source `scripts/lib/common.sh` instead of duplicating config/path logic.
- Use configured values from common config, especially `ACM_ROOT`, `CURRENT_LINK`, `AUTH_SERVICE`, and `WORLD_SERVICE`.
- Treat `SOURCE_ROOT` as the source parent directory and `ACORE_SOURCE_DIR` as the AzerothCore git checkout.
- Keep scripts idempotent where practical.
- Check required commands before using them.
- Print clear status messages before important actions.
- Prefer explicit validation before changing symlinks, services, files, or directories.
- Build scripts must not restart services unless explicitly part of a release/switch workflow.
- Runtime scripts must use configured service names from common config.
- Release switching should preserve the safe order: stop world, stop auth, update link, start auth, start world.

## Config And Secrets Rules

- Public files must not contain private IPs, hostnames, usernames, passwords, emails, access tokens, personal branding, or private server names.
- Use placeholders in docs/examples:
  - `<mysql-host>`
  - `<mysql-user>`
  - `<mysql-password>`
  - `<server-host>`
- Do not commit real `config/local/manager.conf`, `config/local/modules.txt`, `config/local/db.conf`, or `.env`.
- Do not add private module packs to default examples.
- Do not hardcode credentials into scripts, docs, systemd files, OliveTin config, or examples.
- `config/defaults/*.example` files should contain safe generic defaults only.

## Testing And Validation Expectations

For shell changes, run syntax checks where possible:

```bash
bash -n path/to/script.sh
```

For dispatcher changes, smoke-test read-only commands:

```bash
./bin/acore-manager --help
./bin/acore-manager status
```

For config changes:

```bash
./bin/acore-manager validate
```

For documentation or public examples, scan for private values and stale script names.

Do not run scripts that install packages, start/stop services, switch releases, build AzerothCore, or modify `/opt/acore-manager` unless the user explicitly asked for that action and the environment is appropriate.

## Documentation Expectations

- Keep `README.md` concise. It should introduce the project, show quick start, and link to docs.
- Put practical details in `docs/`.
- Make command examples match real scripts or `bin/acore-manager` commands.
- Prefer the CLI wrapper in user-facing docs.
- Use `/opt/acore-manager` for example paths.
- Keep docs generic and public-safe.
- Update docs when script names, paths, config keys, or workflows change.

## Things Agents Must Not Do

- Do not introduce private branding, private paths, private IPs, usernames, passwords, emails, or hostnames.
- Do not replace generic defaults with one server's local configuration.
- Do not commit files under `config/local/` except `.gitkeep`.
- Do not make OliveTin, or any optional integration, required for core functionality.
- Do not add build/release behavior to runtime-only scripts.
- Do not start, stop, restart, enable, or disable services from scripts that are meant to be read-only checks.
- Do not make build scripts switch `CURRENT_LINK`.
- Do not delete modules or releases unless the script is explicitly for pruning and preserves the active release.
- Do not overwrite existing local config or installed service files by default.
- Do not reintroduce a monolithic build-and-deploy script.

## Suggested Pre-Commit Checklist

- Scripts use `scripts/lib/common.sh` where config or derived paths are needed.
- New scripts are executable when intended to be run directly.
- Shell scripts pass `bash -n`.
- Commands in docs match files that exist.
- Public files contain no secrets or private values.
- Local config remains ignored by git.
- Optional integrations remain optional.
- Existing behavior is preserved unless explicitly changed.
- README stays short; detailed guidance belongs in `docs/`.
- For release/runtime changes, service order and `CURRENT_LINK` behavior are intentional.

## When Unsure

Prefer small, reviewable changes. Preserve existing behavior. Ask for clarification rather than making broad architecture changes.
