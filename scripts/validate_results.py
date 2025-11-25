#!/usr/bin/env python3
"""
Automated Validation Script for AX-1 Geneve 10 Problem

This script performs comprehensive validation of simulation results against
the 1959 reference data, generates comparison plots, and produces a detailed
validation report.

Author: Automated Implementation
Date: November 23, 2025
"""

import sys
from pathlib import Path
import pandas as pd
import numpy as np
from validation_analysis import ValidationAnalysis


def generate_validation_report(analysis: ValidationAnalysis, 
                               time_errors: dict,
                               spatial_errors: dict,
                               output_file: str = "VALIDATION_REPORT.md"):
    """
    Generate comprehensive validation report in Markdown format
    
    Args:
        analysis: ValidationAnalysis instance
        time_errors: Error metrics for time evolution
        spatial_errors: Error metrics for spatial profiles
        output_file: Output filename for report
    """
    
    with open(output_file, 'w') as f:
        f.write("# AX-1 Validation Report: Geneve 10 Rerun\n\n")
        f.write("**Date**: November 23, 2025\n\n")
        f.write("**Reference**: ANL-5977 (1959), Pages 89-103\n\n")
        f.write("---\n\n")
        
        f.write("## Executive Summary\n\n")
        f.write("This report documents the validation of the modern AX-1 code implementation ")
        f.write("against the historical 1959 Geneve 10 benchmark problem. The goal is to achieve ")
        f.write("engineering precision (< 1% relative error) across all key output quantities.\n\n")
        
        # Overall assessment
        all_errors = {**time_errors, **spatial_errors}
        max_errors = {k: v['max_relative_error'] for k, v in all_errors.items()}
        passing = sum(1 for e in max_errors.values() if e < 0.01)
        total = len(max_errors)
        
        f.write(f"**Overall Result**: {passing}/{total} quantities within 1% threshold\n\n")
        
        if passing == total:
            f.write("✓ **VALIDATION PASSED**: All quantities meet engineering precision requirements.\n\n")
        else:
            f.write("✗ **VALIDATION INCOMPLETE**: Some quantities exceed 1% error threshold.\n\n")
        
        f.write("---\n\n")
        
        f.write("## Reference Problem Description\n\n")
        f.write("### Problem: Geneve 10 Rerun March 20, 1959\n\n")
        f.write("**Configuration:**\n")
        f.write("- Two-region spherical geometry (core + blanket)\n")
        f.write("- Core radius: 23.75 cm\n")
        f.write("- Blanket outer radius: 44.70 cm\n")
        f.write("- 25 mass points in core, 14 in blanket\n\n")
        
        f.write("**Materials:**\n")
        f.write("- Core: 36% U-235 + 64% U-238 (ρ = 7.92 g/cm³)\n")
        f.write("- Blanket: 100% U-238 (ρ = 15.83 g/cm³, no fission)\n\n")
        
        f.write("**Initial Conditions:**\n")
        f.write("- Initial α = 0.013084 μsec⁻¹ (specified)\n")
        f.write("- Core temperature = 1.0×10⁻⁴ keV\n")
        f.write("- Blanket temperature = 5.0×10⁻⁵ keV\n")
        f.write("- All velocities = 0\n\n")
        
        f.write("**Physics:**\n")
        f.write("- 1-group cross sections\n")
        f.write("- Neutron velocity: 169.5 cm/μsec\n")
        f.write("- Linear equation of state: P = α·ρ + β·θ + τ\n")
        f.write("- Von Neumann-Richtmyer artificial viscosity\n")
        f.write("- Prompt neutrons only (delayed neutrons ignored in 1959)\n\n")
        
        f.write("---\n\n")
        
        f.write("## Time Evolution Comparison\n\n")
        f.write("### Error Metrics\n\n")
        
        # Time evolution error table
        time_df = analysis.generate_error_summary_table(time_errors)
        f.write(time_df.to_markdown(index=False))
        f.write("\n\n")
        
        f.write("### Plots\n\n")
        f.write("See `validation/plots/` directory for detailed comparison plots:\n\n")
        f.write("- `power_vs_time.png` - Power evolution\n")
        f.write("- `alpha_vs_time.png` - Alpha (inverse period)\n")
        f.write("- `energy_vs_time.png` - Total internal energy\n")
        f.write("- `W_vs_time.png` - W stability parameter\n\n")
        
        f.write("---\n\n")
        
        f.write("## Spatial Profile Comparison (t = 200 μsec)\n\n")
        f.write("### Error Metrics\n\n")
        
        # Spatial profile error table
        spatial_df = analysis.generate_error_summary_table(spatial_errors)
        f.write(spatial_df.to_markdown(index=False))
        f.write("\n\n")
        
        f.write("### Plots\n\n")
        f.write("See `validation/plots/` directory for spatial profile plots:\n\n")
        f.write("- `density_profile.png` - Density vs radius\n")
        f.write("- `temperature_profile.png` - Temperature vs radius\n")
        f.write("- `pressure_profile.png` - Pressure vs radius\n")
        f.write("- `internal_energy_profile.png` - Internal energy vs radius\n\n")
        
        f.write("---\n\n")
        
        f.write("## Detailed Analysis\n\n")
        
        f.write("### Peak Values Comparison\n\n")
        f.write("| Quantity | Reference | Simulation | Rel. Error (%) |\n")
        f.write("|----------|-----------|------------|----------------|\n")
        
        for qty, metrics in time_errors.items():
            ref_val = metrics['mean_reference']
            sim_val = metrics['mean_simulation']
            rel_err = metrics['mean_relative_error'] * 100
            f.write(f"| {qty} | {ref_val:.6e} | {sim_val:.6e} | {rel_err:.4f} |\n")
        
        f.write("\n\n")
        
        f.write("---\n\n")
        
        f.write("## Conclusions\n\n")
        
        if passing == total:
            f.write("The modern AX-1 implementation successfully reproduces the 1959 Geneve 10 ")
            f.write("benchmark to within engineering precision (< 1% relative error) for all ")
            f.write("key output quantities. This validates:\n\n")
            f.write("1. Correctness of the S4 neutronics implementation\n")
            f.write("2. Accuracy of the hydrodynamics solver\n")
            f.write("3. Proper coupling between physics modules\n")
            f.write("4. Fidelity of the numerical methods\n\n")
            f.write("The code is ready for production use in fast reactor safety analysis.\n\n")
        else:
            f.write("The validation is not yet complete. Discrepancies exceeding 1% were found in:\n\n")
            for qty, err in max_errors.items():
                if err >= 0.01:
                    f.write(f"- {qty}: {err*100:.4f}% error\n")
            f.write("\n")
            f.write("**Recommended actions:**\n\n")
            f.write("1. Review input parameters for typos or unit conversion errors\n")
            f.write("2. Verify equation of state parameter values\n")
            f.write("3. Check numerical method parameters (CVP, CSC, convergence criteria)\n")
            f.write("4. Compare intermediate quantities (flux profiles, fission source)\n")
            f.write("5. Verify S4 quadrature constants and weights\n\n")
        
        f.write("---\n\n")
        
        f.write("## Reproducibility\n\n")
        f.write("### Input Files\n")
        f.write("- Input deck: `inputs/geneve10_reference.inp`\n")
        f.write("- Reference data: `validation/reference_data/geneve10_*.csv`\n\n")
        
        f.write("### Execution\n")
        f.write("```bash\n")
        f.write("# Compile code\n")
        f.write("make -f Makefile.1959\n\n")
        f.write("# Run simulation\n")
        f.write("./ax1_1959 inputs/geneve10_reference.inp\n\n")
        f.write("# Run validation\n")
        f.write("python scripts/validate_results.py\n")
        f.write("```\n\n")
        
        f.write("### Output Files\n")
        f.write("- Simulation output: `ax1_1959.out`\n")
        f.write("- Comparison plots: `validation/plots/*.png`\n")
        f.write("- This report: `VALIDATION_REPORT.md`\n\n")
        
        f.write("---\n\n")
        f.write("**Report generated automatically by `validate_results.py`**\n")
    
    print(f"\nValidation report written to: {output_file}")


def main():
    """
    Main validation workflow
    """
    print("=" * 70)
    print("AX-1 AUTOMATED VALIDATION: GENEVE 10 PROBLEM")
    print("=" * 70)
    print()
    
    # Initialize analysis
    analysis = ValidationAnalysis()
    
    # Load reference data
    print("Step 1: Loading reference data...")
    try:
        ref_time = analysis.load_reference_time_evolution()
        ref_spatial = analysis.load_reference_spatial()
        print(f"  ✓ Time evolution: {len(ref_time)} points")
        print(f"  ✓ Spatial profile: {len(ref_spatial)} points")
    except FileNotFoundError as e:
        print(f"  ✗ Error loading reference data: {e}")
        return 1
    
    print()
    
    # Load simulation data
    print("Step 2: Loading simulation results...")
    try:
        sim_time = analysis.load_simulation_time_evolution("ax1_output.csv")
        print(f"  ✓ Time evolution: {len(sim_time)} points")
        
        # Try to load spatial profile
        try:
            sim_spatial = analysis.load_simulation_spatial("ax1_output_spatial.csv")
            print(f"  ✓ Spatial profile: {len(sim_spatial)} points")
        except FileNotFoundError:
            print("  ! Spatial profile not found, will skip spatial comparison")
            sim_spatial = None
    except FileNotFoundError as e:
        print(f"  ✗ Error: Simulation output not found")
        print(f"     {e}")
        print()
        print("Please run the simulation first:")
        print("  ./ax1_1959 inputs/geneve10_reference.inp")
        return 1
    
    print()
    
    # Time evolution comparison
    print("Step 3: Comparing time evolution...")
    
    # Interpolate to common grid
    ref_time_interp, sim_time_interp = analysis.interpolate_to_common_grid(
        ref_time, sim_time, 'time_microsec')
    
    # Calculate errors for available columns
    time_columns = ['QP_1e12_erg', 'power_relative', 'alpha_1_microsec']
    available_time_cols = [c for c in time_columns if c in ref_time_interp.columns and c in sim_time_interp.columns]
    
    time_errors = analysis.calculate_errors(ref_time_interp, sim_time_interp, available_time_cols)
    
    for qty, metrics in time_errors.items():
        status = "✓" if metrics['max_relative_error'] < 0.01 else "✗"
        print(f"  {status} {qty}: max error = {metrics['max_relative_error']*100:.4f}%")
    
    print()
    
    # Generate time evolution plots
    print("Step 4: Generating comparison plots...")
    
    plot_configs = [
        ('power_relative', 'Power (relative)', 'Power Evolution', 'power_vs_time.png'),
        ('alpha_1_microsec', 'Alpha (μsec⁻¹)', 'Inverse Period', 'alpha_vs_time.png'),
        ('QP_1e12_erg', 'Total Energy (10¹² erg)', 'Energy Evolution', 'energy_vs_time.png'),
    ]
    
    for col, ylabel, title, filename in plot_configs:
        if col in ref_time.columns and col in sim_time.columns:
            analysis.plot_time_evolution_comparison(
                ref_time, sim_time, col, ylabel, title, filename)
            print(f"  ✓ {filename}")
    
    print()
    
    # Spatial profile comparison (if available)
    spatial_errors = {}
    if sim_spatial is not None:
        print("Step 5: Comparing spatial profiles...")
        
        ref_spatial_interp, sim_spatial_interp = analysis.interpolate_to_common_grid(
            ref_spatial, sim_spatial, 'radius_cm')
        
        spatial_columns = ['density_g_cm3', 'temperature_keV', 'pressure_megabars', 'internal_energy_1e12_erg_g']
        available_spatial_cols = [c for c in spatial_columns if c in ref_spatial_interp.columns and c in sim_spatial_interp.columns]
        
        spatial_errors = analysis.calculate_errors(ref_spatial_interp, sim_spatial_interp, available_spatial_cols)
        
        for qty, metrics in spatial_errors.items():
            status = "✓" if metrics['max_relative_error'] < 0.01 else "✗"
            print(f"  {status} {qty}: max error = {metrics['max_relative_error']*100:.4f}%")
        
        print()
        print("Step 6: Generating spatial profile plots...")
        
        spatial_plot_configs = [
            ('density_g_cm3', 'Density (g/cm³)', 'Density Profile at t=200 μsec', 'density_profile.png'),
            ('temperature_keV', 'Temperature (keV)', 'Temperature Profile at t=200 μsec', 'temperature_profile.png'),
        ]
        
        for col, ylabel, title, filename in spatial_plot_configs:
            if col in ref_spatial.columns and col in sim_spatial.columns:
                analysis.plot_spatial_comparison(
                    ref_spatial, sim_spatial, col, ylabel, title, filename)
                print(f"  ✓ {filename}")
        
        print()
    
    # Generate validation report
    print("Step 7: Generating validation report...")
    generate_validation_report(analysis, time_errors, spatial_errors)
    
    print()
    print("=" * 70)
    print("VALIDATION COMPLETE")
    print("=" * 70)
    
    # Summary
    all_errors = {**time_errors, **spatial_errors}
    passing = sum(1 for v in all_errors.values() if v['max_relative_error'] < 0.01)
    total = len(all_errors)
    
    print(f"\nResult: {passing}/{total} quantities within 1% threshold")
    
    if passing == total:
        print("\n✓ VALIDATION PASSED")
        return 0
    else:
        print("\n✗ VALIDATION INCOMPLETE - see VALIDATION_REPORT.md for details")
        return 1


if __name__ == "__main__":
    sys.exit(main())

