#!/usr/bin/env bash
#
# Uninstall battery-limit and restore full charging.

set -euo pipefail

if (( EUID != 0 )); then
  exec sudo -- "$0" "$@"
fi

systemctl disable --now battery-limit.service 2>/dev/null || true
rm -f /etc/systemd/system/battery-limit.service
rm -f /usr/local/bin/battery-limit
rm -f /etc/battery-limit.conf
systemctl daemon-reload 2>/dev/null || true

shopt -s nullglob
for file in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
  printf '100\n' > "$file"
done
shopt -u nullglob

printf 'battery-limit removed. The battery will charge to 100%% again.\n'
