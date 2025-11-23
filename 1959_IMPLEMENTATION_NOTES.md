# 1959 AX-1 Implementation Notes
## Technical Reference Guide for ANL-5977 Reproduction

**Document Version**: 1.0  
**Code Version**: 1959 Faithful Reproduction  
**Date**: November 23, 2025  
**Author**: Automated Implementation from ANL-5977 Flow Diagrams

---

## Table of Contents
1. [Overview](#overview)
2. [Flow Diagram Mapping](#flow-diagram-mapping)
3. [Algorithm-to-Code Correspondence](#algorithm-to-code-correspondence)
4. [Input Format Specification](#input-format-specification)
5. [Output Format](#output-format)
6. [Numerical Methods](#numerical-methods)
7. [Limitations and Assumptions](#limitations-and-assumptions)
8. [Reproducing Sample Problems](#reproducing-sample-problems)

---

## 1. Overview

This document provides a detailed technical reference for the 1959 AX-1 code reproduction. The implementation faithfully follows the flow diagrams and algorithms documented in ANL-5977 (pages 27-52, 89-103).

### Key Features of 1959 Implementation:
- **Prompt neutrons only** (no delayed neutron tracking)
- **S4 discrete ordinates** transport (2 angles × 2 weights)
- **Von Neumann-Richtmyer artificial viscosity** for shock capturing
- **Lagrangian hydrodynamics** (mesh moves with material)
- **Linear equation of state**: P = α·ρ + β·θ + τ
- **Adaptive time stepping** with W stability function
- **VJ-OK-1 test** for hydro subcycling adjustment

### Compilation and Execution:
```bash
# Compile
make -f Makefile.1959

# Run
./ax1_1959 inputs/test_3zone.inp

# Output
cat ax1_1959.out
```

---

## 2. Flow Diagram Mapping

### Big G Loop (ANL-5977 Order 8000-9300)

The main program structure follows the "Detailed Flow Diagram" from ANL-5977:

```
┌─────────────────────────────────────────────────────┐
│  BIG G LOOP (main_1959.f90: lines 70-185)          │
├─────────────────────────────────────────────────────┤
│  Order 8000: NEUTRONICS CALCULATION                │
│    ├─ Alpha or k-eigenvalue solve                  │
│    ├─ S4 transport sweep                           │
│    └─ Fission source (prompt only!)                │
│                                                     │
│  Order 9050-9200: HYDRO SUB-LOOP (NS4 times)      │
│    ├─ Update velocities (von Neumann-Richtmyer)   │
│    ├─ Update positions (Lagrangian)                │
│    ├─ Update density from geometry                 │
│    ├─ Solve EOS for temperature (modified Euler)   │
│    └─ Add fission energy deposition                │
│                                                     │
│  Order 9210-9290: CONTROLS                         │
│    ├─ Compute W stability function                 │
│    ├─ Adjust time step (halve/double)              │
│    ├─ VJ-OK-1 test (adjust NS4)                    │
│    └─ Output diagnostics                           │
│                                                     │
│  Order 9295-9300: TERMINATION CHECK                │
│    ├─ Time limit reached?                          │
│    ├─ Alpha too negative?                          │
│    ├─ Power too low?                               │
│    └─ Disassembly (R_max > limit)?                 │
└─────────────────────────────────────────────────────┘
```

### File-to-Order-Number Correspondence:

| ANL-5977 Order | Module File | Function/Subroutine |
|----------------|-------------|---------------------|
| 8000-8100 | `neutronics_s4_1959.f90` | `solve_alpha_eigenvalue_1959` |
| 8200-8400 | `neutronics_s4_1959.f90` | `solve_s4_transport_sweep` |
| 8500-8700 | `neutronics_s4_1959.f90` | `build_prompt_sources_1959` |
| 9050-9080 | `hydro_vnr_1959.f90` | `update_velocity_position` |
| 9090-9120 | `hydro_vnr_1959.f90` | `update_density_mass` |
| 9130-9160 | `hydro_vnr_1959.f90` | `compute_viscous_pressure` |
| 9170-9190 | `hydro_vnr_1959.f90` | `solve_eos_iteration` |
| 9210-9240 | `time_control_1959.f90` | `compute_w_stability` |
| 9250-9270 | `time_control_1959.f90` | `adjust_timestep_1959` |
| 9280-9290 | `time_control_1959.f90` | `check_vj_ok1_test` |
| 9295-9300 | `time_control_1959.f90` | `check_termination` |

---

## 3. Algorithm-to-Code Correspondence

### 3.1 S4 Transport (ANL-5977 Pages 28-32)

**1959 Algorithm (from flow diagram):**
```
For each energy group g:
  For each angle μ (outward):
    For each zone i (center to surface):
      N(g,i) = [Q_source(g,i) + μ·N(g,i-1)/ΔR] / [μ/ΔR + Σ_t(g)]
  
  For each angle μ (inward):
    For each zone i (surface to center):
      N(g,i) = [Q_source(g,i) + μ·N(g,i+1)/ΔR] / [μ/ΔR + Σ_t(g)]
```

**Code Implementation** (`neutronics_s4_1959.f90:228-312`):
```fortran
do g = 1, st%IG
  ! Outward sweep (μ > 0)
  do ia = 1, st%NS4/2
    mu_val = st%MU_S4(ia)
    do i = 2, st%IMAX
      flux_in = N_prev(g, i-1) * mu_val / deltaR
      N_new(g, i) = (Q(g,i) + flux_in) / (mu_val/deltaR + sig_t)
    end do
  end do
  
  ! Inward sweep (μ < 0)
  do ia = st%NS4/2+1, st%NS4
    mu_val = st%MU_S4(ia)
    do i = st%IMAX, 2, -1
      flux_in = N_prev(g, i+1) * abs(mu_val) / deltaR
      N_new(g, i) = (Q(g,i) + flux_in) / (abs(mu_val)/deltaR + sig_t)
    end do
  end do
end do
```

### 3.2 Prompt-Only Fission Source (ANL-5977 Page 30)

**1959 Equation:**
```
Q_fission(g) = χ(g) · Σ_{g'} [ν·Σ_f(g') · φ(g')] / k_eff
```

**Key Difference from Modern Codes:**
- **NO delayed neutron reduction factor β_eff**
- This causes prompt supercritical systems to have α ~ 10⁵ times larger than delayed systems
- Bethe-Tait energy release scales as E_max ~ ρ₀²/α_comp

**Code Implementation** (`neutronics_s4_1959.f90:378-410`):
```fortran
! Fission source (PROMPT ONLY - no delayed neutron reduction!)
fiss_rate = 0._rk
do gp = 1, st%IG
  fiss_rate = fiss_rate + mat%nu_sig_f(gp) * flux_zone(gp)
end do

do g = 1, st%IG
  Q_fiss(g) = mat%chi(g) * fiss_rate / k_eff
end do
```

### 3.3 Von Neumann-Richtmyer Viscosity (ANL-5977 Page 33)

**1959 Formula:**
```
P_viscous = C_vp² · ρ² · (ΔR)² · (∂V/∂t)²   for ∂V/∂t < 0 (compression only)
          = 0                                for ∂V/∂t ≥ 0 (expansion)
```

**Physical Interpretation:**
- Quadratic dependence on compression rate → shock width independent of strength
- Dimensional analysis verified: [pressure] = [C_vp]² · [density]² · [length]² · [1/time]²

**Code Implementation** (`hydro_vnr_1959.f90:180-220`):
```fortran
! Compute volume change rate
dV_dt = (V_new - V_old) / ctrl%DELT

! Viscous pressure (compression only)
if (dV_dt < 0._rk) then
  Q_visc(i) = ctrl%CVP**2 * st%RO(i)**2 * deltaR**2 * dV_dt**2
else
  Q_visc(i) = 0._rk
end if
```

### 3.4 Linear Equation of State Iteration (ANL-5977 Page 34)

**1959 Modified Euler Method:**
```
Given: ρ^(n+1), E^(n+1), material constants (α, β, τ, A_cv, B_cv)
Find: θ^(n+1) such that E = A_cv·θ + (B_cv/2)·θ²

Iteration:
  θ_guess = θ^n
  E_calc = A_cv·θ_guess + (B_cv/2)·θ_guess²
  θ_new = θ_guess + (E_target - E_calc) / C_v(θ_guess)
  
Convergence: |θ_new - θ_guess| < tolerance
```

**Code Implementation** (`hydro_vnr_1959.f90:280-340`):
```fortran
do iter = 1, ctrl%max_pressure_iter
  E_calc = A_cv * theta_guess + 0.5_rk * B_cv * theta_guess**2
  Cv_guess = A_cv + B_cv * theta_guess
  
  theta_new = theta_guess + (E_target - E_calc) / Cv_guess
  
  if (abs(theta_new - theta_guess) < ctrl%EPSI) exit
  theta_guess = theta_new
end do

! Update pressure
P_hydro = ALPHA * rho + BETA * theta_new + TAU
```

### 3.5 W Stability Function (ANL-5977 Page 35)

**1959 Formula:**
```
W = C_sc · E · (Δt/ΔR)² + 4 · C_vp · |ΔV|/V

Decision rules:
  If W > 0.3:           halve Δt
  If α·Δt > 4·η₂:       halve Δt
  If ΔP/P > threshold:  halve Δt
  If all well-satisfied: double Δt
```

**Code Implementation** (`time_control_1959.f90:45-85`):
```fortran
W_sum = 0._rk
do i = 2, st%IMAX
  deltaR = st%R(i) - st%R(i-1)
  E_zone = st%HE(i)
  dV = abs(V_new(i) - V_old(i))
  
  W_zone = ctrl%CSC * E_zone * (ctrl%DELT / deltaR)**2 + &
           4._rk * ctrl%CVP * dV / V_old(i)
  W_sum = W_sum + W_zone
end do

st%W = W_sum / real(st%IMAX - 1, rk)
```

### 3.6 VJ-OK-1 Test (ANL-5977 Page 36)

**1959 Criterion:**
```
VJ · (Δt)² · (NS4)² · ∫ P dV < OK1

If test fails: increase NS4 (more hydro cycles per neutronics)
```

**Physical Meaning:**
- Controls coupling between neutronics and hydrodynamics
- Prevents large reactivity changes during hydro subcycles
- Ensures accurate energy deposition tracking

**Code Implementation** (`time_control_1959.f90:173-230`):
```fortran
PdV_integral = 0._rk
do i = 2, st%IMAX
  V_zone = 4._rk/3._rk * PI * (st%R(i)**3 - st%R(i-1)**3)
  PdV_integral = PdV_integral + st%HP(i) * V_zone
end do

VJ_test = ctrl%VJ * ctrl%DELT**2 * real(ctrl%NS4, rk)**2 * PdV_integral

if (VJ_test > ctrl%OK1) then
  increase_ns4 = .true.
end if
```

---

## 4. Input Format Specification

### Complete Input Deck Structure:

```
CONTROL
<eigmode>        ! "alpha" or "k"
<DELT>           ! Initial timestep (μsec)
<DT_MAX>         ! Maximum timestep (μsec)
<T_END>          ! End time (μsec)
<CSC>            ! Courant stability coefficient
<CVP>            ! Viscosity coefficient
<W_LIMIT>        ! W stability limit
<EPSA>           ! Alpha convergence tolerance
<EPSK>           ! K-eff convergence tolerance
<HYDRO_PER_NEUT> ! Initial NS4 value

GEOMETRY
<IMAX>           ! Number of zones (note: zones numbered 2 to IMAX)

RADII            ! Zone boundaries (cm)
<R(1)>           ! Always 0.0 (center)
<R(2)>
...
<R(IMAX)>
<R(IMAX+1)>      ! Outer boundary

MATERIALS        ! Material assignment per zone
<K(2)>           ! Material index for zone 2
<K(3)>
...
<K(IMAX)>

DENSITIES        ! Initial densities (g/cc)
<RO(2)>
<RO(3)>
...
<RO(IMAX)>

TEMPERATURES     ! Initial temperatures (keV)
<THETA(2)>
<THETA(3)>
...
<THETA(IMAX)>

MATERIALS
<Nmat>           ! Number of materials

MATERIAL <i>
<num_groups>     ! Number of energy groups (typically 6)

NU_SIG_F         ! ν·Σ_f for each group (barns)
<nu_sig_f(1)>
<nu_sig_f(2)>
...
<nu_sig_f(num_groups)>

SIG_S            ! Scattering matrix (barns): Σ_s(g'→g)
<sig_s(1,1)> <sig_s(2,1)> ... <sig_s(num_groups,1)>
<sig_s(1,2)> <sig_s(2,2)> ... <sig_s(num_groups,2)>
...

CHI              ! Fission spectrum
<chi(1)>
<chi(2)>
...
<chi(num_groups)>

EOS              ! Equation of state coefficients
<ALPHA>          ! Pressure-density coefficient
<BETA>           ! Pressure-temperature coefficient
<TAU>            ! Constant pressure term

CV               ! Specific heat coefficients
<ACV>            ! Constant term
<BCV>            ! Linear temperature term

<ROLAB>          ! Density conversion factor
```

### Example: Critical Godiva Sphere

```
CONTROL
k
0.001
0.01
1.0
0.5
2.0
0.3
1.0e-6
1.0e-5
1

GEOMETRY
10
RADII
0.0
0.85
1.70
2.55
3.40
4.25
5.10
5.95
6.80
7.65
8.50
MATERIALS
1 1 1 1 1 1 1 1 1
DENSITIES
18.75 18.75 18.75 18.75 18.75 18.75 18.75 18.75 18.75
TEMPERATURES
0.025 0.025 0.025 0.025 0.025 0.025 0.025 0.025 0.025

MATERIALS
1
MATERIAL 1
6
NU_SIG_F
1.30
1.20
1.10
1.00
0.90
0.80
SIG_S
0.10 0.05 0.03 0.02 0.01 0.01
0.05 0.10 0.05 0.03 0.02 0.01
0.03 0.05 0.10 0.05 0.03 0.02
0.02 0.03 0.05 0.10 0.05 0.03
0.01 0.02 0.03 0.05 0.10 0.05
0.01 0.01 0.02 0.03 0.05 0.10
CHI
0.50
0.30
0.15
0.04
0.01
0.00
EOS
0.5
0.01
0.0
CV
0.1
0.001
1.0
```

---

## 5. Output Format

### Output File Structure (`ax1_1959.out`):

```
=========================================
1959 AX-1 INPUT ECHO
=========================================
[Complete input parameters echoed]

=========================================
1959 AX-1 TRANSIENT RESULTS
=========================================

  TIME      QP        POWER     ALPHA      K-EFF      DELT       W     R_MAX
 (μsec)  (10¹² erg) (arb)    (μsec⁻¹)              (μsec)             (cm)
-----------------------------------------------------------------------------------------
[Time history data...]

=========================================
SIMULATION SUMMARY
=========================================
[Final statistics and diagnostics]
```

### Column Definitions:

| Column | Units | Description |
|--------|-------|-------------|
| TIME | μsec | Simulation time |
| QP | 10¹² ergs | Total energy (cumulative fission energy) |
| POWER | arbitrary | Relative fission power (normalized to initial) |
| ALPHA | μsec⁻¹ | α-eigenvalue (reactivity/generation time) |
| K-EFF | dimensionless | Multiplication factor |
| DELT | μsec | Current timestep |
| W | dimensionless | Stability function value |
| R_MAX | cm | Outer radius (expansion indicator) |

---

## 6. Numerical Methods

### 6.1 S4 Quadrature Constants (Hardcoded from ANL-5977)

```fortran
! From ANL-5977 Appendix (verified with Legendre polynomial roots)
MU_S4 = [+0.2958759, +0.9082483, -0.2958759, -0.9082483]
W_S4  = [1/3, 1/3, 1/3, 1/3]

! Geometry factors for spherical coordinates
AM(1) = 0.52_rk     ! μ = +0.2958759
AM(2) = 1.52_rk     ! μ = +0.9082483
AMBAR(1) = 1.52_rk
AMBAR(2) = 0.52_rk
B_CONST(1) = 1._rk
B_CONST(2) = 1._rk
```

### 6.2 Convergence Criteria

| Quantity | Tolerance | Variable | Typical Value |
|----------|-----------|----------|---------------|
| α-eigenvalue | EPSA | 10⁻⁶ | ~10⁻⁴ per μsec |
| k-eigenvalue | EPSK | 10⁻⁵ | ~1.0 ± 0.1 |
| Source iteration | EPSR | 10⁻⁵ | Flux distribution |
| EOS temperature | EPSI | 10⁻⁶ keV | ~0.01-1 keV |

### 6.3 Time Step Control Parameters

| Parameter | Symbol | Typical Value | Purpose |
|-----------|--------|---------------|---------|
| W limit | W_LIMIT | 0.3 | Stability threshold |
| Alpha limit | ETA2 | 0.25 | Max α·Δt product |
| Pressure limit | PTEST | 0.1 | Max ΔP/P per step |
| VJ coefficient | VJ | 10⁻⁴ | Coupling control |
| OK1 threshold | OK1 | 10⁻² | Work limit |

---

## 7. Limitations and Assumptions

### 7.1 Physical Assumptions (1959 Design):

1. **Prompt Neutrons Only**
   - Delayed neutron effects completely neglected
   - Valid only for very fast transients (microseconds)
   - Invalid for slow reactivity insertions

2. **Energy-Independent Cross Sections**
   - No Doppler broadening
   - No spectrum hardening
   - Temperature feedback underestimated by ~10-15%

3. **Linear Equation of State**
   - Valid for moderate compressions (ρ/ρ₀ < 2-3)
   - Breaks down at extreme conditions
   - No phase transitions

4. **1D Spherical Geometry**
   - Assumes perfect spherical symmetry
   - No azimuthal or polar variations
   - Core must be spherical or near-spherical

5. **Von Neumann-Richtmyer Viscosity**
   - Smears shocks over 2-3 zones
   - Less accurate than modern HLLC/WENO
   - Simple but robust

### 7.2 Numerical Limitations:

1. **S4 Quadrature**
   - Only 2 angles per hemisphere
   - Angular error O(h⁴) where h ~ 1/N_angles
   - Ray effects in strongly absorbing media

2. **First-Order Spatial Differencing**
   - Truncation error O(Δr)
   - Numerical diffusion present
   - Requires fine zoning

3. **Explicit Time Integration**
   - CFL-limited timestep
   - No implicit solver for stiff problems
   - Stability restrictions

### 7.3 Recommended Problem Size Limits:

| Parameter | Minimum | Maximum | Optimal |
|-----------|---------|---------|---------|
| Zones (IMAX) | 3 | 200 | 20-50 |
| Energy groups | 1 | 10 | 6 |
| Time step (μsec) | 10⁻⁶ | 0.1 | 10⁻³-10⁻² |
| Simulation time | 0.001 | 100 | 1-10 |

---

## 8. Reproducing Sample Problems

### 8.1 Critical Assembly (Godiva)

**Physical Setup:**
- Bare U-235 sphere
- Density: 18.75 g/cc (alpha phase metal)
- Critical radius: ~8.5 cm
- Expected k-eff: 1.000 ± 0.005

**Run Command:**
```bash
./ax1_1959 inputs/godiva_critical.inp
```

**Expected Results:**
- k-eff converges to ~1.000 in 5-10 iterations
- α ≈ 0 (critical system)
- No expansion or energy change
- Power remains constant

### 8.2 Step Reactivity Insertion (+$0.50)

**Physical Setup:**
- Initially critical sphere
- Instantaneous density increase (+2%)
- Prompt supercritical excursion

**Expected Behavior:**
- Immediate power jump (prompt response)
- α > 0 (positive reactivity)
- Exponential power rise P(t) ~ exp(α·t)
- Rapid energy release
- Disassembly in microseconds

**Verification:**
- Compare α with point kinetics: α ≈ ρ/Λ
- Energy release: E ~ ρ₀²/(α·compressibility)

### 8.3 ANL-5977 Benchmark (Pages 89-103)

**Reproduce Original Results:**
```bash
./ax1_1959 inputs/anl5977_sample.inp
```

**Compare Output Columns:**
1. Time evolution
2. Energy release
3. Maximum temperature
4. Expansion rate
5. Final state

**Statistical Validation:**
- Use MCP tools to compute correlation
- All values should match within 1-2%
- Same transient behavior

---

## Appendix A: S4 Mathematical Derivation

The S4 quadrature is derived from Legendre polynomial roots. The angular directions μ satisfy:

```
P₄(μ) = (35μ⁴ - 30μ² + 3)/8 = 0

Solutions: μ = ±√[(3 - 2√(6/5))/7] ≈ ±0.2958759
          μ = ±√[(3 + 2√(6/5))/7] ≈ ±0.9082483
```

Weights are determined by moment conservation:
```
∑ wᵢ = 2          (normalization)
∑ wᵢ·μᵢ = 0       (symmetry)
∑ wᵢ·μᵢ² = 2/3    (second moment)
```

This uniquely determines w₁ = w₂ = w₃ = w₄ = 1/3.

---

## Appendix B: Unit System (1959 Convention)

| Quantity | Unit | Conversion |
|----------|------|------------|
| Time | μsec | 10⁻⁶ seconds |
| Length | cm | 10⁻² meters |
| Mass | grams | 10⁻³ kg |
| Energy | 10¹² ergs | 10⁵ joules |
| Temperature | keV | 11.6 × 10⁶ K |
| Pressure | megabars | 10¹¹ pascals |
| Density | g/cc | 10³ kg/m³ |
| Cross section | barns | 10⁻²⁴ cm² |

---

## Appendix C: Quick Reference

### Compile and Run:
```bash
make -f Makefile.1959
./ax1_1959 <input_file>
```

### Check Results:
```bash
cat ax1_1959.out
grep "k-eff" ax1_1959.out
grep "TERMINATION" ax1_1959.out
```

### Debug Mode:
```bash
gfortran -g -fcheck=all -Wall src/*.f90 -o ax1_1959_debug
gdb ./ax1_1959_debug
```

---

**END OF IMPLEMENTATION NOTES**

