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

contains

  ! ===========================================================================
  ! Compute W stability function
  ! ANL-5977 Appendix D, Order 9210
  ! W = C_sc·E·(Δt/ΔR)² + 4·C_vp·|ΔV|/V
  ! ===========================================================================
  subroutine compute_w_stability(st, ctrl)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    
    integer :: i
    real(rk) :: W_sum, W_cfl, W_visc, delta_R, delta_V, V_zone
    real(rk) :: sound_speed, E_internal
    
    W_sum = 0._rk
    
    do i = 2, st%IMAX
      ! Zone width
      delta_R = st%R(i) - st%R(i-1)
      if (delta_R < 1.0e-12_rk) cycle
      
      ! Zone volume
      V_zone = (4._rk/3._rk) * 3.14159265_rk * (st%R(i)**3 - st%R(i-1)**3)
      
      ! Volume change (approximate from velocity)
      delta_V = (st%U(i) - st%U(i-1)) * ctrl%DELT * st%R(i)**2
      
      ! Internal energy per unit mass
      E_internal = st%HE(i)
      
      ! Sound speed estimate: c_s ~ sqrt(∂P/∂ρ) ~ sqrt(E)
      sound_speed = sqrt(max(E_internal, 1.0_rk))
      
      ! CFL-like term: C_sc·E·(Δt/ΔR)²
      W_cfl = ctrl%CSC * sound_speed * (ctrl%DELT / delta_R)**2
      
      ! Viscous term: 4·C_vp·|ΔV|/V
      W_visc = 4._rk * ctrl%CVP * abs(delta_V) / max(V_zone, 1.0e-30_rk)
      
      ! Maximum W in system
      W_sum = max(W_sum, W_cfl + W_visc)
    end do
    
    st%W = W_sum
    
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
    ! CRITERION 4: Consider doubling if all criteria well-satisfied
    ! ANL-5977 Order 9290
    ! If W < 0.5*W_limit AND α·Δt < 0.5*limit, consider doubling
    ! =========================================================================
    if (st%W < 0.5_rk * ctrl%W_LIMIT) then
      if (trim(ctrl%EIGMODE) == "k" .or. &
          abs(st%ALPHA * ctrl%DELT) < 0.5_rk * ctrl%ALPHA_DELTA_LIMIT) then
        ! Also check we're not at maximum time step
        if (ctrl%DELT < ctrl%DT_MAX) then
          double = .true.
          if (ctrl%verbose) then
            print *, "TIME CONTROL: All criteria satisfied → DOUBLING Δt"
          end if
        end if
      end if
    end if
    
  end subroutine adjust_timestep_1959

  ! ===========================================================================
  ! VJ-OK-1 test: Adjust NS4 (number of hydro steps per neutron step)
  ! ANL-5977 Order 9220
  ! VJ·(Δt)²·(NS4)²·∫P dV < OK1
  ! ===========================================================================
  subroutine check_vj_ok1_test(st, ctrl, increase_ns4)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(inout) :: ctrl
    logical, intent(out) :: increase_ns4
    
    integer :: i
    real(rk) :: PdV_integral, VJ_test, R_mid, V_zone
    
    increase_ns4 = .false.
    
    ! Compute ∫P dV over entire system
    PdV_integral = 0._rk
    do i = 2, st%IMAX
      ! Zone volume
      V_zone = (4._rk/3._rk) * 3.14159265_rk * (st%R(i)**3 - st%R(i-1)**3)
      
      ! Add pressure × volume
      PdV_integral = PdV_integral + st%HP(i) * V_zone
    end do
    
    ! VJ test: VJ·(Δt)²·(NS4)²·∫P dV
    VJ_test = ctrl%VJ * (ctrl%DELT**2) * (real(ctrl%NS4, rk)**2) * PdV_integral
    
    ! Check against OK1 limit
    if (VJ_test > ctrl%OK1) then
      increase_ns4 = .true.
      if (ctrl%verbose) then
        print *, "VJ-OK-1 TEST: VJ_test =", VJ_test, " > ", ctrl%OK1
        print *, "               → INCREASING NS4 from", ctrl%NS4, "to", ctrl%NS4 + 1
      end if
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
    
    ! Power termination criterion
    if (st%FLAG1 > 0._rk) then
      terminate = .true.
      reason = "Power termination flag set"
      return
    end if
    
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
    if (ctrl%R_MAX_DISASSEMBLY < 1.0_rk) ctrl%R_MAX_DISASSEMBLY = 100.0_rk  ! 100 cm
    
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

