# AX-1 Equation Mapping: 1959 PDF to Modern Code

## Document Purpose

This document maps the computational methods, equations, and algorithms from the 1959 ANL-5977 report to their implementations in the modern Fortran codebase.

## 1. Neutronics: S4 Discrete Ordinates Method

### 1.1 Transport Equation (1959 PDF Section II)

**PDF Description**: "The neutronics of this system is calculated in conventional fashion, using the Sn method"

**1959 Implementation**: S4 approximation with 5 angular directions

**Modern Implementation**: 
- File: `src/neutronics_s4_alpha.f90`
- Subroutine: `sweep_spherical_k` (lines ~100-500)
- Enhancement: Supports S4, S6, S8 via `set_Sn_quadrature`

**Equation Mapping**:
```
PDF: S4 discrete ordinates in spherical geometry
Code: Lines 6333-6499 in 1959 Fortran listing
Modern: neutronics_s4_alpha.f90, subroutine sweep_spherical_k
Status: ✓ CORE MATCH (S4), ⊕ ENHANCED (S6/S8 added)
```

### 1.2 Angular Quadrature Weights (1959 Lines 6174-6188)

**PDF Constants**:
```fortran
AM(1) = 1.0,  AM(2) = 0.6666667,  AM(3) = 0.1666667
AM(4) = 0.3333333,  AM(5) = 0.8333333

AMBAR(1) = 0.0,  AMBAR(2) = 0.8333333,  AMBAR(3) = 0.3333333
AMBAR(4) = 0.1666667,  AMBAR(5) = 0.6666667

B(1) = 0.0,  B(2) = 1.6666667,  B(3) = 3.6666667
B(4) = 3.6666667,  B(5) = 1.6666667
```

**Modern Implementation**:
- File: `src/neutronics_s4_alpha.f90`
- Subroutine: `set_Sn_quadrature` or hardcoded constants
- Status: **VERIFY** - Check if exact constants match

### 1.3 Alpha Eigenvalue (1959 Section II)

**PDF Definition**: 
```
α = k_ex (inverse period)
Power variation: P(t) = P₀ · e^(α·Δt)
```

**Modern Implementation**:
- File: `src/neutronics_s4_alpha.f90`
- Subroutine: `solve_alpha_by_root`
- Algorithm: Root-finding to determine α such that k_eff matches configuration
- Status: ✓ MATCHES 1959 CONCEPT

### 1.4 Fission Source (1959 Lines 6379-6380)

**PDF Equation** (Line 6379):
```fortran
SO(I) = 4.0 * DELTA(I) * (ANU(IG) * F(I) / AKEFF + RHO(I) * SUM1)
```

where:
- SO(I) = source term for shell I
- ANU(IG) = ν for energy group IG
- F(I) = fission density
- AKEFF = k-effective
- SUM1 = scattering contribution

**Modern Implementation**:
- File: `src/neutronics_s4_alpha.f90`
- Location: Source term construction in sweep
- Status: **VERIFY** - Check exact form

### 1.5 Delayed Neutrons

**PDF Statement** (Page 5): "All delayed neutron effects are ignored"

**Modern Implementation**:
- Files: `src/main.f90` (precursor update), `src/types.f90` (precursor arrays)
- Method: 6-group Keepin model
- Equation: dC_j/dt = β_j · (fission rate) - λ_j · C_j
- Status: ⊕ **MAJOR ENHANCEMENT** (not in 1959)

## 2. Hydrodynamics: Lagrangian Method

### 2.1 Von Neumann-Richtmyer Artificial Viscosity (1959)

**PDF Reference**: Appendix C - "Hydrodynamic Stability Criteria and Shock Wave Treatment"

**1959 Method**: Synthetic viscous pressure
```
P_total = P_H + P_visc
P_visc = function(CVP coefficient, velocity gradient)
```

**Modern Replacement**:
- File: `src/hydro.f90`
- Method: HLLC Riemann solver with PVRS interface pressure
- Subroutine: `hydro_step`
- Status: ⊕ **ENHANCEMENT** - Modern shock capturing replaces artificial viscosity

### 2.2 Momentum Equation (1959 Appendix C)

**PDF Equation**: Lagrangian form
```
ρ · dv/dt = -∇P
```

**Modern Implementation**:
- File: `src/hydro.f90`
- Lines: Velocity update from pressure gradient
- Status: ✓ **MATCHES** - Same physics, different numerical scheme

### 2.3 CFL Stability Condition (1959 Input: CSC)

**PDF Parameter**: CSC = Courant stability constant

**Modern Implementation**:
- File: `src/controls.f90`
- Parameter: `ctrl%cfl`
- Function: `adapt` - time step control
- Status: ✓ **MATCHES CONCEPT**

## 3. Thermodynamics and Equation of State

### 3.1 Linear EOS (1959 Section II, Lines 418-424)

**PDF Equation**:
```
P_H = α·ρ + β·θ + τ
```

where:
- P_H = hydrodynamic pressure (megabars)
- ρ = density (g/cm³)
- θ = temperature (keV)
- α, β, τ = ALPH(M), BETA(M), TAU(M) in code

**Modern Implementation**:
- File: `src/thermo.f90`
- Function: Pressure calculation from EOS
- Status: ✓ **EXACT MATCH**

### 3.2 Specific Heat (1959 Lines 423-424)

**PDF Equation**:
```
c_v = A_cv + B_cv · θ
```

**Modern Implementation**:
- File: `src/thermo.f90`
- Arrays: `ACV(M)`, `BCV(M)` from input
- Status: ✓ **EXACT MATCH**

### 3.3 Internal Energy Update (1959 Appendix D)

**PDF Method**: Work and heat balance

**Modern Implementation**:
- File: `src/thermo.f90`
- Subroutine: `update_thermo`
- Status: **VERIFY** - Check thermodynamic cycle matches Appendix D

### 3.4 Tabular EOS

**1959**: Not present

**Modern Enhancement**:
- File: `src/eos_table.f90`
- Method: CSV table with bilinear interpolation
- Status: ⊕ **ENHANCEMENT**

## 4. Control Logic and Time Stepping

### 4.1 Hydrocycles per Neutron Cycle (1959: NS4)

**PDF Description**: "NS4 = number of hydrocycles between neutronics calculations"

**PDF Control** (Lines 6272-6278): NS4 starts at 1, can be adjusted based on:
- Rate of change of alpha
- Power variation
- Density changes

**Modern Implementation**:
- File: `src/controls.f90`, `src/main.f90`
- Variable: `hydro_per_neut`
- Status: ✓ **CONCEPT MATCHES** - Details to verify

### 4.2 Time Step Control (1959: DELT, DTMAX)

**PDF Parameters**:
- DELT = initial time increment (µsec)
- DTMAX = maximum allowed time increment
- Time step can be halved if α·Δt exceeds ETA2

**Modern Implementation**:
- File: `src/controls.f90`
- Function: `adapt` - adaptive time stepping
- Variables: `ctrl%dt`, `ctrl%dt_max`, `ctrl%dt_min`
- Status: ✓ **CONCEPT MATCHES**

### 4.3 Convergence Criteria

| Criterion | 1959 Symbol | Modern Variable | Location |
|-----------|-------------|-----------------|----------|
| Alpha convergence | EPSA | `tol` in solve_alpha | neutronics_s4_alpha.f90 |
| K-eff convergence | EPSK | `tol` in sweep_k | neutronics_s4_alpha.f90 |
| Pressure iteration | ETA1 | Check thermo.f90 | thermo.f90 |
| Alpha change limit | ETA3 | Check controls | controls.f90 |
| α·Δt limit | ETA2 | Check controls | controls.f90 |

**Status**: **VERIFY** - Map exact convergence criteria

## 5. Mixture Code (Cross Section Homogenization)

### 5.1 1959 Implementation (Lines 6278-6313)

**PDF Method**: Homogenize cross sections for material mixtures

**Code Loop**:
```fortran
DO 215 M = 1, MMAX
  DO 215 IG = 1, IGMAX
    ! Sum over constituents with weights P(M,IS)
    SUM(IH) = SUM(IH) + P(M,IS) * SIGMA(IG,IH,MA)
```

**Modern Implementation**:
- Location: Check if mixture code exists in modern version
- Status: **VERIFY** - May be in input_parser or separate module

## 6. Phase 3 Enhancements (Not in 1959)

### 6.1 Reactivity Feedback

**1959**: None

**Modern**:
- File: `src/reactivity_feedback.f90`
- Methods: Doppler, fuel expansion, void feedback
- Status: ⊕ **MAJOR ENHANCEMENT**

### 6.2 Temperature-Dependent Cross Sections

**1959**: Fixed cross sections

**Modern**:
- File: `src/temperature_xs.f90`
- Method: Doppler broadening σ(T) = σ(T_ref) · (T_ref/T)^n
- Status: ⊕ **ENHANCEMENT**

### 6.3 DSA Acceleration

**1959**: None (pure source iteration)

**Modern**:
- File: `src/neutronics_s4_alpha.f90`
- Method: Diffusion Synthetic Acceleration
- Status: ⊕ **ENHANCEMENT**

### 6.4 UQ and Sensitivity Analysis

**1959**: None

**Modern**:
- Files: `src/uq_mod.f90`, `src/sensitivity_mod.f90`
- Status: ⊕ **PHASE 3 ENHANCEMENT**

### 6.5 Checkpoint/Restart

**1959**: Tape dump routine (Appendix F) - basic memory dump

**Modern**:
- File: `src/checkpoint_mod.f90`
- Status: ⊕ **ENHANCED** - More sophisticated state management

## 7. Data Structures

### 7.1 1959 COMMON Blocks vs Modern Derived Types

**1959**: Fortran IV COMMON blocks for data sharing

**Modern**: Fortran 90+ derived types
- `type(State)` in `src/types.f90` - replaces geometry/physics arrays
- `type(Control)` in `src/types.f90` - replaces control parameters
- `type(Shell)` in `src/types.f90` - per-shell properties
- `type(Material)` in `src/types.f90` - material properties

**Status**: ✓ **MODERN EQUIVALENT** - Same data, better organization

## 8. Unit System

### 8.1 1959 Units (Section III, Lines 495-540)

- Mass: grams
- Length: cm  
- Time: **µsec** (microseconds)
- Temperature: **keV** (kilo-electron-volts)
- Pressure: megabars
- Energy: 10^12 ergs
- Power: 10^12 ergs/sec
- Velocity: cm/µsec
- Acceleration: cm/µsec²

**Modern Implementation**:
- File: `src/constants.f90`
- Status: **VERIFY** - Check if same unit system used

## Summary of Mapping Status

| Component | 1959 → Modern | Status |
|-----------|---------------|--------|
| S4 Neutronics | S4 → S4/S6/S8 | ✓ MATCH + ⊕ ENHANCE |
| Alpha Eigenvalue | Root finding → Root finding | ✓ MATCH |
| Delayed Neutrons | None → 6-group | ⊕ MAJOR ENHANCE |
| Hydrodynamics | von Neumann → HLLC | ⊕ ENHANCE |
| EOS | Linear → Linear + Tabular | ✓ MATCH + ⊕ ENHANCE |
| Time Stepping | Adaptive → Adaptive | ✓ CONCEPT MATCH |
| Convergence | Multiple criteria → Multiple criteria | **VERIFY** |
| Cross Sections | Fixed → Temperature-dependent | ⊕ ENHANCE |
| Reactivity Feedback | None → Doppler/Expansion/Void | ⊕ MAJOR ENHANCE |
| Data Structures | COMMON → Derived types | ✓ MODERN EQUIVALENT |

## Legend

- ✓ **MATCH**: Implementation matches 1959 method
- ⊕ **ENHANCE**: Modern improvement/addition
- **VERIFY**: Requires detailed code inspection
- ❌ **DISCREPANCY**: Difference requiring investigation

## Next Steps

1. Verify S4 quadrature constants match exactly
2. Map convergence criteria parameters precisely
3. Verify mixture code implementation
4. Check unit system consistency
5. Extract Section X sample problem for reproduction

