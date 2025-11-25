#!/usr/bin/env python3
"""
Comprehensive validation of AX-1 Phase 1 simulation against Geneve 10 reference data.
Compares time evolution and spatial profiles with detailed error metrics.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import sys

def calculate_metrics(ref, sim, quantity_name):
    """Calculate validation metrics for a quantity"""
    # Remove NaN and infinite values
    mask = np.isfinite(ref) & np.isfinite(sim) & (ref != 0)
    ref_clean = ref[mask]
    sim_clean = sim[mask]
    
    if len(ref_clean) == 0:
        return {
            'max_abs_error': np.nan,
            'max_rel_error': np.nan,
            'rms_error': np.nan,
            'mean_rel_error': np.nan,
            'points_compared': 0
        }
    
    abs_error = np.abs(sim_clean - ref_clean)
    rel_error = abs_error / np.abs(ref_clean)
    
    return {
        'max_abs_error': np.max(abs_error),
        'max_rel_error': np.max(rel_error) * 100,  # Convert to %
        'rms_error': np.sqrt(np.mean(abs_error**2)),
        'mean_rel_error': np.mean(rel_error) * 100,  # Convert to %
        'points_compared': len(ref_clean)
    }

def validate_time_evolution():
    """Validate time-dependent quantities"""
    print("\n" + "="*70)
    print("TIME EVOLUTION VALIDATION")
    print("="*70)
    
    # Load reference data
    ref_file = Path("validation/reference_data/geneve10_time_evolution_extended.csv")
    if not ref_file.exists():
        print(f"ERROR: Reference file not found: {ref_file}")
        return None
    
    ref_data = pd.read_csv(ref_file)
    print(f"\n✓ Loaded reference data: {len(ref_data)} time points")
    
    # Load simulation output
    sim_file = Path("output_time_series.csv")
    if not sim_file.exists():
        print(f"ERROR: Simulation output not found: {sim_file}")
        print("Please run the simulation first!")
        return None
    
    sim_data = pd.read_csv(sim_file)
    print(f"✓ Loaded simulation data: {len(sim_data)} time points")
    
    # Match time points (allow small tolerance)
    results = []
    
    for _, ref_row in ref_data.iterrows():
        t_ref = ref_row['time_microsec']
        
        # Find closest simulation time point
        sim_match = sim_data.iloc[(sim_data['time_microsec'] - t_ref).abs().argsort()[:1]]
        
        if len(sim_match) == 0:
            continue
        
        t_sim = sim_match['time_microsec'].values[0]
        
        # Only compare if times are very close (within 0.1 μsec)
        if abs(t_sim - t_ref) > 0.1:
            continue
        
        # Extract values
        qp_ref = ref_row['QP_1e12_erg']
        qp_sim = sim_match['QP_1e12_erg'].values[0]
        
        power_ref = ref_row['power_relative']
        power_sim = sim_match['power_relative'].values[0]
        
        alpha_ref = ref_row['alpha_1_microsec']
        alpha_sim = sim_match['alpha_1_microsec'].values[0]
        
        # Calculate relative errors
        qp_err = abs(qp_sim - qp_ref) / qp_ref * 100
        power_err = abs(power_sim - power_ref) / power_ref * 100 if power_ref > 0 else 0
        alpha_err = abs(alpha_sim - alpha_ref) / alpha_ref * 100
        
        results.append({
            'time': t_ref,
            'qp_ref': qp_ref,
            'qp_sim': qp_sim,
            'qp_error': qp_err,
            'power_ref': power_ref,
            'power_sim': power_sim,
            'power_error': power_err,
            'alpha_ref': alpha_ref,
            'alpha_sim': alpha_sim,
            'alpha_error': alpha_err
        })
    
    if not results:
        print("\nERROR: No matching time points found!")
        return None
    
    df_results = pd.DataFrame(results)
    
    # Print summary statistics
    print(f"\n{'Quantity':<15} {'Mean Error':<12} {'Max Error':<12} {'Assessment':<15}")
    print("-" * 70)
    
    quantities = [
        ('QP (Energy)', 'qp_error', 2.0),
        ('Power', 'power_error', 5.0),
        ('Alpha', 'alpha_error', 1.0)
    ]
    
    all_pass = True
    
    for name, col, threshold in quantities:
        mean_err = df_results[col].mean()
        max_err = df_results[col].max()
        
        if max_err <= threshold:
            status = "✓ EXCELLENT"
        elif max_err <= threshold * 2:
            status = "✓ GOOD"
        elif max_err <= threshold * 5:
            status = "○ ACCEPTABLE"
            all_pass = False
        else:
            status = "✗ NEEDS WORK"
            all_pass = False
        
        print(f"{name:<15} {mean_err:>10.2f}%  {max_err:>10.2f}%  {status:<15}")
    
    print("-" * 70)
    
    # Detailed breakdown for critical time points
    print("\n" + "="*70)
    print("CRITICAL TIME POINTS")
    print("="*70)
    
    critical_times = [0.0, 100.0, 200.0, 295.0]
    
    for t in critical_times:
        match = df_results[df_results['time'].between(t-0.1, t+0.1)]
        if len(match) > 0:
            row = match.iloc[0]
            print(f"\nt = {row['time']:.1f} μsec:")
            print(f"  QP:    {row['qp_ref']:.2f} (ref) vs {row['qp_sim']:.2f} (sim) → {row['qp_error']:.2f}% error")
            print(f"  Power: {row['power_ref']:.3f} (ref) vs {row['power_sim']:.3f} (sim) → {row['power_error']:.2f}% error")
            print(f"  Alpha: {row['alpha_ref']:.6f} (ref) vs {row['alpha_sim']:.6f} (sim) → {row['alpha_error']:.2f}% error")
    
    # Save detailed results
    output_file = Path("validation_time_evolution_results.csv")
    df_results.to_csv(output_file, index=False)
    print(f"\n✓ Detailed results saved: {output_file}")
    
    return df_results, all_pass

def validate_spatial_profile():
    """Validate spatial distributions"""
    print("\n" + "="*70)
    print("SPATIAL PROFILE VALIDATION")
    print("="*70)
    
    # Load reference data (t=295 μsec, 39 zones)
    ref_file = Path("validation/reference_data/geneve10_spatial_t295_complete.csv")
    if not ref_file.exists():
        print(f"ERROR: Reference file not found: {ref_file}")
        return None
    
    ref_data = pd.read_csv(ref_file)
    print(f"\n✓ Loaded reference data: {len(ref_data)} zones")
    
    # Load simulation output
    sim_file = Path("output_spatial_profile.csv")
    if not sim_file.exists():
        print(f"ERROR: Simulation output not found: {sim_file}")
        print("Note: You may need to save spatial profile at t=295 μsec")
        return None
    
    sim_data = pd.read_csv(sim_file)
    print(f"✓ Loaded simulation data: {len(sim_data)} zones")
    
    # Match zones
    merged = ref_data.merge(sim_data, on='zone_index', how='inner', suffixes=('_ref', '_sim'))
    
    if len(merged) == 0:
        print("\nERROR: No matching zones found!")
        return None
    
    print(f"✓ Matched {len(merged)} zones")
    
    # Calculate errors for each quantity
    quantities = [
        ('Density', 'density_g_cm3', 1.0),
        ('Radius', 'radius_cm', 0.5),
        ('Velocity', 'velocity_cm_microsec', 5.0),
        ('Pressure', 'pressure_megabars', 5.0),
        ('Energy', 'internal_energy_1e12_erg_g', 2.0),
        ('Temperature', 'temperature_keV', 2.0)
    ]
    
    print(f"\n{'Quantity':<15} {'Mean Error':<12} {'Max Error':<12} {'Assessment':<15}")
    print("-" * 70)
    
    all_pass = True
    
    for name, col, threshold in quantities:
        ref_col = f"{col}_ref"
        sim_col = f"{col}_sim"
        
        if ref_col not in merged.columns or sim_col not in merged.columns:
            print(f"{name:<15} {'N/A':<12} {'N/A':<12} {'MISSING':<15}")
            continue
        
        # Calculate relative errors (skip zeros)
        mask = merged[ref_col] != 0
        if mask.sum() == 0:
            continue
        
        rel_errors = np.abs(merged.loc[mask, sim_col] - merged.loc[mask, ref_col]) / np.abs(merged.loc[mask, ref_col]) * 100
        
        mean_err = rel_errors.mean()
        max_err = rel_errors.max()
        
        if max_err <= threshold:
            status = "✓ EXCELLENT"
        elif max_err <= threshold * 2:
            status = "✓ GOOD"
        elif max_err <= threshold * 5:
            status = "○ ACCEPTABLE"
            all_pass = False
        else:
            status = "✗ NEEDS WORK"
            all_pass = False
        
        print(f"{name:<15} {mean_err:>10.2f}%  {max_err:>10.2f}%  {status:<15}")
    
    print("-" * 70)
    
    # Core-blanket boundary check
    print("\n" + "="*70)
    print("CORE-BLANKET BOUNDARY CHECK")
    print("="*70)
    
    # Find boundary (density jump)
    boundary_zone = merged[merged['density_g_cm3_ref'] > 10].iloc[0]['zone_index'] if len(merged[merged['density_g_cm3_ref'] > 10]) > 0 else None
    
    if boundary_zone:
        print(f"\nBoundary zone: {boundary_zone}")
        
        core_zone = merged[merged['zone_index'] == boundary_zone - 1].iloc[0]
        blanket_zone = merged[merged['zone_index'] == boundary_zone].iloc[0]
        
        print(f"\nCore edge (zone {boundary_zone-1}):")
        print(f"  Density: {core_zone['density_g_cm3_ref']:.2f} g/cm³")
        print(f"  Radius:  {core_zone['radius_cm_ref']:.2f} cm")
        
        print(f"\nBlanket start (zone {boundary_zone}):")
        print(f"  Density: {blanket_zone['density_g_cm3_ref']:.2f} g/cm³")
        print(f"  Radius:  {blanket_zone['radius_cm_ref']:.2f} cm")
    
    # Save detailed results
    output_file = Path("validation_spatial_results.csv")
    merged.to_csv(output_file, index=False)
    print(f"\n✓ Detailed results saved: {output_file}")
    
    return merged, all_pass

def generate_validation_plots(time_results, spatial_results):
    """Generate validation comparison plots"""
    print("\n" + "="*70)
    print("GENERATING VALIDATION PLOTS")
    print("="*70)
    
    fig = plt.figure(figsize=(16, 12))
    
    if time_results is not None:
        # Plot 1: Power evolution
        ax1 = plt.subplot(3, 2, 1)
        ax1.plot(time_results['time'], time_results['power_ref'], 'ko-', label='Reference', markersize=4)
        ax1.plot(time_results['time'], time_results['power_sim'], 'r^--', label='Simulation', markersize=3)
        ax1.set_xlabel('Time (μsec)')
        ax1.set_ylabel('Relative Power')
        ax1.set_title('Power Evolution')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Plot 2: Power error
        ax2 = plt.subplot(3, 2, 2)
        ax2.plot(time_results['time'], time_results['power_error'], 'b.-')
        ax2.axhline(y=1.0, color='g', linestyle='--', label='1% threshold')
        ax2.axhline(y=5.0, color='orange', linestyle='--', label='5% threshold')
        ax2.set_xlabel('Time (μsec)')
        ax2.set_ylabel('Relative Error (%)')
        ax2.set_title('Power Error vs Time')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        ax2.set_yscale('log')
        
        # Plot 3: Alpha evolution
        ax3 = plt.subplot(3, 2, 3)
        ax3.plot(time_results['time'], time_results['alpha_ref'], 'ko-', label='Reference', markersize=4)
        ax3.plot(time_results['time'], time_results['alpha_sim'], 'r^--', label='Simulation', markersize=3)
        ax3.set_xlabel('Time (μsec)')
        ax3.set_ylabel('Alpha (μsec⁻¹)')
        ax3.set_title('Alpha Evolution')
        ax3.legend()
        ax3.grid(True, alpha=0.3)
        
        # Plot 4: Energy evolution
        ax4 = plt.subplot(3, 2, 4)
        ax4.plot(time_results['time'], time_results['qp_ref'], 'ko-', label='Reference', markersize=4)
        ax4.plot(time_results['time'], time_results['qp_sim'], 'r^--', label='Simulation', markersize=3)
        ax4.set_xlabel('Time (μsec)')
        ax4.set_ylabel('QP (×10¹² erg)')
        ax4.set_title('Total Energy Evolution')
        ax4.legend()
        ax4.grid(True, alpha=0.3)
    
    if spatial_results is not None:
        # Plot 5: Density profile
        ax5 = plt.subplot(3, 2, 5)
        ax5.plot(spatial_results['radius_cm_ref'], spatial_results['density_g_cm3_ref'], 'ko-', label='Reference', markersize=4)
        ax5.plot(spatial_results['radius_cm_sim'], spatial_results['density_g_cm3_sim'], 'r^--', label='Simulation', markersize=3)
        ax5.set_xlabel('Radius (cm)')
        ax5.set_ylabel('Density (g/cm³)')
        ax5.set_title('Density Profile at t=295 μsec')
        ax5.legend()
        ax5.grid(True, alpha=0.3)
        
        # Plot 6: Temperature profile
        ax6 = plt.subplot(3, 2, 6)
        ax6.plot(spatial_results['radius_cm_ref'], spatial_results['temperature_keV_ref']*1000, 'ko-', label='Reference', markersize=4)
        ax6.plot(spatial_results['radius_cm_sim'], spatial_results['temperature_keV_sim']*1000, 'r^--', label='Simulation', markersize=3)
        ax6.set_xlabel('Radius (cm)')
        ax6.set_ylabel('Temperature (eV)')
        ax6.set_title('Temperature Profile at t=295 μsec')
        ax6.legend()
        ax6.grid(True, alpha=0.3)
        ax6.set_yscale('log')
    
    plt.tight_layout()
    
    output_file = Path("validation_comparison_plots.png")
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"\n✓ Plots saved: {output_file}")
    
    plt.close()

def main():
    """Main validation routine"""
    print("\n" + "="*70)
    print("AX-1 PHASE 1 SIMULATION VALIDATION")
    print("Geneve 10 Rerun - March 20, 1959")
    print("="*70)
    
    # Validate time evolution
    time_results, time_pass = validate_time_evolution()
    
    # Validate spatial profile
    spatial_results, spatial_pass = validate_spatial_profile()
    
    # Generate plots
    if time_results is not None or spatial_results is not None:
        generate_validation_plots(
            time_results if isinstance(time_results, pd.DataFrame) else None,
            spatial_results if isinstance(spatial_results, pd.DataFrame) else None
        )
    
    # Final summary
    print("\n" + "="*70)
    print("FINAL VALIDATION SUMMARY")
    print("="*70)
    
    if time_results is not None and spatial_results is not None:
        if time_pass and spatial_pass:
            print("\n✓✓✓ VALIDATION PASSED ✓✓✓")
            print("\nAll critical quantities agree within required thresholds!")
            print("The simulation successfully replicates the 1959 Geneve 10 results.")
        elif time_pass or spatial_pass:
            print("\n○ PARTIAL VALIDATION")
            print("\nSome quantities meet requirements, others need improvement.")
        else:
            print("\n✗ VALIDATION INCOMPLETE")
            print("\nSignificant discrepancies found. Further debugging required.")
    else:
        print("\n✗ VALIDATION FAILED")
        print("\nCould not complete validation - check simulation outputs.")
    
    print("\n" + "="*70)

if __name__ == "__main__":
    main()

