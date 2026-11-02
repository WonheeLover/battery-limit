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

die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
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

if (( EUID != 0 )); then
  exec sudo -- "$0" "${original_args[@]}"
fi

shopt -s nullglob
batteries=(/sys/class/power_supply/BAT*/charge_control_end_threshold)
shopt -u nullglob

(( ${#batteries[@]} > 0 )) ||
  die "no compatible battery found. This tool requires an ASUS laptop using the asus-wmi driver."

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
