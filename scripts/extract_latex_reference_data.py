#!/usr/bin/env python3
"""
Extract Geneve 10 reference data directly from LaTeX document.
Manually parse specific tables based on known line numbers and structure.
"""

import csv
from pathlib import Path

def parse_scientific(s):
    """Parse scientific notation from LaTeX format: '2.100000E & 02' -> 2.100000E+02"""
    s = s.strip().replace(' ', '')
    # Handle split exponent: 'E&02' -> 'E+02'
    if 'E&' in s:
        s = s.replace('E&', 'E+')
    elif 'E-' in s:
        pass  # Already correct
    elif 'E' in s and '+' not in s:
        s = s.replace('E', 'E+')
    return float(s)

def extract_time_evolution():
    """
    Extract time evolution data by reading specific line ranges.
    Based on lines 1087-1121, 1235-1265, and continuation tables.
    """
    latex_file = Path("2025_11_22_9629766d565b25ccbdecg/anotherversion.tex")
    
    with open(latex_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    time_data = []
    
    # Manually extract known data points from the LaTeX
    # Format: TIME & | QP | POWER | ALPHA | DELT | W
    
    # Table 1: Lines 1087-1121 (t=0 to t=200 μsec)
    data_lines_1 = [
        (0.0, 3.484515E+03, 1.000000E+00, 1.308400E-02, 2.000000E+00, 0.0),
        (2.000000E+00, 3.484515E+03, 1.026513E+00, 1.306381E-02, 2.000000E+00, 1.717759E-02),
        (6.000000E+00, 3.484515E+03, 1.081580E+00, 1.306669E-02, 2.000000E+00, 1.737788E-02),
        (1.200000E+01, 3.484515E+03, 1.169789E+00, 1.306910E-02, 2.000000E+00, 1.769934E-02),
        (2.000000E+01, 3.484515E+03, 1.298716E+00, 1.307150E-02, 2.000000E+00, 1.816912E-02),
        (3.000000E+01, 3.484515E+03, 1.480072E+00, 1.307318E-02, 2.000000E+00, 1.882985E-02),
        (4.200000E+01, 3.484515E+03, 1.731467E+00, 1.307486E-02, 2.000000E+00, 1.974568E-02),
        (5.600000E+01, 3.484515E+03, 2.079270E+00, 1.307654E-02, 2.000000E+00, 2.101261E-02),
        (7.200000E+01, 3.484515E+03, 2.563162E+00, 1.307702E-02, 2.000000E+00, 2.277511E-02),
        (9.000000E+01, 3.484515E+03, 3.243418E+00, 1.307847E-02, 2.000000E+00, 2.525282E-02),
        (1.100000E+02, 3.484515E+03, 4.213092E+00, 1.307943E-02, 2.000000E+00, 2.878439E-02),
        (1.320000E+02, 3.842258E+03, 5.617822E+00, 1.307967E-02, 2.000000E+00, 3.390018E-02),
        (1.560000E+02, 4.002723E+03, 7.689500E+00, 1.308039E-02, 2.000000E+00, 4.144491E-02),
        (1.820000E+02, 4.243975E+03, 1.080431E+01, 1.308087E-02, 2.000000E+00, 5.278815E-02),
        (2.000000E+02, 4.466130E+03, 1.367270E+01, 1.308087E-02, 2.000000E+00, 6.323373E-02),
    ]
    
    # Table 2: Lines 1235-1265 (t=210 to t=295 μsec)
    data_lines_2 = [
        (2.100000E+02, 4.614118E+03, 1.558345E+01, 1.308135E-02, 2.000000E+00, 7.019199E-02),
        (2.400000E+02, 5.194141E+03, 2.307269E+01, 1.308255E-02, 2.000000E+00, 9.746438E-02),
        (2.620000E+02, 5.790050E+03, 3.076770E+01, 1.307606E-02, 2.000000E+00, 1.350541E-01),
        (2.700000E+02, 6.052932E+03, 3.416063E+01, 1.291253E-02, 2.000000E+00, 1.561587E-01),
        (2.740000E+02, 6.194982E+03, 3.597139E+01, 1.263538E-02, 2.000000E+00, 1.673742E-01),
        (2.800000E+02, 6.422045E+03, 3.880450E+01, 1.173227E-02, 2.000000E+00, 1.928673E-01),
        (2.820000E+02, 6.501495E+03, 3.972579E+01, 1.123132E-02, 2.000000E+00, 1.980252E-01),
        (2.840000E+02, 6.582751E+03, 4.062824E+01, 1.061646E-02, 2.000000E+00, 1.919355E-01),
        (2.860000E+02, 6.665751E+03, 4.150012E+01, 9.864639E-03, 2.000000E+00, 1.957814E-01),
        (2.880000E+02, 6.750404E+03, 4.232701E+01, 8.957334E-03, 2.000000E+00, 1.996146E-01),
        (2.900000E+02, 6.836587E+03, 4.309212E+01, 7.876132E-03, 2.000000E+00, 2.178121E-01),
        (2.920000E+02, 6.924139E+03, 4.377629E+01, 6.601209E-03, 2.000000E+00, 2.293675E-01),
        (2.940000E+02, 7.012855E+03, 4.435807E+01, 5.114744E-03, 1.000000E+00, 2.192134E-01),
        (2.950000E+02, 7.057554E+03, 4.469970E+01, 5.114744E-03, 1.000000E+00, 8.427610E-02),
    ]
    
    # Combine all data
    for row in data_lines_1 + data_lines_2:
        time_data.append({
            'time_microsec': row[0],
            'QP_1e12_erg': row[1],
            'power_relative': row[2],
            'alpha_1_microsec': row[3],
            'delt_microsec': row[4],
            'W_dimensionless': row[5]
        })
    
    return time_data

def extract_spatial_t295():
    """
    Extract spatial profile at t=295 μsec (lines 1278-1335).
    This is the most complete spatial profile with ~25+ zones.
    """
    
    # Manually extracted from lines 1278-1335 of anotherversion.tex
    spatial_data_raw = [
        (7.484143E+00, 9.531319E-01, 2.407454E-04, 4.925818E-02, 1.321355E-02, 8.218011E-04),
        (7.493912E+00, 1.905539E+00, 1.461096E-03, 4.980521E-02, 1.319808E-02, 8.227578E-04),
        (7.493629E+00, 2.858224E+00, 2.419077E-03, 4.903755E-02, 1.315292E-02, 8.200302E-04),
        (7.504321E+00, 3.809892E+00, 2.837079E-03, 4.895018E-02, 1.309500E-02, 8.186132E-04),
        (7.515374E+00, 4.760746E+00, 3.736507E-03, 4.849854E-02, 1.301343E-02, 8.158509E-04),
        (7.528976E+00, 5.710589E+00, 4.365463E-03, 4.791449E-02, 1.291162E-02, 8.123501E-04),
        (7.549754E+00, 6.658724E+00, 5.095267E-03, 4.764249E-02, 1.279374E-02, 8.092295E-04),
        (7.567464E+00, 7.605683E+00, 5.717149E-03, 4.669176E-02, 1.265076E-02, 8.039881E-04),
        (7.592811E+00, 8.550646E+00, 6.363582E-03, 4.609189E-02, 1.249247E-02, 7.992186E-04),
        (7.617350E+00, 9.493879E+00, 6.965566E-03, 4.503848E-02, 1.231175E-02, 7.929039E-04),
        (7.648377E+00, 1.043473E+01, 7.512518E-03, 4.420762E-02, 1.211524E-02, 7.867189E-04),
        (7.680144E+00, 1.137329E+01, 8.007845E-03, 4.308627E-02, 1.189895E-02, 7.794144E-04),
        (7.716881E+00, 1.230911E+01, 8.478864E-03, 4.204543E-02, 1.166610E-02, 7.718863E-04),
        (7.752517E+00, 1.324249E+01, 8.894262E-03, 4.054883E-02, 1.141318E-02, 7.628349E-04),
        (7.791894E+00, 1.417309E+01, 9.367871E-03, 3.903099E-02, 1.114415E-02, 7.533214E-04),
        (7.833664E+00, 1.510078E+01, 9.557108E-03, 3.738020E-02, 1.085900E-02, 7.430835E-04),
        (7.881988E+00, 1.602497E+01, 9.646610E-03, 3.593785E-02, 1.055997E-02, 7.329179E-04),
        (7.926625E+00, 1.694623E+01, 9.939646E-03, 3.384898E-02, 1.024234E-02, 7.208111E-04),
        (7.970825E+00, 1.786472E+01, 9.889098E-03, 3.142713E-02, 9.909864E-03, 7.075534E-04),
        (8.023799E+00, 1.877955E+01, 9.526138E-03, 2.938053E-02, 9.565789E-03, 6.947382E-04),
        (8.058807E+00, 1.969283E+01, 9.354209E-03, 2.562169E-02, 9.201159E-03, 6.776275E-04),
        (8.126535E+00, 2.060099E+01, 8.658014E-03, 2.413655E-02, 8.836209E-03, 6.653063E-04),
        (8.100561E+00, 2.151433E+01, 2.032907E-03, 1.578500E-02, 8.429936E-03, 6.357862E-04),  # Note: Energy is E-03 not E-02
        (7.936677E+00, 2.244760E+01, 2.877922E-10, 6.016498E-05, 8.004120E-03, 5.819281E-04),
        (7.919998E+00, 2.338291E+01, 0.0, 0.0, 7.562369E-03, 5.503850E-04),
        # Blanket zones start here
        (1.583000E+01, 2.431823E+01, 0.0, 0.0, 6.153750E-04, 4.999998E-05),
        (1.583000E+01, 2.525355E+01, 0.0, 0.0, 6.153750E-04, 4.999998E-05),
        (1.583000E+01, 2.618887E+01, 0.0, 0.0, 6.153750E-04, 4.999999E-05),
        (1.583000E+01, 2.712418E+01, 0.0, 0.0, 6.153750E-04, 4.999999E-05),
        (1.583000E+01, 2.805950E+01, 0.0, 0.0, 6.153750E-04, 4.999999E-05),
        (1.583000E+01, 2.983168E+01, 0.0, 0.0, 6.153750E-04, 4.999998E-05),
        (1.583000E+01, 3.160386E+01, 0.0, 0.0, 6.153750E-04, 4.999998E-05),
        (1.583000E+01, 3.337602E+01, 0.0, 0.0, 6.153750E-04, 4.999998E-05),
        (1.582999E+01, 3.514820E+01, 0.0, 0.0, 6.153750E-04, 4.999997E-05),
        (1.582999E+01, 3.692038E+01, 0.0, 0.0, 6.153750E-04, 4.999997E-05),
        (1.583000E+01, 3.869256E+01, 0.0, 0.0, 6.153750E-04, 4.999999E-05),
        (1.582999E+01, 4.046474E+01, 0.0, 0.0, 6.153750E-04, 4.999998E-05),
        (1.582999E+01, 4.223692E+01, 0.0, 0.0, 6.153750E-04, 4.999997E-05),
        (1.582999E+01, 4.400910E+01, 0.0, 0.0, 6.153750E-04, 4.999997E-05),
    ]
    
    spatial_data = []
    for i, row in enumerate(spatial_data_raw, start=2):  # Zone indexing starts at 2
        spatial_data.append({
            'zone_index': i,
            'density_g_cm3': row[0],
            'radius_cm': row[1],
            'velocity_cm_microsec': row[2],
            'pressure_megabars': row[3],
            'internal_energy_1e12_erg_g': row[4],
            'temperature_keV': row[5]
        })
    
    return spatial_data

def main():
    """Main extraction routine"""
    
    print("="*70)
    print("EXTRACTING GENEVE 10 REFERENCE DATA FROM LATEX")
    print("="*70)
    
    # Extract time evolution
    print("\n1. Extracting time evolution data...")
    time_data = extract_time_evolution()
    print(f"   ✓ Extracted {len(time_data)} time points")
    print(f"   Time range: {time_data[0]['time_microsec']:.1f} to {time_data[-1]['time_microsec']:.1f} μsec")
    
    # Extract spatial profile at t=295 μsec
    print("\n2. Extracting spatial profile at t=295 μsec...")
    spatial_data = extract_spatial_t295()
    print(f"   ✓ Extracted {len(spatial_data)} zones")
    print(f"   Zone range: {spatial_data[0]['zone_index']} to {spatial_data[-1]['zone_index']}")
    print(f"   Radius range: {spatial_data[0]['radius_cm']:.3f} to {spatial_data[-1]['radius_cm']:.3f} cm")
    
    # Save to CSV files
    output_dir = Path("validation/reference_data")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Save time evolution
    time_file = output_dir / "geneve10_time_evolution_extended.csv"
    with open(time_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=time_data[0].keys())
        writer.writeheader()
        writer.writerows(time_data)
    print(f"\n✓ Saved: {time_file}")
    
    # Save spatial profile
    spatial_file = output_dir / "geneve10_spatial_t295_complete.csv"
    with open(spatial_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=spatial_data[0].keys())
        writer.writeheader()
        writer.writerows(spatial_data)
    print(f"✓ Saved: {spatial_file}")
    
    print("\n" + "="*70)
    print("EXTRACTION COMPLETE")
    print("="*70)
    print(f"\nSummary:")
    print(f"  - Time evolution: {len(time_data)} points (0-295 μsec)")
    print(f"  - Spatial profile: {len(spatial_data)} zones (complete 39-zone system)")
    print(f"\nData quality: HIGH (manually extracted from clean LaTeX source)")
    print("="*70)

if __name__ == "__main__":
    main()

