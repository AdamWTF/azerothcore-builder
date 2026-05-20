# Install

`acore-manager` is designed to run on a Linux host that will build and operate an AzerothCore server. The default install root is:

```text
/opt/acore-manager
```

## Clone

Clone the repository where you want to manage it. If you use the default root:

```bash
sudo mkdir -p /opt/acore-manager
sudo chown "$USER":"$USER" /opt/acore-manager
git clone <repository-url> /opt/acore-manager
cd /opt/acore-manager
```

## Bootstrap

Ensure executable permissions are present before the first direct script run:

```bash
find scripts -type f -name "*.sh" -exec chmod +x {} \;
chmod +x bin/acore-manager 2>/dev/null || true
```

Run the bootstrap script:

```bash
sudo ./scripts/setup/acore-bootstrap.sh
```

The bootstrap script:

- installs typical Ubuntu/Debian build dependencies
- creates the configured `ACORE_USER` and `ACORE_GROUP` if missing
- creates standard directories under `/opt/acore-manager`
- copies default config examples into `config/local/` only when missing
- installs systemd service templates without overwriting existing service files unless `--force` is used

To overwrite installed service templates:

```bash
sudo ./scripts/setup/acore-bootstrap.sh --force
```

The bootstrap does not build AzerothCore and does not start or enable services.

## Permission Denied Recovery

If a copied checkout loses executable bits and a script fails with `Permission denied`, run:

```bash
sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh
```

Or use standard shell commands:

```bash
sudo find /opt/acore-manager/scripts -type f -name "*.sh" -exec chmod +x {} \;
sudo chmod +x /opt/acore-manager/bin/acore-manager 2>/dev/null || true
```

If you manage the host remotely, confirm shell access before running host setup:

```bash
ssh <server-host>
```

## Verify

After bootstrap:

```bash
./bin/acore-manager validate
./bin/acore-manager status
```

If `bin/acore-manager` is added to your `PATH`, you can run `acore-manager` from anywhere.
