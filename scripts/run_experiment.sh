#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 experiments/configs/exp_X.json"
  exit 2
fi

CONFIG="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_RAW="$ROOT/results/raw"
RESULTS_META="$ROOT/results/meta"
mkdir -p "$RESULTS_RAW" "$RESULTS_META"

timestamp() { date -u +"%Y%m%dT%H%M%SZ"; }

EXP_ID=$(jq -r '.id' "$CONFIG")
MODE=$(jq -r '.mode' "$CONFIG")
DIFFICULTY=$(jq -r '.difficulty' "$CONFIG")
THREADS=$(jq -r '.threads' "$CONFIG")
AFFINITY=$(jq -r '.affinity' "$CONFIG")
REPS=$(jq -r '.repetitions' "$CONFIG")
TIMEOUT=$(jq -r '.timeout' "$CONFIG")
SEED=$(jq -r '.seed' "$CONFIG")

for ((i=1;i<=REPS;i++)); do
  TS=$(timestamp)
  RUN_ID="${EXP_ID}_run_${TS}_rep${i}"
  OUT_CSV="$RESULTS_RAW/${RUN_ID}.csv"
  OUT_META="$RESULTS_META/${RUN_ID}.meta.json"

  echo "Running ${RUN_ID} -> ${OUT_CSV}"

  # create meta placeholder
  jq -n --arg run_id "$RUN_ID" --arg exp_id "$EXP_ID" '{run_id:$run_id, experiment_id:$exp_id, timestamp:now}' > "$OUT_META"

  # collect system metadata (lscpu, compiler, git commit) into meta
  GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  COMPILER=$(g++ --version 2>/dev/null | head -n1 || echo "unknown")
  LSCPU=$(lscpu 2>/dev/null || true)
  jq --arg git "$GIT_COMMIT" --arg compiler "$COMPILER" --arg lscpu "$LSCPU" '. + {git_commit:$git, compiler:$compiler, lscpu:$lscpu}' "$OUT_META" > "${OUT_META}.tmp" && mv "${OUT_META}.tmp" "$OUT_META" || true

  echo "Running miner (background) and collector for ${RUN_ID}"

  # run miner in background so we can collect proc metrics tied to its PID
  ( source ${HOME}/.venv/bin/activate || true; ./build/miner --mode ${MODE} --difficulty ${DIFFICULTY} --threads ${THREADS} --seed ${SEED} --timeout ${TIMEOUT} --metrics-out "${OUT_CSV}" ) &
  MINER_PID=$!

  # start collector attached to miner PID (collector will exit when miner exits)
  COLLECT_PREFIX="$RESULTS_RAW/${RUN_ID}.proc"
  ./scripts/collect_proc_metrics.sh "$MINER_PID" "$COLLECT_PREFIX" 1 &
  COLLECT_PID=$!

  # wait for miner to finish
  wait "$MINER_PID" || true

  # give collector a small moment to flush and then ensure it's terminated
  sleep 1
  if kill -0 "$COLLECT_PID" >/dev/null 2>&1; then
    kill "$COLLECT_PID" 2>/dev/null || true
  fi

  # record PIDs and file locations in metadata
  jq --arg miner_pid "$MINER_PID" --arg collect_pid "$COLLECT_PID" --arg collect_prefix "$COLLECT_PREFIX" '. + {miner_pid:$miner_pid, collector_pid:$collect_pid, collect_prefix:$collect_prefix}' "$OUT_META" > "${OUT_META}.tmp" && mv "${OUT_META}.tmp" "$OUT_META" || true

  # small delay between runs
  sleep 1
done
