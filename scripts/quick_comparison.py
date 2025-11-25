#!/usr/bin/env python3
"""
Quick comparison of simulation results with reference data
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Load reference data
ref_df = pd.read_csv('validation/reference_data/geneve10_time_evolution.csv', comment='#')

# Load simulation data
sim_df = pd.read_csv('output_time_series.csv')

# Remove duplicate rows
sim_df = sim_df.drop_duplicates()

print("="*70)
print("GENEVE 10 TRANSIENT SIMULATION VS. REFERENCE (1959)")
print("="*70)
print()

print(f"Reference data: {len(ref_df)} time points from t=0 to t={ref_df['time_microsec'].max()} μsec")
print(f"Simulation data: {len(sim_df)} time points from t={sim_df['time_microsec'].min()} to t={sim_df['time_microsec'].max()} μsec")
print()

print("REFERENCE DATA (first and last):")
print(ref_df.iloc[[0, -1]])
print()

print("SIMULATION DATA:")
print(sim_df)
print()

# Calculate differences at overlapping time points
print("="*70)
print("STATUS")
print("="*70)
print()
print("⚠️  SIMULATION TERMINATED EARLY AT t = 3.75 μsec")
print("    Target: t = 200 μsec")
print("    Reason: System disassembled (W >> 1)")
print()
print("ISSUE:")
print("  - Initial QP: Simulation = 783, Reference = 3485 (4.4x difference)")
print("  - Alpha: Simulation = 0.0349, Reference = 0.01308 (2.7x difference)")
print("  - System is too supercritical in simulation")
print()
print("PROBABLE CAUSES:")
print("  1. Initial energy not properly set (should be ~3485 instead of ~783)")
print("  2. Generation time Λ = 0.1 μsec may be incorrect (affects alpha calculation)")
print("  3. Cross sections may need further adjustment")
print()
print("NEXT STEPS:")
print("  1. Adjust initial energy to match reference (QP ~ 3485)")
print("  2. Investigate generation time calculation")
print("  3. Consider using ICNTRL=1 to find critical geometry first")
print()

# Try to make a plot if we have enough data
if len(sim_df) >= 2:
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    # QP vs Time
    axes[0, 0].plot(ref_df['time_microsec'], ref_df['QP_1e12_erg'], 'o-', label='Reference (1959)', markersize=4)
    axes[0, 0].plot(sim_df['time_microsec'], sim_df['QP_1e12_erg'], 's--', label='Simulation', markersize=6)
    axes[0, 0].set_xlabel('Time (μsec)')
    axes[0, 0].set_ylabel('Total Energy QP (10¹² ergs)')
    axes[0, 0].legend()
    axes[0, 0].grid(True, alpha=0.3)
    axes[0, 0].set_title('Total Internal Energy vs. Time')
    
    # Power vs Time
    axes[0, 1].plot(ref_df['time_microsec'], ref_df['power_relative'], 'o-', label='Reference', markersize=4)
    axes[0, 1].plot(sim_df['time_microsec'], sim_df['power_relative'], 's--', label='Simulation', markersize=6)
    axes[0, 1].set_xlabel('Time (μsec)')
    axes[0, 1].set_ylabel('Relative Power')
    axes[0, 1].set_yscale('log')
    axes[0, 1].legend()
    axes[0, 1].grid(True, alpha=0.3)
    axes[0, 1].set_title('Relative Power vs. Time')
    
    # Alpha vs Time
    axes[1, 0].plot(ref_df['time_microsec'], ref_df['alpha_1_microsec'], 'o-', label='Reference', markersize=4)
    axes[1, 0].plot(sim_df['time_microsec'], sim_df['alpha_1_microsec'], 's--', label='Simulation', markersize=6)
    axes[1, 0].set_xlabel('Time (μsec)')
    axes[1, 0].set_ylabel('Alpha (μsec⁻¹)')
    axes[1, 0].legend()
    axes[1, 0].grid(True, alpha=0.3)
    axes[1, 0].set_title('Inverse Period Alpha vs. Time')
    
    # W vs Time
    axes[1, 1].plot(ref_df['time_microsec'], ref_df['W_dimensionless'], 'o-', label='Reference', markersize=4)
    axes[1, 1].plot(sim_df['time_microsec'], sim_df['W_dimensionless'], 's--', label='Simulation', markersize=6)
    axes[1, 1].set_xlabel('Time (μsec)')
    axes[1, 1].set_ylabel('W (dimensionless)')
    axes[1, 1].set_yscale('log')
    axes[1, 1].legend()
    axes[1, 1].grid(True, alpha=0.3)
    axes[1, 1].set_title('Stability Parameter W vs. Time')
    
    plt.tight_layout()
    plt.savefig('validation/plots/geneve10_preliminary_comparison.png', dpi=150)
    print(f"Plot saved: validation/plots/geneve10_preliminary_comparison.png")
else:
    print("Not enough simulation data for plotting.")

print()
print("="*70)

