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
git clone https://github.com/AdamWTF/acore-manager.git /opt/acore-manager
cd /opt/acore-manager
```

## Bootstrap

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
