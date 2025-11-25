#!/usr/bin/env python3
"""
Extract complete Geneve 10 reference data from the LaTeX source document.
This script parses the ANL-5977 LaTeX file to extract:
1. Time evolution data (TIME, QP, POWER, ALPHA, DELT, W)
2. Multiple spatial profiles at different times
3. All 39 zones of spatial data

Outputs clean CSV files for validation.
"""

import re
import csv
from pathlib import Path
import sys

def clean_latex_number(s):
    """
    Clean LaTeX number formatting.
    Examples:
        '2.000000E & 00' -> '2.000000E+00'
        '3.484515E & 03' -> '3.484515E+03'
        '1 & .200000E' -> '1.200000E'
        '7.920000E 00' -> '7.920000E+00'
    """
    s = s.strip()
    
    # Handle split scientific notation across cells: '3 & 03' or '3 & .03'
    s = s.replace(' & ', '')
    
    # Remove '&' artifacts
    s = s.replace('&', '')
    
    # Handle space before exponent: '7.920000E 00' -> '7.920000E+00'
    s = re.sub(r'E\s+(\d)', r'E+\1', s)
    
    # Handle missing + sign: 'E 03' -> 'E+03'
    s = re.sub(r'E\s*(\d)', r'E+\1', s)
    
    # Handle missing + sign: 'E-03' is OK, 'E03' -> 'E+03'
    s = re.sub(r'E([0-9])', r'E+\1', s)
    
    # Remove extra spaces
    s = ' '.join(s.split())
    
    return s

def extract_time_evolution(latex_file):
    """
    Extract the complete time evolution table from the LaTeX document.
    Returns list of dicts with keys: time, QP, power, alpha, delt, W
    """
    with open(latex_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find the time evolution table (starts after "K EFFECTIVE" and before first spatial profile)
    # Look for lines like: "| & 0. & 3.484515E & 03 & 1.000000E & 1.308400E-02 & 2.000000E & 00 & 0. \\"
    
    time_data = []
    
    # Pattern for time evolution rows
    # Match lines with format: number & number & number & ...
    pattern = r'\|\s*([&\d\.\sE+-]+)\s*\\\\'
    
    # Find the section between "TIME" header and first "TOTAL ENERGY"
    time_section_pattern = r'TIME.*?QP.*?POWER.*?ALPHA.*?DELT.*?W.*?\n(.*?)TOTAL ENERGY'
    match = re.search(time_section_pattern, content, re.DOTALL)
    
    if match:
        time_section = match.group(1)
        
        for line in time_section.split('\n'):
            if '&' in line and '\\hline' not in line and 'DUMP' not in line and 'HALVE' not in line:
                # Extract numbers from the line
                # Remove LaTeX formatting
                line = line.replace('|', '').replace('\\\\', '').replace('\\hline', '')
                parts = [p.strip() for p in line.split('&') if p.strip()]
                
                if len(parts) >= 6:
                    try:
                        time_str = clean_latex_number(parts[0] + parts[1] if len(parts[0]) < 3 else parts[0])
                        qp_str = clean_latex_number(parts[1] + parts[2] if '03' in parts[2] else parts[1])
                        power_str = clean_latex_number(parts[3] if len(parts) > 3 else parts[2])
                        alpha_str = clean_latex_number(parts[4] if len(parts) > 4 else parts[3])
                        delt_str = clean_latex_number(parts[5] + parts[6] if len(parts) > 6 else parts[4])
                        w_str = clean_latex_number(parts[7] if len(parts) > 7 else parts[5])
                        
                        # Parse the values
                        time_val = float(time_str)
                        qp_val = float(qp_str)
                        power_val = float(power_str)
                        alpha_val = float(alpha_str)
                        delt_val = float(delt_str)
                        w_val = float(w_str)
                        
                        time_data.append({
                            'time_microsec': time_val,
                            'QP_1e12_erg': qp_val,
                            'power_relative': power_val,
                            'alpha_1_microsec': alpha_val,
                            'delt_microsec': delt_val,
                            'W_dimensionless': w_val
                        })
                    except (ValueError, IndexError) as e:
                        # Skip lines that don't parse correctly
                        continue
    
    return time_data

def extract_spatial_profile(latex_file, time_label="t=200"):
    """
    Extract spatial profile data at a specific time.
    Returns list of dicts with keys: zone, density, radius, velocity, pressure, energy, temperature
    """
    with open(latex_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    spatial_data = []
    
    # Find spatial profile tables
    # Look for lines like: "7.920000E 00 & 9.353166E-01 & -O. &  & 0. & 4.609830E-03 & 3.500994E-04 \\"
    
    # Find section with DENSITY & RADIUS & VELOCITY header
    pattern = r'DENSITY.*?RADIUS.*?VELOCITY.*?PRESSURE.*?INTERNAL ENERGY.*?TEMPERATURE.*?\n(.*?)(?:\n\n|\\end{tabular})'
    
    matches = re.findall(pattern, content, re.DOTALL)
    
    # Use the LAST match which should have the most complete data
    if matches:
        spatial_section = matches[-1]  # Last spatial profile table
        
        zone_idx = 2  # Start at zone 2 (zone 1 is at r=0, not included in data)
        
        for line in spatial_section.split('\n'):
            if '&' in line and '\\hline' not in line and 'DENSITY' not in line:
                # Extract numbers from the line
                line = line.replace('|', '').replace('\\\\', '').replace('\\hline', '')
                parts = [p.strip() for p in line.split('&') if p.strip()]
                
                if len(parts) >= 6:
                    try:
                        density_str = clean_latex_number(parts[0])
                        radius_str = clean_latex_number(parts[1])
                        velocity_str = clean_latex_number(parts[2])
                        pressure_str = clean_latex_number(parts[3])
                        energy_str = clean_latex_number(parts[4])
                        temp_str = clean_latex_number(parts[5])
                        
                        # Handle special cases
                        if '-O' in velocity_str or 'O.' in velocity_str:
                            velocity_str = '0.0'
                        if velocity_str == '0':
                            velocity_str = '0.0'
                        
                        density_val = float(density_str)
                        radius_val = float(radius_str)
                        velocity_val = float(velocity_str)
                        pressure_val = float(pressure_str)
                        energy_val = float(energy_str)
                        temp_val = float(temp_str)
                        
                        spatial_data.append({
                            'zone_index': zone_idx,
                            'density_g_cm3': density_val,
                            'radius_cm': radius_val,
                            'velocity_cm_microsec': velocity_val,
                            'pressure_megabars': pressure_val,
                            'internal_energy_1e12_erg_g': energy_val,
                            'temperature_keV': temp_val
                        })
                        
                        zone_idx += 1
                    except (ValueError, IndexError) as e:
                        # Skip lines that don't parse correctly
                        continue
    
    return spatial_data

def main():
    """Main extraction routine"""
    latex_file = Path("2025_11_22_9629766d565b25ccbdecg/anotherversion.tex")
    
    if not latex_file.exists():
        print(f"ERROR: LaTeX file not found: {latex_file}")
        sys.exit(1)
    
    print("Extracting Geneve 10 reference data from LaTeX document...")
    print(f"Source: {latex_file}")
    
    # Extract time evolution
    print("\n1. Extracting time evolution data...")
    time_data = extract_time_evolution(latex_file)
    print(f"   Found {len(time_data)} time points")
    
    if time_data:
        print(f"   Time range: {time_data[0]['time_microsec']:.1f} to {time_data[-1]['time_microsec']:.1f} μsec")
    
    # Extract spatial profile
    print("\n2. Extracting spatial profile data...")
    spatial_data = extract_spatial_profile(latex_file)
    print(f"   Found {len(spatial_data)} zones")
    
    if spatial_data:
        print(f"   Zone range: {spatial_data[0]['zone_index']} to {spatial_data[-1]['zone_index']}")
        print(f"   Radius range: {spatial_data[0]['radius_cm']:.3f} to {spatial_data[-1]['radius_cm']:.3f} cm")
    
    # Save to CSV files
    output_dir = Path("validation/reference_data")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Save time evolution
    time_file = output_dir / "geneve10_time_evolution_complete.csv"
    if time_data:
        with open(time_file, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=time_data[0].keys())
            writer.writeheader()
            writer.writerows(time_data)
        print(f"\n✓ Saved time evolution: {time_file}")
    else:
        print("\n✗ No time evolution data extracted")
    
    # Save spatial profile
    spatial_file = output_dir / "geneve10_spatial_profile_complete.csv"
    if spatial_data:
        with open(spatial_file, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=spatial_data[0].keys())
            writer.writeheader()
            writer.writerows(spatial_data)
        print(f"✓ Saved spatial profile: {spatial_file}")
    else:
        print("✗ No spatial profile data extracted")
    
    print("\n" + "="*60)
    print("EXTRACTION SUMMARY")
    print("="*60)
    print(f"Time evolution points: {len(time_data)}")
    print(f"Spatial profile zones: {len(spatial_data)}")
    print(f"\nOutput directory: {output_dir}")
    print("="*60)

if __name__ == "__main__":
    main()

