! ##############################################################################
! hydro_vnr_1959.f90
!
! 1959 AX-1 Lagrangian Hydrodynamics with von Neumann-Richtmyer Viscosity
!
! Based on: ANL-5977, Appendices B & C, Order Numbers 9050-9200
!           Fortran listing lines 1400-1750
!
! CRITICAL FEATURES:
!   - Lagrangian coordinates (mass-following)
!   - von Neumann-Richtmyer artificial viscosity (NOT HLLC)
!   - Linear equation of state ONLY
!   - Modified Euler iteration for pressure
!   - Free boundary condition
!
! Mathematical Foundation:
!   Velocity:  U^(n+1/2) = U^(n-1/2) - Δt·(R²/RL²)·∂P/∂RL
!   Position:  R^(n+1) = R^n + U^(n+1/2)·Δt
!   Density:   ρ = RL²/(R²·∂R/∂RL)
!   EOS:       P_H = α·ρ + β·θ + τ
!   Viscosity: P_v = C_vp²·ρ²·(ΔR)²·(∂V/∂t)²/V² (compression only)
!
! ##############################################################################

module hydro_vnr_1959
  use kinds
  use types_1959
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none

  private
  public :: hydro_step_1959, compute_lagrangian_coords
  public :: update_thermo_1959, compute_viscous_pressure
  public :: compute_total_energy

contains

  ! ===========================================================================
  ! Complete hydro step: velocity → position → density → EOS
  ! ANL-5977 Order 9050-9200
  ! ===========================================================================
  subroutine hydro_step_1959(st, ctrl, qbar)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    real(rk), intent(in) :: qbar
    
    integer :: i, imat
    real(rk) :: delq, delta_v, ro_inv_new, ro_inv_old
    real(rk) :: dele, z_term, delta_v_eff
    real(rk) :: energy_error
    
    ! Reset per-cycle diagnostics
    st%DELQ_TOTAL = 0._rk
    st%ERRLCL = 0._rk
    st%DELV_MAX = 0._rk  ! Reset max specific volume change for W calculation
    
    ! Update velocities from pressure gradient (Lagrangian)
    call update_velocities_lagrangian(st, ctrl)
    call diagnose_geometry_finiteness(st, "after velocity update")
    
    ! Update positions from velocities
    call update_positions(st, ctrl)
    call diagnose_geometry_finiteness(st, "after position update")
    
    ! Update density from Lagrangian coordinates (store previous)
    st%RO_PREV = st%RO
    call update_density_lagrangian(st)
    call diagnose_geometry_finiteness(st, "after density update")
    
    ! Preserve previous total pressure for work term
    st%HP_PREV(2:st%IMAX) = st%HP(2:st%IMAX)
    
    ! Predictor pressure using current density / old temperature
    call compute_hydrodynamic_pressure(st)
    
    ! Update thermodynamics (EOS iteration)
    do i = 2, st%IMAX
      imat = st%K(i)
      
      ! Specific volume change (DELV in ANL-5977)
      ro_inv_new = 1.0_rk / max(st%RO(i), 1.0e-30_rk)
      ro_inv_old = 1.0_rk / max(st%RO_PREV(i), 1.0e-30_rk)
      delta_v = ro_inv_new - ro_inv_old
      
      ! Store max |DELV| for W stability calculation (Order 9190)
      st%DELV_MAX(i) = max(st%DELV_MAX(i), abs(delta_v))
      
      ! Fission energy increment per gram (ANL-1959 Order 9070)
      delq = qbar * st%FREL(i) / max(st%ROSN(i), 1.0e-30_rk)
      if (delq > 0._rk) then
        delq = min(delq, 0.05_rk * max(st%HE(i), 1.0e-6_rk))
      end if
      
      ! Mechanical work correction and EOS linear terms (Orders 9130-9134)
      delta_v_eff = delta_v
      if (st%TIME < ENERGY_RELEASE_TIME_1959) delta_v_eff = 0._rk
      
      dele = delq - 0.5_rk * (st%HP_PREV(i) + st%HP(i)) * delta_v_eff
      z_term = dele + delta_v_eff * (st%mat(imat)%TAU + &
                st%mat(imat)%ALPHA * 0.5_rk * (st%RO(i) + st%RO_PREV(i)))
      
      ! Accumulate total energy (Q lacking 4π/3)
      st%Q = st%Q + delq * st%HMASS(i)
      st%DELQ_TOTAL = st%DELQ_TOTAL + delq * st%HMASS(i)
      
      ! Update thermodynamics with energy source
      call update_thermo_1959(st, ctrl, i, z_term, energy_error)
      st%ERRLCL = max(st%ERRLCL, energy_error)
    end do
    
    ! Recompute hydrodynamic pressure from updated state
    call compute_hydrodynamic_pressure(st)
    
    ! Compute viscous pressure (von Neumann-Richtmyer) using updated θ, ρ
    call compute_viscous_pressure(st, ctrl)
    
    ! Apply free boundary condition
    st%HP(st%IMAX + 1) = -st%HP(st%IMAX)
    
  end subroutine hydro_step_1959

  ! ===========================================================================
  ! Update velocities using Lagrangian momentum equation
  ! ANL-5977 Appendix B, equations around line 872
  ! U^(n+1/2) = U^(n-1/2) - Δt·(R²/RL²)·∂P/∂RL
  ! ===========================================================================
  subroutine update_velocities_lagrangian(st, ctrl)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    
    integer :: i
    real(rk) :: dP_dRL, R_ratio_sq, accel
    
    ! Central point always has zero velocity
    st%U(1) = 0._rk
    
    ! Update velocities at zone boundaries (I = 2 to IMAX)
    do i = 2, st%IMAX
      ! Pressure gradient in Lagrangian coordinates
      ! ∂P/∂RL ≈ (P(i+1) - P(i)) / (0.5*(RL(i+1) - RL(i-1)))
      dP_dRL = (st%HP(i+1) - st%HP(i)) / &
               max(0.5_rk * (st%RL(i+1) - st%RL(i-1)), 1.0e-12_rk)
      
      ! Ratio (R/RL)² for coordinate transformation
      R_ratio_sq = (st%R(i)**2) / max(st%RL(i)**2, 1.0e-30_rk)
      
      ! Acceleration: -1/ρ · ∂P/∂r = -(R²/RL²) · ∂P/∂RL
      accel = -R_ratio_sq * dP_dRL
      
      ! Velocity update (leapfrog scheme)
      st%U(i) = st%U(i) + ctrl%DELT * accel
    end do
    
  end subroutine update_velocities_lagrangian

  ! ===========================================================================
  ! Update positions from velocities
  ! R^(n+1) = R^n + U^(n+1/2)·Δt
  ! ===========================================================================
  subroutine update_positions(st, ctrl)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    
    integer :: i
    
    ! Central point always at r=0
    st%R(1) = 0._rk
    
    ! Update radial positions
    do i = 2, st%IMAX + 1
      st%R(i) = st%R(i) + st%U(i) * ctrl%DELT
      
      ! Prevent negative radii or collapse
      if (st%R(i) < st%R(i-1)) then
        st%R(i) = st%R(i-1) + 1.0e-10_rk
      end if
    end do
    
  end subroutine update_positions

  ! ===========================================================================
  ! Update density from Lagrangian coordinates
  ! Mass conservation: ρ·R²·dR = RL²·dRL = constant
  ! Therefore: ρ = RL²/(R²·∂R/∂RL)
  ! ===========================================================================
  subroutine update_density_lagrangian(st)
    type(State_1959), intent(inout) :: st
    
    integer :: i
    real(rk) :: dR_dRL, volume_ratio
    
    do i = 2, st%IMAX
      ! Finite difference approximation of ∂R/∂RL
      dR_dRL = (st%R(i) - st%R(i-1)) / max(st%RL(i) - st%RL(i-1), 1.0e-30_rk)
      
      ! Volume ratio (RL/R)²
      volume_ratio = (st%RL(i)**2) / max(st%R(i)**2, 1.0e-30_rk)
      
      ! Hydrodynamic density (g/cc)
      st%RO(i) = volume_ratio / max(dR_dRL, 1.0e-12_rk)
      
      ! Prevent unphysical densities
      if (st%RO(i) < 1.0e-6_rk) st%RO(i) = 1.0e-6_rk
      if (st%RO(i) > 1.0e6_rk) st%RO(i) = 1.0e6_rk
      
      ! Convert to neutronic density (atoms/cc × 10⁻²⁴)
      ! RHO = RO / ROLAB
      st%RHO(i) = st%RO(i) / st%mat(st%K(i))%ROLAB
    end do
    
  end subroutine update_density_lagrangian

  ! ===========================================================================
  ! Compute Lagrangian coordinates from current density
  ! ANL-5977 line 1400 (Order 6818)
  ! RL(I)³ = RL(I-1)³ + ρ(I)·[R(I)³ - R(I-1)³]
  ! ===========================================================================
  subroutine compute_lagrangian_coords(st)
    type(State_1959), intent(inout) :: st
    
    integer :: i
    real(rk) :: delta_volume
    
    ! Central Lagrangian coordinate
    st%RL(1) = 0._rk
    
    ! Compute RL from mass conservation
    do i = 2, st%IMAX + 1
      delta_volume = st%RO(min(i, st%IMAX)) * (st%R(i)**3 - st%R(i-1)**3)
      st%RL(i) = (st%RL(i-1)**3 + delta_volume)**(1._rk/3._rk)
    end do
    
    ! Compute zone masses HMASS(I) = RL(I)³ - RL(I-1)³
    ! (factor 4π/3 omitted as in 1959 code)
    do i = 2, st%IMAX
      st%HMASS(i) = st%RL(i)**3 - st%RL(i-1)**3
    end do
    
  end subroutine compute_lagrangian_coords

  ! ===========================================================================
  ! Compute von Neumann-Richtmyer artificial viscosity
  ! ANL-5977 Appendix C, lines 798-902
  ! P_v = C_vp²·ρ²·(ΔR)²·(∂V/∂t)² for compression ONLY
  ! ===========================================================================
  subroutine compute_viscous_pressure(st, ctrl)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    
    integer :: i, imat
    real(rk) :: P_H, P_v, delta_R, delta_V, V_old, V_new, dV_dt
    real(rk) :: compression_check
    
    do i = 2, st%IMAX
      imat = st%K(i)
      P_H = st%HP(i)
      
      ! Check for compression: ΔV < 0 ?
      ! Volume of shell: V ∝ R³ - R_{i-1}³
      V_new = st%R(i)**3 - st%R(i-1)**3
      
      ! Estimate old volume (crude approximation)
      V_old = V_new + st%U(i) * ctrl%DELT * 3._rk * st%R(i)**2
      
      delta_V = V_new - V_old
      compression_check = delta_V / max(abs(V_old), 1.0e-30_rk)
      
      ! Apply viscous pressure ONLY for compression
      if (compression_check < 0._rk) then
        ! Zone width
        delta_R = st%R(i) - st%R(i-1)
        
        ! Rate of volume change
        dV_dt = delta_V / max(ctrl%DELT, 1.0e-30_rk)
        
        ! von Neumann-Richtmyer viscosity
        ! P_v = C_vp²·ρ²·(ΔR)²·(dV/dt)²/V²
        P_v = (ctrl%CVP**2) * (st%RO(i)**2) * (delta_R**2) * &
              (dV_dt**2) / max(V_new**2, 1.0e-60_rk)
        
        ! Limit viscous pressure to avoid instability
        P_v = min(P_v, 10._rk * max(abs(P_H), 1.0e-12_rk))
      else
        P_v = 0._rk  ! No viscosity during expansion
      end if
      
      ! Total pressure
      st%HP(i) = P_H + P_v
      
      if (.not. ieee_is_finite(st%HP(i))) then
        print *, "==== VISCOSITY NAN TRACE zone", i, " t =", st%TIME, "μsec ===="
        print *, "  P_H =", P_H, "  P_v =", P_v
        print *, "  R(i) =", st%R(i), "  R(i-1) =", st%R(i-1), " delta_R =", delta_R
        print *, "  RO(i) =", st%RO(i), "  THETA(i) =", st%THETA(i)
        print *, "  delta_V =", delta_V, "  compression_check =", compression_check
        print *, "==== END VISCOSITY NAN TRACE ===="
      end if
    end do
    
  end subroutine compute_viscous_pressure

  ! ===========================================================================
  ! Update thermodynamics with Modified Euler iteration
  ! ANL-5977 Order 9124-9150
  ! Iterates: P_H → θ → P_H until convergence
  ! ===========================================================================
  subroutine update_thermo_1959(st, ctrl, i, delta_e, energy_error)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    integer, intent(in) :: i
    real(rk), intent(in) :: delta_e
    real(rk), intent(out) :: energy_error
    
    integer :: iter, imat
    real(rk) :: P_guess, P_new, delta_P, theta_new, discriminant
    real(rk) :: E_specific, A_cv, B_cv, energy_floor
    logical :: converged
    
    imat = st%K(i)
    energy_error = 0._rk
    
    ! Get EOS and specific heat parameters
    A_cv = st%mat(imat)%ACV
    B_cv = st%mat(imat)%BCV
    
    ! Specific internal energy (per gram)
    E_specific = st%HE(i) + delta_e
    
    ! Modified Euler iteration
    ! Initial guess: P_new = P_old
    P_guess = st%HP(i)
    
    converged = .false.
    do iter = 1, ctrl%max_pressure_iter
      
      ! Solve for temperature from energy
      ! E = A_cv·θ + 0.5·B_cv·θ²
      ! Quadratic formula: θ = (-A_cv + sqrt(A_cv² + 2·B_cv·E))/B_cv
      if (abs(B_cv) > 1.0e-12_rk) then
        energy_floor = -0.5_rk * (A_cv**2) / max(B_cv, 1.0e-12_rk)
        if (E_specific < energy_floor) then
          print *, "==== ENERGY FLOOR TRACE zone", i, " t =", st%TIME, "μsec ===="
          print *, "  A_cv =", A_cv, "  B_cv =", B_cv
          print *, "  E_specific(before) =", E_specific, "  floor =", energy_floor
          print *, "  delta_e =", delta_e
          print *, "==== END ENERGY FLOOR TRACE ===="
          E_specific = energy_floor
        end if
        discriminant = A_cv**2 + 2._rk * B_cv * E_specific
        if (discriminant < 0._rk) then
          print *, "==== THETA NAN TRACE zone", i, " t =", st%TIME, "μsec ===="
          print *, "  A_cv =", A_cv, "  B_cv =", B_cv
          print *, "  E_specific =", E_specific, "  delta_e =", delta_e
          print *, "  discriminant =", discriminant
          print *, "==== END THETA NAN TRACE ===="
          discriminant = max(discriminant, 0._rk)
        end if
        theta_new = (-A_cv + sqrt(discriminant)) / B_cv
      else
        ! Linear case: E = A_cv·θ
        theta_new = E_specific / max(A_cv, 1.0e-12_rk)
      end if
      
      ! Prevent negative temperature
      if (theta_new < 0._rk) theta_new = 0._rk
      
      ! Compute new pressure from EOS
      P_new = st%mat(imat)%ALPHA * st%RO(i) + &
              st%mat(imat)%BETA * theta_new + &
              st%mat(imat)%TAU
      
      ! No negative pressure
      if (P_new < 0._rk) P_new = 0._rk
      
      ! Check convergence
      delta_P = abs(P_new - P_guess)
      if (delta_P < ctrl%ETA1 * (abs(P_new) + ctrl%EPSI)) then
        converged = .true.
        st%THETA(i) = theta_new
        ! Note: Total pressure HP includes viscosity, computed separately
        exit
      end if
      
      ! Update guess (simple iteration, could use relaxation)
      P_guess = P_new
    end do
    
    if (.not. converged) then
      ! Use last computed values anyway
      st%THETA(i) = theta_new
    end if
    
    ! Update internal energy
    st%HE(i) = A_cv * st%THETA(i) + 0.5_rk * B_cv * st%THETA(i)**2
    energy_error = abs(st%HE(i) - E_specific)
    
  end subroutine update_thermo_1959

  ! ===========================================================================
  ! Compute total energy (kinetic + internal)
  ! ANL-5977 Order 6840, lines 1416-1428
  ! ===========================================================================
  subroutine compute_total_energy(st)
    type(State_1959), intent(inout) :: st
    
    integer :: i
    real(rk) :: RKE
    
    st%TOTKE = 0._rk
    st%TOTIEN = 0._rk
    
    do i = 2, st%IMAX
      ! Kinetic energy: 0.25·(U(I)² + U(I-1)²)·mass
      RKE = 0.25_rk * (st%U(i)**2 + st%U(i-1)**2)
      st%TOTKE = st%TOTKE + st%HMASS(i) * RKE
      
      ! Internal energy: HE(I)·mass
      st%TOTIEN = st%TOTIEN + st%HMASS(i) * st%HE(i)
    end do
    
    ! Energy balance check (Q from sums vs. integrated Q)
    ! Apply 4π/3 factor since HMASS omits it
    st%CHECK = (st%Q - 4.1887902047863909_rk * (st%TOTKE + st%TOTIEN)) / &
               max(abs(st%Q), 1.0e-30_rk)
    
  end subroutine compute_total_energy

  subroutine diagnose_geometry_finiteness(st, context)
    type(State_1959), intent(in) :: st
    character(len=*), intent(in) :: context
    integer :: i
    logical :: header_printed
    integer, save :: last_report_cycle = -1
    real(rk), save :: last_report_time = -1._rk

    if (st%NH == last_report_cycle .and. abs(st%TIME - last_report_time) < 1.0e-9_rk) return

    header_printed = .false.

    do i = 2, st%IMAX
      if (.not. ieee_is_finite(st%R(i))) then
        if (.not. header_printed) then
          print *, "==== HYDRO NAN MONITOR (", trim(context), ")  t =", st%TIME, "μsec ===="
          header_printed = .true.
        end if
        print *, "  R(", i, ") =", st%R(i)
      end if
      if (.not. ieee_is_finite(st%HMASS(i))) then
        if (.not. header_printed) then
          print *, "==== HYDRO NAN MONITOR (", trim(context), ")  t =", st%TIME, "μsec ===="
          header_printed = .true.
        end if
        print *, "  HMASS(", i, ") =", st%HMASS(i)
      end if
      if (.not. ieee_is_finite(st%RO(i))) then
        if (.not. header_printed) then
          print *, "==== HYDRO NAN MONITOR (", trim(context), ")  t =", st%TIME, "μsec ===="
          header_printed = .true.
        end if
        print *, "  RO(", i, ") =", st%RO(i)
      end if
      if (.not. ieee_is_finite(st%U(i))) then
        if (.not. header_printed) then
          print *, "==== HYDRO NAN MONITOR (", trim(context), ")  t =", st%TIME, "μsec ===="
          header_printed = .true.
        end if
        print *, "  U(", i, ") =", st%U(i)
      end if
      if (.not. ieee_is_finite(st%RL(i))) then
        if (.not. header_printed) then
          print *, "==== HYDRO NAN MONITOR (", trim(context), ")  t =", st%TIME, "μsec ===="
          header_printed = .true.
        end if
        print *, "  RL(", i, ") =", st%RL(i)
      end if
    end do

    if (header_printed) then
      last_report_cycle = st%NH
      last_report_time = st%TIME
    end if

  end subroutine diagnose_geometry_finiteness

  subroutine compute_hydrodynamic_pressure(st)
    type(State_1959), intent(inout) :: st
    integer :: i, imat
    real(rk) :: P_H

    do i = 2, st%IMAX
      imat = st%K(i)
      P_H = st%mat(imat)%ALPHA * st%RO(i) + &
            st%mat(imat)%BETA * st%THETA(i) + &
            st%mat(imat)%TAU
      if (P_H < 0._rk) P_H = 0._rk
      st%HP(i) = P_H
    end do

  end subroutine compute_hydrodynamic_pressure

end module hydro_vnr_1959

