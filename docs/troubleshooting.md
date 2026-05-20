# Troubleshooting

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
