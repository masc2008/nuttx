#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/home/hma/nuttx"
BUILD_DIR="${ROOT_DIR}/build-qemu-armv7a-full"
IMAGE="${BUILD_DIR}/nuttx"

if [[ -n "${QEMU_BIN:-}" ]]; then
  QEMU_BIN="${QEMU_BIN}"
elif command -v qemu-system-arm >/dev/null 2>&1; then
  QEMU_BIN="$(command -v qemu-system-arm)"
elif [[ -x /home/hma/open-vela/vela-opensource/prebuilts/qemu/linux-x86_64/bin/qemu-system-arm ]]; then
  QEMU_BIN="/home/hma/open-vela/vela-opensource/prebuilts/qemu/linux-x86_64/bin/qemu-system-arm"
else
  QEMU_BIN="qemu-system-arm"
fi
MACHINE="${QEMU_MACHINE:-virt,gic-version=2}"
CPU="${QEMU_CPU:-cortex-a7}"
MEMORY="${QEMU_MEMORY:-256M}"
SMP_CPUS="${QEMU_SMP:-1}"
IPV4_NET="${QEMU_IPV4_NET:-10.0.2.0/24}"
IPV4_HOST="${QEMU_IPV4_HOST:-10.0.2.2}"
IPV6_NET="${QEMU_IPV6_NET:-fd00::/64}"
IPV6_HOST="${QEMU_IPV6_HOST:-fd00::2}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--gdb] [--image PATH] [extra qemu args...]

Environment overrides:
  QEMU_BIN      QEMU executable to use (default: qemu-system-arm)
  QEMU_MACHINE  QEMU machine type     (default: virt,gic-version=2)
  QEMU_CPU      CPU model             (default: cortex-a7)
  QEMU_MEMORY   Guest RAM size        (default: 256M)
  QEMU_SMP      Number of CPUs        (default: 1)
  QEMU_IPV4_NET IPv4 usernet subnet   (default: 10.0.2.0/24)
  QEMU_IPV4_HOST IPv4 usernet host    (default: 10.0.2.2)
  QEMU_IPV6_NET IPv6 usernet subnet   (default: fd00::/64)
  QEMU_IPV6_HOST IPv6 usernet host    (default: fd00::2)

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
  echo "Set QEMU_BIN=/full/path/to/qemu-system-arm if it is not on PATH." >&2
  exit 1
fi

QEMU_ARGS=(
  -M "${MACHINE}"
  -cpu "${CPU}"
  -m "${MEMORY}"
  -smp "${SMP_CPUS}"
  -nographic
  -no-reboot
  -global virtio-mmio.force-legacy=false
  -netdev user,id=u1,ipv4=on,net="${IPV4_NET}",host="${IPV4_HOST}",ipv6=on,ipv6-net="${IPV6_NET}",ipv6-host="${IPV6_HOST}"
  -device virtio-net-device,netdev=u1,mac=52:54:00:12:34:56,bus=virtio-mmio-bus.0
  -kernel "${IMAGE}"
)

if [[ ${GDB_WAIT} -eq 1 ]]; then
  QEMU_ARGS+=(-S -s)
fi

exec "${QEMU_BIN}" "${QEMU_ARGS[@]}" "$@"
