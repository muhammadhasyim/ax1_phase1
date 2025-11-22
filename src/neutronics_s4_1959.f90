! ##############################################################################
! neutronics_s4_1959.f90
!
! 1959 AX-1 S4 Discrete Ordinates Neutron Transport
!
! Based on: ANL-5977, Section V "Detailed Flow Diagram", Order Numbers 8000-8800
!           Fortran listing lines 1219-1360
!
! CRITICAL DIFFERENCE FROM MODERN CODE:
!   **NO DELAYED NEUTRON REDUCTION** in fission source
!   All fission neutrons treated as PROMPT (1959 assumption)
!
! Mathematical Foundation:
!   Transport: μ ∂ψ/∂r + (1-μ²)/r ∂ψ/∂μ + Σ_t ψ = Q
!   Fission source: Q_fiss(g) = χ(g) · Σ_{g'} ν·Σ_f(g') · φ(g') / k
!   NO factor of (1-β) unlike modern delayed-neutron codes!
!
! ##############################################################################

module neutronics_s4_1959
  use kinds
  use types_1959
  implicit none

  private
  public :: solve_alpha_eigenvalue_1959, solve_k_eigenvalue_1959
  public :: transport_sweep_s4_1959, build_prompt_sources_1959

contains

  ! ===========================================================================
  ! Solve for alpha eigenvalue (inverse period)
  ! ANL-5977 Order 8000-8500
  ! ===========================================================================
  subroutine solve_alpha_eigenvalue_1959(st, ctrl, alpha_out, k_out)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    real(rk), intent(out) :: alpha_out, k_out
    
    real(rk) :: alpha_guess, k_eff, alpha_prev
    integer :: iter
    logical :: converged
    
    print *, "========================================="
    print *, "1959 AX-1: Alpha Eigenvalue Solution"
    print *, "========================================="
    print *, "WARNING: Prompt neutrons ONLY (no delayed)"
    print *, "========================================="
    
    ! Initial guess for alpha
    alpha_guess = st%ALPHA
    if (abs(alpha_guess) < 1.0e-10_rk) alpha_guess = 0.001_rk
    
    converged = .false.
    
    do iter = 1, ctrl%max_source_iter
      alpha_prev = alpha_guess
      
      ! Solve transport for current alpha guess
      call transport_sweep_s4_1959(st, ctrl, alpha_guess, k_eff)
      
      ! Update alpha using point kinetics: α = (k-1)/Λ
      ! For prompt-only: α ≈ (k-1)/Λ with Λ computed from flux
      ! Simplified: use iteration on k_eff
      alpha_guess = compute_alpha_from_k(k_eff, st)
      
      ! Check convergence
      if (abs(alpha_guess - alpha_prev) < ctrl%EPSA) then
        converged = .true.
        if (mod(iter, 10) == 0 .or. converged) then
          print *, "  Iter", iter, ": alpha =", alpha_guess, ", k_eff =", k_eff
        end if
        exit
      end if
      
      if (mod(iter, 10) == 0) then
        print *, "  Iter", iter, ": alpha =", alpha_guess, ", k_eff =", k_eff, &
                 ", delta =", abs(alpha_guess - alpha_prev)
      end if
    end do
    
    if (.not. converged) then
      print *, "WARNING: Alpha iteration did not converge in", ctrl%max_source_iter, " iterations"
    else
      print *, "Alpha converged in", iter, " iterations"
    end if
    
    alpha_out = alpha_guess
    k_out = k_eff
    st%ALPHA = alpha_guess
    st%AKEFF = k_eff
    
  end subroutine solve_alpha_eigenvalue_1959

  ! ===========================================================================
  ! Solve for k-effective (criticality eigenvalue)
  ! ANL-5977 Order 6800-6850 (k-mode branch)
  ! ===========================================================================
  subroutine solve_k_eigenvalue_1959(st, ctrl, k_out)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    real(rk), intent(out) :: k_out
    
    real(rk) :: k_guess, k_prev
    integer :: iter
    logical :: converged
    
    print *, "========================================="
    print *, "1959 AX-1: K-effective Solution"
    print *, "========================================="
    
    ! Initial guess
    k_guess = st%AKEFF
    if (abs(k_guess - 1.0_rk) < 1.0e-10_rk) k_guess = 1.0_rk
    
    converged = .false.
    
    do iter = 1, ctrl%max_source_iter
      k_prev = k_guess
      
      ! Solve transport for current k guess
      call transport_sweep_s4_1959(st, ctrl, 0.0_rk, k_guess)
      
      ! k is updated inside transport_sweep
      k_guess = st%AKEFF
      
      ! Check convergence
      if (abs(k_guess - k_prev) < ctrl%EPSK) then
        converged = .true.
        if (mod(iter, 10) == 0 .or. converged) then
          print *, "  Iter", iter, ": k_eff =", k_guess
        end if
        exit
      end if
      
      if (mod(iter, 10) == 0) then
        print *, "  Iter", iter, ": k_eff =", k_guess, ", delta =", abs(k_guess - k_prev)
      end if
    end do
    
    if (.not. converged) then
      print *, "WARNING: K iteration did not converge in", ctrl%max_source_iter, " iterations"
    else
      print *, "K-eff converged in", iter, " iterations"
    end if
    
    k_out = k_guess
    st%AKEFF = k_guess
    
  end subroutine solve_k_eigenvalue_1959

  ! ===========================================================================
  ! S4 Transport Sweep
  ! ANL-5977 Lines 1219-1360 (Order 101-110)
  ! ===========================================================================
  subroutine transport_sweep_s4_1959(st, ctrl, alpha, k_eff)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    real(rk), intent(in) :: alpha
    real(rk), intent(inout) :: k_eff
    
    type(S4Transport) :: tr
    integer :: iter, i, j, g, gp, imat
    real(rk) :: k_old, fission_sum, fission_sum_old
    real(rk) :: AMT, AMBART, BT, BS, HI
    logical :: converged
    
    ! Initialize transport arrays
    call init_transport_arrays(st, tr)
    
    ! Outer iteration on k or alpha
    converged = .false.
    k_old = k_eff
    fission_sum_old = 1.0_rk
    
    do iter = 1, ctrl%max_source_iter
      
      ! Build sources (PROMPT ONLY - no delayed neutron reduction!)
      call build_prompt_sources_1959(st, tr, k_eff, alpha)
      
      ! Sweep over energy groups
      do g = 1, st%IG
        imat = st%K(2)  ! For now, assume single material
        
        ! Build source for this group
        tr%SO = 0._rk
        do i = 2, st%IMAX
          imat = st%K(i)
          ! Scattering source
          do gp = 1, st%IG
            tr%SO(i) = tr%SO(i) + st%mat(imat)%sig_s(gp, g) * st%N(gp, i)
          end do
          ! Fission source (PROMPT - no beta reduction!)
          tr%SO(i) = tr%SO(i) + st%mat(imat)%chi(g) * tr%FE(i) / max(k_eff, 1.0e-30_rk)
        end do
        
        ! S4 angular sweep (5 angular components)
        ! This follows ANL-5977 lines 1219-1260 EXACTLY
        call s4_angular_sweep(st, tr, g)
        
        ! Update scalar flux N(g,i) from angular fluxes ENN
        do i = 2, st%IMAX
          st%N(g, i) = sum(st%ENN(i, 1:5)) / 5.0_rk  ! Average over angles
        end do
      end do
      
      ! Update fission rate
      fission_sum = 0._rk
      do i = 2, st%IMAX
        tr%FE(i) = 0._rk
        imat = st%K(i)
        do g = 1, st%IG
          tr%FE(i) = tr%FE(i) + st%mat(imat)%nu_sig_f(g) * st%N(g, i)
        end do
        fission_sum = fission_sum + tr%FE(i) * tr%WN(i)
      end do
      
      ! Update k-effective
      if (fission_sum > 1.0e-30_rk) then
        k_eff = k_eff * fission_sum / max(fission_sum_old, 1.0e-30_rk)
      end if
      
      ! Check convergence
      if (abs(k_eff - k_old) < ctrl%EPSK) then
        converged = .true.
        exit
      end if
      
      k_old = k_eff
      fission_sum_old = fission_sum
      st%AITCT = st%AITCT + 1
    end do
    
    st%AKEFF = k_eff
    st%FBAR = fission_sum
    
  end subroutine transport_sweep_s4_1959

  ! ===========================================================================
  ! S4 Angular Sweep (ANL-5977 lines 1219-1260)
  ! ===========================================================================
  subroutine s4_angular_sweep(st, tr, g)
    type(State_1959), intent(inout) :: st
    type(S4Transport), intent(inout) :: tr
    integer, intent(in) :: g
    
    integer :: i, j, imat, L, II
    real(rk) :: AMT, AMBART, BT, BS, HI
    
    ! Compute H array (opacity-related)
    do i = 2, st%IMAX
      imat = st%K(i)
      tr%H(i) = st%mat(imat)%sig_f(g) + sum(st%mat(imat)%sig_s(:, g)) / st%RHO(i)
    end do
    
    ! Boundary condition at outer edge
    do j = 1, 5
      st%ENN(st%IMAX, j) = 0._rk
    end do
    
    ! Angular sweep J=1 to 5 (ANL-5977 Order 101-110)
    do j = 1, 5
      AMT = st%AM(j)
      AMBART = st%AMBAR(j)
      BT = st%B_CONST(j)
      
      ! Spatial sweep from I=2 to IMAX
      do i = 2, st%IMAX
        if (i == 2) then
          L = 1  ! Central point
        else
          L = i - 1
        end if
        II = i
        
        ! Transport equation (ANL-5977 line 1254)
        HI = tr%H(II)
        BS = BT / st%R(II)
        
        st%ENN(i, j) = (AMT - BS - HI) * st%ENN(L, j) + tr%SO(II) / 2.0_rk
        
        ! Angular coupling (lines 1258-1259)
        if (j > 1) then
          st%ENN(i, j) = st%ENN(i, j) + (AMBART + BS - HI) * st%ENN(L, j-1) &
                                       - (AMBART - BS + HI) * st%ENN(i, j-1) &
                                       + tr%SO(II) / 2.0_rk
        end if
        
        ! Normalize (line 1260)
        st%ENN(i, j) = st%ENN(i, j) / (AMT + BS + HI)
        
        ! Prevent negative flux
        if (st%ENN(i, j) < 0._rk) st%ENN(i, j) = 0._rk
      end do
    end do
    
  end subroutine s4_angular_sweep

  ! ===========================================================================
  ! Build PROMPT-ONLY sources (NO delayed neutron reduction!)
  ! CRITICAL: This is the key difference from modern codes
  ! ===========================================================================
  subroutine build_prompt_sources_1959(st, tr, k_eff, alpha)
    type(State_1959), intent(in) :: st
    type(S4Transport), intent(inout) :: tr
    real(rk), intent(in) :: k_eff, alpha
    
    integer :: i, g, imat
    
    ! Compute fission rate at each zone
    do i = 2, st%IMAX
      imat = st%K(i)
      tr%FE(i) = 0._rk
      do g = 1, st%IG
        ! PROMPT FISSION SOURCE - NO (1-beta) FACTOR!
        ! This is the critical 1959 assumption
        tr%FE(i) = tr%FE(i) + st%mat(imat)%nu_sig_f(g) * st%N(g, i)
      end do
    end do
    
    ! Weight function WN(I) = T(I) * sum(N(g,I))
    ! ANL-5977 Order 8301
    do i = 2, st%IMAX
      tr%T(i) = (st%R(i)**3 - st%R(i-1)**3) / 3.0_rk
      tr%WN(i) = tr%T(i) * sum(st%N(:, i))
    end do
    
  end subroutine build_prompt_sources_1959

  ! ===========================================================================
  ! Initialize transport arrays
  ! ===========================================================================
  subroutine init_transport_arrays(st, tr)
    type(State_1959), intent(in) :: st
    type(S4Transport), intent(inout) :: tr
    
    tr%H = 0._rk
    tr%SO = 0._rk
    tr%T = 0._rk
    tr%WN = 1._rk
    tr%FE = 0._rk
    tr%FEP = 0._rk
    
  end subroutine init_transport_arrays

  ! ===========================================================================
  ! Compute alpha from k-effective
  ! Prompt neutron approximation: α = (k-1)/Λ
  ! ===========================================================================
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

end module neutronics_s4_1959

