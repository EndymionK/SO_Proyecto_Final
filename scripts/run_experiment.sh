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

  # run miner; expect binary at build/miner
  bash -lc "source ${HOME}/.venv/bin/activate || true; ./build/miner --mode ${MODE} --difficulty ${DIFFICULTY} --threads ${THREADS} --seed ${SEED} --timeout ${TIMEOUT} --metrics-out ${OUT_CSV}"

  # small delay between runs
  sleep 1
done
