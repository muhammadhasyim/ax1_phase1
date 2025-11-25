#!/usr/bin/env python3
"""
Parse LaTeX tables from the ANL-5977 (1959) Geneve 10 study.
Extracts time-series and spatial profile data directly from LaTeX source.
"""

import re
import csv
from pathlib import Path
import numpy as np

def clean_latex_number(s):
    """
    Clean LaTeX number formatting artifacts.
    Examples:
        '2.407454 E -04' -> '2.407454E-04'
        '1.510078E Ol' -> '1.510078E+01'
        '4•980521E-02' -> '4.980521E-02'
        '-0.' -> '0.0'
    """
    s = s.strip()
    
    # Handle '-0.' edge case
    if s == '-0.':
        return '0.0'
    
    # Replace bullet • with decimal point
    s = s.replace('•', '.')
    
    # Fix 'Ol' OCR error (should be '01')
    s = s.replace('E Ol', 'E+01')
    s = s.replace('E OO', 'E+00')
    s = s.replace('E OI', 'E+01')
    
    # Remove spaces in scientific notation
    s = re.sub(r'(\d)\s+E\s*([+-]?\d)', r'\1E\2', s)
    s = re.sub(r'E\s+([+-]?\d)', r'E\1', s)
    s = re.sub(r'E([+-]?\s+\d)', lambda m: 'E' + m.group(1).replace(' ', ''), s)
    
    # Handle missing sign in exponent (assume positive)
    s = re.sub(r'E\s*(\d)', r'E+\1', s)
    
    return s

def parse_time_series_table(latex_lines, start_line, end_line):
    """
    Parse a time-series table with columns: TIME, QP, POWER, ALPHA, DELT, W
    Handles entries like: "2 & .400000E & 02" → "2.400000E+02"
    """
    data = []
    
    for line in latex_lines[start_line:end_line]:
        line = line.strip()
        
        # Skip non-data lines
        if not line or '\\hline' in line or '\\end{' in line or '\\begin{' in line:
            continue
        if 'TIME' in line or 'GENEVE' in line or 'DUMP' in line or 'HALVE' in line:
            continue
        if 'LIGHT' in line or 'SENSE' in line:
            continue
        if '\\multicolumn' in line or '\\multirow' in line:
            continue
        if 'TOTAL' in line or 'CHECK' in line or 'ERROR' in line:
            continue
        
        # Remove LaTeX formatting
        line = line.replace('\\\\', '').replace('\\hline', '').strip()
        
        # Split by &
        parts = [p.strip() for p in line.split('&')]
        
        # Filter out empty parts
        parts = [p for p in parts if p]
        
        # We need to reconstruct split numbers
        # Pattern: might have "2" ".400000E" "02" → "2.400000E+02"
        # Or: "2" "2.620000E" "02" → skip first "2", use "2.620000E+02"
        
        try:
            reconstructed = []
            i = 0
            while i < len(parts):
                part = parts[i].strip()
                
                # Check if this is a single digit (row index)
                if len(part) <= 2 and part.isdigit():
                    # Check if next part starts with decimal point
                    if i+1 < len(parts) and parts[i+1].startswith('.'):
                        # Combine: "2" + ".400000E" → "2.400000E"
                        combined = part + parts[i+1]
                        i += 1
                        # Check for exponent part
                        if i+1 < len(parts) and re.match(r'^\d{2}$', parts[i+1].strip()):
                            combined = combined + parts[i+1]
                            i += 1
                        reconstructed.append(clean_latex_number(combined))
                    else:
                        # Skip standalone row index
                        pass
                elif part.startswith('.') or 'E' in part.upper():
                    # This is a number part
                    combined = part
                    # Check for exponent
                    if i+1 < len(parts) and re.match(r'^\d{2}$', parts[i+1].strip()):
                        combined = combined + parts[i+1]
                        i += 1
                    # Check if we need to prepend a digit
                    if combined.startswith('.'):
                        # Missing leading digit, assume from context or previous
                        # For time series, leading digit is often "2" for 200+ microsec
                        combined = '2' + combined
                    reconstructed.append(clean_latex_number(combined))
                elif re.match(r'^\d+\.\d+E', part):
                    # Complete number with E notation
                    combined = part
                    if i+1 < len(parts) and re.match(r'^[+-]?\d{2}$', parts[i+1].strip()):
                        combined = combined + parts[i+1]
                        i += 1
                    reconstructed.append(clean_latex_number(combined))
                else:
                    # Try to parse as-is
                    try:
                        float_val = clean_latex_number(part)
                        reconstructed.append(float_val)
                    except:
                        pass
                
                i += 1
            
            # Try to extract 6 values
            if len(reconstructed) >= 6:
                values = [float(v) for v in reconstructed[:6]]
                data.append(values)
        except (ValueError, IndexError) as e:
            # Skip malformed lines
            pass
    
    return data

def parse_spatial_table(latex_lines, start_line, end_line):
    """
    Parse a spatial profile table with columns:
    DENSITY, RADIUS, VELOCITY, PRESSURE, INTERNAL ENERGY, TEMPERATURE
    """
    data = []
    
    for line in latex_lines[start_line:end_line]:
        line = line.strip()
        
        # Skip non-data lines
        if not line or '\\hline' in line or '\\end{' in line or '\\begin{' in line:
            continue
        if 'DENSITY' in line or 'RADIUS' in line or 'VELOCITY' in line:
            continue
        if 'PRESSURE' in line or 'ENERGY' in line or 'TEMPERATURE' in line:
            continue
        if 'GENEVE' in line or 'TOTAL' in line or 'KINETIC' in line or 'CHECK' in line:
            continue
        if '\\multicolumn' in line or '\\multirow' in line or '\\caption' in line:
            continue
        
        # Remove LaTeX formatting
        line = line.replace('\\\\', '').replace('\\hline', '').replace('$', '').strip()
        line = line.replace('\\mathrm{E}', 'E')
        
        # Split by &
        parts = [p.strip() for p in line.split('&')]
        
        # Filter out empty parts
        parts = [p for p in parts if p]
        
        # We expect 7 values (or 6 if split): DENSITY, RADIUS, VELOCITY, PRESSURE, ENERGY, TEMP
        # But they may be split like: '7.484143E' '00' '9.531319E-01' ...
        if len(parts) >= 6:
            try:
                values = []
                i = 0
                while i < len(parts) and len(values) < 6:
                    val = clean_latex_number(parts[i])
                    # Check if next part is just exponent continuation (like '00' or '01')
                    if i+1 < len(parts) and re.match(r'^\d{2}$', parts[i+1].strip()):
                        val = val + parts[i+1].strip()
                        i += 1
                    values.append(float(val))
                    i += 1
                
                if len(values) == 6:
                    data.append(values)
            except (ValueError, IndexError) as e:
                # Skip malformed lines
                pass
    
    return data

def extract_all_geneve10_tables(latex_file):
    """
    Extract all Geneve 10 tables from the LaTeX source.
    Returns: (time_series_data, spatial_data_dict)
    """
    with open(latex_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find all table blocks containing "GENEVE 10"
    table_blocks = []
    in_table = False
    table_start = None
    
    for i, line in enumerate(lines):
        if '\\begin{tabular}' in line and not in_table:
            # Look back a few lines to see if this is a Geneve 10 table
            context = ''.join(lines[max(0, i-10):i+5])
            if 'GENEVE 10' in context or 'GENEVE10' in context:
                in_table = True
                table_start = i
        elif '\\end{tabular}' in line and in_table:
            table_blocks.append((table_start, i+1))
            in_table = False
    
    print(f"Found {len(table_blocks)} table blocks in LaTeX")
    
    # Parse each table
    all_time_data = []
    spatial_data = {}
    
    for start, end in table_blocks:
        # Check if it's a time-series or spatial table
        table_text = ''.join(lines[start:min(end+10, len(lines))])
        
        if 'TIME' in table_text and 'QP' in table_text and 'POWER' in table_text:
            # Time-series table
            time_data = parse_time_series_table(lines, start, end)
            if time_data:
                print(f"  Time-series table at lines {start}-{end}: {len(time_data)} rows")
                all_time_data.extend(time_data)
        
        elif 'DENSITY' in table_text and 'RADIUS' in table_text and 'VELOCITY' in table_text:
            # Spatial table - try to identify the time
            # Look for context before table
            context_before = ''.join(lines[max(0, start-50):start])
            
            # Try to find time reference
            time_match = re.search(r'(\d+\.?\d*)\s*(?:E\s*)?0?(\d)\s*(?:μsec|microsec)', context_before)
            if not time_match:
                # Try to extract from nearby text
                time_match = re.search(r'(\d+)\.(\d+)E\s*0(\d)', context_before)
            
            spatial_data_vals = parse_spatial_table(lines, start, end)
            if spatial_data_vals:
                # Use line number as identifier if we can't find time
                time_key = f"lines_{start}_{end}"
                print(f"  Spatial table at lines {start}-{end}: {len(spatial_data_vals)} zones")
                spatial_data[time_key] = spatial_data_vals
    
    # Remove duplicate time entries (keep first occurrence)
    if all_time_data:
        seen_times = set()
        unique_time_data = []
        for row in all_time_data:
            time = round(row[0], 6)
            if time not in seen_times:
                seen_times.add(time)
                unique_time_data.append(row)
        all_time_data = sorted(unique_time_data, key=lambda x: x[0])
    
    return all_time_data, spatial_data

def main():
    """Main extraction workflow"""
    latex_file = Path('2025_11_22_9629766d565b25ccbdecg/2025_11_22_9629766d565b25ccbdecg.tex')
    output_dir = Path('validation/reference_data')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Parsing LaTeX file: {latex_file}")
    
    # Extract tables
    time_data, spatial_data = extract_all_geneve10_tables(latex_file)
    
    print(f"\nExtracted {len(time_data)} time points")
    print(f"Extracted {len(spatial_data)} spatial snapshots")
    
    # Save time-series data
    if time_data:
        time_csv = output_dir / 'geneve10_time_evolution_complete.csv'
        with open(time_csv, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['# Geneve 10 Rerun March 20, 1959 - Complete Time Evolution'])
            writer.writerow(['# Extracted from LaTeX source: 2025_11_22_9629766d565b25ccbdecg.tex'])
            writer.writerow(['time_microsec', 'QP_1e12_erg', 'power_relative', 'alpha_1_microsec', 'delt_microsec', 'W_dimensionless'])
            for row in time_data:
                writer.writerow([f'{v:.6e}' for v in row])
        print(f"\nSaved time-series: {time_csv}")
        print(f"  Time range: {time_data[0][0]:.1f} to {time_data[-1][0]:.1f} μsec")
    
    # Save spatial data
    for i, (key, spatial_vals) in enumerate(sorted(spatial_data.items())):
        spatial_csv = output_dir / f'geneve10_spatial_snapshot_{i+1}.csv'
        with open(spatial_csv, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['# Geneve 10 Rerun March 20, 1959 - Spatial Profile'])
            writer.writerow([f'# Source: {key}'])
            writer.writerow(['zone_index', 'density_g_cm3', 'radius_cm', 'velocity_cm_microsec', 
                           'pressure_megabars', 'internal_energy_1e12_erg_g', 'temperature_keV'])
            for j, row in enumerate(spatial_vals, start=2):
                writer.writerow([j] + [f'{v:.6e}' for v in row])
        print(f"\nSaved spatial snapshot {i+1}: {spatial_csv}")
        print(f"  Zones: {len(spatial_vals)}")

if __name__ == '__main__':
    main()

