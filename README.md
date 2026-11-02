# battery-limit

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](#requirements)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](#requirements)

A small, dependency-free CLI that sets a battery charge limit on ASUS laptops
running Linux. It is the Linux equivalent of **MyASUS → Battery Health
Charging** on Windows: it tells the embedded controller to stop charging at 80%
and hold the battery there.

No daemon, no extra packages, no patched kernel.

## Why

Lithium-ion batteries age faster when they sit at 100% for long periods,
especially while warm. If your laptop is plugged in most of the day, stopping at
80% can meaningfully extend the battery's useful life. The same feature has
been available in MyASUS for years; this project exposes it on Linux through the
standard kernel interface.

## Features

- Uses the in-tree `asus-wmi` driver — no proprietary software and no `asusctl`
  daemon.
- Applies the limit immediately and re-applies it at every boot with a tiny
  systemd oneshot service.
- Plain Bash; works on any distribution that exposes the sysfs file.
- Human-readable `status` and JSON output for scripts.
- Idempotent install and a clean uninstall that restores full charging.
- MIT licensed.

## Requirements

- An ASUS TUF/ROG laptop whose embedded controller exposes the charge
  threshold. Check with:

  ```bash
  ls /sys/class/power_supply/BAT*/charge_control_end_threshold
  ```

  If that file exists, the hardware is supported.

- Linux with the in-tree `asus-wmi` driver (tested on kernel 7.2).
- `bash`, `coreutils` and `sudo`.
- `systemd` only for boot persistence; the CLI itself works without it.

## Install

```bash
git clone <repository-url> battery-limit
cd battery-limit
sudo ./install.sh
```

If you downloaded a release tarball instead, extract it and run
`sudo ./install.sh` from the extracted directory.

The installer copies the CLI to `/usr/local/bin/battery-limit`, creates
`/etc/battery-limit.conf`, applies the limit immediately, and enables
`battery-limit.service` so the limit survives reboots.

### Install options

| Option | Description |
| --- | --- |
| `--limit N` | Initial charge limit, 40–100 (default: `80`) |
| `--no-service` | Apply the limit now but do not install the systemd service |
| `-h`, `--help` | Show usage |

```bash
sudo ./install.sh --limit 60
sudo ./install.sh --limit 80 --no-service
```

## Usage

| Command | Description |
| --- | --- |
| `battery-limit status` | Show battery state, active limit, saved limit and service |
| `battery-limit status --json` | Same data as machine-readable JSON |
| `battery-limit get` | Print the active limit as a number (for scripts) |
| `battery-limit set <40-100>` | Set and persist a new limit |
| `battery-limit on` | Apply the saved limit |
| `battery-limit off` | Disable the limit (charge to 100%) |
| `battery-limit toggle` | Switch between the saved limit and 100% |
| `battery-limit apply` | Apply the saved limit (used by the service) |
| `battery-limit version` | Print the version |

`status`, `get`, `help` and `version` do not need root. Commands that change the
limit re-run themselves through `sudo` automatically.

### Examples

```bash
# Check the current state
battery-limit status

# Stop charging at 80% (recommended for daily use)
battery-limit set 80

# Maximum lifespan mode for a laptop that lives on a desk
battery-limit set 60

# Charge to 100% before a trip
battery-limit off

# Go back to the saved limit afterwards
battery-limit on
```

Example output:

```text
Battery:       BAT0
Charge:        79% (Not charging)
Charge limit:  80% (holding at 80%)
Saved limit:   80%
Service:       enabled
```

## Choosing a limit

| Limit | Best for | Trade-off |
| --- | --- | --- |
| `100%` | Travel, long unplugged sessions | Most wear if kept plugged in |
| `80%` | Daily use, mostly plugged in | About 20% less unplugged runtime |
| `60%` | Laptop that stays on a desk | Roughly half the unplugged runtime |

`80%` is the best default for most people. You can change the limit at any time
without reinstalling.

## How it works

The Linux `asus-wmi` driver exposes the embedded controller's charge threshold
through the standard `power_supply` class:

```text
/sys/class/power_supply/BAT0/charge_control_end_threshold
```

Writing `80` tells the controller to stop charging when the battery reaches
80%. Writing `100` removes the limit. This is the same interface used by
`asusctl` and by desktop power panels.

`install.sh` stores the desired value in `/etc/battery-limit.conf`:

```ini
LIMIT=80
```

`battery-limit.service` runs `battery-limit apply` at boot and re-applies that
value. The controller normally remembers the setting across reboots; the
service is there to restore it after a full power loss or firmware reset.

## Persistence

- The active limit survives suspend and normal reboots on its own.
- The systemd service re-applies the saved value at every boot.
- `battery-limit set N` updates both the hardware and
  `/etc/battery-limit.conf`, so the change is permanent.
- `battery-limit off` disables the limit but keeps the saved value; `on` brings
  it back.

## Desktop integration

Because this uses the standard `power_supply` interface, UPower-based panels
(GNOME, KDE, Omarchy, Waybar, and others) automatically show the limit state.
No extension or plugin is needed. In Omarchy, for example, the power panel shows
`Charge limit: 80%` and `Battery state: Holding` while the limit is active.

## Uninstall

```bash
cd battery-limit
sudo ./uninstall.sh
```

This disables and removes the service, deletes the CLI and config, and sets the
charge limit back to 100%.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| `no battery with charge_control_end_threshold found` | Your model may not expose the interface. Check the `ls` command above, update the BIOS/kernel, or use `asusctl` if it supports your model. |
| `Permission denied` when setting the limit | Run the command as root or with `sudo`. The installed service already runs as root. |
| The limit resets after unplugging the laptop | Some controllers lose the value after a full power loss. The service re-applies it at boot; check `systemctl status battery-limit.service`. |
| The battery stays above the limit | Expected. The controller pauses charging; it does not force the battery to discharge. Let it drop below the limit or unplug it for a while. |
| The service does not start | Inspect `systemctl status battery-limit.service` and `journalctl -u battery-limit.service`. |
| `systemctl` is not available | Reinstall with `--no-service`, then run `battery-limit apply` from your init system or autostart. |

## Compatibility

- **Tested on:** ASUS TUF Gaming F15 FX507VV (2023), Omarchy/Arch, Linux 7.2.
- **Expected to work on:** most recent ASUS TUF/ROG laptops that expose
  `charge_control_end_threshold`.
- **Not supported:** non-ASUS laptops and Windows.

If you test it on another model, please open an issue with your model name
(`cat /sys/class/dmi/id/product_name`) and kernel version.

## Repository layout

```text
bin/battery-limit              CLI
systemd/battery-limit.service  Boot-time service
install.sh                     Installer
uninstall.sh                   Uninstaller
tests/run-tests.sh             Test suite (uses a temporary sysfs fixture)
```

## Development

```bash
make test    # run the test suite
make lint    # run shellcheck
```

The tests never touch the real battery: they point the CLI at a temporary
fixture through the `BATTERY_LIMIT_SYSFS` and `BATTERY_LIMIT_CONF` environment
variables.

## Related projects

- [asusctl](https://gitlab.com/asus-linux/asusctl) — full ASUS control suite
  (fan curves, keyboard lighting, graphics mode, and more).
- [TLP](https://linrunner.de/tlp/) — general Linux power management.

This project intentionally does one thing: set the charge limit and keep it
set.

## Contributing

Issues and pull requests are welcome, especially reports from other ASUS models.
Please run `make test` and `make lint` before submitting a PR.

## License

[MIT](LICENSE)

## Disclaimer

This is an independent project and is not affiliated with ASUS. It writes a
standard kernel interface provided by the `asus-wmi` driver. Use it at your own
risk.
