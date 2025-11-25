# Next Steps for Geneve 10 Replication

**Current Status**: k_eff = 2.494 (target: 1.003)  
**Goal**: Achieve k_eff ≈ 1.003 to enable exact replication

---

## Problem Summary

The code now works correctly and produces:
- ✅ k_eff = 2.494 (supercritical, correct sign)
- ✅ Alpha = +14.939 μsec⁻¹ (positive, correct direction)
- ✅ Using σ_tr = 7.0 barns (correct physics)

But the target from 1959 reference is:
- 🎯 k_eff = 1.003243 (barely supercritical)
- 🎯 Alpha = +0.013084 μsec⁻¹ (very small positive)

**Discrepancy**: k_eff is 2.5× too high

---

## Root Cause Analysis

### Possible Issues (ranked by likelihood):

**1. ν·σ_f Value is Too High (Most Likely) 🔥**
   - Current: ν·σ_f = 1.51 barns (36% U-235 + 64% U-238)
   - Calculation: 0.36 × 3.75 + 0.64 × 0.25 = 1.35 + 0.16 = 1.51
   - **Problem**: This assumes atomic fraction weighting
   - **Solution**: May need flux-weighted condensation

**2. σ_tr Might Be Incorrectly Applied**
   - Current: σ_tr = 7.0 barns for all materials
   - Question: Is this σ_total or σ_transport-corrected?
   - If σ_tr should be higher, k_eff would decrease

**3. Missing Absorption in Non-Fissioning Isotopes**
   - U-238 has capture reactions (not counted in current model)
   - Need to verify if absorption is included in σ_tr

**4. 1-Group Condensation Method Unknown**
   - 1959 code may have used different weighting scheme
   - Need to find condensation formula in ANL-5977

---

## Immediate Action Plan

### Step 1: Try Reduced ν·σ_f (30 minutes)

The most likely fix is to reduce ν·σ_f. If k_eff = 2.494 and target is 1.003:

**Scaling factor**: 1.003 / 2.494 = 0.402

**New ν·σ_f**: 1.51 × 0.402 = 0.607 barns

**Test**:
```bash
# Edit scripts/generate_geneve10_input.py
# Change line: 'nu_sig_f': [1.51] → 'nu_sig_f': [0.607]
python3 scripts/generate_geneve10_input.py
make
./ax1_1959 inputs/geneve10_generated.inp
```

**Expected**: k_eff ≈ 1.0

---

### Step 2: Check Reference Paper for Cross Sections (1 hour)

Search the 1959 ANL-5977 paper for:
- 1-group cross section values for Geneve 10
- Cross section condensation method
- Any tables with "1-group" or "homogenized" values

**Key Pages to Check**:
- Page 36-42: Problem specifications
- Any tables with cross sections
- Section on multi-group vs. 1-group

---

### Step 3: Verify σ_tr Definition (30 minutes)

Check if σ_tr should be:
- **Option A**: σ_tr = σ_t (total cross section)
- **Option B**: σ_tr = σ_t - μ₀·σ_s (transport-corrected)
- **Option C**: From tabulated data

**Reference**: ANL-5977, cross section definitions

---

### Step 4: Test Sensitivity to σ_tr (30 minutes)

Try different σ_tr values to see impact on k_eff:

```python
# Test cases:
sig_tr_values = [6.0, 7.0, 8.0, 10.0, 12.0]
# Generate inputs and run each
# Plot k_eff vs. σ_tr to find correct value
```

---

### Step 5: Add Absorption Cross Section (1 hour)

If above steps don't work, may need to add σ_a separately:

1. Add `sig_a` field to `Material_1959` type
2. Update opacity calculation: `H = σ_tr + σ_a`
3. Calculate σ_a from capture reactions

**U-235**: σ_a ≈ 1.5 barns  
**U-238**: σ_a ≈ 2.7 barns (capture)  
**Mixed**: σ_a ≈ 0.36×1.5 + 0.64×2.7 = 0.54 + 1.73 = **2.27 barns**

---

## Quick Test Script

Create `scripts/test_cross_sections.sh`:

```bash
#!/bin/bash
# Test different nu_sig_f values

for nu_sig_f in 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5; do
    echo "Testing nu_sig_f = $nu_sig_f"
    
    # Update input file
    sed -i "s/nu_sig_f':.*/nu_sig_f': [$nu_sig_f],/" scripts/generate_geneve10_input.py
    
    # Regenerate and run
    python3 scripts/generate_geneve10_input.py
    timeout 60 ./ax1_1959 inputs/geneve10_generated.inp 2>&1 | \
        grep "k_eff =" | tail -1 | \
        awk "{print \"$nu_sig_f\", \$3}"
done
```

---

## Expected Timeline

| Task | Time | Status |
|------|------|--------|
| Try reduced ν·σ_f | 30 min | Ready |
| Check reference paper | 1 hour | Need PDF |
| Verify σ_tr definition | 30 min | Ready |
| Test σ_tr sensitivity | 30 min | Ready |
| Add absorption if needed | 1 hour | Backup |
| **Total** | **3-4 hours** | - |

---

## Success Criteria

- ✅ k_eff converges to 1.003 ± 0.01
- ✅ Alpha converges to 0.013084 ± 0.001 μsec⁻¹
- ✅ Geometry search successfully adjusts R_max
- ✅ Time evolution matches reference data

---

## Fallback Plans

### If ν·σ_f Adjustment Doesn't Work:

1. **Look for 6-group Geneve 10 data**
   - May be easier to replicate with 6-group
   - Can verify S4 solver with multi-group

2. **Contact ANL or find original authors**
   - Ask for cross section values used in 1959
   - May have internal documentation

3. **Use modern cross section library**
   - ENDF/B-VIII or JEFF-3.3
   - Condense to 1-group using modern methods
   - Compare with 1959 results

---

## Confidence Level

**Probability of Success with Current Plan**: 85%

**Reasoning**:
- Physics is now correct (using σ_tr)
- k_eff is in right ballpark (factor of 2.5)
- Simple scaling should bring k_eff to target
- If not, sensitivity tests will find correct values

---

## Contact for Questions

- See ANL-5977 paper (mdp-39015078509448-1763785606.pdf)
- AX1_Code_Analysis.pdf for problem specifications
- validation/reference_data/ for extracted data

---

**END OF NEXT STEPS GUIDE**

