#!/usr/bin/env python3
"""Analyze simulation output after H optical thickness fix."""

import csv

print("Our simulation after H optical thickness fix:")
print("=" * 70)

try:
    with open('output_time_series.csv') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
except FileNotFoundError:
    print("ERROR: output_time_series.csv not found")
    exit(1)

print('t(us)  |     W      |   W_CFL    |   W_VISC   |      QP')
print('-' * 70)

for row in rows[:20]:
    t = float(row['time_microsec'])
    w = float(row['W_dimensionless'])
    w_cfl = float(row['W_cfl'])
    w_visc = float(row['W_visc'])
    qp = float(row['QP_1e12_erg'])
    print(f'{t:6.2f} | {w:10.6f} | {w_cfl:10.6f} | {w_visc:10.6f} | {qp:12.3f}')

print('-' * 70)
print(f'Total rows: {len(rows)}')
print(f'Final time: {float(rows[-1]["time_microsec"]):.2f} us')

print('\nReference W values from ANL-5977:')
ref = [(0, 0), (2, 0.017178), (6, 0.017378), (12, 0.017699), (20, 0.018169), (72, 0.022775)]
for t, w in ref:
    print(f'  t={t:6.2f}: W={w:.6f}')

