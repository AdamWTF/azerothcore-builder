# OliveTin

OliveTin integration is optional. `acore-manager` does not require or install OliveTin.

An example config is provided at:

```text
olivetin/config.yaml.example
```

It exposes common actions as web buttons by calling the CLI wrapper:

```text
/opt/acore-manager/bin/acore-manager
```

Actions include status, start, stop, restart, logs, last errors, database backup, build latest release, list releases, and rollback.

If your install path differs, adjust the command path in the OliveTin config after copying it into your OliveTin setup.

Review permissions carefully before exposing service control or backup actions through a web UI.
