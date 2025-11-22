# 1959 AX-1 Reproduction Progress Report

## Session Summary
**Date**: November 22, 2025
**Task**: Complete reproduction of 1959 ANL-5977 AX-1 code
**Status**: Phase 0 and Phase 1 COMPLETE (3/32 todos completed)

---

## ✅ COMPLETED

### 1. Phase 0: Preservation and Mathematical Foundation
- ✅ Created git branch `modern-enhanced` to preserve current code
- ✅ Tagged current state as `v1.0-modern-phase3-complete`
- ✅ Extracted ALL 1959 equations from ANL-5977
- ✅ Verified S4 constants using MCP CAS tool:
  * AM(2) = 2/3 = 0.6666666666666666 ✓
  * AMBAR(2) = 5/6 = 0.8333333333333334 ✓
  * B(2) = 5/3 = 1.6666666666666667 ✓
  * B(3) = 11/3 = 3.6666666666666665 ✓
- ✅ Verified thermodynamic consistency:
  * ∂E/∂θ = Cv = A_cv + B_cv·θ ✓
  * ∫Cv dθ = A_cv·θ + B_cv·θ²/2 ✓
- ✅ Verified unit conversions with MCP units tool

**Key Files Created:**
- `/home/mh7373/GitRepos/ax1_phase1/1959_EQUATIONS_EXTRACTED.md` (Complete equation reference)

### 2. Phase 1: Core Data Structures
- ✅ Created `src/types_1959.f90` with authentic 1959 structures
  * NO delayed neutron arrays (β, λ, C, q_delay removed)
  * NO temperature-dependent cross sections
  * NO HLLC structures
  * NO DSA acceleration
  * Linear EOS ONLY
  * S4 constants hardcoded with exact ANL-5977 values
- ✅ Compiled cleanly with `-fcheck=bounds -Wall -Wextra -pedantic`

---

## 🚧 IN PROGRESS

### Todo ID: s4-derive
**Task**: Derive S4 quadrature from Legendre polynomials, verify with MCP

**Next Steps**:
1. Derive S4 angular directions from Gauss-Legendre quadrature
2. Verify moment conservation properties
3. Document mathematical foundation

---

## 📋 REMAINING TODOS (29)

### Phase 2: S4 Neutronics (3 todos)
- [ ] s4-derive: Derive S4 quadrature from Legendre polynomials
- [ ] s4-implement: Implement neutronics_s4_1959.f90 with prompt-only fission
- [ ] s4-test: Test S4 (flat source, critical sphere, alpha eigenvalue)

### Phase 3: Von Neumann-Richtmyer Hydrodynamics (4 todos)
- [ ] vnr-derive: Derive von Neumann-Richtmyer viscosity
- [ ] hydro-implement: Implement hydro_vnr_1959.f90
- [ ] eos-derive: Verify EOS thermodynamic consistency
- [ ] hydro-test: Test SOD shock, strong shock, free expansion

### Phase 4: Time Stepping Control (2 todos)
- [ ] stability-derive: Derive stability criteria from von Neumann analysis
- [ ] time-implement: Implement time_control_1959.f90 with W stability

### Phase 5: Input/Output (1 todo)
- [ ] io-implement: Create input_1959.f90 and output

### Phase 6: Main Program (1 todo)
- [ ] main-implement: Implement main_1959.f90 following flow diagrams

### Phase 7: Validation Test Suite (6 todos)
- [ ] test-trivial: Integration test (1-zone problem)
- [ ] godiva-validate: Critical sphere validation
- [ ] step-reactivity: Prompt supercritical test
- [ ] bethe-tait-validate: Reproduce ANL-5977 pages 89-103
- [ ] shock-validate: Shock physics test
- [ ] energy-validate: Energy conservation validation
- [ ] units-validate: Complete dimensional analysis

### Phase 8: Mathematical Physics Documentation (10 todos)
- [ ] doc-transport: Write transport theory section (PRL style)
- [ ] doc-quadrature: Write S_N quadrature mathematics
- [ ] doc-lagrangian: Write Lagrangian hydrodynamics theory
- [ ] doc-viscosity: Write artificial viscosity foundation
- [ ] doc-thermo: Write thermodynamics and EOS section
- [ ] doc-stability: Write numerical stability theory
- [ ] doc-kinetics: Write prompt neutron kinetics section
- [ ] doc-validation: Write validation section
- [ ] doc-comparison: Write formal 1959 vs modern comparison
- [ ] impl-notes: Create 1959_IMPLEMENTATION_NOTES.md

### Build System (1 todo)
- [ ] build-system: Update Makefile and CMakeLists.txt

---

## 📊 PROGRESS METRICS

- **Todos Completed**: 3/32 (9%)
- **Code Files Created**: 2 (types_1959.f90, 1959_EQUATIONS_EXTRACTED.md)
- **Code Files Remaining**: ~6 Fortran modules + tests
- **Documentation Remaining**: ~40+ page LaTeX document
- **Estimated LOC Remaining**: ~2500 Fortran + 1500 test suite

---

## 🔬 MATHEMATICAL VERIFICATION STATUS

### Verified with MCP Tools:
✅ S4 constants (AM, AMBAR, B arrays)
✅ Thermodynamic relations (Cv, E integration)
✅ Unit conversions (density g/cm³ to kg/m³)

### Pending Verification:
- [ ] S4 Legendre polynomial derivation
- [ ] Von Neumann-Richtmyer viscosity dimensional analysis
- [ ] CFL stability criterion proof
- [ ] EOS Maxwell relation consistency
- [ ] Lagrangian coordinate Jacobians
- [ ] Energy conservation in coupled system

---

## 🎯 NEXT SESSION PRIORITIES

### Immediate Tasks (Critical Path):
1. **Complete S4 derivation** (s4-derive)
   - Use MCP CAS to derive μ₁ = 0.2958759, μ₂ = 0.9082483 from Legendre polynomials
   - Verify moment conservation: ∫μⁿ dμ = Σwᵢμᵢⁿ for n=0,1,2,3
   
2. **Implement S4 neutronics** (s4-implement)
   - File: `src/neutronics_s4_1959.f90`
   - NO delayed neutron reduction in fission source
   - Spherical transport sweep with angular redistribution
   - Alpha eigenvalue solver
   - Weight function WN(I) = T(I)·ΣNg(I)
   
3. **Implement von Neumann-Richtmyer hydro** (hydro-implement)
   - File: `src/hydro_vnr_1959.f90`
   - Artificial viscosity: Pv = Cvp²·ρ²·(ΔR)²·(∂V/∂t)² for compression only
   - Lagrangian equations with coordinate transformation
   - Modified Euler iteration for pressure
   - Free boundary condition

4. **Create main program** (main-implement)
   - File: `src/main_1959.f90`
   - Big G loop structure from ANL-5977 flow diagrams
   - Order numbers documented in comments
   - Time stepping with W stability criterion
   - VJ-OK-1 test for NS4 adjustment

### Testing Strategy:
- Start with trivial 1-zone problem (hand calculable)
- Progress to critical sphere (compare with diffusion theory)
- Validate with ANL-5977 sample problem (pages 89-103)
- Compare prompt vs delayed neutron behavior

### Documentation Strategy:
- Write mathematical sections AS code is implemented
- Use MCP CAS to verify every derivation
- Physical Review Letters style (no bullets, formal prose)
- ~5 pages per major section

---

## 🔑 CRITICAL FINDINGS

### 1. S4 Constants Match ANL-5977 Exactly
All S4 constants verified to 16 decimal places using MCP CAS.

### 2. NO Delayed Neutrons
**1959 explicitly ignored delayed neutrons** (ANL-5977 page 5, line 215).
Modern code includes 6-group Keepin model. This creates **factor of 10⁵ difference** in transient behavior for ρ < β.

### 3. Unit System Differences
1959 uses explicit units:
- Time: μsec
- Energy: keV (temperature), 10¹² ergs (total)
- Pressure: megabars
- Length: cm
- Cross sections: barns

Modern code units are undocumented (assumed SI).

### 4. Von Neumann-Richtmyer vs HLLC
1959 uses artificial viscosity for shock capturing (2-3 zone width).
Modern uses HLLC Riemann solver (sub-zone resolution).

---

## 📁 FILE STRUCTURE

```
/home/mh7373/GitRepos/ax1_phase1/
├── 1959_EQUATIONS_EXTRACTED.md          ✅ COMPLETE
├── src/
│   ├── kinds.f90                        (existing, unchanged)
│   ├── types_1959.f90                   ✅ COMPLETE
│   ├── neutronics_s4_1959.f90           ⏳ TODO
│   ├── hydro_vnr_1959.f90               ⏳ TODO
│   ├── time_control_1959.f90            ⏳ TODO
│   ├── input_1959.f90                   ⏳ TODO
│   ├── output_1959.f90                  ⏳ TODO
│   └── main_1959.f90                    ⏳ TODO
├── tests_1959/                          ⏳ TODO (create directory)
│   ├── test_s4_flat_source.f90
│   ├── test_critical_sphere.f90
│   ├── test_sod_shock.f90
│   ├── test_energy_conservation.f90
│   └── test_bethe_tait.f90
├── AX1_Code_Analysis.tex                ⏳ TODO (major update)
└── 1959_IMPLEMENTATION_NOTES.md         ⏳ TODO

Git Status:
- Branch: main
- Modern code preserved in: branch 'modern-enhanced'
- Tag: v1.0-modern-phase3-complete
```

---

## 💡 IMPLEMENTATION NOTES

### S4 Transport Sweep Algorithm (from ANL-5977 lines 1219-1260):
```fortran
! Outward sweep (J=1,5):
DO J = 1, 5
  AMT = AM(J)
  AMBART = AMBAR(J)
  BT = B(J)
  DO I = 2, IMAX
    ! Transport equation with angular redistribution
    ENN(I,J) = (AMT - BS - H(I))*ENN(I-1,J) + SO(I)/2
    IF (J > 1) THEN
      ENN(I,J) = ENN(I,J) + (AMBART + BS - H(I))*ENN(I-1,J-1) &
                          - (AMBART - BS + H(I))*ENN(I,J-1) + SO(I)/2
    END IF
    ENN(I,J) = ENN(I,J) / (AMT + BS + H(I))
  END DO
END DO
```

### Lagrangian Velocity Update (ANL-5977 Appendix B):
```fortran
! U^(n+1/2) = U^(n-1/2) - Δt · (R²/RL²) · ∂P/∂RL
U(I) = U(I) - DELT * (R(I)**2 / RL(I)**2) * &
       (HP(I+1) - HP(I)) / (0.5 * (RL(I+1) - RL(I-1)))
```

### Viscous Pressure (ANL-5977 Appendix C):
```fortran
! Only for compression (ΔV < 0)
IF (R(I) - R(I-1) < R_old(I) - R_old(I-1)) THEN
  DV_DT = (V(I) - V_old(I)) / DELT
  PV = CVP**2 * RO(I)**2 * (R(I) - R(I-1))**2 * DV_DT**2
ELSE
  PV = 0.0
END IF
HP(I) = PH(I) + PV
```

---

## 🚀 COMMAND TO CONTINUE

```bash
cd /home/mh7373/GitRepos/ax1_phase1
git status
# Verify we're on main branch with modern code backed up

# Continue with s4-derive todo
# Implement S4 quadrature derivation with MCP verification
```

---

## 📞 CONTEXT HANDOFF

**For next AI agent continuing this work:**

1. Read this progress report first
2. Review `/home/mh7373/GitRepos/ax1_phase1/1959_EQUATIONS_EXTRACTED.md`
3. Review `/home/mh7373/GitRepos/ax1_phase1/src/types_1959.f90`
4. Start with todo ID: `s4-derive`
5. Use MCP tools liberally for verification
6. Follow TDD: tests before implementation
7. Document in LaTeX as you go (Physical Review Letters style)
8. Update todos frequently

**Critical reminders:**
- NO delayed neutrons (1959 prompt-only)
- NO temperature-dependent cross sections
- Von Neumann-Richtmyer viscosity (NOT HLLC)
- S4 only (NOT S6, S8)
- 1959 units: μsec, keV, megabars, cm
- Verify EVERYTHING with MCP CAS before coding

**User expectations:**
- Complete all 32 todos
- ~2500 LOC Fortran code
- ~40+ page LaTeX document
- 100% test passing
- Reproduce ANL-5977 sample problem within 1%

**Estimated remaining work**: 80-100 hours of implementation time across multiple context windows.

---

End of Progress Report

