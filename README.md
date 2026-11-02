# battery-limit

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](#linux-support)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](#requirements)

Set a battery charge limit on Linux laptops.

A small, dependency-free CLI that stops battery charging at a chosen percentage.
It started as a Linux equivalent of **MyASUS → Battery Health Charging** for ASUS
laptops, but it uses the generic Linux `power_supply` interface and works on many
other brands when their kernel driver exposes the same file.

No daemon, no extra packages, no patched kernel.

## Why

Lithium-ion batteries age faster when they sit at 100% for long periods,
especially while warm. If your laptop is plugged in most of the day, stopping at
80% can meaningfully extend the battery's useful life. The same feature has
been available in vendor tools for years; this project exposes it on Linux
through the standard kernel interface.

## Features

- Uses the in-tree Linux `power_supply` interface — no proprietary software and
  no vendor daemon.
- Applies the limit immediately and re-applies it at every boot with a tiny
  systemd oneshot service.
- Plain Bash; works on any distribution that exposes the sysfs file.
- Human-readable `status` and JSON output for scripts.
- Verifies the value read back from sysfs and reports when the hardware rounds
  the requested limit to a supported value.
- Idempotent install and a clean uninstall that restores full charging.
- MIT licensed.

## Requirements

A laptop whose kernel exposes the standard charge threshold:

```bash
ls /sys/class/power_supply/*/charge_control_end_threshold
```

If that command prints a path, your hardware has the interface. You also need:

- Linux with the matching kernel driver (in-tree for most supported models).
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

## Compatibility

Support depends on the laptop's firmware and kernel driver. The table below is
based on the Linux `power_supply` interface and the vendor notes maintained by
[TLP](https://linrunner.de/tlp/settings/bc-vendors.html).

| Vendor / family | Kernel interface | Status with this tool | Notes |
| --- | --- | --- | --- |
| ASUS TUF / ROG | `asus_wmi` (5.4+) | **Tested** | Tested on a TUF Gaming F15 FX507VV. Some models accept only 40/60/80. The EC resets the threshold on power-on; the service restores it. |
| Lenovo ThinkPad | `thinkpad_acpi` | **Partial** | Exposes start and end thresholds. This tool sets only the end threshold; set the start threshold with TLP or manually. |
| Dell | `dell_laptop` (6.12+) | **Partial** | Requires `charge_type=Custom` and no BIOS admin password. TLP handles this setup; this tool does not. |
| LG Gram | `lg_laptop` (5.18+) | **Expected** | Only 80 or 100 is accepted. |
| MSI | `msi_ec` (6.3+) | **Model-dependent** | The driver accepts only specific models and BIOS versions. |
| System76 | `system76_acpi` (5.16+) | **Partial** | Exposes start and end thresholds; the start threshold may need manual adjustment. |
| Toshiba / Dynabook | `toshiba_acpi` (6.0+) | **Expected** | Only 80 or 100 is accepted. |
| Chromebooks / Framework | `cros_charge-control` (6.12+; Framework may need 6.17) | **Model-dependent** | Framework EC firmware and module options vary. |
| Apple Silicon (Asahi) | `macsmc_power` (6.3+) | **Expected** | Battery device is `macsmc-battery`; only 80 or 100 is accepted. |
| Tuxedo / Clevo | `clevo_acpi` (out-of-tree `tuxedo-drivers`) | **Model-dependent** | Discrete threshold values only. |
| Lenovo IdeaPad | `conservation_mode` | **Not supported** | Uses a vendor-specific file instead of the standard interface. |
| Huawei MateBook | `charge_control_thresholds` | **Not supported** | Uses a different sysfs path. |
| Samsung | `battery_life_extender` | **Not supported** | Vendor-specific sysfs. |
| Sony VAIO | `battery_care_limiter` | **Not supported** | Vendor-specific sysfs. |
| Acer, HP, others | varies | **Check** | Run the `ls` command in [Requirements](#requirements). |

**Tested** means this project has been verified on that hardware. **Expected**
means the standard interface exists but this project has not been tested on that
family. **Partial** means some setup is missing. **Model-dependent** means support
varies by model and BIOS.

If your laptop exposes the file but the limit does not work, open an issue with:

```bash
cat /sys/class/dmi/id/product_name
uname -r
ls /sys/class/power_supply/*/charge_control*
```

## Linux support

The tool is distribution-agnostic: it only needs Bash, coreutils and sysfs.

- **systemd distributions** — Arch, Omarchy, Fedora, Ubuntu, Debian, openSUSE,
  Linux Mint, Pop!_OS, EndeavourOS, CachyOS, Manjaro and others: use the
  installer normally.
- **Non-systemd distributions** — Alpine, Void, Artix and others: install with
  `--no-service`, then run `battery-limit apply` from your init system or
  session autostart.
- **NixOS** — package the script and unit declaratively; `/usr/local` is not the
  right place.
- **Windows, macOS, BSD** — not supported; this is a Linux `power_supply`
  interface.
- **WSL, containers, virtual machines** — no physical battery, so there is
  nothing to limit.

This project is not packaged in distribution repositories yet. On Arch and
Omarchy, install it from source with the steps above. An AUR package would be a
welcome contribution.

## How it works

The Linux kernel exposes the embedded controller's charge threshold through the
standard `power_supply` class:

```text
/sys/class/power_supply/BAT0/charge_control_end_threshold
```

Writing `80` tells the controller to stop charging when the battery reaches
80%. Writing `100` removes the limit. This is the same interface used by TLP,
`asusctl` and many desktop power panels.

The exact driver depends on the laptop: `asus_wmi`, `thinkpad_acpi`,
`dell_laptop`, `lg_laptop`, `msi_ec`, `system76_acpi`, `toshiba_acpi`,
`cros_charge-control`, `macsmc_power`, and others.

`install.sh` stores the desired value in `/etc/battery-limit.conf`:

```ini
LIMIT=80
```

`battery-limit.service` runs `battery-limit apply` at boot and re-applies that
value. Some controllers remember the setting across reboots; others reset it on
power-on. The service covers both cases.

## Persistence

- The active limit usually survives suspend and normal reboots on its own.
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
| `no battery with charge_control_end_threshold found` | Your model may not expose the interface. Run the `ls` command from [Requirements](#requirements), update the BIOS/kernel, or use TLP or a vendor tool. |
| `Requested 80%, but the hardware accepted 60%` | The firmware only supports discrete values. Use the value it accepted. |
| `Permission denied` when setting the limit | Run the command as root or with `sudo`. The installed service already runs as root. |
| The limit resets after unplugging the laptop | Some controllers lose the value after a full power loss. The service re-applies it at boot; check `systemctl status battery-limit.service`. |
| The battery stays above the limit | Expected. The controller pauses charging; it does not force the battery to discharge. Let it drop below the limit or unplug it for a while. |
| The service does not start | Inspect `systemctl status battery-limit.service` and `journalctl -u battery-limit.service`. |
| `systemctl` is not available | Reinstall with `--no-service`, then run `battery-limit apply` from your init system or autostart. |

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

- [TLP](https://linrunner.de/tlp/) — mature power management with battery charge
  thresholds for many vendors, including start and stop thresholds.
- [asusctl](https://gitlab.com/asus-linux/asusctl) — ASUS control suite (fan
  curves, keyboard lighting, graphics mode, and more).
- [Battery Health Charging](https://github.com/maniacx/Battery-Health-Charging)
  — GNOME extension with a graphical charge-limit interface for many brands.

This project intentionally does one thing: set the stop threshold and keep it
set.

## Contributing

Issues and pull requests are welcome, especially reports from laptops not listed
as tested. Please run `make test` and `make lint` before submitting a PR.

## License

[MIT](LICENSE)

## Disclaimer

This is an independent project and is not affiliated with ASUS or any other
vendor. It writes a standard kernel interface provided by your laptop's driver.
Use it at your own risk.
