#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/home/hma/nuttx"
BUILD_DIR="${ROOT_DIR}/build-sim-tcpblaster"
BOARD_DEFCONFIG="${ROOT_DIR}/nuttx/boards/sim/sim/sim/configs/tcpblaster/defconfig"
GENERATED_DEFCONFIG="${BUILD_DIR}/defconfig"

COPY_BACK=1

usage() {
  cat <<EOF
Usage: $(basename "$0") [--copy-back]

Options:
  --copy-back   Copy ${GENERATED_DEFCONFIG} back to ${BOARD_DEFCONFIG}
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy-back)
      COPY_BACK=1
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

if [[ ! -f "${BUILD_DIR}/build.ninja" ]]; then
  echo "Build directory is not configured: ${BUILD_DIR}" >&2
  echo "Run ~/nuttx/nuttx/prebuilds/menuconfig-sim-tcpblaster.sh or ~/nuttx/nuttx/prebuilds/build-sim-tcpblaster.sh first." >&2
  exit 1
fi

cmake --build "${BUILD_DIR}" -- savedefconfig

echo "Generated: ${GENERATED_DEFCONFIG}"

if [[ ${COPY_BACK} -eq 1 ]]; then
  cp "${GENERATED_DEFCONFIG}" "${BOARD_DEFCONFIG}"
  echo "Updated board defconfig: ${BOARD_DEFCONFIG}"
fi
