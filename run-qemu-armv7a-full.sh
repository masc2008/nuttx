#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/home/hma/apache"
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
NET_MODE="${QEMU_NET_MODE:-user}"
USER_NET="${QEMU_USER_NET:-10.0.2.0/24}"
USER_HOST="${QEMU_USER_HOST:-10.0.2.2}"
USER_DNS="${QEMU_USER_DNS:-10.0.2.3}"
USER_DHCPSTART="${QEMU_USER_DHCPSTART:-10.0.2.15}"
USER_HOSTFWD_TELNET="${QEMU_USER_HOSTFWD_TELNET:-tcp:127.0.0.1:10023-10.0.2.15:23}"
USER_HOSTFWD_IPERF="${QEMU_USER_HOSTFWD_IPERF:-tcp:127.0.0.1:15001-10.0.2.15:5001}"
TAP_IFNAME="${QEMU_TAP_IF:-tap0}"

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
  QEMU_NET_MODE Guest network mode    (default: user, supported: user|tap)
  QEMU_TAP_IF   TAP device for tap mode (default: tap0)
  QEMU_USER_NET User-mode subnet        (default: 10.0.2.0/24)
  QEMU_USER_HOST User-mode gateway IP   (default: 10.0.2.2)
  QEMU_USER_DNS User-mode DNS IP        (default: 10.0.2.3)
  QEMU_USER_DHCPSTART First DHCP lease  (default: 10.0.2.15)

Options:
  --gdb         Start paused with a GDB stub on tcp::1234.
  --image PATH  Use a different ELF image instead of ${IMAGE}.

Tap mode example for DHCP option 42 testing:
  sudo ip tuntap add dev tap0 mode tap
  sudo ip addr add 192.168.50.1/24 dev tap0
  sudo ip link set tap0 up
  dnsmasq --no-daemon --interface=tap0 --bind-interfaces \\
    --dhcp-range=192.168.50.20,192.168.50.50,255.255.255.0 \\
    --dhcp-option=option:router,192.168.50.1 \\
    --dhcp-option=option:dns-server,192.168.50.1 \\
    --dhcp-option=option:ntp-server,192.168.50.1
  QEMU_NET_MODE=tap ${0##*/} --image ${IMAGE}
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

case "${NET_MODE}" in
  user)
    NETDEV_ARGS=(
      -netdev
      "user,id=u1,ipv4=on,net=${USER_NET},host=${USER_HOST},dns=${USER_DNS},dhcpstart=${USER_DHCPSTART},ipv6=on,ipv6-net=fd00::/64,ipv6-host=fd00::2,hostfwd=${USER_HOSTFWD_TELNET},hostfwd=${USER_HOSTFWD_IPERF}"
    )
    ;;
  tap)
    NETDEV_ARGS=(
      -netdev
      "tap,id=u1,ifname=${TAP_IFNAME},script=no,downscript=no"
    )
    ;;
  *)
    echo "Unsupported QEMU_NET_MODE: ${NET_MODE}" >&2
    echo "Expected one of: user, tap" >&2
    exit 1
    ;;
esac

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
  "${NETDEV_ARGS[@]}"
  -device virtio-net-device,netdev=u1,bus=virtio-mmio-bus.0
  -mon chardev=con,mode=readline
  -kernel "${IMAGE}"
)

if [[ ${GDB_WAIT} -eq 1 ]]; then
  QEMU_ARGS+=(-S -s)
fi

exec "${QEMU_BIN}" "${QEMU_ARGS[@]}" "$@"
