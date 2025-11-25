#!/usr/bin/env bash
# Regression test: verify alpha eigenvalue sweep never starts with NaN k_eff
# Mirrors ANL-5977 expectation that stored Keff provides next-iteration guess.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

make -f Makefile.1959 ax1_1959 >/dev/null

tmp_log="$(mktemp)"
trap 'rm -f "$tmp_log"' EXIT

./ax1_1959 inputs/geneve10_generated.inp >"$tmp_log" 2>&1

if grep -q "Initial k_eff =                       NaN" "$tmp_log"; then
  echo "ERROR: Alpha sweep started with NaN k_eff; regression detected." >&2
  exit 1
fi

if grep -q "STATE NAN MONITOR" "$tmp_log"; then
  echo "ERROR: State finiteness monitor triggered; see geneve10_transient_debug.log." >&2
  exit 1
fi

if grep -q "HYDRO NAN MONITOR" "$tmp_log"; then
  echo "ERROR: Hydro finiteness monitor triggered; see geneve10_transient_debug.log." >&2
  exit 1
fi

if grep -q "VISCOSITY NAN TRACE" "$tmp_log"; then
  echo "ERROR: Viscosity diagnostics reported non-finite pressure terms." >&2
  exit 1
fi

python3 <<'PY'
import csv, sys

qp_ref = 3484.515
tol = 0.05 * qp_ref
max_time = 0.0
samples = 0

with open("output_time_series.csv", newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        t = float(row["time_microsec"])
        max_time = max(max_time, t)
        if t <= 72.0 + 1e-9:
            samples += 1
            qp = float(row["QP_1e12_erg"])
            if abs(qp - qp_ref) > tol:
                sys.exit(f"ERROR: QP deviated >5% before 72 μs (t={t:.2f}, QP={qp:.3f})")

if max_time < 72.0 - 1e-9:
    sys.exit(f"ERROR: Simulation terminated before 72 μs (max time {max_time:.2f} μs)")

if samples == 0:
    sys.exit("ERROR: No samples found prior to 72 μs")
PY

echo "PASS: Alpha sweep k_eff initialization remains finite and diagnostics stayed clean."


