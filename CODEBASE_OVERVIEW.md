# AX-1 Codebase Overview: Nuclear Physics Fast Reactor Transient Code

## Executive Summary

**AX-1** is a modern **Fortran-based coupled neutronics-hydrodynamics code** for simulating **fast nuclear reactor transients**, particularly focused on **Bethe-Tait analysis** for reactor safety studies. Despite the user's mention of "Monte Carlo code," **AX-1 is actually a deterministic transport code** that uses **S_n discrete ordinates** methods combined with **1D spherical hydrodynamics** to model reactor physics phenomena.

The code implements **α-eigenvalue solvers**, **delayed neutrons**, **reactivity feedback**, **temperature-dependent cross sections**, and advanced features like **uncertainty quantification** and **sensitivity analysis**. It is currently at **Phase 3** of development, incorporating research-grade capabilities for transient analysis.

---

## 1. Code Purpose and Domain

### Nuclear Physics Application

AX-1 is designed for modeling **fast reactor transients** in spherical geometry, specifically:

- **Critical assembly transients** (Godiva-type problems)
- **Reactivity insertion accidents** (Bethe-Tait scenarios)
- **Fast reactor safety analysis**
- **Coupled neutronics-hydrodynamics phenomena**

### Key Physics Phenomena

1. **Neutron Transport**: Multi-group discrete ordinates (S_n) transport with upscatter and downscatter
2. **Delayed Neutrons**: 6-group delayed neutron precursor tracking
3. **Hydrodynamics**: 1D spherical Lagrangian hydrodynamics with HLLC Riemann solver
4. **Reactivity Feedback**: Doppler, fuel expansion, and void feedback mechanisms
5. **Temperature Effects**: Temperature-dependent cross sections with Doppler broadening

---

## 2. Core Computational Methods

### 2.1 Neutron Transport (S_n Discrete Ordinates)

**Method**: Discrete ordinates transport with angular quadrature

**Key Features**:
- **Angular Discretization**: S4, S6, and S8 quadrature sets (Gauss-Legendre abscissae)
- **Energy Groups**: Up to 7 energy groups (typically 3 for fast spectrum)
- **Geometry**: 1D spherical shells with explicit boundary conditions
- **Acceleration**: Diffusion Synthetic Acceleration (DSA) to reduce iteration count
- **Upscatter Control**: Configurable upscatter treatment (allow/neglect/scale)

**Implementation** (`neutronics_s4_alpha.f90`):
```fortran
subroutine sweep_spherical_k(st, k, alpha, tol, itmax, use_dsa)
  ! Performs transport sweeps in spherical geometry
  ! Iterates until flux converges (k-eigenvalue problem)
  ! Optional DSA correction for acceleration
```

**α-Eigenvalue Solver**:
The code solves for the **α-eigenvalue** (time-dependent reactivity) via root-finding:
```
∂n/∂t = (ρ - β)/Λ * n + Σλ_j C_j
```
where α represents the asymptotic period of the neutron population.

### 2.2 Hydrodynamics (1D Spherical Lagrangian)

**Method**: Lagrangian hydrodynamics with HLLC-inspired Riemann solver

**Key Features**:
- **PVRS Interface Pressure**: Primitive Variable Riemann Solver for cell interface pressure
- **Slope Limiting**: Minmod limiter for second-order accuracy without oscillations
- **CFL Stability**: Configurable CFL condition for time step control
- **Conservation**: Mass and momentum conserved in Lagrangian frame

**Implementation** (`hydro.f90`):
```fortran
subroutine hydro_step(st, ctrl, c_vp)
  ! 1. Compute interface pressures using HLLC Riemann solver
  ! 2. Update velocities from pressure gradient
  ! 3. Update shell positions and densities
  ! 4. Enforce CFL stability condition
```

**No artificial viscosity**: Replaced by pressure-based flux evaluation for shock capturing.

### 2.3 Equation of State (EOS)

**Methods**:
1. **Analytic EOS**: P = aρ + bρ²T + cT
2. **Tabular EOS**: CSV tables with bilinear interpolation

**Thermodynamics**:
- Ideal gas model for fast reactor materials
- Temperature-dependent heat capacity: c_v = A_cv + B_cv * T

### 2.4 Delayed Neutrons

**6-Group Keepin Model**:
- Tracks precursor concentrations for each delayed group
- Decay constants and yields based on U-235 data
- Properly accounts for delayed neutron contribution to fission source

```fortran
type :: Material
  real(rk) :: beta(DGRP) = 0._rk      ! Delayed neutron fractions
  real(rk) :: lambda(DGRP) = 0._rk    ! Decay constants
```

---

## 3. Phase 3 Features (Research/Engineering Grade)

### 3.1 Reactivity Feedback Mechanisms

**Implemented Feedback Types**:

1. **Doppler Feedback** (temperature-dependent):
   ```
   ρ_doppler = α_D * (T - T_ref)
   ```
   
2. **Fuel Expansion Feedback** (density-dependent):
   ```
   ρ_expansion = α_E * (ρ - ρ_ref) / ρ_ref * 100
   ```
   
3. **Void Feedback** (density-dependent):
   ```
   ρ_void = α_V * (ρ - ρ_ref) / ρ_ref * 100
   ```

**Total Reactivity**:
```
ρ_total = ρ_inserted + ρ_doppler + ρ_expansion + ρ_void
```

**Implementation** (`reactivity_feedback.f90`):
- Calculates average temperature and density across all shells
- Computes feedback contributions based on configured coefficients
- Updates k_eff from reactivity: ρ = (k - 1) / k

### 3.2 Temperature-Dependent Cross Sections

**Doppler Broadening Model**:
```
σ(T) = σ(T_ref) * (T_ref / T)^exponent
```
where the exponent is typically 0.5 for Doppler broadening.

**Features**:
- Per-shell temperature correction
- Reference cross section storage
- Integrated into transport solver
- Checkpoint/restart support

**Implementation** (`temperature_xs.f90`):
```fortran
function get_temperature_corrected_sig_t(st, shell_idx, g)
  ! Returns temperature-corrected total cross section
  T = st%sh(shell_idx)%temp
  doppler_factor = (T_ref / T)**exponent
  sig_t_corrected = sig_t_ref * doppler_factor
```

### 3.3 Time History Output

**Time-Dependent Quantities**:
- P(t): Total reactor power
- α(t): Reactivity eigenvalue
- k_eff(t): Effective multiplication factor
- ρ(t): Total reactivity (pcm)

**Spatial History**:
- Radius (r_in, r_out)
- Velocity
- Pressure
- Temperature
- Density

**Output Format**: CSV files for easy post-processing

### 3.4 Checkpoint/Restart Capability

**Binary Checkpoint Files**:
- Complete state restoration
- Time history included
- Control parameters saved
- Cross section reference values preserved

**Usage**:
```fortran
! Save checkpoint
call write_checkpoint(st, ctrl, "checkpoint.chk", iostat)

! Restart from checkpoint
call read_checkpoint(st, ctrl, "checkpoint.chk", iostat)
```

### 3.5 Uncertainty Quantification (UQ)

**Monte Carlo Framework**:
- Uniform parameter sampling
- Parameter perturbation (±5% for XS, ±2% for EOS, ±10% for β)
- Statistics calculation (mean, std, min, max, 95% CI)

**Sampled Parameters**:
- Cross sections (σ_t, ν σ_f, σ_s)
- Equation of state parameters
- Delayed neutron fractions (β)

**Output**:
- k_eff statistics
- α statistics
- Power statistics

**Limitation**: Currently only runs k-eigenvalue, not full transient UQ

### 3.6 Sensitivity Analysis

**Finite Difference Method**:
```
∂k/∂X = (k(X + ΔX) - k(X - ΔX)) / (2ΔX)
```

**Sensitivity Coefficients**:
- ∂k/∂σ: Sensitivity of k_eff to cross sections
- ∂α/∂σ: Sensitivity of α to cross sections
- ∂P/∂σ: Sensitivity of power to cross sections

**Perturbation**: 1% for XS, EOS, and delayed neutron fractions

**Limitation**: Currently only calculates steady-state sensitivities

---

## 4. Code Architecture

### 4.1 Module Structure

```
ax1 (main)
├── kinds.f90             - Precision definitions (real(rk) = real(8))
├── types.f90             - Data structures (State, Control, Material, Shell, EOS)
├── constants.f90         - Physical constants
├── utils.f90             - Utility functions (volume, safe_div, minmod)
├── input_parser.f90      - Deck file parser
├── io_mod.f90            - I/O functions
├── neutronics_s4_alpha.f90 - S_n transport solver
├── hydro.f90             - Hydrodynamics solver
├── thermo.f90            - Thermodynamics (EOS, temperature)
├── eos_table.f90         - Tabular EOS reader
├── controls.f90          - Time step and stability control
├── reactivity_feedback.f90 - Feedback mechanisms
├── temperature_xs.f90    - Temperature-dependent cross sections
├── history_mod.f90       - Time history storage
├── checkpoint_mod.f90    - Checkpoint/restart
├── uq_mod.f90            - Uncertainty quantification
├── sensitivity_mod.f90   - Sensitivity analysis
├── simulation_mod.f90    - High-level simulation control
└── xs_lib.f90            - Cross section library (HDF5 stub)
```

### 4.2 Key Data Types

**State**: Complete reactor state
```fortran
type :: State
  integer :: Nshell                     ! Number of spatial shells
  type(Shell), allocatable :: sh(:)    ! Shell properties
  type(EOS), allocatable :: eos(:)     ! Equation of state per shell
  integer :: G                          ! Number of energy groups
  type(Material), allocatable :: mat(:) ! Material properties
  real(rk) :: k_eff, alpha, time, total_power
  real(rk), allocatable :: phi(:,:)     ! Flux (G, Nshell)
  real(rk), allocatable :: C(:,:,:)     ! Delayed neutron precursors
```

**Control**: Simulation control parameters
```fortran
type :: Control
  character(len=8) :: eigmode          ! "k" or "alpha"
  real(rk) :: dt, dt_max, dt_min       ! Time step control
  real(rk) :: cfl                      ! CFL number
  integer :: Sn_order                  ! 4, 6, or 8
  logical :: use_dsa                   ! DSA acceleration
  real(rk) :: rho_insert               ! Reactivity insertion (pcm)
  real(rk) :: t_end                    ! Simulation end time
```

### 4.3 Main Loop Structure

```fortran
program ax1
  ! 1. Parse input deck
  call load_deck(deck, st, ctrl)
  
  ! 2. Set up neutronics (S_n quadrature)
  call set_Sn_quadrature(st, ctrl%Sn_order)
  
  ! 3. Restart from checkpoint (if specified)
  if (ctrl%use_restart) call read_checkpoint(...)
  
  ! 4. Main time loop
  do while (st%time < ctrl%t_end)
    ! 4.1 Calculate reactivity feedback
    call calculate_reactivity_feedback(st, ctrl)
    
    ! 4.2 Solve neutronics (α-eigenvalue or k-eigenvalue)
    if (eigmode == "alpha") then
      call solve_alpha_by_root(st, alpha, k, use_dsa)
    else
      call sweep_spherical_k(st, k, alpha, use_dsa)
    end if
    
    ! 4.3 Update delayed neutron precursors
    call decay_precursors(st, ctrl%dt)
    
    ! 4.4 Thermodynamics (energy deposition)
    call thermo_step(st, ctrl, ...)
    
    ! 4.5 Hydrodynamics (material motion)
    call hydro_step(st, ctrl, ...)
    
    ! 4.6 Output time history
    call append_history(st, ctrl)
    
    ! 4.7 Write checkpoint (if requested)
    if (checkpoint_freq) call write_checkpoint(...)
  end do
  
  ! 5. Final output and cleanup
  call write_final_output(st, ctrl)
```

---

## 5. Input Deck Format

### Example: Bethe-Tait Benchmark

```
[controls]
eigmode alpha
dt 1.0e-6
Sn 8
use_dsa true
rho_insert 100.0         # Insert 100 pcm
t_end 0.01               # Run for 10 ms
output_freq 10           # Output every 10 steps

[geometry]
Nshell 30                # 30 spatial shells
G 3                      # 3 energy groups

[materials]
nmat 1                   # 1 material

[material_properties]
1 true 300.0 0.5         # Material 1: temp-dependent, T_ref=300K, exponent=0.5

# Fast reactor cross sections (3-group)
[xs_group]
1 1  2.5   0.40  0.99    # mat g sig_t nu_sig_f chi
1 2  3.0   0.30  0.01
1 3  4.5   0.20  0.00

# Scattering matrix
[scatter]
1 1 1  2.0               # mat g'->g sig_s
1 1 2  0.05
1 2 2  2.5
1 2 3  0.10
1 3 3  3.5

# Delayed neutrons (Keepin 6-group for U-235)
[delayed]
1 1  0.000230  0.0127    # mat j beta lambda

# Reactivity feedback
[reactivity_feedback]
enable_doppler true
enable_expansion true
doppler_coef -2.0        # pcm/K
expansion_coef -1.5      # pcm/K
T_ref 300.0

# Equation of state
[eos]
1  0 0 287  717 0        # shell a b c Acv Bcv

# Initial conditions
[shells]
1 0.25 1 18.7 300        # shell r_out mat rho0 temp0
2 0.50 1 18.7 300
...
```

---

## 6. Benchmark Problems

### 6.1 Godiva Criticality

**Purpose**: Tests criticality eigenvalue solver with realistic fast reactor parameters

**Physics**:
- Bare highly enriched uranium sphere
- 93.8% U-235
- Fast neutron spectrum
- k_eff ≈ 1.0 (critical)

### 6.2 SOD Shock Tube

**Purpose**: Validates HLLC Riemann solver and slope limiting

**Physics**:
- 1D Riemann problem
- Shock wave, rarefaction wave, contact discontinuity
- Tests hydrodynamics without oscillations

### 6.3 Bethe-Tait Transient

**Purpose**: Fast reactor transient with reactivity insertion

**Physics**:
- Reactivity insertion (100 pcm)
- Doppler and expansion feedback
- Temperature-dependent cross sections
- Power excursion and shutdown

### 6.4 Upscatter Treatment

**Purpose**: Tests upscatter control feature

**Physics**:
- Thermal reactor with significant upscatter
- Tests allow/neglect/scale modes

### 6.5 DSA Convergence

**Purpose**: Demonstrates DSA acceleration effectiveness

**Physics**:
- Scattering-dominant problem
- Compares iteration counts with/without DSA

---

## 7. Build and Test System

### 7.1 Build System

**Makefile**:
```makefile
FC = gfortran
FFLAGS = -O2 -Wall -fcheck=all
SOURCES = kinds.f90 types.f90 constants.f90 utils.f90 ...
OBJECTS = $(SOURCES:.f90=.o)

ax1: $(OBJECTS)
	$(FC) $(FFLAGS) -o ax1 $(OBJECTS)
```

**CMake** (optional):
```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . -j
```

### 7.2 Test Suite

**Phase 1 Tests** (`tests/smoke_test.sh`):
- Basic α-eigenvalue solve
- Delayed neutron tracking

**Phase 2 Tests**:
- `phase2_attn.sh`: S8 transport with DSA
- `phase2_shocktube.sh`: HLLC hydrodynamics

**Phase 3 Tests** (`tests/test_phase3.sh`):
- Reactivity feedback
- Time history output
- Checkpoint/restart
- Bethe-Tait benchmark

**UQ/Sensitivity Tests** (`tests/test_uq_sensitivity.sh`):
- Uncertainty quantification
- Sensitivity analysis

**Validation** (`validation/`):
- Bethe-Tait validation
- Code-to-code comparison framework

---

## 8. Output Files

### 8.1 Time History Files

**`*_time.csv`**:
```csv
time, power, alpha, keff, reactivity
0.000000, 1.234e+6, -12.345, 1.0023, 23.5
0.000001, 1.456e+6, -11.234, 1.0028, 28.1
...
```

**`*_spatial.csv`**:
```csv
time, shell, radius, velocity, pressure, temperature
0.000000, 1, 0.25, 0.0, 1.0e5, 300.0
0.000000, 2, 0.50, 0.0, 1.0e5, 300.0
...
```

### 8.2 UQ Results

**`uq_results.csv`**:
```csv
sample, k_eff, alpha, power
0, 1.0000, -10.0, 1.0e6
1, 1.0023, -9.8, 1.02e6
2, 0.9988, -10.2, 0.98e6
...
# Statistics
mean, 1.0005, -10.0, 1.0e6
std, 0.0012, 0.15, 1.2e4
```

### 8.3 Sensitivity Results

**`sensitivity_results.csv`**:
```csv
parameter, dk_dxs, dalpha_dxs, dpower_dxs
xs_g1, 0.234, -0.012, 1234.5
xs_g2, 0.456, -0.023, 2345.6
xs_g3, 0.123, -0.005, 567.8
```

---

## 9. Strengths and Limitations

### 9.1 Strengths

✅ **Well-structured Fortran code**: Modern Fortran 90+ with modules, implicit none
✅ **Coupled physics**: Neutronics + hydrodynamics + thermodynamics
✅ **Advanced transport**: S_n with DSA acceleration
✅ **Delayed neutrons**: Proper 6-group treatment
✅ **Reactivity feedback**: Doppler, expansion, void
✅ **Temperature-dependent XS**: Fully integrated Doppler broadening
✅ **Time history output**: Full transient tracking
✅ **Checkpoint/restart**: Complete state preservation
✅ **UQ/Sensitivity**: Monte Carlo and finite difference methods
✅ **Validation framework**: Bethe-Tait and code comparison tools

### 9.2 Limitations

⚠️ **1D spherical geometry only**: No 2D or 3D capability
⚠️ **Deterministic, not Monte Carlo**: Despite user's mention, this is **not a Monte Carlo code**
⚠️ **Steady-state UQ/sensitivity only**: No full transient UQ/sensitivity
⚠️ **HDF5 XS reader is stub**: Temperature-dependent XS work via analytic model, not full library
⚠️ **Parameter tuning needed**: Bethe-Tait benchmark may produce NaN values without tuning
⚠️ **No multi-material regions**: Limited material mapping
⚠️ **CSV output only**: No HDF5/NetCDF output

---

## 10. Comparison to "PDF Code" (Inferred Reference)

Based on the capabilities assessment documents, AX-1 is being compared to an unspecified reference code (likely a production fast reactor safety code). The assessment concludes:

**Can AX-1 be used for the same purposes?**

**Answer**: **PARTIALLY YES, WITH LIMITATIONS**

### What Works Well ✅

1. Core transient simulations with reactivity feedback
2. Time history output for transient analysis
3. Checkpoint/restart for long simulations
4. Temperature-dependent cross sections (Doppler broadening)
5. Validation framework (Bethe-Tait)
6. Steady-state UQ and sensitivity

### Critical Gaps ⚠️

1. **Transient UQ/Sensitivity**: Only steady-state implemented
2. **Parameter Validation**: Needs tuning against literature
3. **Production Grade**: Not certified for regulatory use
4. **Multi-dimensional Geometry**: 1D only

### Use Cases

- ✅ **Research**: Fast reactor transient studies
- ✅ **Education**: Teaching reactor physics
- ⚠️ **Engineering**: Preliminary design studies (with caveats)
- ❌ **Production**: Not certified for regulatory analysis

---

## 11. Notable Implementation Details

### 11.1 Not a Monte Carlo Code

**Important**: Despite the user's mention of "Monte Carlo," **AX-1 is a deterministic code**. It uses:
- **Discrete ordinates (S_n)** for neutron transport, not stochastic particle tracking
- **Lagrangian hydrodynamics**, not Monte Carlo fluid dynamics
- **Monte Carlo sampling** only appears in the **UQ module** for parameter sampling

### 11.2 Test-Driven Development

The code follows TDD principles with comprehensive test coverage:
- Smoke tests for basic functionality
- Feature tests for each phase
- Validation tests against benchmarks
- Regression tests to prevent breakage

### 11.3 Scientific Software Best Practices

- **Implicit none** everywhere
- **Double precision** (real(8)) for numerics
- **Modular structure** with clear separation of concerns
- **Comprehensive documentation** in Markdown
- **Validation framework** for code comparison

### 11.4 Phase Development Approach

**Phase 1**: α-eigenvalue, delayed neutrons, basic EOS
**Phase 2**: S_n quadrature, DSA, HLLC hydro, upscatter control
**Phase 3**: Reactivity feedback, temperature XS, UQ/sensitivity, checkpoint/restart

---

## 12. Development Status and Roadmap

### Current Status: Phase 3 Complete

**Implementation**: 11/12 features complete
- ✅ All core transient capabilities
- ✅ Reactivity feedback mechanisms
- ✅ Temperature-dependent cross sections
- ✅ Time history output
- ✅ Checkpoint/restart
- ⚠️ UQ/sensitivity (steady-state only)

### Future Work

1. **Complete Transient UQ/Sensitivity**: Extend to full transient analysis
2. **HDF5 XS Library**: Full NJOY/OpenMC cross section reader
3. **Parameter Validation**: Tune Bethe-Tait against literature
4. **Multi-dimensional Geometry**: Extend beyond 1D spherical
5. **Production Certification**: Full validation for regulatory use

---

## 13. How to Use the Code

### 13.1 Quick Start

```bash
# Build
make

# Run basic example
./ax1 inputs/sample_phase1.deck

# Run Bethe-Tait benchmark
./ax1 benchmarks/bethe_tait_transient.deck

# Run all tests
./tests/smoke_test.sh
./tests/phase2_attn.sh
./tests/test_phase3.sh
```

### 13.2 Running UQ Analysis

```bash
# Create deck with run_uq true
cat > test_uq.deck << EOF
[controls]
eigmode k
run_uq true
uq_output_file uq_results.csv
EOF

# Run
./ax1 test_uq.deck
```

### 13.3 Running Sensitivity Analysis

```bash
# Create deck with run_sensitivity true
cat > test_sensitivity.deck << EOF
[controls]
eigmode k
run_sensitivity true
sensitivity_output_file sensitivity_results.csv
EOF

# Run
./ax1 test_sensitivity.deck
```

---

## 14. Key References

### Physics Methods

- **Bethe-Tait Analysis**: Fast reactor safety transient analysis
- **S_n Transport**: Lewis & Miller, "Computational Methods of Neutron Transport"
- **DSA Acceleration**: Alcouffe et al., NSE 1981
- **HLLC Riemann Solver**: Toro, "Riemann Solvers and Numerical Methods for Fluid Dynamics"
- **SOD Shock Tube**: Sod, JCP 1978

### Benchmarks

- **Godiva**: Los Alamos critical assembly experiments
- **Keepin Delayed Neutron Data**: Standard 6-group model for U-235

---

## 15. Conclusion

**AX-1 is a sophisticated deterministic nuclear reactor physics code** for fast reactor transient analysis. It combines multi-group neutron transport (S_n discrete ordinates), 1D spherical hydrodynamics (HLLC Riemann solver), and thermodynamics with reactivity feedback mechanisms.

The code is **currently at Phase 3** with research-grade capabilities including:
- Temperature-dependent cross sections
- Reactivity feedback (Doppler, expansion, void)
- Time history output for transient analysis
- Checkpoint/restart for long simulations
- Uncertainty quantification and sensitivity analysis (steady-state)
- Validation framework with Bethe-Tait benchmark

**Key Distinction**: **This is NOT a Monte Carlo code**. It is a deterministic transport code using discrete ordinates methods. Monte Carlo sampling appears only in the UQ module for parameter uncertainty propagation.

**Suitable for**:
- ✅ Research: Fast reactor transient studies
- ✅ Education: Teaching reactor physics
- ⚠️ Engineering: Preliminary design (with validation)

**Not suitable for**:
- ❌ Production: Regulatory analysis (not certified)
- ❌ High-fidelity multi-dimensional problems (1D only)

The code demonstrates excellent software engineering practices, comprehensive testing, and a clear development roadmap. It serves as a solid foundation for fast reactor transient analysis in research and educational contexts.

