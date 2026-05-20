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

## Logs

```bash
./bin/acore-manager logs-world
./bin/acore-manager logs-auth
./bin/acore-manager last-errors
```

`last-errors` filters recent logs for useful terms such as `ERROR`, `WARN`, `CRASH`, `DBUpdater`, `failed`, and `exception`.
