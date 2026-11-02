#!/usr/bin/env bash
#
# Install battery-limit.
#
# Usage:
#   sudo ./install.sh [--limit N] [--no-service]

set -euo pipefail

readonly DEFAULT_LIMIT=80
readonly MIN_LIMIT=40
readonly MAX_LIMIT=100
readonly PREFIX="/usr/local"
readonly CHASSIS_FILE="/sys/class/dmi/id/chassis_type"

die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

# Human-readable name for the SMBIOS chassis types rejected by this tool.
chassis_label() {
  case $1 in
    3) printf 'Desktop' ;;
    4) printf 'Low Profile Desktop' ;;
    5) printf 'Pizza Box' ;;
    6) printf 'Mini Tower' ;;
    7) printf 'Tower' ;;
    13) printf 'All-in-One' ;;
    15) printf 'Space-saving' ;;
    16) printf 'Lunch Box' ;;
    17) printf 'Main Server Chassis' ;;
    18) printf 'Expansion Chassis' ;;
    19) printf 'SubChassis' ;;
    20) printf 'Bus Expansion Chassis' ;;
    21) printf 'Peripheral Chassis' ;;
    22) printf 'RAID Chassis' ;;
    23) printf 'Rack Mount Chassis' ;;
    24) printf 'Sealed-case PC' ;;
    25) printf 'Multi-system Chassis' ;;
    26) printf 'Compact PCI' ;;
    27) printf 'Advanced TCA' ;;
    28) printf 'Blade' ;;
    29) printf 'Blade Enclosure' ;;
    33) printf 'IoT Gateway' ;;
    34) printf 'Embedded PC' ;;
    35) printf 'Mini PC' ;;
    36) printf 'Stick PC' ;;
    *) printf 'unknown' ;;
  esac
}

# Refuse to install on desktops, servers and other AC-powered form factors.
require_laptop() {
  local type=${BATTERY_LIMIT_CHASSIS:-}

  if [[ -z $type ]]; then
    type=$(cat "$CHASSIS_FILE" 2>/dev/null || true)
  fi

  [[ $type =~ ^[0-9]+$ ]] || return 0

  case $type in
    3|4|5|6|7|13|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|33|34|35|36)
      die "this machine reports SMBIOS chassis type $type ($(chassis_label "$type")), which is not a laptop. battery-limit only runs on laptops; desktops and servers use AC power and do not need a charge limit."
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: sudo ./install.sh [options]

Options:
  --limit N       Initial charge limit, 40-100 (default: 80)
  --no-service    Apply the limit now but do not install the systemd service
  -h, --help      Show this help

Examples:
  sudo ./install.sh
  sudo ./install.sh --limit 60
  sudo ./install.sh --limit 80 --no-service
EOF
}

original_args=("$@")
limit=""
install_service=true

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    --limit)
      [[ $# -ge 2 ]] || die "--limit needs a value"
      limit=$2
      shift 2
      ;;
    --limit=*)
      limit=${1#*=}
      shift
      ;;
    --no-service)
      install_service=false
      shift
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if [[ -n $limit ]]; then
  [[ $limit =~ ^[0-9]+$ ]] ||
    die "limit must be a number between $MIN_LIMIT and $MAX_LIMIT"
  (( limit >= MIN_LIMIT && limit <= MAX_LIMIT )) ||
    die "limit must be between $MIN_LIMIT and $MAX_LIMIT"
fi

# Check the hardware before asking for a password. Both files are readable by
# unprivileged users.
require_laptop

shopt -s nullglob
batteries=(/sys/class/power_supply/*/charge_control_end_threshold)
shopt -u nullglob

(( ${#batteries[@]} > 0 )) ||
  die "no compatible battery found. Your laptop does not expose charge_control_end_threshold; see the compatibility section in README.md."

if (( EUID != 0 )); then
  if [[ -n ${BATTERY_LIMIT_CHASSIS:-} ]]; then
    exec sudo -- env BATTERY_LIMIT_CHASSIS="$BATTERY_LIMIT_CHASSIS" "$0" "${original_args[@]}"
  fi
  exec sudo -- "$0" "${original_args[@]}"
fi

src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f "$src/bin/battery-limit" ]] || die "bin/battery-limit not found next to install.sh"

install -Dm755 "$src/bin/battery-limit" "$PREFIX/bin/battery-limit"

if [[ -n $limit ]]; then
  printf 'LIMIT=%s\n' "$limit" > /etc/battery-limit.conf
  chmod 0644 /etc/battery-limit.conf
elif [[ ! -f /etc/battery-limit.conf ]]; then
  printf 'LIMIT=%s\n' "$DEFAULT_LIMIT" > /etc/battery-limit.conf
  chmod 0644 /etc/battery-limit.conf
fi

"$PREFIX/bin/battery-limit" apply

if $install_service; then
  if command -v systemctl >/dev/null 2>&1; then
    install -Dm644 "$src/systemd/battery-limit.service" /etc/systemd/system/battery-limit.service
    systemctl daemon-reload
    systemctl enable battery-limit.service
    systemctl restart battery-limit.service
  else
    printf '\nWarning: systemd not found. The limit was applied now but will not persist across reboots.\n' >&2
  fi
else
  printf '\nSkipping the systemd service (--no-service). The limit will not persist across reboots.\n'
fi

printf '\n'
"$PREFIX/bin/battery-limit" status
printf '\nInstalled. Change the limit with: battery-limit set 80\n'
