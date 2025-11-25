! ##############################################################################
! main_1959.f90
!
! 1959 AX-1 Main Program - Big G Loop
!
! Based on: ANL-5977, "Detailed Flow Diagram" pages 27-52
!           Order Numbers 8000-9300
!
! Program structure follows 1959 EXACTLY:
!   BIG G LOOP (Order 8000):
!     1. Neutronics calculation (S4 transport, alpha or k eigenvalue)
!     2. Hydro sub-loop (NS4 cycles)
!        - Update velocities, positions, density
!        - Compute viscous pressure
!        - Solve EOS for temperature
!        - Add fission energy
!     3. Controls and diagnostics
!        - Compute W stability
!        - Adjust time step
!        - VJ-OK-1 test
!        - Output results
!     4. Check termination
!
! ##############################################################################

program ax1_1959
  use kinds
  use types_1959
  use io_1959
  use neutronics_s4_1959
  use hydro_vnr_1959
  use time_control_1959
  implicit none

  type(State_1959) :: state
  type(Control_1959) :: control
  integer :: output_unit, csv_time_unit, csv_spatial_unit
  integer :: big_g_iter, hydro_iter, iz
  logical :: terminate, halve_dt, double_dt, increase_ns4
  logical :: write_spatial_at_200
  character(len=256) :: term_reason, input_file
  real(rk) :: alpha_out, k_out
  real(rk) :: delt_outer, delt_sub, qbar_cycle, ns4_real
  
  ! ============================================================================
  ! Initialization
  ! ============================================================================
  print *, "========================================="
  print *, "1959 AX-1 PROMPT NEUTRON CODE"
  print *, "ANL-5977 Faithful Reproduction"
  print *, "========================================="
  print *
  
  ! Get input filename from command line
  if (command_argument_count() < 1) then
    print *, "Usage: ax1_1959 <input_file>"
    stop
  end if
  call get_command_argument(1, input_file)
  
  ! Read input deck
  call read_input_1959(trim(input_file), state, control)
  
  ! Initialize time control
  call init_time_control(control)
  
  ! Open output files
  output_unit = 20
  csv_time_unit = 21
  csv_spatial_unit = 22
  write_spatial_at_200 = .false.
  
  open(unit=output_unit, file=trim(control%output_file), status='replace', action='write')
  open(unit=csv_time_unit, file='output_time_series.csv', status='replace', action='write')
  open(unit=csv_spatial_unit, file='output_spatial_t200.csv', status='replace', action='write')
  
  ! Write CSV headers
  call write_csv_header_time(csv_time_unit)
  
  ! Echo input
  if (control%print_input) then
    call echo_input(state, control, output_unit)
  end if
  
  ! Write output header
  call write_output_header(output_unit)
  
  ! Initialize Lagrangian coordinates
  call compute_lagrangian_coords(state)
  state%TOTKE = 0._rk
  state%TOTIEN = 0._rk
  do iz = 2, state%IMAX
    state%TOTIEN = state%TOTIEN + state%HMASS(iz) * state%HE(iz)
  end do
  state%Q = state%TOTKE + state%TOTIEN
  state%QPRIME = state%Q
  state%CHECK = 0._rk
  
  ! Diagnostic: print initial energy values
  print *, "========================================="
  print *, "INITIAL ENERGY DIAGNOSTIC"
  print *, "========================================="
  print *, "  TOTIEN (lacking 4π/3) =", state%TOTIEN
  print *, "  QP = 4π/3 * Q =", 4.18879_rk * state%Q
  print *, "  Sample zone 10:"
  print *, "    HMASS(10) =", state%HMASS(10)
  print *, "    HE(10) =", state%HE(10)
  print *, "    θ(10) =", state%THETA(10)
  print *, "    ACV =", state%mat(state%K(10))%ACV
  print *, "    BCV =", state%mat(state%K(10))%BCV
  print *, "========================================="
  
  ! ============================================================================
  ! ICNTRL=01: Critical Geometry Search (ANL-5977 Sheet No. 2)
  ! ============================================================================
  if (control%ICNTRL == 1) then
    print *, "========================================="
    print *, "ICNTRL=01 MODE: Fitting geometry to target alpha"
    print *, "========================================="
    call fit_geometry_to_alpha_1959(state, control)
    ! After geometry fit, recompute Lagrangian coordinates
    call compute_lagrangian_coords(state)
  end if
  
  ! ============================================================================
  ! BIG G LOOP (ANL-5977 Order 8000)
  ! ============================================================================
  big_g_iter = 0
  terminate = .false.
  
  print *, "========================================="
  print *, "STARTING BIG G LOOP"
  print *, "========================================="
  
  do while (.not. terminate)
    big_g_iter = big_g_iter + 1
    
    if (mod(big_g_iter, 10) == 0) then
      print *, "Big G iteration", big_g_iter, ", time =", state%TIME, " μsec"
    end if
    
    ! ==========================================================================
    ! STEP 1: NEUTRONICS CALCULATION (Order 8000-8800)
    ! ==========================================================================
    if (.not. control%skip_neutronics) then
      if (trim(control%eigmode) == "alpha") then
        call solve_alpha_eigenvalue_1959(state, control, alpha_out, k_out)
        state%ALPHA = alpha_out
        state%AKEFF = k_out
      else
        call solve_k_eigenvalue_1959(state, control, k_out)
        state%AKEFF = k_out
        state%ALPHA = 0._rk  ! No alpha in k-mode
      end if
      
      ! Compute total power (fission rate)
      state%TOTAL_POWER = state%FBAR
      if (big_g_iter == 1) state%POWER_PREV = state%TOTAL_POWER
      
      ! Apply point kinetics power growth: P(t+Δt) = P(t) × exp(α·Δt)
      ! This is the prompt supercritical transient behavior
      if (state%ALPHA > 1.0e-10_rk) then
        state%TOTAL_POWER = state%POWER_PREV * exp(state%ALPHA * control%DELT)
        state%POWER_PREV = state%TOTAL_POWER
        print *, "Point kinetics: α =", state%ALPHA, "Δt =", control%DELT, &
                 "Power growth =", exp(state%ALPHA * control%DELT)
      end if
    end if
    
    ! Store ROSN snapshot for this neutron cycle (Order 1190)
    state%ROSN(2:state%IMAX) = state%RO(2:state%IMAX)
    
    ! Compute QBAR = POWER · Δt / (4π · FBAR)
    ! ANL-5977 Order 9060: QBAR = POWER * DELT / (12.56637 * FBAR)
    ! where FBAR = Σ T(I) · F(I) is GEOMETRIC (not flux-weighted)
    state%QBAR = 0._rk
    if (state%FBAR_GEOM > 1.0e-30_rk) then
      state%QBAR = state%TOTAL_POWER * control%DELT / &
                   (12.566370614359172_rk * state%FBAR_GEOM)
    end if
    if (state%QBAR > 0._rk .and. state%W > control%W_LIMIT) then
      state%QBAR = state%QBAR * control%W_LIMIT / max(state%W, control%W_LIMIT)
    end if
    state%QBAR_LAST = state%QBAR
    
    ! ==========================================================================
    ! STEP 2: HYDRO SUB-LOOP (Order 9050-9200, NS4 times)
    ! ==========================================================================
    delt_outer = control%DELT
    if (control%NS4 > 0) then
      ns4_real = real(control%NS4, rk)
      delt_sub = delt_outer / ns4_real
    else
      ns4_real = 1._rk
      delt_sub = delt_outer
    end if
    qbar_cycle = state%QBAR / ns4_real
    
    do hydro_iter = 1, max(control%NS4, 1)
      state%NH = state%NH + 1
      control%DELT = delt_sub
      
      ! Update hydrodynamics
      call hydro_step_1959(state, control, qbar_cycle)
      
      ! Update Lagrangian coordinates
      call compute_lagrangian_coords(state)
    end do
    control%DELT = delt_outer
    
    ! Advance time
    state%TIME = state%TIME + control%DELT
    
    ! ==========================================================================
    ! STEP 3: CONTROLS AND DIAGNOSTICS (Order 9210-9290)
    ! ==========================================================================
    
    ! Compute W stability function
    call compute_w_stability(state, control)
    
    ! Compute total energy
    call compute_total_energy(state)
    if (control%verbose) then
      print *, "----- ORDER 9210 DIAGNOSTICS -----"
      print *, "   W =", state%W, "(limit", control%W_LIMIT, ")"
      print *, "   alpha·Δt =", state%ALPHA * control%DELT, "(limit", 4._rk * control%ETA2, ")"
      print *, "   NS4 =", control%NS4
      print *, "   CHECK =", state%CHECK, "   ERRLCL =", state%ERRLCL
    end if
    
    ! Check VJ-OK-1 test for NS4 adjustment
    call check_vj_ok1_test(state, control, increase_ns4)
    if (increase_ns4) then
      control%NS4 = min(control%NS4 + 1, control%HYDRO_PER_NEUT_MAX)
    end if
    
    ! Adjust time step based on stability
    call adjust_timestep_1959(state, control, halve_dt, double_dt)
    if (halve_dt) then
      control%DELT = control%DELT * 0.5_rk
      control%DELT = max(control%DELT, control%DELT_min)
    else if (double_dt) then
      control%DELT = min(control%DELT * 2.0_rk, control%DT_MAX)
    end if
    
    ! ==========================================================================
    ! STEP 4: OUTPUT (Order 9250)
    ! ==========================================================================
    if (mod(big_g_iter, control%output_freq) == 0) then
      call write_output_step(state, control, output_unit)
      flush(output_unit)
      
      ! Write CSV time-series data
      call write_csv_step_time(state, control, csv_time_unit)
      flush(csv_time_unit)
      
      ! Write spatial profile at t=200 μsec (within tolerance)
      if (.not. write_spatial_at_200 .and. abs(state%TIME - 200.0_rk) < 1.0_rk) then
        call write_csv_header_spatial(csv_spatial_unit)
        call write_csv_step_spatial(state, csv_spatial_unit)
        flush(csv_spatial_unit)
        write_spatial_at_200 = .true.
        print *, "Wrote spatial profile at t =", state%TIME, " μsec"
      end if
    end if
    
    ! Save previous values
    state%QPRIME = state%Q
    state%POWER_PREV = state%TOTAL_POWER
    state%ALPHAP = state%ALPHA
    
    ! ==========================================================================
    ! STEP 5: CHECK TERMINATION (Order 9295-9300)
    ! ==========================================================================
    terminate = check_termination(state, control, term_reason)
    
    if (terminate) then
      print *, "========================================="
      print *, "TERMINATION: ", trim(term_reason)
      print *, "========================================="
      exit
    end if
    
    ! Safety check for runaway iterations
    if (big_g_iter > 1000000) then
      print *, "WARNING: Maximum iterations exceeded!"
      terminate = .true.
      term_reason = "Maximum iterations (safety)"
      exit
    end if
    
  end do  ! End Big G loop
  
  ! ============================================================================
  ! FINALIZATION
  ! ============================================================================
  
  ! Write final output
  call write_output_step(state, control, output_unit)
  call write_csv_step_time(state, control, csv_time_unit)
  
  ! Write summary
  call write_summary(state, control, output_unit)
  
  ! Close output files
  close(output_unit)
  close(csv_time_unit)
  close(csv_spatial_unit)
  
  print *, "========================================="
  print *, "SIMULATION COMPLETE"
  print *, "Final time:    ", state%TIME, " μsec"
  print *, "Iterations:    ", big_g_iter
  print *, "Hydro cycles:  ", state%NH
  print *, "Output file:   ", trim(control%output_file)
  print *, "========================================="
  
end program ax1_1959

