#!/usr/bin/env bash

set -euo pipefail

BRIDGE_DEV="${BRIDGE_DEV:-nuttx0}"
BRIDGE_IP="${BRIDGE_IP:-10.0.1.1/24}"
IFB_DEV="${IFB_DEV:-ifb0}"
RATE="${RATE:-10Mbit}"
LATENCY="${LATENCY:-50ms}"
BURST="${BURST:-1540}"
WAIT_SECS="${WAIT_SECS:-10}"
TAPS=("$@")
BRIDGE_ONLY=0

usage() {
  cat <<EOF
Usage: sudo $(basename "$0") [--bridge-only] [tap0 tap1 ...]

Environment overrides:
  BRIDGE_DEV   Linux bridge device name   (default: nuttx0)
  BRIDGE_IP    Bridge IPv4/CIDR           (default: 10.0.1.1/24)
  IFB_DEV      IFB device name            (default: ifb0)
  RATE         Traffic shaping rate       (default: 10Mbit)
  LATENCY      TBF latency                (default: 50ms)
  BURST        TBF burst                  (default: 1540)
  WAIT_SECS    Seconds to wait for taps   (default: 10)

Examples:
  sudo $0 --bridge-only
  sudo $0
  sudo BRIDGE_IP=10.0.2.1/24 RATE=5Mbit $0 tap0 tap1
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bridge-only)
      BRIDGE_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

TAPS=("$@")

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo/root." >&2
  exit 1
fi

ensure_bridge() {
  if ! ip link show "${BRIDGE_DEV}" >/dev/null 2>&1; then
    ip link add name "${BRIDGE_DEV}" type bridge
  fi

  if ! ip -4 addr show dev "${BRIDGE_DEV}" | grep -q "${BRIDGE_IP%/*}"; then
    ip addr add "${BRIDGE_IP}" dev "${BRIDGE_DEV}" 2>/dev/null || true
  fi

  ip link set "${BRIDGE_DEV}" up
}

ensure_ifb() {
  modprobe ifb

  if ! ip link show "${IFB_DEV}" >/dev/null 2>&1; then
    ip link add "${IFB_DEV}" type ifb
  fi

  ip link set "${IFB_DEV}" up
}

discover_taps() {
  ip -o link show | sed -n 's/^[0-9]\+: \(tap[[:alnum:]_.-]*\):.*/\1/p' | sort
}

resolve_taps() {
  local deadline now
  local discovered=()
  local missing=()
  local tap

  if [[ ${#TAPS[@]} -eq 0 ]]; then
    mapfile -t TAPS < <(discover_taps)
    return 0
  fi

  deadline=$((SECONDS + WAIT_SECS))

  while (( SECONDS <= deadline )); do
    missing=()

    for tap in "${TAPS[@]}"; do
      if ! ip link show "${tap}" >/dev/null 2>&1; then
        missing+=("${tap}")
      fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
      return 0
    fi

    sleep 1
  done

  mapfile -t discovered < <(discover_taps)
  if [[ ${#discovered[@]} -ge ${#TAPS[@]} ]]; then
    echo "Requested TAPs not found: ${missing[*]}" >&2
    echo "Using discovered TAPs instead: ${discovered[*]:0:${#TAPS[@]}}" >&2
    TAPS=("${discovered[@]:0:${#TAPS[@]}}")
    return 0
  fi

  echo "Requested TAPs not found after ${WAIT_SECS}s: ${missing[*]}" >&2
  echo "Discovered TAPs: ${discovered[*]:-none}" >&2
  exit 1
}

attach_taps() {
  local tap

  for tap in "${TAPS[@]}"; do
    ip link set "${tap}" master "${BRIDGE_DEV}"
    ip link set "${tap}" up
  done
}

setup_shaping() {
  tc qdisc del dev "${BRIDGE_DEV}" ingress 2>/dev/null || true
  tc qdisc del dev "${IFB_DEV}" root 2>/dev/null || true

  tc qdisc add dev "${BRIDGE_DEV}" handle ffff: ingress
  tc filter add dev "${BRIDGE_DEV}" parent ffff: \
    u32 match u32 0 0 action mirred egress redirect dev "${IFB_DEV}"
  tc qdisc add dev "${IFB_DEV}" root tbf \
    rate "${RATE}" latency "${LATENCY}" burst "${BURST}"
}

echo "Setting up bridge ${BRIDGE_DEV} (${BRIDGE_IP})"
ensure_bridge

echo "Setting up IFB device ${IFB_DEV}"
ensure_ifb

if [[ ${BRIDGE_ONLY} -eq 0 ]]; then
  resolve_taps

  echo "Attaching TAP devices: ${TAPS[*]}"
  attach_taps
else
  echo "Bridge-only mode: not waiting for or attaching TAP devices"
fi

echo "Applying ingress shaping on ${BRIDGE_DEV} via ${IFB_DEV}"
setup_shaping

echo
echo "Done."
echo "Bridge status:"
ip -br addr show dev "${BRIDGE_DEV}"
echo
echo "TAP membership:"
bridge link show | grep -E "master ${BRIDGE_DEV}|${BRIDGE_DEV}" || true
