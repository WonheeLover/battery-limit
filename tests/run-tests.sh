#!/usr/bin/env bash
#
# Test battery-limit against a temporary sysfs fixture. Does not touch the
# real battery and does not require root.

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bat="$tmp/BAT0"
mkdir -p "$bat"
printf '100\n' > "$bat/charge_control_end_threshold"
printf '47\n' > "$bat/capacity"
printf 'Discharging\n' > "$bat/status"

export BATTERY_LIMIT_SYSFS="$bat/charge_control_end_threshold"
export BATTERY_LIMIT_CONF="$tmp/battery-limit.conf"
export BATTERY_LIMIT_ALLOW_NONROOT=1
export BATTERY_LIMIT_CHASSIS=10

bl="$repo/bin/battery-limit"
passed=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ok() {
  passed=$((passed + 1))
  printf 'ok %d - %s\n' "$passed" "$*"
}

[[ $("$bl" get) == "100" ]] || fail "get should return 100 initially"
ok "get returns the active limit"

"$bl" set 80 >/dev/null
[[ $("$bl" get) == "80" ]] || fail "set 80 did not write the limit"
grep -qx 'LIMIT=80' "$BATTERY_LIMIT_CONF" || fail "set did not persist the limit"
ok "set writes and persists the limit"

status=$("$bl" status)
[[ $status == *"Charge limit:  80% (on battery)"* ]] ||
  fail "unexpected status output: $status"
ok "status shows the active limit"

printf '80\n' > "$bat/capacity"
printf 'Not charging\n' > "$bat/status"
status=$("$bl" status)
[[ $status == *"Charge limit:  80% (holding at 80%)"* ]] ||
  fail "unexpected holding output: $status"
ok "status detects the holding state"

json=$("$bl" status --json)
[[ $json == *'"charge_limit":80'* ]] || fail "unexpected JSON: $json"
ok "status --json is machine readable"

"$bl" off >/dev/null
[[ $("$bl" get) == "100" ]] || fail "off did not disable the limit"
ok "off disables the limit"

"$bl" toggle >/dev/null
[[ $("$bl" get) == "80" ]] || fail "toggle did not apply the saved limit"
"$bl" toggle >/dev/null
[[ $("$bl" get) == "100" ]] || fail "toggle did not disable the limit"
ok "toggle switches between the saved limit and 100"

if "$bl" set 30 >/dev/null 2>&1; then
  fail "set 30 should be rejected"
fi
ok "invalid limits are rejected"

# Detection is not limited to BAT* names (e.g. CMB0 on some laptops).
cmb="$tmp/CMB0"
mkdir -p "$cmb"
printf '100\n' > "$cmb/charge_control_end_threshold"
printf '50\n' > "$cmb/capacity"
printf 'Discharging\n' > "$cmb/status"

BATTERY_LIMIT_SYSFS="$cmb/charge_control_end_threshold" \
  BATTERY_LIMIT_CONF="$tmp/cmb.conf" \
  "$bl" set 80 >/dev/null
cmb_limit=$(BATTERY_LIMIT_SYSFS="$cmb/charge_control_end_threshold" "$bl" get)
[[ $cmb_limit == "80" ]] || fail "non-BAT power supply was not detected"
ok "detects non-BAT power supplies (e.g. CMB0)"

# Desktop and server chassis types must be rejected before touching the battery.
printf '100\n' > "$bat/charge_control_end_threshold"
if BATTERY_LIMIT_CHASSIS=3 "$bl" set 80 >"$tmp/desktop.out" 2>&1; then
  fail "desktop chassis should be rejected"
fi
[[ $(cat "$bat/charge_control_end_threshold") == "100" ]] ||
  fail "desktop rejection still wrote to the battery"
grep -q 'not a laptop' "$tmp/desktop.out" ||
  fail "desktop rejection message is unclear: $(cat "$tmp/desktop.out")"
ok "desktop chassis is rejected"

# Unknown chassis types are allowed for firmware that reports them incorrectly.
if BATTERY_LIMIT_CHASSIS=2 "$bl" set 75 >/dev/null 2>&1; then
  [[ $(BATTERY_LIMIT_CHASSIS=2 "$bl" get) == "75" ]] ||
    fail "unknown chassis did not apply the limit"
else
  fail "unknown chassis should be allowed"
fi
ok "unknown chassis types are allowed"

# The installer must reject desktops before asking for root.
if BATTERY_LIMIT_CHASSIS=3 "$repo/install.sh" >"$tmp/installer-desktop.out" 2>&1; then
  fail "installer should reject a desktop chassis"
fi
grep -q 'not a laptop' "$tmp/installer-desktop.out" ||
  fail "installer rejection message is unclear: $(cat "$tmp/installer-desktop.out")"
ok "installer rejects desktop chassis"

printf '\nAll %d tests passed.\n' "$passed"
