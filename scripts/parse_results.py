#!/usr/bin/env python3
import sys
import argparse
from pathlib import Path
import pandas as pd

def parse_args():
    p = argparse.ArgumentParser(description='Parse raw experiment CSVs and produce summaries, stats and plots')
    p.add_argument('--raw-dir', default=None, help='Directory with raw CSVs (default: results/raw)')
    p.add_argument('--out-dir', default=None, help='Output directory for processed results (default: results/processed)')
    return p.parse_args()


def main():
    args = parse_args()
    ROOT = Path(__file__).resolve().parents[1]
    RAW = Path(args.raw_dir) if args.raw_dir else ROOT / 'results' / 'raw'
    OUT = Path(args.out_dir) if args.out_dir else ROOT / 'results' / 'processed'
    OUT.mkdir(parents=True, exist_ok=True)

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
    # basic aggregation
    grouped = all_df.groupby(['experiment_id','mode','threads']).agg({'hashes_per_second':['mean','std','count'],'elapsed_s':'mean'})
    grouped.columns = ['_'.join(col).strip() for col in grouped.columns.values]
    summary = grouped.reset_index()

    # compute speedup and efficiency relative to sequential baseline (threads==1, mode==sequential)
    baselines = all_df[(all_df['mode']=='sequential') & (all_df['threads']==1)].groupby('experiment_id')['hashes_per_second'].mean().to_dict()
    def baseline_for(row):
        return baselines.get(row['experiment_id'], None)

    summary['baseline_hps'] = summary.apply(baseline_for, axis=1)
    if 'hashes_per_second_mean' not in summary.columns and 'hashes_per_second_mean' in summary.columns:
        pass

    def compute_speedup(row):
        b = row['baseline_hps']
        if b is None or b == 0:
            return None
        return row['hashes_per_second_mean'] / b

    summary['speedup'] = summary.apply(compute_speedup, axis=1)
    summary['efficiency'] = summary.apply(lambda r: (r['speedup'] / r['threads']) if r['speedup'] not in (None, 0) else None, axis=1)

    summary.to_csv(OUT / 'summary.csv', index=False)
    print('Wrote', OUT / 'summary.csv')

    # Statistical analysis: ANOVA / Kruskal-Wallis and pairwise tests
    stats_out = OUT / 'stats_summary.csv'
    stats_txt = OUT / 'stats_summary.txt'
    stats_rows = []
    with open(stats_txt, 'w') as stf:
        stf.write('Statistical summary\n')
        stf.write('===================\n\n')

    try:
        from scipy import stats
        has_scipy = True
    except Exception:
        has_scipy = False

    # For each experiment_id and thread count, compare modes
    for (exp_id, threads), group_df in all_df.groupby(['experiment_id','threads']):
        modes = group_df['mode'].unique()
        mode_samples = {m: group_df[group_df['mode']==m]['hashes_per_second'].values for m in modes}
        counts = {m: len(vals) for m, vals in mode_samples.items()}

        # prepare human readable header
        header = f'Experiment: {exp_id}  Threads: {threads}  Modes: {",".join(modes)}'
        with open(stats_txt, 'a') as stf:
            stf.write(header + '\n')
            stf.write('-' * len(header) + '\n')
        if has_scipy and len(modes) >= 2:
            try:
                samples = [mode_samples[m] for m in modes]
                # ANOVA (one-way)
                fstat, p_anova = stats.f_oneway(*samples)
            except Exception:
                fstat, p_anova = (None, None)

            try:
                # Kruskal-Wallis (non-parametric)
                kstat, p_kruskal = stats.kruskal(*samples)
            except Exception:
                kstat, p_kruskal = (None, None)

            # pairwise Mann-Whitney U tests with Bonferroni correction
            from itertools import combinations
            pair_results = []
            pairs = list(combinations(modes, 2))
            for a,b in pairs:
                va = mode_samples[a]
                vb = mode_samples[b]
                if len(va) < 1 or len(vb) < 1:
                    pval = None
                else:
                    try:
                        u, pval = stats.mannwhitneyu(va, vb, alternative='two-sided')
                    except Exception:
                        pval = None
                pair_results.append((a,b,pval))

            # Bonferroni correction
            raw_ps = [p for (_,_,p) in pair_results if p is not None]
            m = len(raw_ps)
            corrected = []
            for (a,b,p) in pair_results:
                if p is None:
                    p_corr = None
                else:
                    p_corr = min(p * max(1, m), 1.0)
                corrected.append((a,b,p,p_corr))

            with open(stats_txt, 'a') as stf:
                stf.write(f'ANOVA p-value: {p_anova}  F-stat: {fstat}\n')
                stf.write(f'Kruskal p-value: {p_kruskal}  H-stat: {kstat}\n')
                stf.write('Pairwise Mann-Whitney U (p, bonferroni_corrected):\n')
                for a,b,p,p_corr in corrected:
                    stf.write(f'  {a} vs {b}: {p} , {p_corr}\n')
                stf.write('\n')

            stats_rows.append({
                'experiment_id': exp_id,
                'threads': threads,
                'modes': '|'.join(modes),
                'anova_p': p_anova,
                'kruskal_p': p_kruskal,
                'pairwise': ';'.join([f'{a}vs{b}:{p}->{pc}' for (a,b,p,pc) in corrected])
            })
        else:
            with open(stats_txt, 'a') as stf:
                if not has_scipy:
                    stf.write('scipy not available; statistical tests skipped.\n\n')
                else:
                    stf.write('Not enough groups to run tests.\n\n')

    # save stats summary CSV
    try:
        import csv
        with open(stats_out, 'w', newline='') as csvf:
            if stats_rows:
                writer = csv.DictWriter(csvf, fieldnames=list(stats_rows[0].keys()))
                writer.writeheader()
                for r in stats_rows:
                    writer.writerow(r)
        print('Wrote', stats_out)
    except Exception:
        pass

    # Optional plotting (if matplotlib available)
    try:
        import matplotlib.pyplot as plt
        PLOTS_DIR = OUT / 'plots'
        PLOTS_DIR.mkdir(parents=True, exist_ok=True)
        for exp_id in summary['experiment_id'].unique():
            s = summary[summary['experiment_id'] == exp_id]
            plt.figure(figsize=(8,5))
            for mode in s['mode'].unique():
                subset = s[s['mode'] == mode].sort_values('threads')
                plt.plot(subset['threads'], subset['hashes_per_second_mean'], marker='o', label=mode)
            plt.xlabel('threads')
            plt.ylabel('hashes/s (mean)')
            plt.title(f'Throughput vs threads - {exp_id}')
            plt.legend()
            plt.grid(True)
            plt.savefig(PLOTS_DIR / f'throughput_{exp_id}.png')
            plt.close()
        print('Saved plots to', PLOTS_DIR)
    except Exception:
        pass


if __name__ == '__main__':
    main()
