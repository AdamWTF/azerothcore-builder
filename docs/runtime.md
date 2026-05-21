# Runtime

Runtime scripts use configured systemd service names:

```bash
AUTH_SERVICE="azerothcore-auth.service"
WORLD_SERVICE="azerothcore-world.service"
```

The service templates in `systemd/` point at:

```text
/opt/acore-manager/current/bin/authserver
/opt/acore-manager/current/bin/worldserver
```

Bootstrap installs these templates when possible, but does not enable or start them. If needed, install them manually:

```bash
sudo cp systemd/azerothcore-auth.service /etc/systemd/system/azerothcore-auth.service
sudo cp systemd/azerothcore-world.service /etc/systemd/system/azerothcore-world.service
sudo systemctl daemon-reload
sudo systemctl enable azerothcore-auth.service
sudo systemctl enable azerothcore-world.service
```

Prepare databases, data files, and configs before starting services. See [Full Server Setup](full-server-setup.md).

## Status

```bash
./bin/acore-manager status
```

Shows active release, service status, common ports, disk usage, memory usage, and source commit information.

## Service Control

```bash
./bin/acore-manager start
./bin/acore-manager stop
./bin/acore-manager restart
./bin/acore-manager restart-world
./bin/acore-manager restart-auth
```

Full restart order is:

1. stop world
2. stop auth
3. start auth
4. start world

Direct systemd equivalents:

```bash
sudo systemctl start azerothcore-auth.service
sudo systemctl start azerothcore-world.service
sudo systemctl stop azerothcore-world.service
sudo systemctl stop azerothcore-auth.service
systemctl status azerothcore-auth.service --no-pager
systemctl status azerothcore-world.service --no-pager
```

Recommended startup order is database first, then authserver, then worldserver, then client login testing.

## Logs

```bash
./bin/acore-manager logs-world
./bin/acore-manager logs-auth
./bin/acore-manager last-errors
```

`last-errors` filters recent logs for useful terms such as `ERROR`, `WARN`, `CRASH`, `DBUpdater`, `failed`, and `exception`.

Direct journal checks:

```bash
journalctl -u azerothcore-auth.service -n 100 --no-pager
journalctl -u azerothcore-world.service -n 100 --no-pager
```

## Ports

Common AzerothCore ports:

```text
3724  authserver
8085  worldserver
```

Check listeners:

```bash
ss -ltnp | grep -E '3724|8085'
```

## Common Runtime Failures

- Missing `/opt/acore-manager/current`: create and switch to a release.
- Missing data files: copy `dbc`, `maps`, `vmaps`, and `mmaps` into `/opt/acore-manager/shared/data`.
- Missing configs: prepare `authserver.conf` and `worldserver.conf` from release `.conf.dist` files.
- DB failures: run `./bin/acore-manager db-check` and check credentials in `config/local/db.conf`.
- Client cannot connect: check realmlist, firewall, auth port `3724`, world port `8085`, and service logs.

See [Command Reference](commands.md) for all wrapper commands.
