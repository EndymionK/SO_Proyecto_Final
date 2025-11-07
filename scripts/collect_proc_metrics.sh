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
  # process snapshot
  echo "timestamp,ts_rank" > "${OUT_PREFIX}.${TS}.proc.csv"
  ps -p "$PID" -o pid,ppid,%cpu,%mem,stime,cmd >> "${OUT_PREFIX}.${TS}.proc.csv" || true
  awk '/^cpu /{print}' /proc/stat > "${OUT_PREFIX}.${TS}.cpu.stat" || true
  cat /proc/$PID/status > "${OUT_PREFIX}.${TS}.proc.status" || true

  # temperature (if available)
  if [ -d "/sys/class/thermal" ]; then
    echo "timestamp,temp_file,temp_value_C" > "${OUT_PREFIX}.${TS}.temp.csv"
    for f in /sys/class/thermal/thermal_zone*/temp; do
      if [ -r "$f" ]; then
        raw=$(cat "$f" 2>/dev/null || echo "")
        if [ -n "$raw" ]; then
          # many kernels report millidegrees
          if [ "$raw" -gt 1000 ] 2>/dev/null; then
            val=$(awk "BEGIN{printf \"%.3f\", $raw/1000.0}")
          else
            val="$raw"
          fi
          echo "${TS},${f},${val}" >> "${OUT_PREFIX}.${TS}.temp.csv" || true
        fi
      fi
    done
  fi

  # energy (try intel-rapl or generic powercap) if available
  ENERGY_PATH=""
  for p in /sys/class/powercap/*/energy_uj /sys/class/powercap/intel-rapl:*/energy_uj; do
    if [ -r "$p" ]; then
      ENERGY_PATH="$p"
      break
    fi
  done
  if [ -n "$ENERGY_PATH" ]; then
    echo "timestamp,energy_uj" > "${OUT_PREFIX}.${TS}.energy.csv"
    energy=$(cat "$ENERGY_PATH" 2>/dev/null || echo "")
    echo "${TS},${energy}" >> "${OUT_PREFIX}.${TS}.energy.csv" || true
  fi

  sleep "$INTERVAL"
done
