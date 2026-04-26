#!/usr/bin/env bash

set -euo pipefail

BIND_IP="${BIND_IP:-10.0.1.1}"
START_PORT="${START_PORT:-10003}"
COUNT="${COUNT:-4}"
LOG_DIR="${LOG_DIR:-/tmp/nuttx-iperf-logs}"
PID_DIR="${PID_DIR:-/tmp/nuttx-iperf-pids}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [count]

Starts multiple host-side iperf servers for the NuttX SIM NewReno test.

Environment overrides:
  BIND_IP     IP to bind on Linux host     (default: 10.0.1.1)
  START_PORT  First TCP port               (default: 10003)
  COUNT       Number of servers            (default: 4)
  LOG_DIR     Directory for iperf logs     (default: /tmp/nuttx-iperf-logs)
  PID_DIR     Directory for pid files      (default: /tmp/nuttx-iperf-pids)

Examples:
  $0
  $0 2
  BIND_IP=10.0.2.1 START_PORT=11003 COUNT=4 $0
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ge 1 ]]; then
  COUNT="$1"
fi

if ! command -v iperf >/dev/null 2>&1; then
  echo "Host iperf is not installed or not in PATH." >&2
  exit 1
fi

mkdir -p "${LOG_DIR}" "${PID_DIR}"

for ((i = 0; i < COUNT; i++)); do
  port=$((START_PORT + i))
  logfile="${LOG_DIR}/iperf-${port}.log"
  pidfile="${PID_DIR}/iperf-${port}.pid"

  if [[ -f "${pidfile}" ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
    echo "iperf server already running on port ${port} (pid $(cat "${pidfile}"))"
    continue
  fi

  nohup iperf -s -B "${BIND_IP}" -i 1 -p "${port}" >"${logfile}" 2>&1 &
  pid=$!
  echo "${pid}" > "${pidfile}"
  echo "started iperf server pid=${pid} ${BIND_IP}:${port} log=${logfile}"
done

echo
echo "Listening ports:"
ss -ltn | grep -E ":(${START_PORT}|$((START_PORT + COUNT - 1)))" || true
