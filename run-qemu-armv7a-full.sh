#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/home/hma/nuttx"
BUILD_DIR="${ROOT_DIR}/build-qemu-armv7a-full"
IMAGE="${BUILD_DIR}/nuttx"
OPENVELA_ROOT="${OPENVELA_ROOT:-/home/hma/open-vela/vela-opensource}"

host_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
host_arch="$(uname -m)"

case "${host_arch}" in
  aarch64|arm64)
    host_arch="aarch64"
    ;;
  x86_64)
    host_arch="x86_64"
    ;;
esac

OPENVELA_QEMU_BIN="${OPENVELA_ROOT}/prebuilts/qemu/${host_os}-${host_arch}/bin/qemu-system-arm"

resolve_qemu_bin() {
  if [[ -n "${QEMU_BIN:-}" ]]; then
    printf '%s\n' "${QEMU_BIN}"
  elif [[ -x "${OPENVELA_QEMU_BIN}" ]]; then
    printf '%s\n' "${OPENVELA_QEMU_BIN}"
  elif command -v qemu-system-arm >/dev/null 2>&1; then
    command -v qemu-system-arm
  else
    printf '%s\n' "qemu-system-arm"
  fi
}

QEMU_BIN="$(resolve_qemu_bin)"
MACHINE="${QEMU_MACHINE:-virt,virtualization=off,gic-version=2}"
CPU="${QEMU_CPU:-cortex-a7}"
MEMORY="${QEMU_MEMORY:-256M}"
SMP_CPUS="${QEMU_SMP:-1}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--gdb] [--image PATH] [extra qemu args...]

Environment overrides:
  QEMU_BIN      QEMU executable to use
  OPENVELA_ROOT OpenVela root used to resolve prebuilts/qemu host binary
  QEMU_MACHINE  QEMU machine type     (default: virt,gic-version=2)
  QEMU_CPU      CPU model             (default: cortex-a7)
  QEMU_MEMORY   Guest RAM size        (default: 256M)
  QEMU_SMP      Number of CPUs        (default: 1)

Options:
  --gdb         Start paused with a GDB stub on tcp::1234.
  --image PATH  Use a different ELF image instead of ${IMAGE}.
EOF
}

GDB_WAIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gdb)
      GDB_WAIT=1
      shift
      ;;
    --image)
      IMAGE="$2"
      shift 2
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

if [[ ! -f "${IMAGE}" ]]; then
  echo "Image not found: ${IMAGE}" >&2
  echo "Build it first with /home/hma/nuttx/nuttx/build-qemu-armv7a-full.sh" >&2
  exit 1
fi

if ! command -v "${QEMU_BIN}" >/dev/null 2>&1; then
  echo "QEMU not found: ${QEMU_BIN}" >&2
  echo "Set QEMU_BIN=/full/path/to/qemu-system-arm or OPENVELA_ROOT=/path/to/open-vela." >&2
  exit 1
fi

QEMU_ARGS=(
  -M "${MACHINE}"
  -cpu "${CPU}"
  -m "${MEMORY}"
  -smp "${SMP_CPUS}"
  -nographic
  -no-reboot
  -chardev stdio,id=con,mux=on
  -serial chardev:con
  -global virtio-mmio.force-legacy=false
  -netdev user,id=u1,ipv4=on,net=10.0.2.0/24,host=10.0.2.2,ipv6=on,ipv6-net=fd00::/64,ipv6-host=fd00::2,hostfwd=tcp:127.0.0.1:10023-10.0.2.15:23,hostfwd=tcp:127.0.0.1:15001-10.0.2.15:5001
  -device virtio-net-device,netdev=u1,bus=virtio-mmio-bus.0
  -mon chardev=con,mode=readline
  -kernel "${IMAGE}"
)

if [[ ${GDB_WAIT} -eq 1 ]]; then
  QEMU_ARGS+=(-S -s)
fi

exec "${QEMU_BIN}" "${QEMU_ARGS[@]}" "$@"
