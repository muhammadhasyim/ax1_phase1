#!/usr/bin/env python3
"""
Compare AX-1 Geneva 10 simulation results with 1959 ANL-5977 reference data.
Generates comparison plots and tables.
"""

import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
from pathlib import Path

# Set up matplotlib style
plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 12
plt.rcParams['axes.labelsize'] = 14
plt.rcParams['axes.titlesize'] = 16

# =============================================================================
# Reference data from ANL-5977 (1959) Geneva 10 problem
# CORRECTED extraction from the paper's output tables
# Units: TIME (μsec), QP (10^12 ergs), POWER (relative), ALPHA (μsec^-1), W (dimensionless)
# =============================================================================

# Data from the 1959 paper - carefully extracted from the LaTeX tables
# Note: The paper shows output at various time points

# ACTUAL DATA FROM ANL-5977 (1959) - extracted directly from paper tables
# Only using data points that appear in the original printout
ref_1959_time = np.array([
    0.0,      # Initial
    132.0,    # t=1.32E02 (from table)
    210.0,    # t=2.10E02
    240.0,    # t=2.40E02
    262.0,    # t=2.62E02
    270.0,    # t=2.70E02
    274.0,    # t=2.74E02
    280.0,    # t=2.80E02
    282.0,    # t=2.82E02
    284.0,    # t=2.84E02
    286.0,    # t=2.86E02
    288.0,    # t=2.88E02
    290.0,    # t=2.90E02
    292.0,    # t=2.92E02
    294.0,    # t=2.94E02
    295.0,    # t=2.95E02
    295.5,    # t=2.955E02
    296.0,    # t=2.96E02
    296.5,    # t=2.965E02
    297.0,    # t=2.97E02
    297.5,    # t=2.975E02
    298.0,    # t=2.98E02
    298.5,    # t=2.985E02
    299.0,    # t=2.99E02
    299.5,    # t=2.995E02
    300.0,    # t=3.00E02
])

ref_1959_QP = np.array([
    3484.515,  # Initial (TOTAL INTERNAL ENERGY = 3.484515E03)
    3842.258,  # t=132
    4614.118,  # t=210
    5194.141,  # t=240
    5790.050,  # t=262
    6052.932,  # t=270
    6194.982,  # t=274
    6422.045,  # t=280
    6501.495,  # t=282
    6582.751,  # t=284
    6665.751,  # t=286
    6750.404,  # t=288
    6836.587,  # t=290
    6924.139,  # t=292
    7012.855,  # t=294
    7057.554,  # t=295
    7079.975,  # t=295.5
    7102.438,  # t=296
    7124.940,  # t=296.5
    7147.474,  # t=297
    7170.036,  # t=297.5
    7192.619,  # t=298
    7215.218,  # t=298.5
    7237.827,  # t=299
    7260.439,  # t=299.5
    7283.048,  # t=300
])

ref_1959_power = np.array([
    1.0,       # Initial (normalized)
    5.617822,  # t=132
    15.58345,  # t=210
    23.07269,  # t=240
    30.76770,  # t=262
    34.16063,  # t=270
    35.97139,  # t=274
    38.80450,  # t=280
    39.72579,  # t=282
    40.62824,  # t=284
    41.50012,  # t=286
    42.32701,  # t=288
    43.09212,  # t=290
    43.77629,  # t=292
    44.35807,  # t=294
    44.69970,  # t=295
    44.84325,  # t=295.5
    44.92919,  # t=296
    45.00503,  # t=296.5
    45.07040,  # t=297
    45.12488,  # t=297.5
    45.16808,  # t=298
    45.19958,  # t=298.5
    45.21895,  # t=299
    45.22577,  # t=299.5 - PEAK POWER!
    45.21964,  # t=300 - starting to decrease
])

# Alpha values from 1959 paper - extracted directly
ref_1959_alpha = np.array([
    0.013084,    # Initial target
    0.01307967,  # t=132
    0.01308135,  # t=210
    0.01308255,  # t=240
    0.01307606,  # t=262
    0.01291253,  # t=270 - starting to decrease!
    0.01263538,  # t=274
    0.01173227,  # t=280
    0.01123132,  # t=282
    0.01061646,  # t=284
    0.00986464,  # t=286
    0.00895733,  # t=288
    0.00787613,  # t=290
    0.00660121,  # t=292
    0.00511474,  # t=294
    0.00427507,  # t=295
    0.00382939,  # t=295.5
    0.00337305,  # t=296
    0.00290279,  # t=296.5
    0.00241626,  # t=297
    0.00191396,  # t=297.5
    0.00139451,  # t=298
    0.00085673,  # t=298.5
    0.00030183,  # t=299
    -0.00027106, # t=299.5 - ALPHA GOES NEGATIVE!
    -0.00086276, # t=300
])

# W values from 1959 paper - extracted directly
ref_1959_W = np.array([
    0.0,       # t=0
    0.03390,   # t=132
    0.07019,   # t=210
    0.09746,   # t=240
    0.13505,   # t=262
    0.15616,   # t=270
    0.16737,   # t=274
    0.19287,   # t=280
    0.19803,   # t=282
    0.19194,   # t=284
    0.19578,   # t=286
    0.19961,   # t=288
    0.21781,   # t=290
    0.22937,   # t=292
    0.21921,   # t=294
    0.08428,   # t=295 - TIME STEP HALVED!
    0.03102,   # t=295.5
    0.02742,   # t=296
    0.03258,   # t=296.5
    0.03735,   # t=297
    0.04068,   # t=297.5
    0.04233,   # t=298
    0.04214,   # t=298.5
    0.04009,   # t=299
    0.03625,   # t=299.5
    0.03206,   # t=300
])

# =============================================================================
# Load our simulation results
# =============================================================================

def load_simulation_data(csv_file):
    """Load simulation data from CSV file."""
    df = pd.read_csv(csv_file)
    # Clean column names (remove leading/trailing spaces)
    df.columns = df.columns.str.strip()
    return df

# =============================================================================
# Plotting functions
# =============================================================================

def plot_QP_comparison(ref_time, ref_QP, sim_time, sim_QP, output_file):
    """Plot total energy QP comparison."""
    fig, ax = plt.subplots(figsize=(10, 7))
    
    ax.plot(ref_time, ref_QP, 'o-', color='blue', linewidth=2, markersize=8, 
            label='1959 ANL-5977 Reference')
    ax.plot(sim_time, sim_QP, 's--', color='red', linewidth=2, markersize=6,
            label='Current Simulation')
    
    ax.set_xlabel('Time (μsec)')
    ax.set_ylabel('Total Energy QP (10^12 ergs)')
    ax.set_title('Geneva 10: Total Energy vs Time')
    ax.legend(loc='upper left')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def plot_power_comparison(ref_time, ref_power, sim_time, sim_power, output_file):
    """Plot power comparison."""
    fig, ax = plt.subplots(figsize=(10, 7))
    
    ax.semilogy(ref_time, ref_power, 'o-', color='blue', linewidth=2, markersize=8,
                label='1959 ANL-5977 Reference')
    ax.semilogy(sim_time, sim_power, 's--', color='red', linewidth=2, markersize=6,
                label='Current Simulation')
    
    ax.set_xlabel('Time (μsec)')
    ax.set_ylabel('Relative Power')
    ax.set_title('Geneva 10: Power vs Time (Log Scale)')
    ax.legend(loc='upper left')
    ax.grid(True, alpha=0.3, which='both')
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def plot_alpha_comparison(ref_time, ref_alpha, sim_time, sim_alpha, output_file):
    """Plot alpha (inverse period) comparison."""
    fig, ax = plt.subplots(figsize=(10, 7))
    
    ax.plot(ref_time, ref_alpha * 1000, 'o-', color='blue', linewidth=2, markersize=8,
            label='1959 ANL-5977 Reference')
    ax.plot(sim_time, sim_alpha * 1000, 's--', color='red', linewidth=2, markersize=6,
            label='Current Simulation')
    
    ax.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax.set_xlabel('Time (μsec)')
    ax.set_ylabel('Alpha (10^-3 / μsec)')
    ax.set_title('Geneva 10: Reactivity Parameter α vs Time')
    ax.legend(loc='upper right')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def plot_W_comparison(ref_time, ref_W, sim_time, sim_W, output_file):
    """Plot W stability parameter comparison."""
    fig, ax = plt.subplots(figsize=(10, 7))
    
    ax.plot(ref_time, ref_W, 'o-', color='blue', linewidth=2, markersize=8,
            label='1959 ANL-5977 Reference')
    ax.plot(sim_time, sim_W, 's--', color='red', linewidth=2, markersize=6,
            label='Current Simulation')
    
    ax.axhline(y=0.3, color='orange', linestyle='--', linewidth=1.5, label='W limit (0.3)')
    ax.set_xlabel('Time (μsec)')
    ax.set_ylabel('W (dimensionless)')
    ax.set_title('Geneva 10: Stability Parameter W vs Time')
    ax.legend(loc='upper left')
    ax.grid(True, alpha=0.3)
    ax.set_ylim(0, 0.5)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def plot_combined_comparison(ref_time, ref_QP, ref_power, ref_alpha, ref_W,
                             sim_time, sim_QP, sim_power, sim_alpha, sim_W,
                             output_file):
    """Create a 2x2 subplot with all comparisons."""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # QP
    ax = axes[0, 0]
    ax.plot(ref_time, ref_QP, 'o-', color='blue', linewidth=2, markersize=6, label='1959 Reference')
    ax.plot(sim_time, sim_QP, 's--', color='red', linewidth=2, markersize=4, label='Simulation')
    ax.set_xlabel('Time (μsec)')
    ax.set_ylabel('QP (10^12 ergs)')
    ax.set_title('Total Energy')
    ax.legend(loc='upper left', fontsize=10)
    ax.grid(True, alpha=0.3)
    
    # Power
    ax = axes[0, 1]
    ax.semilogy(ref_time, ref_power, 'o-', color='blue', linewidth=2, markersize=6, label='1959 Reference')
    ax.semilogy(sim_time, sim_power, 's--', color='red', linewidth=2, markersize=4, label='Simulation')
    ax.set_xlabel('Time (μsec)')
    ax.set_ylabel('Relative Power')
    ax.set_title('Power (Log Scale)')
    ax.legend(loc='upper left', fontsize=10)
    ax.grid(True, alpha=0.3, which='both')
    
    # Alpha
    ax = axes[1, 0]
    ax.plot(ref_time, ref_alpha * 1000, 'o-', color='blue', linewidth=2, markersize=6, label='1959 Reference')
    ax.plot(sim_time, sim_alpha * 1000, 's--', color='red', linewidth=2, markersize=4, label='Simulation')
    ax.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax.set_xlabel('Time (μsec)')
    ax.set_ylabel('Alpha (10^-3 / μsec)')
    ax.set_title('Reactivity Parameter')
    ax.legend(loc='upper right', fontsize=10)
    ax.grid(True, alpha=0.3)
    
    # W
    ax = axes[1, 1]
    ax.plot(ref_time, ref_W, 'o-', color='blue', linewidth=2, markersize=6, label='1959 Reference')
    ax.plot(sim_time, sim_W, 's--', color='red', linewidth=2, markersize=4, label='Simulation')
    ax.axhline(y=0.3, color='orange', linestyle='--', linewidth=1.5, label='W limit')
    ax.set_xlabel('Time (μsec)')
    ax.set_ylabel('W')
    ax.set_title('Stability Parameter (W ~ dt^2)')
    ax.legend(loc='upper left', fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.set_ylim(0, 0.5)
    
    plt.suptitle('Geneva 10 Transient: 1959 ANL-5977 vs Current Simulation', fontsize=16, y=1.02)
    plt.tight_layout()
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def create_comparison_table(ref_time, ref_QP, ref_power, ref_alpha,
                            sim_time, sim_QP, sim_power, sim_alpha, output_file):
    """Create a comparison table at key time points using filtered data."""
    
    # Key time points for comparison
    key_times = [0, 50, 100, 150, 200, 250, 300]
    
    rows = []
    for t in key_times:
        # Find closest reference point
        ref_idx = np.argmin(np.abs(ref_time - t))
        
        # Find closest simulation point
        sim_idx = np.argmin(np.abs(sim_time - t))
        
        if ref_idx < len(ref_time) and sim_idx < len(sim_time):
            row = {
                'Time (μsec)': t,
                'Ref QP': f"{ref_QP[ref_idx]:.1f}",
                'Sim QP': f"{sim_QP[sim_idx]:.1f}",
                'Ref Power': f"{ref_power[ref_idx]:.2f}",
                'Sim Power': f"{sim_power[sim_idx]:.2f}",
                'Ref α (10^-3)': f"{ref_alpha[ref_idx]*1000:.3f}",
                'Sim α (10^-3)': f"{sim_alpha[sim_idx]*1000:.3f}",
            }
            rows.append(row)
    
    df = pd.DataFrame(rows)
    
    # Save to file
    with open(output_file, 'w') as f:
        f.write("=" * 90 + "\n")
        f.write("Geneva 10 Transient Comparison: 1959 ANL-5977 vs Current Simulation\n")
        f.write("=" * 90 + "\n\n")
        f.write(df.to_string(index=False))
        f.write("\n\n")
        f.write("Notes:\n")
        f.write("- QP: Total energy in 10^12 ergs\n")
        f.write("- Power: Relative power (initial = 1.0)\n")
        f.write("- α: Reactivity parameter in 10^-3 μsec^-1\n")
        f.write("\nKey observations from 1959 paper:\n")
        f.write("- Alpha stays ~constant (0.0130-0.0131) until t~270 μsec\n")
        f.write("- Hydrodynamic expansion begins around t~270-280 μsec\n")
        f.write("- Alpha goes negative around t~299.5 μsec\n")
        f.write("- Peak power ~45 at t~300 μsec, then decreases\n")
    
    print(f"Saved: {output_file}")
    return df

# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    # Create output directory (relative to script location)
    output_dir = Path(__file__).parent / "figures"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Load simulation data
    csv_file = Path(__file__).parent.parent / "output_time_series.csv"
    if csv_file.exists():
        sim_data = load_simulation_data(csv_file)
        print(f"Loaded simulation data: {len(sim_data)} time points")
        
        # Extract simulation arrays
        sim_time = sim_data['time_microsec'].values
        sim_QP = sim_data['QP_1e12_erg'].values
        sim_power = sim_data['power_relative'].values
        sim_alpha = sim_data['alpha_1_microsec'].values
        sim_W = sim_data['W_dimensionless'].values
        
        # Filter out blowup points (where values become unphysical)
        # Keep only points where QP < 1e6 (reasonable range)
        # Also skip the first data point (t < 1 μsec) which has initialization artifacts
        valid_mask = (sim_time > 1.0) & (sim_QP < 1e6) & (np.abs(sim_alpha) < 1.0) & (sim_W < 10)
        sim_time = sim_time[valid_mask]
        sim_QP = sim_QP[valid_mask]
        sim_power = sim_power[valid_mask]
        sim_alpha = sim_alpha[valid_mask]
        sim_W = sim_W[valid_mask]
        print(f"After filtering blowup points: {len(sim_time)} time points")
        
        # Clip W values for plotting (some may be very large)
        sim_W_plot = np.clip(sim_W, 0, 1.0)
        
        # Generate plots
        plot_QP_comparison(ref_1959_time, ref_1959_QP, sim_time, sim_QP,
                          output_dir / "geneva10_QP_comparison.png")
        
        plot_power_comparison(ref_1959_time, ref_1959_power, sim_time, sim_power,
                             output_dir / "geneva10_power_comparison.png")
        
        plot_alpha_comparison(ref_1959_time, ref_1959_alpha, sim_time, sim_alpha,
                             output_dir / "geneva10_alpha_comparison.png")
        
        plot_W_comparison(ref_1959_time, ref_1959_W, sim_time, sim_W_plot,
                         output_dir / "geneva10_W_comparison.png")
        
        plot_combined_comparison(ref_1959_time, ref_1959_QP, ref_1959_power, ref_1959_alpha, ref_1959_W,
                                sim_time, sim_QP, sim_power, sim_alpha, sim_W_plot,
                                output_dir / "geneva10_combined_comparison.png")
        
        # Create comparison table (using filtered data)
        create_comparison_table(ref_1959_time, ref_1959_QP, ref_1959_power, ref_1959_alpha,
                               sim_time, sim_QP, sim_power, sim_alpha,
                               output_dir / "geneva10_comparison_table.txt")
        
        print("\nAll comparison plots and tables generated!")
        
    else:
        print(f"Error: Could not find {csv_file}")
        print("Please run the simulation first to generate output data.")
