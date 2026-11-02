# battery-limit

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform: Linux laptops](https://img.shields.io/badge/platform-Linux%20laptops-lightgrey.svg)](#scope-and-non-goals)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](#requirements)

Set a battery charge limit on Linux laptops.

`battery-limit` is a small, dependency-free CLI that stops battery charging at a
chosen percentage (80% by default). It started as a Linux equivalent of
**MyASUS → Battery Health Charging** for ASUS TUF/ROG laptops, but it uses the
generic Linux `power_supply` interface, so it also works on other laptops when
their kernel driver exposes the same file.

It is **laptop-only by design**. Desktops, servers and other AC-powered machines
are rejected explicitly. Apple hardware is out of scope because macOS already
provides its own battery-health controls and Asahi Linux has its own
Apple-specific power stack.

No daemon, no extra packages, no patched kernel.

## Why

Lithium-ion batteries age faster when they sit at 100% for long periods,
especially while warm. If your laptop is plugged in most of the day, stopping at
80% can meaningfully extend the battery's useful life. The same feature has
been available in vendor tools for years; this project exposes it on Linux
through the standard kernel interface.

A charge limit is not a substitute for good thermal design, but it is one of the
few battery-health settings users can actually control.

## Features

- Uses the in-tree Linux `power_supply` interface — no proprietary software and
  no vendor daemon.
- Laptop-only guard based on the SMBIOS chassis type. Desktops and servers are
  refused before anything is written.
- Applies the limit immediately and re-applies it at every boot with a tiny
  systemd oneshot service.
- Plain Bash; works on any distribution that exposes the sysfs file.
- Human-readable `status` and JSON output for scripts.
- Verifies the value read back from sysfs and reports when the hardware rounds
  the requested limit to a supported value.
- Idempotent install and a clean uninstall that restores full charging.
- MIT licensed.

## Scope and non-goals

| Scope | Behaviour |
| --- | --- |
| **Linux laptops** | Supported when the kernel exposes `charge_control_end_threshold`. |
| **Desktops and servers** | **Rejected.** They run from AC power and usually have no battery to protect. |
| **Apple hardware** | **Out of scope.** macOS has built-in battery-health controls; Asahi Linux has Apple-specific drivers and tooling. |
| **Windows, macOS, BSD** | Not supported. This is a Linux `power_supply` interface. |
| **WSL, containers, virtual machines** | Not supported. There is no physical battery to limit. |
| **GUI** | Not included. The CLI and the boot service are the whole product. |
| **Fan curves, RGB, graphics modes** | Not included. Use `asusctl` for those on ASUS laptops. |
| **Charge start threshold** | Not included. This tool sets the stop threshold only. Use TLP if you need both. |
| **Vendor-specific interfaces** | Not included. See [compatibility](#compatibility). |

The chassis check reads `/sys/class/dmi/id/chassis_type` and rejects SMBIOS
types `3–7`, `13`, `15–29` and `33–36` (desktop, tower, all-in-one, server,
rack, blade, embedded, mini PC and similar form factors). It allows types `1`
(Other) and `2` (Unknown) because some laptops report them incorrectly, plus the
portable types `8`, `9`, `10`, `11`, `12`, `14`, `30`, `31` and `32`.

## Requirements

A laptop whose kernel exposes the standard charge threshold:

```bash
ls /sys/class/power_supply/*/charge_control_end_threshold
```

If that command prints a path, your hardware has the interface. You also need:

- Linux with the matching kernel driver (in-tree for most supported models).
- `bash`, `coreutils` and `sudo`.
- `systemd` only for boot persistence; the CLI itself works without it.

### Check your laptop

Run these commands before installing. They are read-only and safe:

```bash
# Chassis type: 8-12, 14, 30-32 are laptop-like; 3-7, 13, 15-29 and 33-36 are rejected.
cat /sys/class/dmi/id/chassis_type

# Vendor and model, useful when reporting compatibility.
cat /sys/class/dmi/id/sys_vendor
cat /sys/class/dmi/id/product_name

# Kernel version and driver information.
uname -r
ls /sys/class/power_supply/*/charge_control_end_threshold
```

If the last command prints nothing, this tool will not work on that machine.
See [compatibility](#compatibility) for alternatives.

## Install

```bash
git clone <repository-url> battery-limit
cd battery-limit
sudo ./install.sh
```

If you downloaded a release tarball instead, extract it and run
`sudo ./install.sh` from the extracted directory.

The installer checks the chassis type and the battery interface **before**
asking for a password. It then copies the CLI to
`/usr/local/bin/battery-limit`, creates `/etc/battery-limit.conf`, applies the
limit immediately, and enables `battery-limit.service` so the limit survives
reboots.

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

JSON output:

```bash
battery-limit status --json
```

```json
{"battery":"BAT0","capacity":79,"state":"Not charging","charge_limit":80,"saved_limit":80,"service":"enabled"}
```

## Choosing a limit

| Limit | Best for | Trade-off |
| --- | --- | --- |
| `100%` | Travel, long unplugged sessions | Most wear if kept plugged in |
| `80%` | Daily use, mostly plugged in | About 20% less unplugged runtime |
| `60%` | Laptop that stays on a desk | Roughly half the unplugged runtime |

`80%` is the best default for most people. You can change the limit at any time
without reinstalling. Some firmware only accepts a few discrete values, such as
40, 60, 80 or 100; the CLI reports the value the hardware actually accepted.

If your laptop's firmware already has a charge limit in the BIOS/UEFI setup, use
that instead. A firmware setting survives OS reinstalls and does not depend on a
service.

## Compatibility

Support depends on the laptop's firmware and kernel driver. The table below is
based on the Linux `power_supply` interface and the vendor notes maintained by
[TLP](https://linrunner.de/tlp/settings/bc-vendors.html).

| Vendor / family | Kernel interface | Status with this tool | Notes |
| --- | --- | --- | --- |
| ASUS TUF / ROG | `asus_wmi` (5.4+) | **Tested** | Tested on a TUF Gaming F15 FX507VV. Some models accept only 40/60/80. The EC may reset the threshold on power-on; the service restores it. |
| Lenovo ThinkPad | `thinkpad_acpi` | **Partial** | Exposes start and end thresholds. This tool sets only the end threshold; set the start threshold with TLP or manually. |
| Dell | `dell_laptop` (6.12+) | **Partial** | Recent kernels expose the interface in `charge_type=Custom` mode; the BIOS admin password must be disabled. TLP handles this setup; this tool does not. |
| LG Gram | `lg_laptop` (5.18+) | **Expected** | Only 80 or 100 is accepted. |
| MSI | `msi_ec` (6.3+) | **Model-dependent** | The driver accepts only specific models and BIOS versions. |
| System76 | `system76_acpi` (5.16+) | **Partial** | Exposes start and end thresholds; the start threshold may need manual adjustment. |
| Toshiba / Dynabook | `toshiba_acpi` (6.0+) | **Expected** | Only 80 or 100 is accepted. |
| Chromebooks / Framework | `cros_charge-control` (6.12+; Framework may need 6.17) | **Model-dependent** | Framework EC firmware and module options vary. |
| Tuxedo / Clevo | `clevo_acpi` (out-of-tree `tuxedo-drivers`) | **Model-dependent** | Discrete threshold values only. |
| Acer, HP, others | varies | **Check** | Run the `ls` command in [Requirements](#requirements). |

**Tested** means this project has been verified on that hardware. **Expected**
means the standard interface exists but this project has not been tested on that
family. **Partial** means some setup is missing. **Model-dependent** means support
varies by model and BIOS.

### Apple is out of scope

This project does not target Apple hardware:

- Recent macOS versions on Apple Silicon offer an 80% charge limit; older
  versions provide Optimized Battery Charging.
- Asahi Linux uses Apple-specific platform drivers and its own power-management
  tooling. It is not a generic `asus_wmi`/`thinkpad_acpi`-style target.
- Adding Apple support would mean depending on a vendor-specific stack for a
  feature Apple already ships.

If you use macOS or Asahi, use the battery controls provided by that platform.

### Vendor-specific interfaces not supported

These laptops expose a different sysfs interface, so `battery-limit` will not
find `charge_control_end_threshold`:

| Vendor / family | Interface | Recommended alternative |
| --- | --- | --- |
| Lenovo IdeaPad | `conservation_mode` | TLP |
| Huawei MateBook | `charge_control_thresholds` | TLP or vendor tooling |
| Samsung | `battery_life_extender` | TLP or vendor tooling |
| Sony VAIO | `battery_care_limiter` | TLP or vendor tooling |

The tool intentionally does not write to interfaces it does not understand.
Guessing at vendor-specific EC registers is a good way to brick a laptop.

If your laptop exposes the standard file but the limit does not work, open an
issue with:

```bash
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/chassis_type
uname -r
ls /sys/class/power_supply/*/charge_control*
```

## Linux support

The tool is distribution-agnostic: it only needs Bash, coreutils and sysfs.

- **systemd distributions** — Arch, Omarchy, Fedora, Ubuntu, Debian, openSUSE,
  Linux Mint, Pop!_OS, EndeavourOS, CachyOS, Manjaro, Gentoo and others: use the
  installer normally.
- **Non-systemd distributions** — Alpine, Void, Artix and others: install with
  `--no-service`, then run `battery-limit apply` from your init system or
  session autostart.
- **NixOS** — package the script and unit declaratively; `/usr/local` is not the
  right place. The CLI itself works when the sysfs interface exists.
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
`cros_charge-control`, and others.

`install.sh` stores the desired value in `/etc/battery-limit.conf`:

```ini
LIMIT=80
```

`battery-limit.service` runs `battery-limit apply` at boot and re-applies that
value. Some controllers remember the setting across reboots; others reset it on
power-on. The service covers both cases.

The service is a `oneshot` unit with `RemainAfterExit=yes`; it does not keep a
daemon running. There is nothing to monitor and no background process.

## Persistence

- The active limit usually survives suspend and normal reboots on its own.
- The systemd service re-applies the saved value at every boot.
- `battery-limit set N` updates both the hardware and
  `/etc/battery-limit.conf`, so the change is permanent.
- `battery-limit off` disables the limit but keeps the saved value; `on` brings
  it back.
- A full power loss, firmware reset or BIOS update can clear the EC setting. The
  service restores it on the next boot.

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
| `this machine reports SMBIOS chassis type ...` | The laptop-only guard rejected the machine. Desktops and servers are not supported. If a laptop is misreported by its firmware, see the FAQ. |
| `no battery with charge_control_end_threshold found` | Your model may not expose the interface. Run the `ls` command from [Requirements](#requirements), update the BIOS/kernel, or use TLP or a vendor tool. |
| `Requested 80%, but the hardware accepted 60%` | The firmware only supports discrete values. Use the value it accepted. |
| `Permission denied` when setting the limit | Run the command as root or with `sudo`. The installed service already runs as root. |
| The limit resets after unplugging the laptop | Some controllers lose the value after a full power loss. The service re-applies it at boot; check `systemctl status battery-limit.service`. |
| The battery stays above the limit | Expected. The controller pauses charging; it does not force the battery to discharge. Let it drop below the limit or unplug it for a while. |
| The service does not start | Inspect `systemctl status battery-limit.service` and `journalctl -u battery-limit.service`. |
| `systemctl` is not available | Reinstall with `--no-service`, then run `battery-limit apply` from your init system or autostart. |
| The limit does not survive a reboot | Check that the service is enabled: `systemctl is-enabled battery-limit.service`. |
| The installed command is outdated | Re-run `sudo ./install.sh` from the updated repository. |

## FAQ

### Is this ASUS-only?

No. It is ASUS-first because that is the hardware it was built and tested on,
but the detection is vendor-agnostic. Any laptop whose kernel driver exposes
`charge_control_end_threshold` can use it. See [compatibility](#compatibility).

### Why does it refuse to run on desktops and servers?

Because a desktop or server runs from AC power and has no battery to protect.
Writing a charge threshold to a machine that has no battery is pointless at
best. The chassis guard makes the limitation explicit instead of failing with a
confusing sysfs error.

### Does it work on desktops with a UPS battery?

No. A UPS is not a laptop battery, and `battery-limit` is not a UPS management
tool. The chassis guard rejects desktop form factors.

### Does it work on Apple Silicon Macs?

No. Apple is out of scope. macOS already provides built-in battery-health
controls, including an 80% limit on recent Apple Silicon models, and Asahi Linux
uses its own Apple-specific power stack. See
[Apple is out of scope](#apple-is-out-of-scope).

### Does it work on Windows, macOS or BSD?

No. This project writes a Linux `power_supply` sysfs interface. On Windows, use
MyASUS or the vendor's own utility. On macOS, use the built-in battery settings.

### Does it work in WSL, a container or a virtual machine?

No. Those environments do not expose a physical battery to the guest.

### Do I need `asusctl` or the ASUS daemon?

No. `battery-limit` writes the kernel interface directly. `asusctl` is a much
larger suite for fan curves, RGB, graphics modes and other ASUS features; it is
not required for the charge limit.

### Does it conflict with TLP?

Both tools can write the same `charge_control_end_threshold` file. Do not ask
both of them to manage the same limit, or the last writer wins. TLP is the better
choice on ThinkPad, Dell and System76 because it can manage the start and stop
thresholds together. Use `battery-limit` when you want a tiny tool that only
sets the stop threshold and re-applies it at boot.

### Why 80%?

80% is a good balance between battery longevity and usable runtime. It is also
the value most vendors use for their "battery care" mode. You can choose any
value from 40 to 100.

### Will the battery discharge to the limit when it is already above it?

No. The controller pauses charging; it does not force the battery to discharge.
If the battery is at 95% and you set 80%, it will stay at 95% until you unplug it
and it drops below 80%.

### Does the limit survive reboots?

Usually yes, but it depends on the embedded controller. Some controllers forget
the value after a full power loss or firmware reset. The systemd service
re-applies the saved value at every boot.

### Why did the hardware accept a different value?

Some firmware only supports discrete thresholds, such as 40, 60, 80 or 100.
The CLI reads the value back after writing and reports what the hardware
actually accepted.

### Does it support charge start thresholds?

No. It only sets the stop threshold. ThinkPad, Dell and System76 laptops often
expose both a start and an end threshold; use TLP if you need both.

### Does it support multiple batteries?

It uses the first `power_supply` device that exposes the interface. It does not
provide per-battery selection. Most laptops have a single battery; dual-battery
models are rare and may need manual handling.

### Is it safe?

It writes a standard kernel interface provided by your laptop's driver. It does
not patch the kernel, load out-of-tree modules, or touch EC registers directly.
It also refuses to run on non-laptop chassis types. Use it at your own risk and
keep a way to set the limit back to 100%.

### Does it work with Secure Boot?

Yes. It does not load a kernel module, sign anything, or modify the boot chain.
It only writes a sysfs file.

### Is it packaged in my distribution's repositories?

Not yet. Install it from source. An AUR package, Debian package or Nix flake
would be welcome contributions.

### My laptop reports a desktop chassis type. Can I override it?

Some firmware reports the wrong SMBIOS chassis type. You can override the
detection for a single command:

```bash
sudo BATTERY_LIMIT_CHASSIS=10 battery-limit set 80
```

For the installer:

```bash
sudo BATTERY_LIMIT_CHASSIS=10 ./install.sh
```

Use this only when you are sure the machine is a laptop. The override exists for
misreported firmware and for the test suite, not to bypass the laptop-only rule
on a real desktop.

## Who is this for?

- **ASUS TUF/ROG owners on Linux** who want the MyASUS battery-health feature
  without installing the full `asusctl` suite or a background daemon.
- **Owners of other laptops** whose kernel exposes the standard interface and
  who want a tiny CLI plus a boot-time service.
- **People who prefer explicit, auditable shell scripts** over a GUI extension or
  a large power-management stack.

It is not aimed at:

- Desktop and server users, who are rejected by design.
- Apple users, who already have platform-level battery controls.
- ThinkPad/Dell users who need start and stop thresholds managed together; TLP
  is the better tool there.
- Users who want a graphical interface; use the GNOME extension or your desktop's
  power panel.

### How common is this problem?

There are no reliable public numbers for "Linux users with a specific ASUS TUF
model", so any figure would be a guess. What is clear:

- The ASUS TUF/ROG Linux community is small but real, and battery-health charging
  is a recurring request.
- The standard `power_supply` interface is broader than ASUS; many vendors expose
  it through in-tree drivers.
- TLP maintains vendor-specific battery-care support for many laptop families,
  and there is at least one GNOME extension dedicated to charge limits. The
  problem is not imaginary.

This is a niche tool, not a mass-market product. Its goal is to be the lightest
option for ASUS-first users and a simple fallback for other laptops that expose
the interface.

## Alternatives

| Tool | Best for | Notes |
| --- | --- | --- |
| **BIOS/UEFI charge limit** | Any laptop that has one | Firmware-native, survives OS reinstalls. Check your firmware first. |
| **TLP** | Most laptop brands, especially ThinkPad/Dell/System76 | Mature, handles start and stop thresholds, large configuration surface. |
| **`asusctl`** | ASUS laptops | Full ASUS control suite: fan curves, RGB, graphics mode, charge limit. Runs a daemon. |
| **Battery Health Charging (GNOME extension)** | Graphical control on many brands | GUI extension; depends on GNOME. |
| **Vendor utilities** | Windows | MyASUS, Dell Power Manager, Lenovo Vantage, etc. Not Linux. |
| **Manual sysfs write** | One-off experiments | `echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold`. Does not persist. |
| **`battery-limit`** | ASUS-first, minimal Linux laptops | One job: set the stop threshold and keep it set. No daemon, no GUI. |

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
fixture through the `BATTERY_LIMIT_SYSFS`, `BATTERY_LIMIT_CONF` and
`BATTERY_LIMIT_CHASSIS` environment variables. The suite covers the normal
commands, invalid limits, non-`BAT*` device names, desktop rejection in the CLI
and installer, and unknown chassis types.

## Contributing

Issues and pull requests are welcome, especially reports from laptops not listed
as tested. Please run `make test` and `make lint` before submitting a PR.

When reporting compatibility, include:

```bash
cat /sys/class/dmi/id/sys_vendor
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/chassis_type
uname -r
ls /sys/class/power_supply/*/charge_control*
```

## License

[MIT](LICENSE)

## Disclaimer

This is an independent project and is not affiliated with ASUS, Lenovo, Dell,
Apple or any other vendor. It writes a standard kernel interface provided by
your laptop's driver. Use it at your own risk.
