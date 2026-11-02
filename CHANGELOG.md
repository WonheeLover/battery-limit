# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-02

### Added

- `battery-limit` CLI with `status`, `get`, `set`, `on`, `off`, `toggle`,
  `apply`, `version` and `help` commands.
- Human-readable and JSON status output.
- Persistent configuration in `/etc/battery-limit.conf`.
- `battery-limit.service` systemd oneshot unit that re-applies the limit at
  boot.
- Installer with `--limit` and `--no-service` options.
- Uninstaller that restores charging to 100%.
- Test suite using a temporary sysfs fixture.
