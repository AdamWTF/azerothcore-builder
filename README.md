# AzerothCore Builder

A small build and deployment helper for maintaining a custom AzerothCore server from a separate build machine.

This project is designed for a workflow where AzerothCore is built on a more powerful machine, then the compiled server and relevant SQL/module source files are deployed to a remote Linux server.

The original use case is a private AzerothCore + PlayerBots server, but the scripts are intentionally generic enough to support other AzerothCore module combinations.

## What this project does

`azerothcore-builder` can:

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

## Intended workflow

The intended setup is:

```text
Build machine
  └── Builds AzerothCore from source
  └── Pulls modules listed in modules.txt
  └── Stages compiled server files locally
  └── Deploys to remote server over SSH

Remote server
  └── Runs authserver/worldserver via systemd
  └── Stores runtime config in /opt/azerothcore/server/etc
  └── Stores deployed source SQL in /opt/azerothcore/source
````

## Repository layout

```text
azerothcore-builder/
├── build-and-deploy.sh
├── config.env
├── config.env.example
├── modules.txt
└── README.md
```

### `build-and-deploy.sh`

Main script used to sync source, build, deploy, restart services, and view logs.

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

On the build machine:

```bash
sudo apt update
sudo apt install -y git cmake make rsync openssh-client
```

You will also need the normal AzerothCore build dependencies installed.

For Ubuntu/Debian-based systems, refer to the official AzerothCore installation documentation for the full dependency list.

The script expects SSH access to the remote server to already work.

Example:

```bash
ssh user@server-ip
```

## Commands

### Check prerequisites and SSH

```bash
./build-and-deploy.sh check
```

This verifies required local tools and confirms SSH connectivity to the remote server.

---

### Sync AzerothCore source and modules

```bash
./build-and-deploy.sh sync-source
```

This will:

* Clone or update AzerothCore.
* Clone or update all modules listed in `modules.txt`.
* Validate that all expected module directories exist locally.

### Build only

```bash
./build-and-deploy.sh build
```

This will:

* Clean the build directory.
* Configure CMake.
* Build AzerothCore.
* Install the build into the local staging directory.

It does not deploy to the remote server.

### Deploy existing staged build

```bash
./build-and-deploy.sh deploy
```

This deploys the existing staged build to the remote server.

It does not rebuild first.

This is useful if the build succeeded but deployment failed later.

### Sync, build, and deploy everything

```bash
./build-and-deploy.sh all
```

This performs the full workflow:

1. Check prerequisites.
2. Check remote SSH.
3. Sync AzerothCore and modules.
4. Build the server.
5. Deploy the server.
6. Deploy SQL/source files.
7. Fix permissions.
8. Restart services, if configured.

### Deploy SQL/source files only

```bash
./build-and-deploy.sh sql
```

This is useful when the compiled server has already been deployed, but module SQL/source files need to be refreshed on the remote server.

It deploys:

```text
AzerothCore SQL:
  SOURCE_DIR/data/sql/
  -> REMOTE_SOURCE_DIR/data/sql/

Module source trees:
  SOURCE_DIR/modules/<module>
  -> REMOTE_SOURCE_DIR/modules/<module>
```

This command is especially useful when a module expects database tables that are missing because its SQL was not available on the server.

### Restart remote services

```bash
./build-and-deploy.sh restart
```

Restarts both configured systemd services:

```text
AUTH_SERVICE
WORLD_SERVICE
```

### Check remote service status

```bash
./build-and-deploy.sh status
```

Displays systemd status for auth and world services.

### Follow worldserver logs

```bash
./build-and-deploy.sh logs
```

Equivalent to following:

```bash
journalctl -u azerothcore-world -f
```

using the configured remote service name.

### Follow authserver logs

```bash
./build-and-deploy.sh logs-auth
```

Equivalent to following:

```bash
journalctl -u azerothcore-auth -f
```

using the configured remote service name.

## Module handling

Modules are defined in `modules.txt`.

Each non-empty, non-comment line should use this format:

```text
module-name|git-url|branch
```

The script parses `modules.txt` once into memory before running sync, build, or deploy tasks.

This avoids a common shell scripting issue where commands like `rsync`, `ssh`, or `git` can accidentally consume stdin inside a `while read` loop, causing only the first module to be processed.

The script also validates that every configured module exists locally before building or deploying.

If a module is missing, the script fails fast instead of silently deploying an incomplete module set.

## Remote directory structure

The remote server is expected to use a layout similar to:

```text
/opt/azerothcore/
├── server/
│   ├── bin/
│   │   ├── authserver
│   │   └── worldserver
│   └── etc/
│       ├── authserver.conf
│       ├── worldserver.conf
│       └── modules/
│           ├── playerbots.conf
│           ├── mod_ahbot.conf
│           └── individualProgression.conf
├── source/
│   ├── data/
│   │   └── sql/
│   └── modules/
│       ├── mod-playerbots/
│       ├── mod-ah-bot/
│       └── mod-individual-progression/
└── backups/
```

The exact paths are controlled by `config.env`.

## Systemd services

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
