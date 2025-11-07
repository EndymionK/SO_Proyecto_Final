#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release
cmake --build build -- -j$(nproc)

if [ ! -x build/miner ]; then
  echo "build/miner not found or not executable"
  exit 1
fi

./build/miner --mode sequential --difficulty 16 --threads 1 --timeout 5 --metrics-out results/raw/smoke_test.csv || true

if [ -f results/raw/smoke_test.csv ]; then
  echo "Smoke test produced results/raw/smoke_test.csv"
  exit 0
else
  echo "Smoke test did not produce CSV"
  exit 2
fi
