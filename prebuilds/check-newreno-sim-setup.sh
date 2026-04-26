#!/usr/bin/env bash

set -euo pipefail

BUILD_DIR="/home/hma/nuttx/build-sim-tcpblaster"
BUILD_SCRIPT="/home/hma/nuttx/nuttx/prebuilds/build-sim-tcpblaster.sh"
RUN_SCRIPT="/home/hma/nuttx/nuttx/prebuilds/run-sim-tcpblaster.sh"
BRIDGE_DEV="${BRIDGE_DEV:-nuttx0}"
IFB_DEV="${IFB_DEV:-ifb0}"
MIN_TAPS="${MIN_TAPS:-2}"
CHECK_BUILD=1
CHECK_HOST=1
CHECK_GUEST=1

usage() {
  cat <<EOF
Usage: $(basename "$0") [--build-only] [--host-only] [--guest-only]

Checks:
  build  Verify SIM build artifacts and cap_net_admin on binaries
  host   Verify ${BRIDGE_DEV}, ${IFB_DEV}, and at least ${MIN_TAPS} tap devices
  guest  Launch the SIM image briefly and check that NSH and iperf3 are present
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only)
      CHECK_BUILD=1
      CHECK_HOST=0
      CHECK_GUEST=0
      shift
      ;;
    --host-only)
      CHECK_BUILD=0
      CHECK_HOST=1
      CHECK_GUEST=0
      shift
      ;;
    --guest-only)
      CHECK_BUILD=0
      CHECK_HOST=0
      CHECK_GUEST=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

check_build() {
  echo "[build] checking artifacts"

  [[ -x "${BUILD_DIR}/nuttx" ]] || fail "missing ${BUILD_DIR}/nuttx"
  [[ -f "${BUILD_DIR}/sim-pac/nuttx" ]] || fail "missing ${BUILD_DIR}/sim-pac/nuttx"
  [[ -f "${BUILD_DIR}/sim-pac/simlaunch.sh" ]] || fail "missing ${BUILD_DIR}/sim-pac/simlaunch.sh"

  if command -v getcap >/dev/null 2>&1; then
    local caps
    caps="$(getcap "${BUILD_DIR}/nuttx" "${BUILD_DIR}/sim-pac/nuttx" 2>/dev/null || true)"
    echo "${caps}"
    grep -q "cap_net_admin=ep" <<<"${caps}" || fail "cap_net_admin not set on SIM binaries"
  else
    echo "[build] getcap not available, skipping capability check"
  fi

  echo "[build] ok"
}

check_host() {
  echo "[host] checking bridge and tap devices"

  ip link show "${BRIDGE_DEV}" >/dev/null 2>&1 || fail "bridge ${BRIDGE_DEV} not found"
  ip link show "${IFB_DEV}" >/dev/null 2>&1 || fail "ifb ${IFB_DEV} not found"

  local taps
  taps="$(ip -o link show | sed -n 's/^[0-9]\+: \(tap[[:alnum:]_.-]*\):.*/\1/p' | sort)"
  echo "${taps:-no tap devices found}"

  [[ -n "${taps}" ]] || fail "no tap devices found"
  [[ "$(wc -w <<<"${taps}")" -ge "${MIN_TAPS}" ]] || fail "expected at least ${MIN_TAPS} tap devices"

  echo "[host] ok"
}

check_guest() {
  echo "[guest] launching SIM briefly"

  local output rc
  set +e
  output="$(printf 'help\npoweroff\n' | timeout 15s bash "${RUN_SCRIPT}" 2>&1)"
  rc=$?
  set -e

  echo "${output}"

  [[ ${rc} -eq 0 || ${rc} -eq 124 ]] || fail "guest launch failed with rc=${rc}"
  grep -q "NuttShell (NSH)" <<<"${output}" || fail "NSH prompt not observed"
  grep -q "iperf3" <<<"${output}" || fail "iperf3 not found in guest help output"

  echo "[guest] ok"
}

if [[ ${CHECK_BUILD} -eq 1 ]]; then
  check_build
fi

if [[ ${CHECK_HOST} -eq 1 ]]; then
  check_host
fi

if [[ ${CHECK_GUEST} -eq 1 ]]; then
  check_guest
fi

echo "All requested checks passed."
