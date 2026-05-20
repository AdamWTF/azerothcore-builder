# Acore Manager

`acore-manager` is a reusable Linux server manager for AzerothCore. It provides small shell tools for updating source and modules, building staged server files, creating timestamped releases, switching or rolling back releases, managing systemd services, viewing logs, and backing up configuration and databases.

It is for server operators who want a simple, scriptable workflow around an AzerothCore Linux host without baking private paths, module packs, or credentials into the repository.

Default install root:

```text
/opt/acore-manager
```

## Quick Start

Clone the repository on the Linux host, then run the bootstrap:

```bash
find scripts -type f -name "*.sh" -exec chmod +x {} \;
chmod +x bin/acore-manager 2>/dev/null || true
sudo ./scripts/setup/acore-bootstrap.sh
```

Review or create local configuration:

```bash
config/local/manager.conf
config/local/modules.txt
config/local/db.conf        # optional, for DB checks and backups
```

Use the CLI wrapper for common actions:

```bash
./bin/acore-manager validate
./bin/acore-manager update-source
./bin/acore-manager update-modules
./bin/acore-manager build
./bin/acore-manager create-release
./bin/acore-manager list-releases
```

After a release exists, switch to it:

```bash
./bin/acore-manager switch-release <release-name>
```

## Documentation

- [Install](docs/install.md)
- [Configuration](docs/configuration.md)
- [Modules](docs/modules.md)
- [Build and Release](docs/build-and-release.md)
- [Runtime](docs/runtime.md)
- [Rollback](docs/rollback.md)
- [Database Backups](docs/database-backups.md)
- [OliveTin](docs/olivetin.md)
- [Troubleshooting](docs/troubleshooting.md)

If a script fails with `Permission denied`, run:

```bash
sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh
```
