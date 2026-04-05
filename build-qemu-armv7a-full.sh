#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/home/hma/nuttx"
NUTTX_DIR="${ROOT_DIR}/nuttx"
APPS_DIR="${ROOT_DIR}/nuttx-apps"
BUILD_DIR="${ROOT_DIR}/build-qemu-armv7a-full"

PREBUILT_ROOT="/home/hma/open-vela/vela-opensource/prebuilts"
PYTHON_BIN_DIR="${PREBUILT_ROOT}/tools/python/bin"
PYTHON_PKG_DIR="${PREBUILT_ROOT}/tools/python/dist-packages"
TOOLCHAIN_BIN_DIR="${PREBUILT_ROOT}/gcc/linux-x86_64/arm-none-eabi/bin"
CMAKE_BIN_DIR="${PREBUILT_ROOT}/cmake/linux-x86_64/bin"
NINJA_BIN_DIR="${PREBUILT_ROOT}/build-tools/linux-x86_64/bin"
HOST_CLANG_BIN_DIR="${PREBUILT_ROOT}/clang/linux/wasm/bin"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--clean] [--reconfigure] [--configure-only] [--build-only] [--jobs N]

Options:
  --clean           Remove ${BUILD_DIR} before configuring.
  --reconfigure     Force CMake configure even if ${BUILD_DIR} already exists.
  --configure-only  Run CMake configure only.
  --build-only      Run build only, assuming configure is already done.
  --jobs N          Use N parallel jobs for the build.
EOF
}

CLEAN=0
RECONFIGURE=0
CONFIGURE_ONLY=0
BUILD_ONLY=0
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"

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
    --configure-only)
      CONFIGURE_ONLY=1
      shift
      ;;
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
    --jobs)
      JOBS="$2"
      shift 2
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

if [[ ${CONFIGURE_ONLY} -eq 1 && ${BUILD_ONLY} -eq 1 ]]; then
  echo "--configure-only and --build-only cannot be used together" >&2
  exit 1
fi

export PATH="${PYTHON_BIN_DIR}:${TOOLCHAIN_BIN_DIR}:${CMAKE_BIN_DIR}:${NINJA_BIN_DIR}:${HOST_CLANG_BIN_DIR}:${PATH}"
export PYTHONPATH="${PYTHON_PKG_DIR}:${PYTHON_PKG_DIR}/kconfiglib:${PYTHON_PKG_DIR}/pyelftools:${PYTHON_PKG_DIR}/cxxfilt"

if [[ ${CLEAN} -eq 1 ]]; then
  rm -rf "${BUILD_DIR}"
fi

NEED_CONFIGURE=0

if [[ ${BUILD_ONLY} -eq 0 ]]; then
  if [[ ${RECONFIGURE} -eq 1 || ${CONFIGURE_ONLY} -eq 1 ]]; then
    NEED_CONFIGURE=1
  elif [[ ! -f "${BUILD_DIR}/build.ninja" || ! -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
    NEED_CONFIGURE=1
  fi
fi

if [[ ${NEED_CONFIGURE} -eq 1 ]]; then
  if ! cmake -S "${NUTTX_DIR}" \
             -B "${BUILD_DIR}" \
             -GNinja \
             -DCMAKE_MAKE_PROGRAM="${NINJA_BIN_DIR}/ninja" \
             -Wno-dev \
             -DBOARD_CONFIG=qemu-armv7a:full \
             -DNUTTX_APPS_DIR="${APPS_DIR}"; then
    if [[ -f "${BUILD_DIR}/build.ninja" && -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
      echo "Configure returned nonzero, but build files were generated. Continuing." >&2
    else
      exit 1
    fi
  fi
fi

if [[ ${CONFIGURE_ONLY} -eq 0 ]]; then
  cmake --build "${BUILD_DIR}" -j"${JOBS}"
fi
