# Pi install layout

Pi runs as a managed install, not an npm global package. A managed install keeps a pinned dependency tree per release, and `pi update` replaces releases atomically, so an interrupted update never leaves a half-installed tree behind. This page records where the pieces sit on this machine and which one is the entrypoint.

## Where things live

| Path | What it is |
| --- | --- |
| `~/.local/install` | Managed root: `releases/<version>/`, `current-version`, `managed-install.json` |
| `~/.local/bin/pi` | Managed launcher, the only executable that runs a release |
| `~/bin/pi` | Account shim, the `pi` on PATH |
| `~/.pi/agent` | Work Profile config dir |
| `~/.pi-personal/agent` | Personal Profile config dir |
| `~/.pi/agent/bin` | `fd` and `rg`, downloaded by pi on demand |

## Entrypoint

`~/bin/pi` is the only `pi` reachable by name. It selects a Profile from the working directory, sets the matching config dir, and execs the launcher by absolute path. The launcher reads `current-version`, runs that release, and exports `PI_MANAGED_INSTALL_ROOT` so `pi update` knows which installation it is updating.

`~/.local/bin` stays off PATH. The launcher is reachable only through the shim, so nothing can resolve `pi` past the Profile routing.

The managed root sits outside both agent dirs. `~/.pi-personal/agent/bin` links to `~/.pi/agent/bin` so the two Profiles share `fd` and `rg`. Keeping the launcher out of that directory means the link can never expose it under a second path.

## Updates

`pi update` stages the next release, verifies it, and activates it by rewriting `current-version`. The release it replaced stays in `releases/` until the update after that.

Nothing else installs or upgrades Pi. The bootstrap in `scripts/setup-hosts.sh` links configuration into the two agent dirs and stops there. See the Pi section of the [README](../README.md) for the link map and the per-Profile settings.
