# AX-1 1959 PDF Content Extraction

## Document Information

**Title**: AX-1, A Computing Program for Coupled Neutronics-Hydrodynamics Calculations on the IBM-704

**Authors**: D. Okrent, J.M. Cook, D. Satkus (Argonne National Laboratory), R.B. Lazarus, M.B. Wells (Los Alamos Scientific Laboratory)

**Report Number**: ANL-5977

**Date**: May 1959

**Source**: HathiTrust Digital Library, Public Domain

**Converted**: November 22, 2025 using markitdown MCP tool

**Total Lines**: 54,779 lines

**Location**: `/home/mh7373/.cursor/projects/home-mh7373-GitRepos-ax1-phase1/agent-tools/160ffb3c-67c7-49f5-bded-14c4053b40ee.txt`

## Executive Summary

The 1959 AX-1 code was developed for fast reactor safety analysis, specifically for calculating energy yield and explosive force in hypothetical nuclear accidents using the Bethe-Tait analytical technique. The code performs coupled neutronics-hydrodynamics calculations on the IBM-704 computer.

### Key Features of 1959 Implementation

1. **Neutronics Method**: S4 discrete ordinates approximation (5 angles per hemisphere)
2. **Delayed Neutrons**: **IGNORED** - "All delayed neutron effects are ignored" (page 5)
3. **Hydrodynamics**: Lagrangian coordinates with von Neumann-Richtmyer artificial viscosity
4. **Geometry**: Spherically symmetric, divided into hypothetical shells
5. **Coupling**: Neutronics → Thermodynamics → Hydrodynamics loop
6. **Time Integration**: Power varies as e^(α·Δt) between neutronics calculations

### Unit System (Special)

- Mass: grams
- Length: cm
- Time: µsec (microseconds)
- Temperature: keV (kilo-electron-volts)
- Pressure: megabars
- Energy: 10^12 ergs
- Power: 10^12 ergs/sec

### Equation of State

The 1959 code uses a linear EOS:

```
PH = α·ρ + β·θ + τ
```

where:
- PH = hydrodynamic pressure (megabars)
- ρ = density (g/cm³)
- θ = temperature (keV)
- α, β, τ = material-dependent constants

Specific heat at constant volume:

```
cv = Acv + Bcv·θ
```

### Von Neumann-Richtmyer Artificial Viscosity

The 1959 code includes synthetic viscous pressure for shock wave treatment:

```
Total Pressure = PH + Pvisc
```

The viscous pressure is calculated with coefficient CVP (input parameter) to smear shock fronts over several mesh cells, preventing numerical instabilities.

### S4 Angular Quadrature Constants

From lines 6174-6188 of the Fortran listing:

```fortran
AM(1) = 1.0
AM(2) = 0.6666667
AM(3) = 0.1666667
AM(4) = 0.3333333
AM(5) = 0.8333333

AMBAR(1) = 0.0
AMBAR(2) = 0.8333333
AMBAR(3) = 0.3333333
AMBAR(4) = 0.1666667
AMBAR(5) = 0.6666667

B(1) = 0.0
B(2) = 1.6666667
B(3) = 3.6666667
B(4) = 3.6666667
B(5) = 1.6666667
```

These are the discrete ordinates quadrature weights and angles for the S4 approximation.

### Alpha Eigenvalue

The code computes α (inverse period):

```
α = k_ex
```

where k_ex is the time eigenvalue. For super-prompt critical systems, α > 0 indicates exponential power growth.

### Convergence Criteria (Input Parameters)

- **EPSA**: Convergence criterion on alpha calculation
- **EPSK**: Convergence criterion on k_eff calculation
- **EPSR**: Convergence criterion on outer radius (when scaling geometry)
- **EPS1**: Pressure convergence (small pressure test)
- **ETA1**: Convergence criterion for hydrodynamic pressure iteration
- **ETA2**: Maximum tolerance for α·ΔT (triggers time step halving if exceeded)
- **ETA3**: Tolerance on fractional change in alpha between S4 calculations

### Control Parameters

- **NS4**: Number of hydrocycles between neutronics calculations (adaptive)
- **DELT**: Time increment Δt (µsec)
- **DTMAX**: Maximum allowed Δt (µsec)
- **CVP**: Viscous pressure coefficient
- **CSC**: Courant stability constant (CFL condition)
- **NP**: Print frequency control
- **NPOFF**: Offset for print control
- **NPOFFP**: Additional print offset

### Program Flow (Block Diagram from Page 5)

```
INPUT
  ↓
MIX CROSS SECTIONS
  ↓
S4 NEUTRONICS: 
Compute NEW α AND FISSION SOURCE DENSITY
  ↓
  ┌─────────────────────────────┐
  │ Is it time to go back to    │ ─yes→ (loop back to S4 NEUTRONICS)
  │ neutronics?                 │
  └─────────────────────────────┘
    │ no
    ↓
THERMODYNAMICS:
Compute NEW PRESSURES FROM THE EQUATION OF STATE
    ↓
HYDRODYNAMICS:
Compute NEW VELOCITIES AND POSITIONS OF MASS POINTS
    ↓
INCREASE t BY Δt
    ↓
(loop back to "Is it time" decision)
```

### Key Differences from Modern Implementation

| Feature | 1959 Original | Modern AX-1 |
|---------|--------------|-------------|
| Delayed Neutrons | **Ignored** | 6-group Keepin model |
| Sn Order | S4 only | S4/S6/S8 |
| Shock Treatment | von Neumann-Richtmyer viscosity | HLLC Riemann solver |
| Cross Sections | Fixed (no temperature dependence) | Temperature-dependent with Doppler broadening |
| Reactivity Feedback | None (fixed geometry initially) | Doppler, expansion, void feedback |
| Advanced Features | None | UQ, sensitivity analysis, checkpoint/restart |
| Acceleration | None | DSA (Diffusion Synthetic Acceleration) |

## Section X: Sample Problem

The 1959 PDF contains a detailed sample problem in Section X with:
- Input data specifications
- Expected results
- Time evolution data

This will be extracted separately for exact reproduction in Phase 4 of the review plan.

## Appendices

The 1959 PDF contains important appendices:

- **Appendix A**: Details of the VJ-OK1 Test
- **Appendix B**: The Time Scale
- **Appendix C**: Discussion of Hydrodynamic Stability Criteria and Shock Wave Treatment
- **Appendix D**: Thermodynamic Considerations
- **Appendix E**: Possible Variations in Program 'AX-1''
- **Appendix F**: The AX-1 Tape Dump and Recall Routine

These provide theoretical background for the computational methods.

## References from 1959 PDF

The document cites key references including:
1. Bethe & Tait (1956) - Original Bethe-Tait analysis
2. Jankus (ANL) - Modified Bethe-Tait technique
3. Stratton, Colvin, Lazarus - Prior work on similar codes
4. Various Sn transport method references

## Status

✓ PDF successfully converted (54,779 lines)
✓ Key methods documented
✓ Known differences identified
✓ Ready for detailed equation extraction

## Next Steps

1. Extract specific equations from neutronics section
2. Extract equations from hydrodynamics appendices
3. Document sample problem parameters for reproduction
4. Map flow diagrams to modern code structure

