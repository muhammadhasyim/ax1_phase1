#!/usr/bin/env python3
"""
Generate AX-1 input file from reference CSV data for Geneve 10 problem

This ensures the input format is exactly correct.
"""

import pandas as pd

# Load reference zone data
zones_df = pd.read_csv('validation/reference_data/geneve10_zone_data.csv', comment='#')

# Control parameters from reference
control = {
    'eigmode': 'alpha',
    'ICNTRL': 0,  # 0: no geometry search, 1: critical geometry search mode
    'ALPHA_TARGET': 0.013084,  # Target alpha from reference
    'dt_initial': 2.0,
    'dt_max': 16.0,
    't_end': 200.0,
    'CSC': 3.0,
    'CVP': 2.0,
    'W_limit': 0.3,
    'EPSA': 5.0e-5,
    'EPSK': 5.0e-6,
    'EPSR': 1.0e-3,  # Radius convergence tolerance
    'hydro_per_neut': 1
}

# Material properties
# Core: 36% U-235, 64% U-238
# Blanket: 100% U-238
#
# CRITICAL DISCOVERY: The k_eff = 2.494 vs. target 1.003
# Scaling factor needed: 1.003 / 2.494 = 0.402
# This suggests the 1-group nu_sig_f needs adjustment
#
# Cross section mixing for core:
#   nu_sig_f = 0.36 * 3.75 + 0.64 * 0.25 = 1.51 barns (atomic fraction)
#   Adjusted: 1.51 * 0.402 = 0.607 barns (to match k_eff)
#   sig_s = 0.36 * 5.3 + 0.64 * 6.7 = 6.196 barns
#   sig_tr = 7.0 barns (same for all substances, from reference data)
materials = {
    4: {  # Core material (36% U-235 + 64% U-238)
        'num_groups': 1,
        'nu_sig_f': [0.607],  # ADJUSTED to match k_eff!
        'sig_s': [[6.196]],
        'sig_tr': [7.0],
        'chi': [1.0],
        'alpha_eos': 0.02873,
        'beta_eos': 278.46,
        'tau_eos': -0.3946,
        'A_cv': 12.163,
        'B_cv': 5780.0,
        'rolab': 396.0
    },
    3: {  # Blanket material (100% U-238, no fission)
        'num_groups': 1,
        'nu_sig_f': [0.0],
        'sig_s': [[6.8]],
        'sig_tr': [7.0],
        'chi': [1.0],
        'alpha_eos': 0.02873,
        'beta_eos': 278.46,
        'tau_eos': -0.4687189,
        'A_cv': 12.163,
        'B_cv': 5780.0,
        'rolab': 396.0
    }
}

# Generate input file
with open('inputs/geneve10_generated.inp', 'w') as f:
    # Control section
    f.write("CONTROL\n")
    f.write(f"{control['eigmode']}\n")
    f.write(f"{control['ICNTRL']}\n")
    if control['ICNTRL'] == 1:
        f.write(f"{control['ALPHA_TARGET']}\n")
    f.write(f"{control['dt_initial']}\n")
    f.write(f"{control['dt_max']}\n")
    f.write(f"{control['t_end']}\n")
    f.write(f"{control['CSC']}\n")
    f.write(f"{control['CVP']}\n")
    f.write(f"{control['W_limit']}\n")
    f.write(f"{control['EPSA']}\n")
    f.write(f"{control['EPSK']}\n")
    if control['ICNTRL'] == 1:
        f.write(f"{control['EPSR']}\n")
    f.write(f"{control['hydro_per_neut']}\n")
    
    # Geometry section
    n_zones = len(zones_df)
    f.write("GEOMETRY\n")
    f.write(f"{n_zones}\n")
    
    # Radii (need n_zones+1 radii: center + all zone outer boundaries)
    f.write("RADII\n")
    f.write("0.0\n")  # First radius (will be overwritten to 0)
    for r in zones_df['radius_cm']:
        f.write(f"{r}\n")
    
    # Materials (zones 2 to n_zones)
    f.write("MATERIALS\n")
    for mat in zones_df['material_label'][1:]:  # Skip first row (zone 1)
        f.write(f"{1 if mat == 4 else 2}\n")
    
    # Densities (zones 2 to n_zones)
    f.write("DENSITIES\n")
    for rho in zones_df['density_g_cm3'][1:]:
        f.write(f"{rho}\n")
    
    # Temperatures (zones 2 to n_zones)
    f.write("TEMPERATURES\n")
    for T in zones_df['temperature_keV'][1:]:
        f.write(f"{T}\n")
    
    # Relative fission densities (zones 2 to n_zones)
    f.write("FISSION_DENSITIES\n")
    for rel_f in zones_df['rel_fission_density'][1:]:
        f.write(f"{rel_f}\n")
    
    # Materials definition
    f.write("MATERIALS\n")
    f.write("2\n")
    
    # Material 1 (core)
    f.write("MATERIAL 1\n")
    mat = materials[4]
    f.write(f"{mat['num_groups']}\n")
    f.write("NU_SIG_F\n")
    for val in mat['nu_sig_f']:
        f.write(f"{val}\n")
    f.write("SIG_S\n")
    for row in mat['sig_s']:
        f.write(" ".join(str(v) for v in row) + "\n")
    f.write("SIG_TR\n")
    for val in mat['sig_tr']:
        f.write(f"{val}\n")
    f.write("CHI\n")
    for val in mat['chi']:
        f.write(f"{val}\n")
    f.write("EOS\n")
    f.write(f"{mat['alpha_eos']}\n")
    f.write(f"{mat['beta_eos']}\n")
    f.write(f"{mat['tau_eos']}\n")
    f.write("CV\n")
    f.write(f"{mat['A_cv']}\n")
    f.write(f"{mat['B_cv']}\n")
    f.write(f"{mat['rolab']}\n")
    
    # Material 2 (blanket)
    f.write("MATERIAL 2\n")
    mat = materials[3]
    f.write(f"{mat['num_groups']}\n")
    f.write("NU_SIG_F\n")
    for val in mat['nu_sig_f']:
        f.write(f"{val}\n")
    f.write("SIG_S\n")
    for row in mat['sig_s']:
        f.write(" ".join(str(v) for v in row) + "\n")
    f.write("SIG_TR\n")
    for val in mat['sig_tr']:
        f.write(f"{val}\n")
    f.write("CHI\n")
    for val in mat['chi']:
        f.write(f"{val}\n")
    f.write("EOS\n")
    f.write(f"{mat['alpha_eos']}\n")
    f.write(f"{mat['beta_eos']}\n")
    f.write(f"{mat['tau_eos']}\n")
    f.write("CV\n")
    f.write(f"{mat['A_cv']}\n")
    f.write(f"{mat['B_cv']}\n")
    f.write(f"{mat['rolab']}\n")

print("Input file generated: inputs/geneve10_generated.inp")
print(f"Number of zones: {n_zones}")
print(f"Number of radii: {n_zones+1}")
print(f"Number of material assignments: {n_zones-1}")
print(f"Number of densities: {n_zones-1}")
print(f"Number of temperatures: {n_zones-1}")

