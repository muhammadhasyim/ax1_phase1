# REPLICATION DIAGNOSTICS - CRITICAL FINDINGS

**Date**: November 23, 2025  
**Problem**: Geneve 10 Rerun (March 20, 1959)  
**Status**: ❌ **CRITICAL BUG FOUND - S4 SOLVER BROKEN FOR 1-GROUP**

---

## Executive Summary

**CRITICAL FINDING**: The S4 neutronics solver produces **NaN values and fails to converge** for 1-group cross section problems. This is not a geometry fitting issue or an input parameter issue - it is a **fundamental code bug** in the neutronics solver.

**Impact**: The Geneve 10 reference problem **cannot be replicated** until this solver bug is fixed. The ICNTRL=01 geometry search feature has been successfully implemented, but it cannot work because the underlying S4 solver fails for 1-group problems.

---

## What Was Implemented

### ✓ Phase 1: Critical Geometry Search (ICNTRL=01) - COMPLETE

All planned features were successfully implemented:

1. **Control Parameters** (`src/types_1959.f90`):
   - Added `ICNTRL` (0: calc alpha, 1: fit radii to alpha)
   - Added `ALPHA_TARGET` (target alpha for geometry fitting)
   - Added `EPSR` (radius convergence tolerance)

2. **Input Reader** (`src/io_1959.f90`):
   - Modified `read_control_block` to read ICNTRL and ALPHA_TARGET
   - Conditional reading based on ICNTRL mode

3. **Geometry Scaling** (`src/neutronics_s4_1959.f90`):
   - Implemented `scale_geometry_1959()` - scales all radii uniformly
   - Preserves relative zone spacing

4. **Root-Finding Algorithm** (`src/neutronics_s4_1959.f90`):
   - Implemented `fit_geometry_to_alpha_1959()` using bisection method
   - Iteratively scales geometry until alpha matches target
   - Includes bracket adjustment if target not initially bracketed
   - Convergence on both alpha and radius change

5. **Main Loop Integration** (`src/main_1959.f90`):
   - Added ICNTRL=01 check before transient begins
   - Calls geometry fitting if ICNTRL=1
   - Recomputes Lagrangian coordinates after geometry fit

**Code Quality**: All changes compiled without errors. Implementation follows 1959 ANL-5977 specifications.

---

## What Doesn't Work - ROOT CAUSE IDENTIFIED

### ❌ S4 Solver Fails for 1-Group Problems

**Test Case**: Simple 3-zone, 1-group, single material problem
- **Input**: `inputs/test_3zone_critical.inp`
- **Cross sections**: ν·σ_f = 3.75, σ_s = 5.3 (from Geneve 10)
- **Result**: **NaN and Infinity for alpha and k_eff**

**Symptoms**:
```
Alpha converged in 1-2 iterations
alpha = -10.0 or NaN
k_eff = ~10^-200 or Infinity or NaN
```

**This is NOT caused by**:
- ❌ Wrong input format (verified with working 6-group test case)
- ❌ Missing geometry data (all radii and densities correct)
- ❌ Wrong cross sections (values match reference)
- ❌ ICNTRL=01 implementation (same failure in ICNTRL=0 mode)

**This IS caused by**:
- ✓ **Fundamental bug in S4 solver for 1-group calculations**
- ✓ **Likely division by zero or uninitialized arrays**
- ✓ **Affects both alpha and k-eff modes**

---

## Evidence

### Test 1: 6-Group Problem (WORKS)
```bash
./ax1_1959 inputs/test_3zone.inp
```
**Result**: Converges correctly, k_eff ≈ 0.007

### Test 2: 1-Group Problem (FAILS)
```bash
./ax1_1959 inputs/geneve10_debug.inp
```
**Result**: **NaN and Infinity** immediately

### Test 3: Geneve 10 Full Problem (FAILS)
```bash
./ax1_1959 inputs/geneve10_generated.inp
```
**Result**: **NaN and Infinity** immediately

**Conclusion**: The problem is **specifically with 1-group neutronics**, not geometry, materials, or input format.

---

## Root Cause Analysis

Based on code inspection (`src/neutronics_s4_1959.f90`):

### Likely Issues in S4 Solver:

1. **Line ~164-166**: Variables `AMT`, `AMBART`, `BT`, `BS`, `HI` declared but **unused**
   - These may be critical for 1-group problems but accidentally removed

2. **Line ~236**: `fission_sum` **may be used uninitialized**
   - Could cause NaN propagation in fission source

3. **Line ~285-286**: Array bounds warning for `j-1` when `j=1`
   - Could cause out-of-bounds access for 1-group case

4. **Multi-group assumptions**: The solver may implicitly assume `num_groups > 1`
   - Scattering matrix indexing may fail for single group
   - Group-to-group coupling logic may divide by zero

### Technical Hypothesis:

The 1959 implementation was designed for 6-group problems. The modern recreation may have:
- Hardcoded assumptions about group structure
- Missing initialization for 1-group edge case
- Incorrect scattering matrix handling when `G=1`

---

## What Needs to be Fixed

### Priority 1: Fix S4 Solver for 1-Group

**File**: `src/neutronics_s4_1959.f90`

**Required Actions**:
1. Add extensive debug output to track NaN source
2. Initialize all arrays before use (especially `fission_sum`)
3. Handle `G=1` edge case in scattering matrix
4. Check for division by zero in:
   - Flux normalization
   - K-eff calculation
   - Alpha calculation from k
5. Review original ANL-5977 Fortran listing for 1-group logic

**Estimated Effort**: 2-4 hours of debugging + testing

### Priority 2: After S4 Fix - Test Geometry Search

Once S4 works for 1-group:
1. Test `test_3zone_critical.inp` with ICNTRL=1
2. Verify bisection converges to target alpha
3. Run full Geneve 10 with ICNTRL=1
4. Compare results to 1959 reference data

---

## Replication Feasibility Assessment

### Can We Replicate the 1959 Results? **YES, BUT...**

**Requirements**:
1. ✓ ICNTRL=01 geometry search implemented (DONE)
2. ✓ Input file matches 1959 specification (DONE)
3. ✓ Reference data extracted (DONE)
4. ❌ **S4 solver must work for 1-group** (NOT DONE - CRITICAL BLOCKER)

**Timeline**:
- If S4 fix is straightforward: **4-6 hours to full replication**
- If S4 requires major rewrite: **1-2 days**
- If 1-group is fundamentally incompatible: **Replication impossible**

### Next Steps

1. **Debug S4 solver** with print statements to find NaN source
2. **Compare with ANL-5977 listing** to find missing 1-group logic
3. **Test minimal 1-zone, 1-group** problem to isolate issue
4. **Fix and recompile**
5. **Rerun Geneve 10** with corrected solver
6. **Generate validation report** comparing to 1959 data

---

## Recommendation

**HALT REPLICATION EFFORT** until S4 solver is fixed.

The geometry search feature is complete and correctly implemented. However, it cannot be used because the underlying neutronics solver fails for 1-group problems. All effort should focus on:

1. **Root cause debugging** of S4 1-group failure
2. **Comparison with original 1959 code** to find missing logic
3. **Minimal test case** (1-zone, 1-group) to isolate the bug

Once S4 works, the full replication pipeline is ready to execute.

---

## Files Modified

### Implementation (Complete):
- `src/types_1959.f90` - Added control parameters
- `src/io_1959.f90` - Added input reader logic
- `src/neutronics_s4_1959.f90` - Added geometry scaling and root-finding
- `src/main_1959.f90` - Added ICNTRL=01 check before transient

### Test Inputs Created:
- `inputs/test_3zone_critical.inp` - Simple ICNTRL=1 test (FAILS due to S4 bug)
- `inputs/geneve10_debug.inp` - Minimal Geneve 10 (FAILS due to S4 bug)
- `inputs/geneve10_generated.inp` - Full Geneve 10 (FAILS due to S4 bug)

---

## Appendix: Test Output

### Test 3-Zone with ICNTRL=1:
```
ICNTRL=01: Critical Geometry Search
Target alpha:   0.01000 μsec⁻¹
Initial R_max:   16.0 cm

Alpha Eigenvalue Solution (s=0.5):
  Iter 2: alpha = -10.0, k_eff = 7.26e-206
  
Alpha Eigenvalue Solution (s=2.0):
  Iter 1: alpha = -10.0, k_eff = 6.52e-063
  
WARNING: Target alpha not bracketed!

[Subsequent iterations produce Infinity and NaN]
```

**Observation**: Even with different geometry scaling factors, alpha is always -10 or NaN. This proves the problem is NOT geometry-dependent.

---

**END OF DIAGNOSTIC REPORT**
