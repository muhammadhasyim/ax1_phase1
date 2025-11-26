#!/usr/bin/env python3
"""Additional comparison plots: KE, CHECK, and spatial profiles."""

import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
from pathlib import Path

plt.style.use('seaborn-v0_8-whitegrid')

# Reference energy data from ANL-5977
ref_energy_time = np.array([200.0, 295.0, 300.0])
ref_KE = np.array([0.0, 13.50323, 20.97754])
ref_CHECK = np.array([-1.378e-4, -4.988e-4, -4.673e-4])

# Load simulation data
output_dir = Path(__file__).parent / "figures"

# Time series data
sim_data = pd.read_csv(Path(__file__).parent.parent / "output_time_series.csv")
sim_data.columns = sim_data.columns.str.strip()
sim_time = sim_data['time_microsec'].values
sim_KE = sim_data['TOTKE_1e12_erg'].values
sim_CHECK = sim_data['CHECK'].values

# Filter valid data
valid = (sim_time > 1) & (sim_time <= 305)
sim_time = sim_time[valid]
sim_KE = sim_KE[valid]
sim_CHECK = sim_CHECK[valid]

# Plot 1: Kinetic Energy
fig, ax = plt.subplots(figsize=(10, 7))
ax.plot(ref_energy_time, ref_KE, 'o-', color='blue', linewidth=2, markersize=12,
        label='1959 Reference')
ax.plot(sim_time, sim_KE, 's--', color='red', linewidth=2, markersize=4,
        label='Simulation')
ax.set_xlabel('Time (μsec)')
ax.set_ylabel('Kinetic Energy (10¹² ergs)')
ax.set_title('Geneva 10: Kinetic Energy vs Time')
ax.legend()
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(output_dir / "geneva10_KE_comparison.png", dpi=150)
plt.close()
print("Saved: geneva10_KE_comparison.png")

# Plot 2: Energy Balance CHECK
fig, ax = plt.subplots(figsize=(10, 7))
ax.plot(ref_energy_time, ref_CHECK, 'o-', color='blue', linewidth=2, markersize=12,
        label='1959 Reference')
ax.plot(sim_time, sim_CHECK, 's--', color='red', linewidth=2, markersize=4,
        label='Simulation')
ax.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
ax.set_xlabel('Time (μsec)')
ax.set_ylabel('CHECK (Energy Balance Error)')
ax.set_title('Geneva 10: Energy Conservation Check')
ax.legend()
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(output_dir / "geneva10_CHECK_comparison.png", dpi=150)
plt.close()
print("Saved: geneva10_CHECK_comparison.png")

# Load spatial data
ref_spatial = pd.read_csv(Path(__file__).parent.parent / "validation/reference_data/geneve10_spatial_t295_complete.csv")
sim_spatial = pd.read_csv(Path(__file__).parent.parent / "output_spatial_t200.csv")  # We only have t=200

# Plot 3: Spatial profiles comparison (reference at t=295)
fig, axes = plt.subplots(2, 2, figsize=(14, 10))

# Density
ax = axes[0, 0]
ax.plot(ref_spatial['radius_cm'], ref_spatial['density_g_cm3'], 'o-', color='blue', 
        label='Reference (t=295)')
ax.set_xlabel('Radius (cm)')
ax.set_ylabel('Density (g/cm³)')
ax.set_title('Density Profile')
ax.legend()
ax.grid(True, alpha=0.3)

# Velocity
ax = axes[0, 1]
ax.plot(ref_spatial['radius_cm'], ref_spatial['velocity_cm_microsec']*1000, 'o-', color='blue',
        label='Reference (t=295)')
ax.set_xlabel('Radius (cm)')
ax.set_ylabel('Velocity (10⁻³ cm/μsec)')
ax.set_title('Velocity Profile')
ax.legend()
ax.grid(True, alpha=0.3)

# Pressure
ax = axes[1, 0]
ax.plot(ref_spatial['radius_cm'], ref_spatial['pressure_megabars'], 'o-', color='blue',
        label='Reference (t=295)')
ax.set_xlabel('Radius (cm)')
ax.set_ylabel('Pressure (megabars)')
ax.set_title('Pressure Profile')
ax.legend()
ax.grid(True, alpha=0.3)

# Temperature
ax = axes[1, 1]
ax.plot(ref_spatial['radius_cm'], ref_spatial['temperature_keV']*1000, 'o-', color='blue',
        label='Reference (t=295)')
ax.set_xlabel('Radius (cm)')
ax.set_ylabel('Temperature (10⁻³ keV)')
ax.set_title('Temperature Profile')
ax.legend()
ax.grid(True, alpha=0.3)

plt.suptitle('Geneva 10 Spatial Profiles at t=295 μsec (Reference Data)', fontsize=14)
plt.tight_layout()
plt.savefig(output_dir / "geneva10_spatial_profiles.png", dpi=150)
plt.close()
print("Saved: geneva10_spatial_profiles.png")

print("\nAdditional plots generated!")
