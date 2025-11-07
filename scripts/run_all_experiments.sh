#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Running All Experiments ==="
echo ""

CONFIGS=(
  "experiments/configs/exp_seq_low.json"
  "experiments/configs/exp_par_2t_low.json"
  "experiments/configs/exp_par_4t_low.json"
  "experiments/configs/exp_con_2t_low.json"
  "experiments/configs/exp_seq_med.json"
  "experiments/configs/exp_par_4t_med.json"
)

for config in "${CONFIGS[@]}"; do
  if [ -f "$config" ]; then
    echo "Running: $config"
    ./scripts/run_experiment.sh "$config"
    echo "Completed: $config"
    echo ""
  else
    echo "Config not found: $config"
  fi
done

echo "=== All Experiments Completed ==="
echo "Analyzing results..."
echo ""

source .venv/bin/activate || true
python3 scripts/parse_results.py

echo ""
echo "=== Summary ==="
cat results/processed/summary.csv

echo ""
echo "Done! Check results/processed/ for detailed analysis."
