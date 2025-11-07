#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <pid> <out_prefix>"
  exit 2
fi

PID="$1"
OUT_PREFIX="$2"
INTERVAL=${3:-1}

while kill -0 "$PID" >/dev/null 2>&1; do
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "timestamp,ts_rank" > "${OUT_PREFIX}.${TS}.proc.csv"
  ps -p "$PID" -o pid,ppid,%cpu,%mem,stime,cmd >> "${OUT_PREFIX}.${TS}.proc.csv" || true
  awk '/^cpu /{print}' /proc/stat > "${OUT_PREFIX}.${TS}.cpu.stat" || true
  cat /proc/$PID/status > "${OUT_PREFIX}.${TS}.proc.status" || true
  sleep "$INTERVAL"
done
