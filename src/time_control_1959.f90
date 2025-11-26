! ##############################################################################
! time_control_1959.f90
!
! 1959 AX-1 Time Step Control and Stability Analysis
!
! Based on: ANL-5977, Appendix D "Stability", Order Numbers 9210-9290
!           Fortran listing lines 1760-1850
!
! CRITICAL FEATURES:
!   - W stability function (von Neumann + Courant)
!   - Automatic time step halving/doubling
!   - VJ-OK-1 test for NS4 adjustment
!   - Alpha and power change limits
!
! Mathematical Foundation:
!   W = C_sc·E·(Δt/ΔR)² + 4·C_vp·|ΔV|/V < 0.3 (stability limit)
!   α·Δt < 4·ETA2 (reactivity change limit)
!   |ΔP/P| < ETA3 (power change limit)
!   VJ·(Δt)²·(NS4)²·∫P dV < OK1 (hydrodynamic work limit)
!
! ##############################################################################

module time_control_1959
  use kinds
  use types_1959
  implicit none

  private
  public :: compute_w_stability, adjust_timestep_1959
  public :: check_vj_ok1_test, compute_ns4_hydro
  public :: check_termination, init_time_control

contains

  ! ===========================================================================
  ! Compute W stability function
  ! ANL-5977 Order 9190 (EXACT formula from original paper):
  !   WR = CSC * ABSF(HE(I)) * DELT**2 / DELR**2 + 4.0 * CVP * RHOT * ABSF(DELV)
  !   W = MAXIF(WR, W)
  ! Where:
  !   - HE(I) = internal energy per gram [10^12 erg/g = cm^2/μs^2]
  !   - DELV = specific volume change = 1/ρ_new - 1/ρ_old [cm^3/g]
  !   - RHOT = current density [g/cm^3]
  ! ===========================================================================
  subroutine compute_w_stability(st, ctrl)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    
    integer :: i
    real(rk) :: W_zone, W_cfl, W_visc, delta_R
    real(rk) :: W_max, W_cfl_max, W_visc_max
    real(rk) :: DELV, RHOT
    
    W_max = 0._rk
    W_cfl_max = 0._rk
    W_visc_max = 0._rk
    
    do i = 2, st%IMAX
      ! Zone width (DELR in original)
      delta_R = st%R(i) - st%R(i-1)
      if (delta_R < 1.0e-12_rk) cycle
      
      ! Current density (RHOT in original)
      RHOT = st%RO(i)
      
      ! Use the stored DELV_MAX from the hydro step (computed as 1/ρ_new - 1/ρ_old)
      ! This is the correct DELV per ANL-5977 Order 9190
      DELV = st%DELV_MAX(i)
      
      ! ANL-5977 Order 9190 CFL term: CSC * |HE(I)| * (Δt/ΔR)²
      ! HE(I) is internal energy per gram [cm²/μs²]
      ! This term represents c² * (Δt/ΔR)² where c² ~ CSC * E_int
      W_cfl = ctrl%CSC * abs(st%HE(i)) * (ctrl%DELT / delta_R)**2
      
      ! ANL-5977 Order 9190 Viscous term: 4 * CVP * RHOT * |DELV|
      ! Note: RHOT * |DELV| = ρ * |Δ(1/ρ)| ~ |Δρ/ρ| (fractional density change)
      W_visc = 4._rk * ctrl%CVP * RHOT * abs(DELV)
      
      ! Total W for this zone
      W_zone = W_cfl + W_visc
      
      ! Track maximum W in system (MAXIF in original)
      W_max = max(W_max, W_zone)
      W_cfl_max = max(W_cfl_max, W_cfl)
      W_visc_max = max(W_visc_max, W_visc)
    end do
    
    st%W = W_max
    st%W_CFL = W_cfl_max
    st%W_VISC = W_visc_max
    
    ! Diagnostic: identify which zone causes W explosion
    if (W_cfl_max > 1.0e6_rk) then
      do i = 2, st%IMAX
        delta_R = st%R(i) - st%R(i-1)
        if (delta_R < 1.0e-12_rk) cycle
        W_cfl = ctrl%CSC * abs(st%HE(i)) * (ctrl%DELT / delta_R)**2
        if (W_cfl > 0.5_rk * W_cfl_max) then
          print *, "=== W_CFL EXPLOSION DIAGNOSTIC t=", st%TIME, "==="
          print *, "  Zone", i, ": W_cfl =", W_cfl
          print *, "  delta_R =", delta_R, " cm"
          print *, "  HE(i) =", st%HE(i), " (10^12 erg/g)"
          print *, "  DELT =", ctrl%DELT, " μsec"
          print *, "  R(i) =", st%R(i), "  R(i-1) =", st%R(i-1)
          print *, "  RO(i) =", st%RO(i), " g/cm³"
          print *, "  U(i) =", st%U(i), "  U(i-1) =", st%U(i-1), " cm/μsec"
          exit  ! Only print first problematic zone
        end if
      end do
    end if
    
  end subroutine compute_w_stability

  ! ===========================================================================
  ! Adjust time step based on stability criteria
  ! ANL-5977 Order 9285-9290
  ! ===========================================================================
  subroutine adjust_timestep_1959(st, ctrl, halve, double)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(inout) :: ctrl
    logical, intent(out) :: halve, double
    
    real(rk) :: alpha_change, power_change, power_ratio
    
    halve = .false.
    double = .false.
    
    ! =========================================================================
    ! CRITERION 0: SENSE LIGHT 3 equivalent (halve_delt_flag)
    ! ANL-5977 Order 9025/9283: Force halve if flag set by NS4 logic
    ! =========================================================================
    if (ctrl%halve_delt_flag) then
      halve = .true.
      ctrl%halve_delt_flag = .false.  ! Clear the flag after use
      if (ctrl%verbose) then
        print *, "TIME CONTROL: halve_delt_flag set → HALVING Δt"
      end if
      return
    end if
    
    ! =========================================================================
    ! CRITERION 1: W stability function
    ! ANL-5977 Order 9285
    ! If W > W_limit, halve time step
    ! =========================================================================
    if (st%W > ctrl%W_LIMIT) then
      halve = .true.
      if (ctrl%verbose) then
        print *, "TIME CONTROL: W =", st%W, " > ", ctrl%W_LIMIT, " → HALVING Δt"
      end if
      return
    end if
    
    ! =========================================================================
    ! CRITERION 2: Alpha change limit (for alpha eigenvalue mode)
    ! ANL-5977 Order 9286
    ! If |α·Δt| > ALPHA_DELTA_LIMIT, halve time step
    ! =========================================================================
    if (trim(ctrl%EIGMODE) == "alpha") then
      alpha_change = abs(st%ALPHA * ctrl%DELT)
      if (alpha_change > ctrl%ALPHA_DELTA_LIMIT) then
        halve = .true.
        if (ctrl%verbose) then
          print *, "TIME CONTROL: α·Δt =", alpha_change, " > ", &
                   ctrl%ALPHA_DELTA_LIMIT, " → HALVING Δt"
        end if
        return
      end if
    end if
    
    ! =========================================================================
    ! CRITERION 3: Power change limit
    ! ANL-5977 Order 9287
    ! If |ΔP/P| > POWER_DELTA_LIMIT, halve time step
    ! =========================================================================
    if (st%TOTAL_POWER > 1.0e-10_rk) then
      power_ratio = abs((st%TOTAL_POWER - st%POWER_PREV) / st%TOTAL_POWER)
      if (power_ratio > ctrl%POWER_DELTA_LIMIT) then
        halve = .true.
        if (ctrl%verbose) then
          print *, "TIME CONTROL: ΔP/P =", power_ratio, " > ", &
                   ctrl%POWER_DELTA_LIMIT, " → HALVING Δt"
        end if
        return
      end if
    end if
    
    ! =========================================================================
    ! CRITERION 4: Consider doubling (Order 9269-9280)
    ! ANL-5977: Doubling requires NL countdown to reach 0
    !   9270 NL = NL - 1
    !   9272 IF(NL > 0) skip doubling
    !   9274 IF(α·Δt >= ETA2) skip doubling
    !   9278 IF(2*DELT > DTMAX) skip doubling
    ! =========================================================================
    
    ! Decrement NL counter (Order 9270)
    ctrl%NL = ctrl%NL - 1
    
    ! Can only double if W is well below limit
    if (st%W < 0.1_rk * ctrl%W_LIMIT) then
      ! Check NL counter (Order 9272)
      if (ctrl%NL <= 0) then
        ! Check alpha stability (Order 9274)
        if (abs(st%ALPHA * ctrl%DELT) < ctrl%ETA2) then
          ! Check DTMAX limit (Order 9278)
          if (2.0_rk * ctrl%DELT <= ctrl%DT_MAX) then
            double = .true.
            if (ctrl%verbose) then
              print *, "TIME CONTROL: NL=", ctrl%NL, ", all criteria satisfied → DOUBLING Δt"
            end if
          end if
        end if
      end if
    end if
    
    ! Reset NL counter after halving or doubling (Order 9310)
    if (halve .or. double) then
      ctrl%NL = ctrl%NLMax
    end if
    
  end subroutine adjust_timestep_1959

  ! ===========================================================================
  ! VJ-OK test: Full NS4 adjustment per ANL-5977 Order 9201-9212
  ! 
  ! Logic:
  !   9201-9202: Skip if NS4 <= 1 or ALPHA <= 0
  !   9203-9204: Skip if max pressure < PTEST
  !   9205-9206: Compute CONST = VJ·Δt²·NS4²·PBAR
  !   9210: Skip if CONST <= OK1
  !   9208: If CONST >= OK2, set NS4 = 1
  !   9209-9212: If OK1 < CONST < OK2, halve NS4
  ! ===========================================================================
  subroutine check_vj_ok1_test(st, ctrl, increase_ns4)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(inout) :: ctrl
    logical, intent(out) :: increase_ns4
    
    integer :: i
    real(rk) :: HPBAR, PBAR, CONST, T_i
    
    increase_ns4 = .false.
    
    ! Order 9201: Skip if NS4 <= 1
    if (ctrl%NS4 <= 1) return
    
    ! Order 9202: Skip if ALPHA <= 0
    if (st%ALPHA <= 0._rk) return
    
    ! Order 9203-9204: Find max pressure
    HPBAR = 0._rk
    do i = 2, st%IMAX
      HPBAR = max(HPBAR, st%HP(i))
    end do
    
    ! Skip if max pressure < PTEST
    if (HPBAR < ctrl%PTEST) return
    
    ! Order 9205-9206: Compute volume-weighted average pressure
    ! PBAR = Σ HP(I) * T(I) * 4π
    PBAR = 0._rk
    do i = 2, st%IMAX
      T_i = (st%R(i)**3 - st%R(i-1)**3) / 3._rk
      PBAR = PBAR + st%HP(i) * T_i
    end do
    PBAR = PBAR * 12.566370614359172_rk  ! 4π factor
    
    ! Compute CONST = VJ * Δt² * NS4² * PBAR
    CONST = ctrl%VJ * (ctrl%DELT**2) * (real(ctrl%NS4, rk)**2) * PBAR
    
    ! Order 9210: Skip if CONST <= OK1
    if (CONST <= ctrl%OK1) return
    
    ! Order 9207-9208: If CONST >= OK2, reset NS4 to 1
    if (CONST >= ctrl%OK2) then
      if (ctrl%verbose) then
        print *, "VJ-OK-2: CONST =", CONST, " >= OK2 =", ctrl%OK2, " → NS4=1"
      end if
      ctrl%NS4 = 1
      return
    end if
    
    ! Order 9209-9212: OK1 < CONST < OK2 → halve NS4
    if (mod(ctrl%NS4, 2) == 1) then
      ! NS4 odd: halve with rounding
      ctrl%NS4 = (ctrl%NS4 - 1) / 2
    else
      ! NS4 even: simple halve
      ctrl%NS4 = ctrl%NS4 / 2
    end if
    
    if (ctrl%verbose) then
      print *, "VJ-OK: CONST =", CONST, " (OK1 < CONST < OK2) → NS4 halved to", ctrl%NS4
    end if
    
  end subroutine check_vj_ok1_test

  ! ===========================================================================
  ! Compute NS4 (number of hydro steps per neutron step)
  ! ANL-5977 Order 8720-8750
  ! NS4 adjusted based on VJ-OK-1 test and stability
  ! ===========================================================================
  subroutine compute_ns4_hydro(st, ctrl)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(inout) :: ctrl
    
    logical :: increase
    
    ! Start with base value
    if (ctrl%NS4 < 1) ctrl%NS4 = 1
    
    ! Check VJ-OK-1 test
    call check_vj_ok1_test(st, ctrl, increase)
    
    if (increase) then
      ctrl%NS4 = ctrl%NS4 + 1
      
      ! Cap at maximum
      if (ctrl%NS4 > ctrl%HYDRO_PER_NEUT_MAX) then
        ctrl%NS4 = ctrl%HYDRO_PER_NEUT_MAX
        if (ctrl%verbose) then
          print *, "WARNING: NS4 capped at maximum =", ctrl%HYDRO_PER_NEUT_MAX
        end if
      end if
    end if
    
  end subroutine compute_ns4_hydro

  ! ===========================================================================
  ! Apply time step change (halving or doubling)
  ! ANL-5977 Order 9288-9291
  ! ===========================================================================
  subroutine apply_timestep_change(ctrl, halve, double)
    type(Control_1959), intent(inout) :: ctrl
    logical, intent(in) :: halve, double
    
    if (halve) then
      ctrl%DELT = ctrl%DELT * 0.5_rk
      if (ctrl%verbose) then
        print *, "TIME STEP HALVED: Δt =", ctrl%DELT, " μsec"
      end if
    else if (double) then
      ctrl%DELT = min(ctrl%DELT * 2.0_rk, ctrl%DT_MAX)
      if (ctrl%verbose) then
        print *, "TIME STEP DOUBLED: Δt =", ctrl%DELT, " μsec"
      end if
    end if
    
  end subroutine apply_timestep_change

  ! ===========================================================================
  ! Check termination criteria
  ! ANL-5977 Order 9295-9300
  ! ===========================================================================
  function check_termination(st, ctrl, reason) result(terminate)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(in) :: ctrl
    character(len=*), intent(out) :: reason
    logical :: terminate
    
    terminate = .false.
    reason = ""
    
    ! Time limit reached
    if (st%TIME >= ctrl%T_END) then
      terminate = .true.
      reason = "Time limit reached"
      return
    end if
    
    ! Maximum alpha (growth rate) exceeded
    if (abs(st%ALPHA) > st%ALPHAO .and. st%ALPHAO > 0._rk) then
      terminate = .true.
      reason = "Alpha exceeded maximum"
      return
    end if
    
    ! Power termination criterion:
    ! NOTE: FLAG1 > 0 just marks that alpha was positive before (for shutdown detection)
    ! NOT a termination condition. Could add late-time shutdown termination here.
    
    ! System disassembly (outer radius too large)
    if (st%R(st%IMAX) > ctrl%R_MAX_DISASSEMBLY) then
      terminate = .true.
      reason = "System disassembled"
      return
    end if
    
  end function check_termination

  ! ===========================================================================
  ! Compute Courant number for diagnostics
  ! CFL = v·Δt/Δx
  ! ===========================================================================
  function compute_courant_number(st, ctrl) result(cfl_max)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(in) :: ctrl
    real(rk) :: cfl_max
    
    integer :: i
    real(rk) :: delta_R, cfl
    
    cfl_max = 0._rk
    
    do i = 2, st%IMAX
      delta_R = st%R(i) - st%R(i-1)
      if (delta_R < 1.0e-12_rk) cycle
      
      cfl = abs(st%U(i)) * ctrl%DELT / delta_R
      cfl_max = max(cfl_max, cfl)
    end do
    
  end function compute_courant_number

  ! ===========================================================================
  ! Initialize time control parameters from input
  ! ANL-5977 Order 6700-6750
  ! ===========================================================================
  subroutine init_time_control(ctrl)
    type(Control_1959), intent(inout) :: ctrl
    
    ! Default stability parameters (if not set in input)
    if (ctrl%CSC < 1.0e-12_rk) ctrl%CSC = 3.0_rk
    if (ctrl%CVP < 1.0e-12_rk) ctrl%CVP = 2.0_rk
    if (ctrl%W_LIMIT < 1.0e-12_rk) ctrl%W_LIMIT = 0.3_rk
    if (ctrl%MIN_ZONE_WIDTH < 1.0e-6_rk) ctrl%MIN_ZONE_WIDTH = 0.5_rk
    if (ctrl%ALPHA_DELTA_LIMIT < 1.0e-12_rk) ctrl%ALPHA_DELTA_LIMIT = 0.2_rk
    if (ctrl%POWER_DELTA_LIMIT < 1.0e-12_rk) ctrl%POWER_DELTA_LIMIT = 0.2_rk
    
    ! VJ-OK-1 parameters
    if (ctrl%VJ < 1.0e-12_rk) ctrl%VJ = 0.001_rk
    if (ctrl%OK1 < 1.0e-12_rk) ctrl%OK1 = 1.0_rk
    
    ! Time step limits
    if (ctrl%DELT < 1.0e-12_rk) ctrl%DELT = 1.0e-3_rk  ! 0.001 μsec default
    if (ctrl%DT_MAX < 1.0e-12_rk) ctrl%DT_MAX = 0.1_rk  ! 0.1 μsec max
    
    ! Hydro subcycling
    if (ctrl%HYDRO_PER_NEUT < 1) ctrl%HYDRO_PER_NEUT = 1
    if (ctrl%HYDRO_PER_NEUT_MAX < 1) ctrl%HYDRO_PER_NEUT_MAX = 200
    if (ctrl%NS4 < 1) ctrl%NS4 = ctrl%HYDRO_PER_NEUT
    
    ! Termination criteria
    if (ctrl%T_END < 1.0e-12_rk) ctrl%T_END = 1.0_rk  ! 1 μsec default
    if (ctrl%R_MAX_DISASSEMBLY < 1.0_rk) ctrl%R_MAX_DISASSEMBLY = 200.0_rk  ! 200 cm
    
    ! Convergence tolerances
    if (ctrl%EPSA < 1.0e-12_rk) ctrl%EPSA = 1.0e-6_rk
    if (ctrl%EPSK < 1.0e-12_rk) ctrl%EPSK = 1.0e-6_rk
    if (ctrl%EPSI < 1.0e-12_rk) ctrl%EPSI = 1.0e-9_rk
    if (ctrl%ETA1 < 1.0e-12_rk) ctrl%ETA1 = 1.0e-4_rk
    if (ctrl%ETA2 < 1.0e-12_rk) ctrl%ETA2 = 0.05_rk
    if (ctrl%ETA3 < 1.0e-12_rk) ctrl%ETA3 = 0.2_rk
    
    ! Iteration limits
    if (ctrl%MAX_SOURCE_ITER < 1) ctrl%MAX_SOURCE_ITER = 100
    if (ctrl%MAX_PRESSURE_ITER < 1) ctrl%MAX_PRESSURE_ITER = 20
    
    if (ctrl%verbose) then
      print *, "========================================"
      print *, "TIME CONTROL INITIALIZED"
      print *, "========================================"
      print *, "CSC (Courant constant)    =", ctrl%CSC
      print *, "CVP (Viscosity constant)  =", ctrl%CVP
      print *, "W_LIMIT                   =", ctrl%W_LIMIT
      print *, "Δt (initial)              =", ctrl%DELT, " μsec"
      print *, "Δt_max                    =", ctrl%DT_MAX, " μsec"
      print *, "NS4 (hydro/neutron)       =", ctrl%NS4
      print *, "T_END                     =", ctrl%T_END, " μsec"
      print *, "========================================"
    end if
    
  end subroutine init_time_control

end module time_control_1959

