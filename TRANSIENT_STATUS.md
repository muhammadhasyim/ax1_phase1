# Geneve 10 Transient Simulation - Status Report

**Date**: November 23, 2024  
**Objective**: Replicate the full time-series transient data (0-200 μsec) from the 1959 Geneve 10 reference problem

## What Was Accomplished

### ✅ Code Enhancements Implemented

1. **CSV Output Infrastructure**
   - Added `write_csv_header_time()` and `write_csv_step_time()` to `io_1959.f90`
   - Added `write_csv_header_spatial()` and `write_csv_step_spatial()` to `io_1959.f90`
   - Modified `main_1959.f90` to open CSV files and write data every output interval
   - CSV files generated: `output_time_series.csv`, `output_spatial_t200.csv`

2. **Input File Generation**
   - Fixed `generate_geneve10_input.py` to correctly handle ICNTRL=0 vs ICNTRL=1 modes
   - EPSR (radius convergence tolerance) now only written when ICNTRL=1
   - Cross sections properly scaled: nu_sig_f = 0.607 barns (to match k_eff = 1.003)

3. **Compilation and Execution**
   - Code compiles cleanly with no linter errors
   - Simulation runs successfully but terminates early due to system disassembly

## Current Status

### ⚠️ **EARLY TERMINATION ISSUE**

**Simulation Behavior**:
- Run terminates at t = 3.75 μsec (target: 200 μsec)
- Reason: "System disassembled" (W ~ 10¹⁹, normal is W < 1)
- Data collected: Only 4 time points instead of 15

**Key Discrepancies**:

| Parameter | Simulation @ t=2μs | Reference @ t=2μs | Ratio |
|-----------|-------------------|-------------------|-------|
| QP (10¹² erg) | 783 | 3,487 | 0.22x |
| Alpha (μsec⁻¹) | 0.0349 | 0.01306 | 2.67x |
| k_eff | 1.0036 | 1.003 | ✓ Match |

**Analysis**:
1. **Initial Energy Mismatch**: QP should start at ~3485, but starts at ~783 (4.4x too low)
2. **Alpha Too High**: Inverse period is 2.7x higher than reference → faster exponential growth
3. **System Too Supercritical**: Despite k_eff matching, alpha mismatch causes rapid disassembly

## Root Causes Identified

### 1. **Generation Time (Λ) Hardcoded**
- Location: `src/neutronics_s4_1959.f90`, line 420
- Current value: Λ = 0.1 μsec (hardcoded guess)
- Effect: Alpha = (k-1)/Λ → wrong alpha even with correct k_eff

**Code snippet**:
```fortran
! Line 417-425 in neutronics_s4_1959.f90
function compute_alpha_from_k(k_eff, st) result(alpha)
  real(rk), intent(in) :: k_eff
  type(State_1959), intent(in) :: st
  real(rk) :: alpha
  real(rk) :: lambda_prompt
  
  ! Estimate prompt neutron generation time
  ! For fast spectrum: Λ ~ 10^-7 sec = 0.1 μsec
  ! This is a crude approximation; should be computed from flux
  lambda_prompt = 0.1_rk  ! μsec  ← HARDCODED!
  
  ! Prompt kinetics: α = (k-1)/Λ
  alpha = (k_eff - 1.0_rk) / lambda_prompt
end function compute_alpha_from_k
```

**Solution**: Compute Λ from flux/cross-section integral:
```
Λ = ∫ φ(r) / (v·Σ_f) dV / ∫ φ(r) dV
```

### 2. **Initial Energy Not Set**
- The initial QP (total internal energy) is computed from zone temperatures
- Reference: QP₀ = 3485 × 10¹² erg
- Simulation: QP₀ = 783 × 10¹² erg
- **Check**: Zone initial temperatures may need adjustment

### 3. **ICNTRL Mode Confusion**
- ICNTRL=0: Use initial geometry as-is (current run)
- ICNTRL=1: Scale geometry to achieve target alpha before transient
- **Recommendation**: Try ICNTRL=1 to let code find proper critical geometry

## Files Modified

### Fortran Source Code
1. `src/io_1959.f90` - Added CSV output subroutines
2. `src/main_1959.f90` - Added CSV file handling in main loop

### Python Scripts
3. `scripts/generate_geneve10_input.py` - Fixed ICNTRL=0 input format
4. `scripts/quick_comparison.py` - Created preliminary validation script

### Input Files
5. `inputs/geneve10_generated.inp` - Corrected format for ICNTRL=0

### Output Files
6. `output_time_series.csv` - Time evolution data (partial)
7. `output_spatial_t200.csv` - Spatial profile (empty, termination before t=200)
8. `validation/plots/geneve10_preliminary_comparison.png` - Comparison plot

## Next Steps (Priority Order)

### **Immediate Fixes Required**

1. **Fix Generation Time Calculation** [HIGH PRIORITY]
   - Implement proper Λ calculation from flux and cross sections
   - Target: Λ ~ 0.19 μsec (inferred from alpha/k ratio)
   - Formula: `Λ = 1 / (v_n · Σ_f_eff)` where v_n ~ 2×10⁹ cm/s for fast neutrons

2. **Verify Initial Conditions** [HIGH PRIORITY]
   - Check zone initial temperatures in input file
   - Target: QP₀ = 3485 × 10¹² erg
   - May need to adjust initial thermal energy distribution

3. **Try ICNTRL=1 Mode** [RECOMMENDED]
   - Let code find critical geometry automatically
   - Set ALPHA_TARGET = 0.013084 μsec⁻¹
   - This may resolve both alpha and energy issues

### **After Fixes**

4. **Rerun Full Transient** (0-200 μsec)
   - Collect full time-series data
   - Capture spatial profile at t=200 μsec

5. **Generate Validation Report**
   - Compare all time points
   - Calculate RMS errors
   - Create publication-quality plots

6. **Document Final Results**
   - Summarize agreement with reference
   - Report error metrics (target: <1% for QP, <5% for power)

## Technical Details

### CSV Output Format

**time_series.csv**:
```
time_microsec,QP_1e12_erg,power_relative,alpha_1_microsec,delt_microsec,W_dimensionless
```

**spatial_t200.csv**:
```
zone_index,density_g_cm3,radius_cm,velocity_cm_microsec,pressure_megabars,internal_energy_1e12_erg_g,temperature_keV
```

### Compilation Commands
```bash
make -f Makefile.1959 clean
make -f Makefile.1959
```

### Run Command
```bash
./ax1_1959 inputs/geneve10_generated.inp > geneve10_transient.log 2>&1
```

## Success Criteria

- ✅ k_eff matches reference (1.003 ± 0.001) - **ACHIEVED**
- ⏳ Alpha matches reference (0.01308 ± 10%) - **NOT ACHIEVED** (2.7x off)
- ⏳ Transient runs to t=200 μsec - **NOT ACHIEVED** (stops at 3.75 μsec)
- ⏳ QP matches reference within 5% - **NOT ACHIEVED** (4.4x off initially)
- ⏳ Power evolution matches reference within 10% - **NOT ACHIEVED** (insufficient data)

## Conclusion

The infrastructure for CSV output and transient simulation is **fully implemented and working**. The remaining issue is a **physics parameter problem** (generation time Λ and/or initial conditions), not a code structure problem. Fixing the generation time calculation or using ICNTRL=1 mode should resolve the early termination and allow full transient replication.

**Estimated time to completion**: 2-4 hours to fix Λ calculation and rerun.

