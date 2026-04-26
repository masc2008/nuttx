#!/usr/bin/env bash

set -euo pipefail

START_PORT="${START_PORT:-10003}"
COUNT="${COUNT:-4}"
PID_DIR="${PID_DIR:-/tmp/nuttx-iperf-pids}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [count]

Stops host-side iperf servers started by start-iperf-servers.sh.

Environment overrides:
  START_PORT  First TCP port          (default: 10003)
  COUNT       Number of servers       (default: 4)
  PID_DIR     Directory for pid files (default: /tmp/nuttx-iperf-pids)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ge 1 ]]; then
  COUNT="$1"
fi

for ((i = 0; i < COUNT; i++)); do
  port=$((START_PORT + i))
  pidfile="${PID_DIR}/iperf-${port}.pid"

  if [[ ! -f "${pidfile}" ]]; then
    continue
  fi

  pid="$(cat "${pidfile}")"
  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
    echo "stopped iperf server pid=${pid} port=${port}"
  fi

  rm -f "${pidfile}"
done
