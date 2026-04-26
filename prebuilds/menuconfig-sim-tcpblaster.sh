#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/home/hma/nuttx"
NUTTX_DIR="${ROOT_DIR}/nuttx"
APPS_DIR="${ROOT_DIR}/nuttx-apps"
BUILD_DIR="${ROOT_DIR}/build-sim-tcpblaster"

PREBUILT_ROOT="/home/hma/open-vela/vela-opensource/prebuilts"
PYTHON_BIN_DIR="${PREBUILT_ROOT}/tools/python/bin"
PYTHON_PKG_DIR="${PREBUILT_ROOT}/tools/python/dist-packages"
CMAKE_BIN_DIR="${PREBUILT_ROOT}/cmake/linux-x86_64/bin"
NINJA_BIN_DIR="${PREBUILT_ROOT}/build-tools/linux-x86_64/bin"
HOST_CLANG_BIN_DIR="${PREBUILT_ROOT}/clang/linux/wasm/bin"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--clean] [--reconfigure]

Options:
  --clean        Remove ${BUILD_DIR} before configuring.
  --reconfigure  Force CMake configure before launching menuconfig.
EOF
}

CLEAN=0
RECONFIGURE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      CLEAN=1
      shift
      ;;
    --reconfigure)
      RECONFIGURE=1
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

export PATH="${PYTHON_BIN_DIR}:${CMAKE_BIN_DIR}:${NINJA_BIN_DIR}:${HOST_CLANG_BIN_DIR}:${PATH}"
export PYTHONPATH="${PYTHON_PKG_DIR}:${PYTHON_PKG_DIR}/kconfiglib:${PYTHON_PKG_DIR}/pyelftools:${PYTHON_PKG_DIR}/cxxfilt"

if [[ ${CLEAN} -eq 1 ]]; then
  rm -rf "${BUILD_DIR}"
fi

if [[ ${RECONFIGURE} -eq 1 || ! -f "${BUILD_DIR}/build.ninja" || ! -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
  cmake -S "${NUTTX_DIR}" \
        -B "${BUILD_DIR}" \
        -GNinja \
        -DCMAKE_MAKE_PROGRAM="${NINJA_BIN_DIR}/ninja" \
        -Wno-dev \
        -DBOARD_CONFIG=sim:tcpblaster \
        -DNUTTX_APPS_DIR="${APPS_DIR}"
fi

cmake --build "${BUILD_DIR}" -- menuconfig
