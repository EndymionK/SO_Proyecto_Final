#!/usr/bin/env python3
import sys
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'results' / 'raw'
OUT = ROOT / 'results' / 'processed'
OUT.mkdir(parents=True, exist_ok=True)

def main():
    csvs = list(RAW.glob('*.csv'))
    if not csvs:
        print('No raw CSVs found in', RAW)
        return
    frames = []
    for f in csvs:
        try:
            df = pd.read_csv(f)
            frames.append(df)
        except Exception as e:
            print('Skipping', f, 'error', e)
    if not frames:
        print('No parsable CSVs')
        return
    all_df = pd.concat(frames, ignore_index=True)
    summary = all_df.groupby(['experiment_id','mode','threads']).agg({'hashes_per_second':['mean','std','count'],'elapsed_s':'mean'})
    summary.to_csv(OUT / 'summary.csv')
    print('Wrote', OUT / 'summary.csv')

if __name__ == '__main__':
    main()
