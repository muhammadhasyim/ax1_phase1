#!/usr/bin/env bash
set -euo pipefail
FC=${FC:-gfortran}
FFLAGS=${FFLAGS:--std=f2008 -O2 -Wall -Wextra}
make clean >/dev/null
make FC="$FC" FFLAGS="$FFLAGS" >/dev/null
tmp_output=$(mktemp)
trap 'rm -f "$tmp_output"' EXIT
set +e
./ax1 inputs/sample_phase1.deck > "$tmp_output"
status=$?
set -e
head -n 8 "$tmp_output"
if [ $status -ne 0 ]; then
  echo "ax1 exited with status $status" >&2
  exit $status
fi
if ! grep -q "Done." "$tmp_output"; then
  echo "Simulation did not complete" >&2
  exit 1
fi
last_transport_line=$(awk '/H\/neu=/{line=$0} END{print line}' "$tmp_output")
if [ -z "$last_transport_line" ]; then
  echo "No transport output captured" >&2
  exit 1
fi
read -r _ time_tok _ alpha_val _ keff_val _ <<<"$last_transport_line"
python3 - "$time_tok" "$alpha_val" "$keff_val" <<'PY'
import math, sys
time_tok, alpha_val, keff_val = sys.argv[1:]
try:
    t = float(time_tok)
    alpha = float(alpha_val)
    keff = float(keff_val)
except ValueError:
    sys.exit("Could not parse transport summary line")
if not math.isclose(t, 0.21000, rel_tol=0.0, abs_tol=5e-3):
    sys.exit(f"Unexpected final time: {t}")
if not math.isclose(alpha, 1.0, rel_tol=0.0, abs_tol=5e-6):
    sys.exit(f"Unexpected alpha: {alpha}")
if not math.isclose(keff, 0.02236, rel_tol=0.0, abs_tol=5e-5):
    sys.exit(f"Unexpected keff: {keff}")
PY
echo "Smoke test OK."
