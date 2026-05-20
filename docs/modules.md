# Modules

Modules are configured with a simple pipe-delimited file:

```text
module-name|git-url|branch
```

The module update script reads:

1. `config/local/modules.txt` if it exists
2. otherwise `config/defaults/modules.txt.example`

Create a local module list:

```bash
cp config/defaults/modules.txt.example config/local/modules.txt
```

Example entry:

```text
mod-example|https://github.com/example/mod-example.git|master
```

Blank lines and comments are ignored.

## Update Modules

```bash
./bin/acore-manager update-modules
```

The script clones missing modules into `MODULES_DIR`, fetches and pulls existing module repositories, and prints each module commit hash.

If `MODULES_DIR` contains directories not listed in the module file, the script warns only. It does not delete modules.
