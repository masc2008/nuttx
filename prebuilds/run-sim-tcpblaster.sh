#!/usr/bin/env bash

set -euo pipefail

BUILD_DIR="/home/hma/nuttx/build-sim-tcpblaster"
SIM_PAC_DIR="${BUILD_DIR}/sim-pac"
SIM_LAUNCH="${SIM_PAC_DIR}/simlaunch.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--direct] [args...]

Options:
  --direct   Run ${BUILD_DIR}/nuttx directly instead of the packaged sim-pac launcher.

Notes:
  - Default mode runs from ${SIM_PAC_DIR} so the packaged loader and libs are used.
  - For networking on Linux, you may need:
      sudo setcap cap_net_admin+ep ${BUILD_DIR}/nuttx
    and sometimes also:
      sudo setcap cap_net_admin+ep ${SIM_PAC_DIR}/nuttx
EOF
}

DIRECT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --direct)
      DIRECT=1
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

if [[ ${DIRECT} -eq 1 ]]; then
  if [[ ! -x "${BUILD_DIR}/nuttx" ]]; then
    echo "SIM binary not found: ${BUILD_DIR}/nuttx" >&2
    echo "Build it first with ~/nuttx/nuttx/prebuilds/build-sim-tcpblaster.sh" >&2
    exit 1
  fi

  cd "${BUILD_DIR}"
  exec "${BUILD_DIR}/nuttx" "$@"
fi

if [[ ! -f "${SIM_LAUNCH}" ]]; then
  echo "SIM launcher not found: ${SIM_LAUNCH}" >&2
  echo "Build it first with ~/nuttx/nuttx/prebuilds/build-sim-tcpblaster.sh" >&2
  exit 1
fi

cd "${SIM_PAC_DIR}"
exec bash "${SIM_LAUNCH}" "$@"
