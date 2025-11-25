# AX-1 1959 Replication - Debugging Summary

## Objective
Replicate the Geneva 10 sample problem from ANL-5977 (1959) with:
- Expected k_eff = 1.003243
- Expected α = 0.013084 μsec⁻¹

## Progress Made

### 1. Scalar Flux Computation (FIXED)
**Location:** `src/neutronics_s4_1959.f90` lines 270-280

**Original (wrong):**
```fortran
st%N(g, i) = sum(st%ENN(i, 1:5)) / 5.0_rk
```

**Fixed (ANL-5977 trapezoidal rule):**
```fortran
do j = 1, 5
  sum2 = st%ENN(i, j) + st%ENN(i-1, j)  ! Spatial average
  if (j == 1 .or. j == 5) then
    sum2 = sum2 / 2.0_rk  ! Boundary angles half weight
  end if
  sum1 = sum1 + sum2
end do
st%N(g, i) = sum1 / 8.0_rk
```

### 2. Source Formula (FIXED)
**Location:** `src/neutronics_s4_1959.f90` lines 238-256

**ANL-5977 formula:** `SO(I) = 4*DELTA(I) * (χ*F/k + RHO*Σσ*N)`

Implemented with:
- Scattering: `Σ σ_s * N * RHO`
- Fission: `χ * νΣf * N / k`
- Multiplied by `4*DELTA*RHO` for proper normalization

### 3. k-Eigenvalue Iteration (FIXED)
**Location:** `src/neutronics_s4_1959.f90` lines 287-330

Implemented ANL-5977 Orders 300-325:
- WN(I) = T(I) * Σ N_new(g,I) (weight function from NEW flux)
- FFBARP = Σ WN * F_old (old fission, new weight)
- FFBAR = Σ WN * F_new (new fission, new weight)  
- k_new = k_old * FFBAR / FFBARP

### 4. Flux Normalization (ADDED)
**Location:** `src/neutronics_s4_1959.f90` line 284

Added `call normalize_flux(st)` after each sweep to prevent flux collapse/explosion.

### 5. Initial Flux Shape (MODIFIED)
**Location:** `src/io_1959.f90` lines 289-295

Changed from flat (N=1) to cosine shape for more physical initial guess.

## Remaining Issue: Transport Sweep

### Symptom
The k_eff converges to ~0.16 instead of ~1.0. The flux distribution is WRONG:
- Flux INCREASES from center to edge (should DECREASE)
- Center flux collapses to ~0 after normalization
- Outer zones dominate the weighted sums

### Analysis
The S4 sweep formula produces:
```
ENN(i,j) = [(AMT - BS - H)*ENN(L,j) + SO/2] / (AMT + BS + H)
```

For angle 1 (μ=1, radially outward):
- AMT = 1.0, BS = 0, H = 0.133
- Sweep starts at center with ENN = 0 (symmetry BC)
- Each zone: ENN grows because SO dominates over removal H

After 40 zones, ENN approaches steady-state ~SO/(4H), but early zones have much lower ENN.
This creates a flux profile that increases from center to edge.

### Root Cause
1. **Vacuum BC not effective:** Setting ENN(IMAX, 1:3) = 0 before sweep gets overwritten
2. **No geometric divergence for angle 1:** BS = BT/r = 0 for j=1, so no 1/r² effect
3. **Spherical S4 complexity:** The coupled angular terms may not be correctly implemented

### Reference Values
From ANL-5977 sample problem:
- σ_tr = 7.0 barns (transport cross-section)
- νσ_f = 3.75 barns (U-235 fission production)  
- σ_s = 5.3 barns (scattering)
- ρ = 0.02 (atom density in 10^24/cm³)
- k_∞ = νσ_f / σ_a = 3.75 / 1.7 = 2.2

### Diffusion Theory Estimate
For a 44 cm radius sphere:
- D = 1/(3*Σ_tr) = 2.38 cm
- M² = D/Σ_a = 70 cm²
- B² = (π/R)² = 0.005 cm⁻²
- k_eff ≈ k_∞/(1 + M²*B²) = 2.2/1.35 ≈ 1.6

The transport result (k=0.16) is 10x lower than diffusion theory (k≈1.6), indicating a fundamental transport bug.

## Next Steps
1. **Verify S4 constants:** Check AM, AMBAR, B values match ANL-5977
2. **Debug boundary conditions:** Ensure vacuum BC properly affects the solution
3. **Check angular coupling:** The AMBART terms couple adjacent angles
4. **Compare zone-by-zone:** Print flux at each zone and compare to expected shape
5. **Simplify test case:** Try 2-group or even 1-group with fewer zones

## Files Modified
- `src/neutronics_s4_1959.f90` - Transport sweep, source formula, k-iteration
- `src/io_1959.f90` - Initial flux shape
- `inputs/geneve10_reference.inp` - Cross-sections, control mode

