#!/usr/bin/env python3
"""
Quick regression check for the Geneve 10 transient reproduction.

The script compares the current simulator output (`output_time_series.csv`)
against the digitized reference trace in
`validation/reference_data/geneve10_time_evolution.csv`.

Only the early portion of the burst (t ≤ limit) is checked because later
times diverge once the published data stops.  The check verifies:

* QP (total energy) stays within ±limit_% of reference
* Power tracks reference within tolerance
* Alpha stays close to reference
* W (stability metric) does not exceed tolerance
"""

from __future__ import annotations

import argparse
import pathlib
import sys
from typing import Tuple

import numpy as np
import pandas as pd


def _closest_row(sim: pd.DataFrame, target_time: float) -> pd.Series:
    idx = (sim["time_microsec"] - target_time).abs().idxmin()
    return sim.loc[idx]


def _percentage_error(sim_val: float, ref_val: float) -> float:
    if ref_val == 0:
        return np.inf
    return abs(sim_val - ref_val) / abs(ref_val)


def run_check(
    sim_csv: pathlib.Path,
    ref_csv: pathlib.Path,
    time_limit: float,
    qp_tol: float,
    power_tol: float,
    alpha_tol: float,
    w_tol: float,
) -> Tuple[bool, pd.DataFrame]:
    ref = pd.read_csv(ref_csv, comment="#")
    ref = ref[ref["time_microsec"] <= time_limit].reset_index(drop=True)

    sim = pd.read_csv(sim_csv, skipinitialspace=True)
    sim = sim.apply(pd.to_numeric, errors="coerce")
    sim = sim.dropna(
        subset=["time_microsec", "QP_1e12_erg", "power_relative", "alpha_1_microsec", "W_dimensionless"]
    )

    rows = []
    passed = True
    for _, ref_row in ref.iterrows():
        sim_row = _closest_row(sim, ref_row["time_microsec"])
        qp_err = _percentage_error(sim_row["QP_1e12_erg"], ref_row["QP_1e12_erg"])
        power_err = _percentage_error(sim_row["power_relative"], ref_row["power_relative"])
        alpha_err = _percentage_error(sim_row["alpha_1_microsec"], ref_row["alpha_1_microsec"])
        w_err = _percentage_error(sim_row["W_dimensionless"], ref_row["W_dimensionless"])

        rows.append(
            {
                "time": ref_row["time_microsec"],
                "sim_QP": sim_row["QP_1e12_erg"],
                "ref_QP": ref_row["QP_1e12_erg"],
                "QP_err_pct": qp_err * 100,
                "sim_power": sim_row["power_relative"],
                "ref_power": ref_row["power_relative"],
                "power_err_pct": power_err * 100,
                "sim_alpha": sim_row["alpha_1_microsec"],
                "ref_alpha": ref_row["alpha_1_microsec"],
                "alpha_err_pct": alpha_err * 100,
                "sim_W": sim_row["W_dimensionless"],
                "ref_W": ref_row["W_dimensionless"],
                "W_err_pct": w_err * 100,
            }
        )

        if (
            qp_err > qp_tol
            or power_err > power_tol
            or alpha_err > alpha_tol
            or w_err > w_tol
        ):
            passed = False

    summary = pd.DataFrame(rows)
    return passed, summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sim-csv",
        type=pathlib.Path,
        default=pathlib.Path("output_time_series.csv"),
        help="Simulator CSV output to check (default: %(default)s)",
    )
    parser.add_argument(
        "--ref-csv",
        type=pathlib.Path,
        default=pathlib.Path("validation/reference_data/geneve10_time_evolution.csv"),
        help="Reference CSV to compare against",
    )
    parser.add_argument(
        "--time-limit",
        type=float,
        default=72.0,
        help="Only compare reference rows with time ≤ limit (μs)",
    )
    parser.add_argument("--qp-tol", type=float, default=0.05, help="QP tolerance (fractional)")
    parser.add_argument("--power-tol", type=float, default=0.05, help="Power tolerance (fractional)")
    parser.add_argument("--alpha-tol", type=float, default=0.10, help="Alpha tolerance (fractional)")
    parser.add_argument("--w-tol", type=float, default=0.10, help="W tolerance (fractional)")
    args = parser.parse_args()

    ok, summary = run_check(
        args.sim_csv,
        args.ref_csv,
        args.time_limit,
        args.qp_tol,
        args.power_tol,
        args.alpha_tol,
        args.w_tol,
    )
    pd.options.display.float_format = "{:0.6f}".format
    print(summary.to_string(index=False))

    if not ok:
        print("Geneve 10 regression FAILED", file=sys.stderr)
        sys.exit(1)
    print("Geneve 10 regression PASSED")


if __name__ == "__main__":
    main()

