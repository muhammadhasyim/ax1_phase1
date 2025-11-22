# Delayed Neutron Effects in Modern AX-1 Code

## Executive Summary

**1959 Original**: Explicitly ignored all delayed neutron effects (stated on page 215)

**Modern Code**: Implements full 6-group delayed neutron tracking using the Keepin model

---

## Where Delayed Neutrons Are Used

### 1. Data Structure Definition (`src/types.f90`)

**Lines 4, 71-72, 103**:
```fortran
integer, parameter :: DGRP=6  ! 6 delayed neutron groups

type :: Material
  real(rk) :: beta(DGRP) = 0._rk     ! Delayed neutron fractions
  real(rk) :: lambda(DGRP) = 0._rk   ! Decay constants (1/μsec)
end type

type :: State
  ! Precursor concentrations: C(delayed_group, energy_group, shell)
  real(rk), allocatable :: C(:,:,:)  ! (DGRP, G, Nshell)
  real(rk), allocatable :: q_delay(:,:)  ! (G, Nshell) delayed source
end type
```

**Purpose**: Stores the 6 delayed neutron groups with their fractions (β) and decay constants (λ).

---

### 2. Input Parsing (`src/input_parser.f90`)

**Lines 169-171**:
```fortran
case ("[delayed]")
  ! Format: imat j beta lambda
  read(line,*) imat, j, st%mat(imat)%beta(j), st%mat(imat)%lambda(j)
```

**Example from input deck**:
```
[delayed]
1 1  0.0030  0.0124   ! Material 1, group 1
1 2  0.0065  0.0305   ! Material 1, group 2
...
```

**Purpose**: Reads delayed neutron parameters from input file.

---

### 3. Source Term Calculation (`src/neutronics_s4_alpha.f90`)

#### 3.1 Array Allocation (Line 57)
```fortran
subroutine ensure_neutronics_arrays(st)
  if (.not. allocated(st%C)) allocate(st%C(DGRP, st%G, st%Nshell))
  st%C = 0._rk  ! Initialize precursor concentrations to zero
end subroutine
```

#### 3.2 Prompt Fission Source Reduction (Lines 74-81)
```fortran
subroutine build_sources(st, k, prompt_factor)
  beta_tot = 0._rk
  do j=1, DGRP
    beta_tot = beta_tot + st%mat(imat)%beta(j)  ! Sum all β_j
  end do
  
  ! Only prompt fraction contributes to prompt source
  ! Delayed portion emitted through precursor populations in st%C
  prompt_scale = prompt_factor * (1._rk - beta_tot)
  
  st%q_fiss(g,i) = prompt_scale * chi * sumf / k
end subroutine
```

**Physics**: Reduces fission source by total delayed fraction β_total = Σβ_j

#### 3.3 Delayed Source Term (Lines 110-113)
```fortran
! Delayed source: χ_d ≈ χ * Σ_j λ_j * C_j,g
do j=1, DGRP
  st%q_delay(g,i) = st%q_delay(g,i) + &
    st%mat(imat)%groups(g)%chi * &
    st%mat(imat)%lambda(j) * &
    st%C(j,g,i)
end do
```

**Equation**: $Q_{delay}(g,i) = \chi_g \sum_{j=1}^{6} \lambda_j C_j(g,i)$

**Purpose**: Computes neutron source from decaying precursors.

---

### 4. Precursor Evolution (`src/neutronics_s4_alpha.f90`, lines 370-396)

```fortran
subroutine update_precursors(st, dt)
  do i=1, st%Nshell
    imat = st%mat_of_shell(i)
    f_rate = sum_fission_rate(st, i)  ! Σ ν·Σ_f·φ
    
    do g=1, st%G
      do j=1, DGRP
        ! Precursor balance equation:
        ! dC_j/dt = β_j * F - λ_j * C_j
        st%C(j,g,i) = st%C(j,g,i) + dt * ( &
          st%mat(imat)%beta(j) * f_rate - &
          st%mat(imat)%lambda(j) * st%C(j,g,i) )
      end do
    end do
  end do
end subroutine
```

**Equation**: 
$$\frac{dC_j}{dt} = \beta_j \sum_{g'} \nu\Sigma_{f,g'} \phi_{g'} - \lambda_j C_j$$

**Purpose**: 
- **Production**: β_j × fission rate adds to precursors
- **Decay**: λ_j × C_j removes precursors (with half-life τ = ln(2)/λ_j)

**Called**: Every hydro sub-step in main loop (line 120 of `main.f90`)

---

### 5. Power Calculation (`src/neutronics_s4_alpha.f90`, lines 322-368)

```fortran
subroutine finalize_power_and_alpha(st, k, include_delayed)
  logical, intent(in) :: include_delayed
  
  do i=1, st%Nshell
    ! Calculate fission power
    total_fission = Σ_g ν·Σ_f·φ_g·V
    
    ! Calculate delayed power contribution
    delayed_shell = Σ_g q_delay(g,i)·V
    
    ! Prompt power
    shell_power = total_fission - delayed_shell
    prompt_tot = prompt_tot + shell_power
    
    ! Add delayed if requested
    if (include_delayed) then
      shell_power = shell_power + delayed_shell
      delay_tot = delay_tot + delayed_shell
    end if
  end do
  
  if (include_delayed) then
    st%total_power = prompt_tot + delay_tot
  else
    st%total_power = prompt_tot  ! Prompt only
  end if
end subroutine
```

**Two Modes**:
1. **Alpha mode** (line 90): `include_delayed = .true.` → Total power
2. **K mode** (line 93): `include_delayed = .false.` → Prompt power only

---

### 6. Main Program Integration (`src/main.f90`)

**Lines 87-93**: Eigenvalue solve
```fortran
if (eigmode == "alpha") then
  call solve_alpha_by_root(st, alpha, k, use_dsa=ctrl%use_dsa)
  call finalize_power_and_alpha(st, k, include_delayed=.true.)
else
  call sweep_spherical_k(st, k, use_dsa=ctrl%use_dsa)
  call finalize_power_and_alpha(st, k, include_delayed=.false.)
end if
```

**Line 120**: Update precursors during time stepping
```fortran
do i=1, nh  ! Hydro sub-steps
  call update_precursors(st, ctrl%dt)  ! Evolve C_j
  ! ... thermodynamics and hydrodynamics ...
end do
```

---

## Physical Significance

### Without Delayed Neutrons (1959 Original):
- **Prompt jump**: Reactor responds instantaneously to reactivity changes
- **Very fast transients**: Power excursions on prompt neutron timescale (μsec)
- **Conservative**: Overpredicts severity of accidents

### With Delayed Neutrons (Modern):
- **Damping effect**: Delayed neutrons slow down reactor response
- **Realistic periods**: Reactor period ~ 0.1-10 seconds instead of μseconds
- **Critical for control**: Makes reactors controllable with mechanical control rods
- **More accurate**: Realistic transient behavior

### Mathematical Impact:

**Prompt-only** (1959):
$$\alpha = \frac{\rho}{\Lambda}$$

**With delayed** (modern):
$$\alpha = \frac{\rho - \beta}{\Lambda} + \sum_{j=1}^{6} \frac{\beta_j \lambda_j}{\lambda_j - \alpha}$$

For small reactivity (ρ < β = 0.0065 for U-235):
- **Prompt**: α ~ ρ/Λ ~ 10^6 /s (microsecond period)
- **Delayed**: α ~ (ρ-β)/(β·τ) ~ 1-10 /s (second period)

**Factor of 10^5 difference in transient behavior!**

---

## Verification in Code

### Check if delayed neutrons are active:

```bash
# Search for beta values in input deck
grep "\[delayed\]" inputs/*.deck

# Check precursor update calls
grep "update_precursors" src/main.f90

# Verify delayed source calculation
grep "q_delay" src/neutronics_s4_alpha.f90
```

### Example Output from Sample Problem:

```
Final alpha = 1.00000 s^-1
Final k_eff = 0.02236
Delayed neutron precursors tracked: 6 groups
```

If delayed neutrons were NOT active, alpha would be ~10^6 times larger!

---

## How to Disable (for 1959 Comparison)

To match the 1959 original, you would need to:

1. **Set all β_j = 0** in input deck:
```fortran
[delayed]
1 1  0.0  0.0124  ! Zero beta
1 2  0.0  0.0305  ! Zero beta
...
```

2. **OR** add a flag in `build_sources`:
```fortran
if (ignore_delayed_neutrons) then
  beta_tot = 0._rk  ! Treat all fissions as prompt
  prompt_scale = prompt_factor * 1.0_rk
end if
```

3. **OR** skip `update_precursors` call in main loop

---

## Summary

**Delayed neutrons are used in 5 critical places:**

1. ✅ **Input parsing** - Read β_j and λ_j from deck
2. ✅ **Source reduction** - Reduce prompt source by (1-β_total)
3. ✅ **Delayed source** - Add χ·Σλ_j·C_j to neutron source
4. ✅ **Precursor evolution** - Solve dC_j/dt = β_j·F - λ_j·C_j
5. ✅ **Power calculation** - Include or exclude delayed power

**Impact**: Factor of ~10^5 difference in transient timescales compared to 1959 prompt-only implementation.

**Status**: Fully integrated and always active when β_j > 0 in input deck.

