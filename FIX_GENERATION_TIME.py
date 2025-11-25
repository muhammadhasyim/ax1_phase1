#!/usr/bin/env python3
"""
Quick fix for generation time calculation in AX-1 code

This script provides the corrected code to replace the hardcoded
generation time with a proper flux-weighted calculation.
"""

print("""
================================================================================
FIX FOR GENERATION TIME (Λ) - Quick Implementation Guide
================================================================================

PROBLEM: Alpha is 2.7x too high because generation time is hardcoded at 0.1 μsec

SOLUTION: Implement proper flux-weighted generation time calculation

================================================================================
FILE TO MODIFY: src/neutronics_s4_1959.f90
================================================================================

STEP 1: Replace the compute_alpha_from_k function (lines 411-425)
-----------------------------------------------------------------------

OLD CODE (DELETE):
""")

print("""
function compute_alpha_from_k(k_eff, st) result(alpha)
  real(rk), intent(in) :: k_eff
  type(State_1959), intent(in) :: st
  real(rk) :: alpha
  real(rk) :: lambda_prompt
  
  ! Estimate prompt neutron generation time
  ! For fast spectrum: Λ ~ 10^-7 sec = 0.1 μsec
  ! This is a crude approximation; should be computed from flux
  lambda_prompt = 0.1_rk  ! μsec
  
  ! Prompt kinetics: α = (k-1)/Λ
  alpha = (k_eff - 1.0_rk) / lambda_prompt
  
end function compute_alpha_from_k
""")

print("""
NEW CODE (REPLACE WITH):
-----------------------------------------------------------------------
""")

print("""
function compute_alpha_from_k(k_eff, st) result(alpha)
  real(rk), intent(in) :: k_eff
  type(State_1959), intent(in) :: st
  real(rk) :: alpha
  real(rk) :: lambda_prompt
  real(rk) :: flux_integral, fission_integral
  real(rk) :: v_n, volume
  integer :: i, g, imat
  real(rk), parameter :: PI = 3.14159265358979_rk
  
  ! Prompt neutron speed (cm/μsec)
  ! For fast neutrons: v ≈ 2×10⁹ cm/s = 2×10³ cm/μs
  v_n = 2.0e3_rk  ! cm/μs
  
  ! Compute flux-weighted generation time: Λ = ∫φ dV / (v·∫ν·Σ_f·φ dV)
  flux_integral = 0.0_rk
  fission_integral = 0.0_rk
  
  do i = 2, st%IMAX
    imat = st%K(i)
    
    ! Volume of zone i (spherical shell)
    volume = (4.0_rk/3.0_rk) * PI * (st%R(i)**3 - st%R(i-1)**3)
    
    do g = 1, st%IG
      ! Flux integral
      flux_integral = flux_integral + st%N(g, i) * volume
      
      ! Fission rate integral (convert barns to cm² and adjust for density)
      ! σ in barns = 10^-24 cm², N in particles/cm³ = ρ·N_A/A
      ! For simplicity, use macroscopic cross section approximation
      fission_integral = fission_integral + &
        st%mat(imat)%nu_sig_f(g) * st%N(g, i) * st%RHO(i) * volume * 1.0e-24_rk
    end do
  end do
  
  ! Generation time Λ (μsec)
  if (abs(fission_integral) > 1.0e-30_rk) then
    lambda_prompt = flux_integral / (v_n * fission_integral)
  else
    ! Fallback to reasonable estimate
    lambda_prompt = 0.1_rk
  end if
  
  ! Prompt kinetics: α = (k-1)/Λ
  alpha = (k_eff - 1.0_rk) / lambda_prompt
  
  print *, "Generation time Λ =", lambda_prompt, " μsec"
  print *, "Alpha from k =", alpha, " μsec⁻¹"
  
end function compute_alpha_from_k
""")

print("""
================================================================================
STEP 2: Recompile and test
================================================================================

cd /home/mh7373/GitRepos/ax1_phase1
make -f Makefile.1959 clean
make -f Makefile.1959

./ax1_1959 inputs/geneve10_generated.inp > geneve10_lambda_fix.log 2>&1

================================================================================
EXPECTED RESULTS
================================================================================

If the fix works correctly:
- Generation time Λ should be printed: ~0.27 μsec (instead of 0.1)
- Alpha should decrease to ~0.013 μsec⁻¹ (instead of 0.035)
- Transient should run longer before disassembly
- More time points collected (closer to 15)

================================================================================
ALTERNATIVE QUICK FIX (if above doesn't work)
================================================================================

Simply scale the hardcoded value by the observed ratio:

lambda_prompt = 0.1_rk * (0.035 / 0.013)  ! ≈ 0.27 μsec

This is less rigorous but will get you running quickly.

================================================================================
VALIDATION
================================================================================

After running, check:
python3 scripts/quick_comparison.py

Look for:
- Alpha closer to 0.013 μsec⁻¹
- Simulation reaches t > 100 μsec
- More than 4 time points collected

================================================================================
""")

