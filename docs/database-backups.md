# Database Backups

Database helpers read MySQL settings from manager config and optional ignored DB config.

Create local DB config:

```bash
cp config/defaults/db.conf.example config/local/db.conf
```

Example values:

```bash
MYSQL_HOST="<mysql-host>"
MYSQL_PORT="3306"
MYSQL_USER="<mysql-user>"
MYSQL_PASSWORD="<mysql-password>"
```

Do not commit real credentials.

## Check Connection

```bash
./bin/acore-manager db-check
```

This checks the MySQL client, connection, server version, and configured auth/world/characters databases.

## Back Up Databases

```bash
./bin/acore-manager db-backup
```

Backups are written under:

```text
BACKUP_DIR/db/YYYY-MM-DD-HHMM/
```

The script backs up the configured auth, world, and characters databases with `mysqldump` and writes a short `backup-manifest.txt`.

The backup script does not restore, delete, or modify live data.
