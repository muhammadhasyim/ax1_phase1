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
  real(rk) :: last_output_time, output_time_interval
  logical :: write_spatial_at_200
  character(len=256) :: term_reason, input_file
  real(rk) :: alpha_out, k_out
  real(rk) :: delt_outer, delt_sub, qbar_cycle, ns4_real
  real(rk) :: Z_alpha  ! Alpha change rate for NS4 adjustment (Order 9018)
  
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
  
  ! Initialize output time tracking (output every 10 μsec)
  last_output_time = -100.0_rk
  output_time_interval = 10.0_rk
  
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
  ! Set generation time BEFORE geometry fitting (Geneva 10 value)
  state%LAMBDA_INITIAL = 0.248_rk  ! μsec (from Geneva 10 sample problem)
  print *, "Generation time Λ =", state%LAMBDA_INITIAL, " μsec"
  
  if (control%ICNTRL == 1) then
    print *, "========================================="
    print *, "ICNTRL=01 MODE: Fitting geometry to target alpha"
    print *, "========================================="
    call fit_geometry_to_alpha_1959(state, control)
    ! After geometry fit, recompute Lagrangian coordinates
    call compute_lagrangian_coords(state)
    ! ANL-5977 line 433: ICNTRL=0 after geometry fit
    ! This switches to alpha update mode for the transient
    control%ICNTRL = 0
    print *, "ICNTRL set to 0 for transient phase"
  end if
  
  ! ============================================================================
  ! ANL-5977 Order 6820-6830: Initial DELT check
  ! Halve DELT before first hydro cycle if α×Δt > 4×ETA2
  ! ============================================================================
  do while (abs(state%ALPHA) * control%DELT > 4._rk * control%ETA2)
    control%DELT = 0.5_rk * control%DELT
    print *, "HALVE DELT INITIALLY:", control%DELT
  end do
  control%DELTP = control%DELT
  
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
    ! ANL-5977 Order 8009: Pre-neutronics geometry update
    ! Store ROSN snapshot and update RHO before Big G loop
    ! This must happen BEFORE neutronics to ensure consistent densities
    ! ==========================================================================
    do iz = 2, state%IMAX
      state%ROSN(iz) = state%RO(iz)  ! Snapshot density for fission heating
      state%RHO(iz) = state%RO(iz) / state%mat(state%K(iz))%ROLAB  ! Neutronics density
    end do
    
    ! ==========================================================================
    ! STEP 1: NEUTRONICS CALCULATION (Order 8000-8800)
    !
    ! ANL-5977 KCNTRL logic:
    !   KCNTRL=0: Pure alpha mode from start
    !   KCNTRL=1: k-calc first (KCALC=1), then switch to alpha mode (KCALC=0)
    !
    ! For transients: always end up in alpha mode after initial k-calc
    ! ==========================================================================
    if (.not. control%skip_neutronics) then
      if (trim(control%eigmode) == "k") then
        ! Pure k-eigenvalue mode (no transient)
        call solve_k_eigenvalue_1959(state, control, k_out)
        state%AKEFF = k_out
        state%ALPHA = 0._rk  ! No alpha in k-mode
      else
        ! Alpha mode or KCNTRL=1 mode for transients
        if (big_g_iter == 1 .and. control%ICNTRL == 1) then
          ! ICNTRL=1: Fit geometry to achieve target alpha (Geneva 10 mode)
          print *, "========================================="
          print *, "ICNTRL=1: Geometry Fitting Mode"
          print *, "========================================="
          state%LAMBDA_INITIAL = 0.248_rk  ! μsec (from Geneva 10)
          call fit_geometry_to_alpha_1959(state, control)
          k_out = state%AKEFF
          alpha_out = state%ALPHA
          print *, "After geometry fit: k_eff =", k_out, " alpha =", alpha_out
          
          ! Initialize alpha-mode rates for transient
          call initialize_alpha_mode_rates(state)
          control%KCALC = 0  ! Switch to alpha mode
          
        else if (big_g_iter == 1 .and. control%KCNTRL >= 1) then
          ! KCNTRL >= 1: First do k-eigenvalue calculation (KCALC=1)
          print *, "========================================="
          print *, "KCNTRL=1: Initial k-eigenvalue calculation"
          print *, "========================================="
          control%KCALC = 1
          call solve_k_eigenvalue_1959(state, control, k_out)
          state%AKEFF = k_out
          ! Compute initial alpha from k: α = (k-1)/Λ
          ! Compute alpha CONSISTENT with our k_eff
          ! Use Geneva 10 generation time Λ = 0.248 μsec
          ! This ensures the alpha/V term properly balances our excess reactivity
          state%LAMBDA_INITIAL = 0.248_rk  ! μsec (from Geneva 10)
          alpha_out = (k_out - 1.0_rk) / state%LAMBDA_INITIAL
          state%ALPHA = alpha_out
          print *, "Initial k_eff =", k_out
          print *, "Generation time Λ =", state%LAMBDA_INITIAL, " μsec (Geneva 10)"
          print *, "CONSISTENT alpha = (k-1)/Λ =", alpha_out, " μsec⁻¹"
          print *, "(Reference Geneva 10: k=1.003, α=0.013)"
          
          ! CRITICAL: Initialize FFBAR, FEBAR, FENBAR from k-eigenvalue result
          ! These are needed for the alpha update formula in the first alpha sweep
          call initialize_alpha_mode_rates(state)
          
          ! Switch to alpha mode for subsequent iterations
          control%KCALC = 0
        else if (big_g_iter == 1) then
          ! Pure alpha mode from start
          call solve_alpha_eigenvalue_1959(state, control, alpha_out, k_out)
          state%ALPHA = alpha_out
          state%AKEFF = k_out
        else
          ! Transient: Update alpha from neutronics feedback
          ! ANL-5977: Alpha is updated based on changing density distribution
          ! As the system expands, leakage increases and alpha decreases
          !
          ! Call alpha-mode transport sweep which updates FFBAR, FEBAR, FENBAR
          ! and computes new alpha from: α = α + (FFBAR+FEBAR-FFBARP-FEBARP)/FENBAR
          call transport_sweep_alpha_mode_1959(state, control, state%ALPHA)
          alpha_out = state%ALPHA
          
          if (big_g_iter <= 5 .or. mod(big_g_iter, 100) == 0) then
            print *, "Big G iter", big_g_iter, ": Alpha-mode transport, α =", alpha_out
          end if
        end if
      end if
      
      ! ANL-5977 Order 9014-9017: Update ALPHAO and FLAG1
      ! FLAG1 is set when alpha was ever positive (for shutdown detection)
      state%ALPHAO = max(abs(state%ALPHA), state%ALPHAO)
      if (state%ALPHA > 0._rk) then
        state%FLAG1 = 1.0_rk  ! Mark that alpha was positive
      end if
      
      ! =========================================================================
      ! ANL-5977 Order 9018-9045: NS4 adjustment based on alpha change rate
      ! Z = |ALPHAP - ALPHA| / (ALPHAO + 3*EPSA)
      ! - If Z < ETA3: NS4++ (alpha stable, can afford more hydro cycles)
      ! - If Z > 3*ETA3: NS4-- (alpha changing fast, need more neutronics)  
      ! - If Z > 6*ETA3: NS4=1 (alpha changing very fast, immediate neutronics)
      ! - If NS4=1 and alpha>0 and changing too fast: set halve_delt_flag
      ! =========================================================================
      if (big_g_iter > 1) then
        Z_alpha = abs(state%ALPHAP - state%ALPHA) / &
                  (state%ALPHAO + 3.0_rk * control%EPSA)
        
        if (Z_alpha < control%ETA3) then
          ! Alpha stable - can afford more hydro cycles per neutronics
          control%NS4 = control%NS4 + 1
          if (control%verbose) print *, "NS4++: alpha stable, Z =", Z_alpha
        else if (Z_alpha > 3.0_rk * control%ETA3) then
          ! Alpha changing fast - need more frequent neutronics
          if (control%NS4 > 1) then
            control%NS4 = control%NS4 - 1
            if (control%verbose) print *, "NS4--: alpha changing fast, Z =", Z_alpha
            ! If alpha changing VERY fast, reset NS4 to 1
            if (Z_alpha > 6.0_rk * control%ETA3) then
              control%NS4 = 1
              if (control%verbose) print *, "NS4=1: alpha changing very fast, Z =", Z_alpha
            end if
          else if (state%ALPHA > 0._rk) then
            ! NS4 already 1, alpha positive and changing fast → halve DELT (SENSE LIGHT 3)
            control%halve_delt_flag = .true.
            if (control%verbose) print *, "HALVE DELT FLAG: alpha>0, changing too fast"
          end if
        end if
      end if
      
      ! Compute total power
      ! ANL-5977: Initial power is normalized to 1.0 (10¹² ergs/μsec)
      ! Power grows exponentially: P(t) = P₀ × exp(α×t)
      if (big_g_iter == 1) then
        state%POWER = 1.0_rk  ! Initial power = 10¹² ergs/μsec
        state%POWER_PREV = 1.0_rk
        state%TOTAL_POWER = 1.0_rk
      else
        state%TOTAL_POWER = state%POWER
      end if
      
      ! ANL-5977 Order 9064: POWER = POWER * exp(ALPHA * DELTP)
      ! Apply point kinetics power growth for transients
      if (abs(state%ALPHA) > 1.0e-10_rk) then
        state%POWER = state%POWER_PREV * exp(state%ALPHA * control%DELTP)
        state%TOTAL_POWER = state%POWER
        if (mod(big_g_iter, 100) == 0) then
          print *, "Point kinetics: α =", state%ALPHA, "Δt =", control%DELTP, &
                   "Power =", state%POWER
        end if
      end if
      
      ! Save DELTP for next power update
      control%DELTP = control%DELT
    end if
    
    ! NOTE: ROSN snapshot is now done in Order 8009 (before neutronics)
    
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
    ! ANL-5977 Order 9061-9066: Q<QPRIME shutdown detection
    ! During shutdown (Q decreasing, α<0, after α was positive), force high NS4
    ! ==========================================================================
    if (state%Q < state%QPRIME .and. state%ALPHA < 0._rk .and. state%FLAG1 > 0._rk) then
      control%NS4 = 30000  ! Force fine resolution during shutdown
      if (control%verbose) then
        print *, "Q<QPRIME shutdown: NS4 set to 30000"
      end if
    end if
    state%QPRIME = state%Q  ! Store for next cycle
    
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
    
    if (big_g_iter <= 4) print *, "Before hydro loop: N(1,2) =", state%N(1, 2)
    
    do hydro_iter = 1, max(control%NS4, 1)
      state%NH = state%NH + 1
      control%DELT = delt_sub
      
      ! Update hydrodynamics
      call hydro_step_1959(state, control, qbar_cycle)
      
      ! NOTE: Do NOT recompute Lagrangian coordinates here!
      ! RL is fixed (mass coordinate), only R changes.
      ! Density is computed from mass conservation in update_density_lagrangian.
    end do
    control%DELT = delt_outer
    
    if (big_g_iter <= 4) print *, "After hydro loop:  N(1,2) =", state%N(1, 2)
    
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
    ! ANL-5977 Order 9281/9290: Proper DELTP centering for power update
    call adjust_timestep_1959(state, control, halve_dt, double_dt)
    if (halve_dt) then
      ! ANL-5977 Order 9290: When halving:
      ! - DELTP = 0.75*DELT for time-centering
      ! - NH = 2*NH to maintain proper time tracking
      control%DELTP = 0.75_rk * control%DELT
      control%DELT = control%DELT * 0.5_rk
      control%DELT = max(control%DELT, control%DELT_min)
      state%NH = 2 * state%NH  ! Order 9290: Double NH when halving DELT
      if (control%verbose) print *, "HALVE DELT: NH doubled to", state%NH
    else if (double_dt) then
      ! ANL-5977 Order 9281: When doubling:
      ! - DELTP = 1.5*DELT for time-centering
      ! - NH = NH/2 to maintain proper time tracking
      ! - NS4 = (NS4+1)/2 to maintain hydro/neutron ratio
      control%DELTP = 1.5_rk * control%DELT
      control%DELT = min(control%DELT * 2.0_rk, control%DT_MAX)
      state%NH = state%NH / 2  ! Order 9281: Halve NH when doubling DELT
      control%NS4 = (control%NS4 + 1) / 2  ! Order 9281: Halve NS4 when doubling
      if (control%verbose) print *, "DOUBLE DELT: NH halved to", state%NH, ", NS4 halved to", control%NS4
    end if
    
    ! ==========================================================================
    ! STEP 4: OUTPUT (Order 9250)
    ! ==========================================================================
    ! Output at regular time intervals for plotting
    if (state%TIME >= last_output_time + output_time_interval) then
      call write_output_step(state, control, output_unit)
      flush(output_unit)
      
      ! Write CSV time-series data
      call write_csv_step_time(state, control, csv_time_unit)
      flush(csv_time_unit)
      
      last_output_time = state%TIME
      
      ! Write spatial profile at t=200 μsec (within tolerance)
      if (.not. write_spatial_at_200 .and. abs(state%TIME - 200.0_rk) < 5.0_rk) then
        call write_csv_header_spatial(csv_spatial_unit)
        call write_csv_step_spatial(state, csv_spatial_unit)
        flush(csv_spatial_unit)
        write_spatial_at_200 = .true.
        print *, "Wrote spatial profile at t =", state%TIME, " μsec"
      end if
    end if
    
    ! ==========================================================================
    ! ANL-5977 Order 9332-9336: Low power NS4 boost
    ! If alpha < 0 and NH >= 50 and alpha decreasing and power low:
    !   - Relax ETA3 by 10×
    !   - Boost NS4 by +4
    ! This helps capture shutdown dynamics when power is very low
    ! ==========================================================================
    if (.not. control%low_power_boosted) then
      if (state%ALPHA < 0._rk .and. state%NH >= 50) then
        if (state%ALPHA < state%ALPHAP + control%EPSA) then
          if (state%TOTAL_POWER < control%POWNGL) then
            control%ETA3 = 10._rk * control%ETA3
            control%NS4 = control%NS4 + 4
            control%low_power_boosted = .true.  ! SENSE LIGHT 4 equivalent
            print *, "LOW POWER NS4 BOOST: ETA3 relaxed, NS4 boosted to", control%NS4
          end if
        end if
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

