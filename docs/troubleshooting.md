# Troubleshooting

For the complete first-server flow, including data files, configs, databases, services, firewall, and client connection, see [Full Server Setup](full-server-setup.md).

## Validate First

```bash
./bin/acore-manager validate
```

Fix missing commands, config values, or path issues reported by validation before running builds or release switches.

## Script Permission Denied

If a script fails with `Permission denied`, fix executable bits:

```bash
sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh
```

Or:

```bash
sudo find /opt/acore-manager/scripts -type f -name "*.sh" -exec chmod +x {} \;
sudo chmod +x /opt/acore-manager/bin/acore-manager 2>/dev/null || true
```

## MySQL Connection Fails

Check `config/local/db.conf`:

```bash
MYSQL_HOST="<mysql-host>"
MYSQL_PORT="3306"
MYSQL_USER="<mysql-user>"
MYSQL_PASSWORD="<mysql-password>"
```

For remote MySQL, confirm the host is reachable from the server running `acore-manager`. For SSH tunnels, `MYSQL_HOST="127.0.0.1"` is common.

Run:

```bash
./bin/acore-manager db-check
```

## Services Do Not Start

Check status and logs:

```bash
./bin/acore-manager status
./bin/acore-manager logs-auth
./bin/acore-manager logs-world
./bin/acore-manager last-errors
```

Confirm `CURRENT_LINK` points at a release containing:

```text
bin/authserver
bin/worldserver
```

Confirm systemd templates match your configured user, group, and install root.

Also confirm client data exists:

```text
/opt/acore-manager/shared/data/dbc
/opt/acore-manager/shared/data/maps
/opt/acore-manager/shared/data/vmaps
/opt/acore-manager/shared/data/mmaps
```

and that `authserver.conf` and `worldserver.conf` have been prepared from the release `.conf.dist` files.

## Client Cannot Connect

Check the client realmlist, firewall, and ports:

```bash
ss -ltnp | grep -E '3724|8085'
```

If login works but the realm or character list hangs, check the realm address in the auth database, worldserver port reachability, and both service logs.

## Build Fails

Update source and modules before building:

```bash
./bin/acore-manager update-source
./bin/acore-manager update-modules
./bin/acore-manager build
```

If dependencies are missing on Ubuntu/Debian, rerun:

```bash
sudo ./scripts/setup/acore-bootstrap.sh
```

## Build Fails In Jemalloc With GCC 15

Symptom:

```text
deps/jemalloc/src/safety_check.c
error: conflicting types for 'je_safety_check_set_abort'
```

This is a compiler/dependency compatibility issue between GCC 15 and AzerothCore's bundled jemalloc, not an `acore-manager` workflow problem.

Workaround:

```bash
echo 'CMAKE_EXTRA_FLAGS="-DNOJEM=1"' | sudo tee -a config/local/manager.conf
./bin/acore-manager build
```

`NOJEM` disables jemalloc. Treat this as a local workaround, not a universal default.

## Release Switch Fails

List releases:

```bash
./bin/acore-manager list-releases
```

Switch only to a release directory that exists under `RELEASES_DIR` and contains executable server binaries.

## Config Diff Has No Output

`config-diff` needs `.dist` files under:

```text
CURRENT_LINK/etc
```

and live configs under:

```text
CONFIG_DIR
```

Run:

```bash
./bin/acore-manager config-diff
```
