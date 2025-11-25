! ##############################################################################
! io_1959.f90
!
! 1959 AX-1 Input/Output Module
!
! Based on: ANL-5977 Input format specification and output tables
!
! Input format follows ANL-5977 deck structure:
!   - Control parameters (eigenmode, time steps, convergence)
!   - Material properties (cross sections, EOS, specific heat)
!   - Geometry and initial conditions
!
! Output format replicates ANL-5977 tables (pages 89-103):
!   TIME, QP, POWER, ALPHA, DELT, W, etc.
!
! ##############################################################################

module io_1959
  use kinds
  use types_1959
  implicit none

  private
  public :: read_input_1959, write_output_header, write_output_step
  public :: write_csv_header_time, write_csv_step_time
  public :: write_csv_header_spatial, write_csv_step_spatial
  public :: write_summary, echo_input

contains

  ! ===========================================================================
  ! Read input deck (simplified 1959 format)
  ! ===========================================================================
  subroutine read_input_1959(filename, st, ctrl)
    character(len=*), intent(in) :: filename
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(inout) :: ctrl
    
    integer :: unit, ios, i, g, gp
    character(len=256) :: line
    
    unit = 10
    open(unit=unit, file=trim(filename), status='old', action='read', iostat=ios)
    if (ios /= 0) then
      print *, "ERROR: Cannot open input file: ", trim(filename)
      stop
    end if
    
    print *, "========================================="
    print *, "READING INPUT: ", trim(filename)
    print *, "========================================="
    
    ! Read control parameters
    call read_control_block(unit, ctrl)
    
    ! Read geometry
    call read_geometry_block(unit, st)
    
    ! Read materials
    call read_materials_block(unit, st)
    
    ! Initialize arrays
    call initialize_state(st, ctrl)
    
    close(unit)
    
    print *, "Input read successfully."
    print *, "========================================="
    
  end subroutine read_input_1959

  ! ===========================================================================
  ! Read control parameters
  ! ===========================================================================
  subroutine read_control_block(unit, ctrl)
    integer, intent(in) :: unit
    type(Control_1959), intent(inout) :: ctrl
    
    character(len=256) :: line
    
    read(unit, '(A)') line  ! Skip header "CONTROL"
    
    ! Eigenvalue mode (string)
    read(unit, '(A)') ctrl%eigmode
    ctrl%eigmode = trim(adjustl(ctrl%eigmode))
    
    ! ANL-5977: ICNTRL and ALPHA_TARGET for geometry fitting
    ! ICNTRL=0: Calculate alpha from geometry
    ! ICNTRL=1: Fit geometry to achieve target alpha (Geneva 10 mode)
    read(unit, *) ctrl%ICNTRL
    read(unit, *) ctrl%ALPHA_TARGET
    ctrl%EPSR = 1.0e-4_rk
    
    print *, "ICNTRL =", ctrl%ICNTRL
    print *, "ALPHA_TARGET =", ctrl%ALPHA_TARGET, " μsec⁻¹"
    
    ! Set KCNTRL=1 for alpha mode (k-calc first, then alpha mode)
    ! This is the standard Geneva 10 transient mode (ANL-5977)
    if (trim(ctrl%eigmode) == "alpha") then
      ctrl%KCNTRL = 1
      ctrl%KCALC = 1  ! Start with k-calc
    else
      ctrl%KCNTRL = 0
      ctrl%KCALC = 1  ! K-mode only
    end if
    
    ! Time parameters
    read(unit, *) ctrl%DELT
    read(unit, *) ctrl%DT_MAX
    read(unit, *) ctrl%T_END
    
    ! Stability parameters
    read(unit, *) ctrl%CSC
    read(unit, *) ctrl%CVP
    read(unit, *) ctrl%W_LIMIT
    
    ! Convergence
    read(unit, *) ctrl%EPSA
    read(unit, *) ctrl%EPSK
    
    ! Minimum time step
    read(unit, *) ctrl%DELT_min
    
    ! Hydro subcycling
    read(unit, *) ctrl%HYDRO_PER_NEUT
    ctrl%NS4 = ctrl%HYDRO_PER_NEUT
    
    print *, "Control parameters read."
    
  end subroutine read_control_block

  ! ===========================================================================
  ! Read geometry
  ! ===========================================================================
  subroutine read_geometry_block(unit, st)
    integer, intent(in) :: unit
    type(State_1959), intent(inout) :: st
    
    character(len=256) :: line
    integer :: i, nzones
    
    read(unit, '(A)') line  ! Skip header
    
    ! Number of zones
    read(unit, *) nzones
    st%IMAX = nzones
    
    ! Zone boundaries (radii in cm)
    ! R(I) is outer boundary of zone I. We read IMAX+1 values: R(0) to R(IMAX)
    ! where R(0)=0 is the center and R(IMAX) is the outer boundary
    read(unit, '(A)') line  ! Skip "RADII"
    do i = 0, st%IMAX
      read(unit, *) st%R(i)
    end do
    
    ! Material assignment per zone
    read(unit, '(A)') line  ! Skip "MATERIALS"
    do i = 2, st%IMAX
      read(unit, *) st%K(i)
    end do
    
    ! Initial densities (g/cc)
    read(unit, '(A)') line  ! Skip "DENSITIES"
    do i = 2, st%IMAX
      read(unit, *) st%RO(i)
    end do
    
    ! Initial temperatures (keV)
    read(unit, '(A)') line  ! Skip "TEMPERATURES"
    do i = 2, st%IMAX
      read(unit, *) st%THETA(i)
    end do
    
    ! Relative fission density F(I)
    read(unit, '(A)') line
    if (trim(adjustl(line)) /= 'FISSION_DENSITIES') then
      print *, 'ERROR: Expected FISSION_DENSITIES block in geometry section.'
      print *, 'Found: ', trim(adjustl(line))
      stop 1
    end if
    do i = 2, st%IMAX
      read(unit, *) st%FREL(i)
    end do
    
    print *, "FISSION_DENSITIES (first 15 zones):"
    do i = 2, min(st%IMAX, 15)
      print '(I5,ES14.6)', i, st%FREL(i)
    end do
    
    print *, "Geometry read: ", st%IMAX, " zones"
    
  end subroutine read_geometry_block

  ! ===========================================================================
  ! Read material properties
  ! ===========================================================================
  subroutine read_materials_block(unit, st)
    integer, intent(in) :: unit
    type(State_1959), intent(inout) :: st
    
    character(len=256) :: line
    integer :: imat, g, gp, nmat
    
    read(unit, '(A)') line  ! Skip header
    
    ! Number of materials
    read(unit, *) nmat
    st%Nmat = nmat
    
    ! Allocate materials
    if (allocated(st%mat)) deallocate(st%mat)
    allocate(st%mat(nmat))
    
    do imat = 1, nmat
      read(unit, '(A)') line  ! Material header
      
      ! Number of groups
      read(unit, *) st%mat(imat)%num_groups
      st%IG = st%mat(imat)%num_groups
      
      ! Fission cross sections (barns)
      read(unit, '(A)') line  ! Skip "NU_SIG_F"
      do g = 1, st%IG
        read(unit, *) st%mat(imat)%nu_sig_f(g)
      end do
      
      ! Scattering matrix (barns)
      read(unit, '(A)') line  ! Skip "SIG_S"
      do g = 1, st%IG
        read(unit, *) (st%mat(imat)%sig_s(gp, g), gp = 1, st%IG)
      end do
      
      ! Transport cross section (optional, if not provided use default)
      read(unit, '(A)') line
      if (trim(adjustl(line)) == 'SIG_TR') then
        do g = 1, st%IG
          read(unit, *) st%mat(imat)%sig_tr(g)
        end do
        read(unit, '(A)') line  ! Read next header for CHI
      end if
      
      ! Fission spectrum
      ! line already contains "CHI" from above
      if (trim(adjustl(line)) /= 'CHI') then
        read(unit, '(A)') line  ! Skip "CHI" if not already read
      end if
      do g = 1, st%IG
        read(unit, *) st%mat(imat)%chi(g)
      end do
      
      ! EOS parameters
      read(unit, '(A)') line  ! Skip "EOS"
      read(unit, *) st%mat(imat)%ALPHA
      read(unit, *) st%mat(imat)%BETA
      read(unit, *) st%mat(imat)%TAU
      
      ! Specific heat
      read(unit, '(A)') line  ! Skip "CV"
      read(unit, *) st%mat(imat)%ACV
      read(unit, *) st%mat(imat)%BCV
      
      ! Conversion factor
      read(unit, *) st%mat(imat)%ROLAB
      
      ! Optional: Neutron velocity (defaults to 169.5 cm/μsec for fast neutrons)
      ! ANL-5977: V(IG) = 1/VLOC where VLOC is inverse velocity
      ! For 1 MeV neutrons: v ≈ 1.4e9 cm/sec = 1.4e3 cm/μsec
      ! But ANL-5977 uses V = 169.5 cm/μsec (appears to be scaled units)
      do g = 1, st%IG
        st%mat(imat)%V(g) = 169.5_rk  ! Default from ANL-5977 sample problem
      end do
    end do
    
    print *, "Materials read: ", nmat, " materials,", st%IG, " groups"
    print *, "  Neutron velocity V(1) =", st%mat(1)%V(1), " cm/μsec"
    
  end subroutine read_materials_block

  ! ===========================================================================
  ! Initialize state arrays
  ! ===========================================================================
  subroutine initialize_state(st, ctrl)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    
    integer :: i, imat, g
    real(rk) :: r_ratio
    
    ! Initialize velocities to zero
    st%U = 0._rk
    
    ! Compute neutronic densities from hydrodynamic densities
    ! RHO = RO / ROLAB where RO is g/cm³ and ROLAB is 10⁻²⁴ g/atom
    ! Result: RHO in 10²⁴ atoms/cm³
    do i = 2, st%IMAX
      imat = st%K(i)
      st%RHO(i) = st%RO(i) / st%mat(imat)%ROLAB
    end do
    print *, "Neutronic density RHO(2) =", st%RHO(2), " (10^24 atoms/cm³)"
    print *, "  RO(2) =", st%RO(2), " g/cm³"
    print *, "  ROLAB =", st%mat(st%K(2))%ROLAB, " (10^-24 g/atom)"
    
    ! Compute internal energy from temperature
    do i = 2, st%IMAX
      imat = st%K(i)
      st%HE(i) = st%mat(imat)%ACV * st%THETA(i) + &
                 0.5_rk * st%mat(imat)%BCV * st%THETA(i)**2
    end do
    
    ! Compute initial pressure
    do i = 2, st%IMAX
      imat = st%K(i)
      st%HP(i) = st%mat(imat)%ALPHA * st%RO(i) + &
                 st%mat(imat)%BETA * st%THETA(i) + &
                 st%mat(imat)%TAU
      if (st%HP(i) < 0._rk) st%HP(i) = 0._rk
    end do
    st%ROSN = st%RO
    st%RO_PREV = st%RO
    st%HP_PREV = st%HP
    
    ! Initialize flux with cosine shape (physical for reactor)
    ! Flux should peak at center and decrease towards edge
    do i = 2, st%IMAX
      ! Cosine shape: N(r) = cos(π/2 * r/R_max) for r < R_core
      r_ratio = st%R(i) / st%R(st%IMAX)
      do g = 1, st%IG
        st%N(g, i) = max(0.1_rk, cos(1.57079632679_rk * r_ratio))
      end do
    end do
    
    ! Initialize time
    st%TIME = 0._rk
    st%NH = 0
    
    ! Initialize eigenvalues
    st%ALPHA = 0._rk
    st%AKEFF = 1._rk
    
    print *, "State initialized."
    
  end subroutine initialize_state

  ! ===========================================================================
  ! Echo input to output file
  ! ===========================================================================
  subroutine echo_input(st, ctrl, unit)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(in) :: ctrl
    integer, intent(in) :: unit
    
    integer :: i, g, imat
    
    write(unit, '(A)') "========================================="
    write(unit, '(A)') "1959 AX-1 INPUT ECHO"
    write(unit, '(A)') "========================================="
    write(unit, *)
    
    write(unit, '(A)') "CONTROL PARAMETERS:"
    write(unit, '(A,A)') "  Eigenmode:         ", trim(ctrl%eigmode)
    write(unit, '(A,ES12.5,A)') "  Initial Δt:        ", ctrl%DELT, " μsec"
    write(unit, '(A,ES12.5,A)') "  Maximum Δt:        ", ctrl%DT_MAX, " μsec"
    write(unit, '(A,ES12.5,A)') "  End time:          ", ctrl%T_END, " μsec"
    write(unit, '(A,F8.3)') "  CSC (Courant):     ", ctrl%CSC
    write(unit, '(A,F8.3)') "  CVP (Viscosity):   ", ctrl%CVP
    write(unit, '(A,F8.3)') "  W limit:           ", ctrl%W_LIMIT
    write(unit, '(A,I5)') "  Hydro/Neutron:     ", ctrl%HYDRO_PER_NEUT
    write(unit, *)
    
    write(unit, '(A)') "GEOMETRY:"
    write(unit, '(A,I5,A)') "  Number of zones:   ", st%IMAX
    write(unit, '(A)') "  Radii (cm):"
    do i = 1, st%IMAX + 1
      write(unit, '(I5,ES14.6)') i, st%R(i)
    end do
    write(unit, *)
    
    write(unit, '(A)') "INITIAL CONDITIONS:"
    write(unit, '(A)') "  Zone  Mat    Density      Temp"
    write(unit, '(A)') "              (g/cc)       (keV)"
    do i = 2, st%IMAX
      write(unit, '(I5,I5,2ES14.6)') i, st%K(i), st%RO(i), st%THETA(i)
    end do
    write(unit, *)
    
    write(unit, '(A,I3,A)') "MATERIALS: ", st%Nmat, " materials"
    do imat = 1, st%Nmat
      write(unit, '(A,I3)') "Material ", imat
      write(unit, '(A,I3)') "  Groups: ", st%mat(imat)%num_groups
      write(unit, '(A)') "  EOS: P = ALPHA*rho + BETA*theta + TAU"
      write(unit, '(A,ES12.5)') "    ALPHA = ", st%mat(imat)%ALPHA
      write(unit, '(A,ES12.5)') "    BETA  = ", st%mat(imat)%BETA
      write(unit, '(A,ES12.5)') "    TAU   = ", st%mat(imat)%TAU
      write(unit, '(A)') "  Specific heat: Cv = ACV + BCV*theta"
      write(unit, '(A,ES12.5)') "    ACV   = ", st%mat(imat)%ACV
      write(unit, '(A,ES12.5)') "    BCV   = ", st%mat(imat)%BCV
      write(unit, *)
    end do
    
    write(unit, '(A)') "========================================="
    write(unit, *)
    
  end subroutine echo_input

  ! ===========================================================================
  ! Write output header
  ! ===========================================================================
  subroutine write_output_header(unit)
    integer, intent(in) :: unit
    
    write(unit, '(A)') "========================================="
    write(unit, '(A)') "1959 AX-1 TRANSIENT RESULTS"
    write(unit, '(A)') "========================================="
    write(unit, *)
    write(unit, '(A)') "  TIME      QP        POWER     ALPHA      K-EFF      DELT       W     R_MAX"
    write(unit, '(A)') " (μsec)  (10¹² erg) (arb)    (μsec⁻¹)              (μsec)             (cm)"
    write(unit, '(A)') "-----------------------------------------------------------------------------------------"
    
  end subroutine write_output_header

  ! ===========================================================================
  ! Write output for current time step
  ! ===========================================================================
  subroutine write_output_step(st, ctrl, unit)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(in) :: ctrl
    integer, intent(in) :: unit
    real(rk), parameter :: four_pi_over_three = 4.1887902047863909_rk
    real(rk) :: qp_print
    
    qp_print = four_pi_over_three * st%Q
    
    write(unit, '(F9.6,2ES12.4,F12.6,F10.6,ES12.4,F8.4,F10.4)') &
      st%TIME, qp_print, st%TOTAL_POWER, st%ALPHA, st%AKEFF, &
      ctrl%DELT, st%W, st%R(st%IMAX)
    
  end subroutine write_output_step

  ! ===========================================================================
  ! Write summary statistics
  ! ===========================================================================
  subroutine write_summary(st, ctrl, unit)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(in) :: ctrl
    integer, intent(in) :: unit
    
    write(unit, *)
    write(unit, '(A)') "========================================="
    write(unit, '(A)') "SIMULATION SUMMARY"
    write(unit, '(A)') "========================================="
    write(unit, '(A,F12.6,A)') "Final time:              ", st%TIME, " μsec"
    write(unit, '(A,I10)') "Hydro cycles:            ", st%NH
    write(unit, '(A,I10)') "Total S4 iterations:     ", st%AITCT
    write(unit, '(A,ES14.6)') "Final alpha:             ", st%ALPHA
    write(unit, '(A,F12.6)') "Final k-eff:             ", st%AKEFF
    write(unit, '(A,ES14.6,A)') "Final energy:            ", &
        4.1887902047863909_rk * st%Q, " × 10¹² ergs"
    write(unit, '(A,ES14.6,A)') "Final KE:                ", st%TOTKE, " × 10¹² ergs"
    write(unit, '(A,ES14.6,A)') "Final IE:                ", st%TOTIEN, " × 10¹² ergs"
    write(unit, '(A,ES14.6)')    "Energy balance CHECK:    ", st%CHECK
    write(unit, '(A,F12.4,A)') "Final radius:            ", st%R(st%IMAX), " cm"
    write(unit, '(A,F12.4,A)') "Final max temp:          ", maxval(st%THETA(2:st%IMAX)), " keV"
    write(unit, '(A,ES14.6,A)') "Final max pressure:      ", maxval(st%HP(2:st%IMAX)), " megabars"
    write(unit, '(A)') "========================================="
    
  end subroutine write_summary

  ! ===========================================================================
  ! Write CSV header for time-series data
  ! Format matches reference data: geneve10_time_evolution.csv
  ! ===========================================================================
  subroutine write_csv_header_time(unit)
    integer, intent(in) :: unit
    
    write(unit, '(A)') "time_microsec,QP_1e12_erg,power_relative,alpha_1_microsec,delt_microsec," // &
                       "W_dimensionless,QBAR_1e12erg_per_g,DELQ_1e12_erg,TOTKE_1e12_erg," // &
                       "TOTIEN_1e12_erg,W_cfl,W_visc,NS4,DTMAX_microsec,FBAR_weighted," // &
                       "FBAR_geom,W_limit_flag,alpha_dt_flag,CHECK,ERRLCL"
    
  end subroutine write_csv_header_time

  ! ===========================================================================
  ! Write CSV data for time-series (one time step)
  ! Format matches reference data: geneve10_time_evolution.csv
  ! ===========================================================================
  subroutine write_csv_step_time(st, ctrl, unit)
    type(State_1959), intent(in) :: st
    type(Control_1959), intent(in) :: ctrl
    integer, intent(in) :: unit
    real(rk), parameter :: four_pi_over_three = 4.1887902047863909_rk
    real(rk) :: qp_print, delq_print, totke_print, totien_print
    real(rk) :: qbar_print, alpha_dt
    integer :: w_flag, alpha_flag
    
    qp_print   = four_pi_over_three * st%Q
    delq_print = four_pi_over_three * st%DELQ_TOTAL
    totke_print = four_pi_over_three * st%TOTKE
    totien_print = four_pi_over_three * st%TOTIEN
    qbar_print = st%QBAR_LAST
    alpha_dt = st%ALPHA * ctrl%DELT
    w_flag = merge(1, 0, st%W > ctrl%W_LIMIT)
    alpha_flag = merge(1, 0, alpha_dt > 4._rk * ctrl%ETA2)
    
    ! CSV format with diagnostics
    write(unit, '(ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,' // &
                'ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,I0,A,' // &
                'ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6)') &
      st%TIME, ',', &
      qp_print, ',', &
      st%TOTAL_POWER, ',', &
      st%ALPHA, ',', &
      ctrl%DELT, ',', &
      st%W, ',', &
      qbar_print, ',', &
      delq_print, ',', &
      totke_print, ',', &
      totien_print, ',', &
      st%W_CFL, ',', &
      st%W_VISC, ',', &
      ctrl%NS4, ',', &
      ctrl%DT_MAX, ',', &
      st%FBAR, ',', &
      st%FBAR_GEOM, ',', &
      real(w_flag, rk), ',', &
      real(alpha_flag, rk), ',', &
      st%CHECK, ',', &
      st%ERRLCL
    
  end subroutine write_csv_step_time

  ! ===========================================================================
  ! Write CSV header for spatial profile data
  ! Format matches reference data: geneve10_spatial_t200.csv
  ! ===========================================================================
  subroutine write_csv_header_spatial(unit)
    integer, intent(in) :: unit
    
    write(unit, '(A)') "zone_index,density_g_cm3,radius_cm,velocity_cm_microsec," // &
                       "pressure_megabars,internal_energy_1e12_erg_g,temperature_keV"
    
  end subroutine write_csv_header_spatial

  ! ===========================================================================
  ! Write CSV data for spatial profile (all zones at current time)
  ! Format matches reference data: geneve10_spatial_t200.csv
  ! ===========================================================================
  subroutine write_csv_step_spatial(st, unit)
    type(State_1959), intent(in) :: st
    integer, intent(in) :: unit
    integer :: i
    
    ! Write data for each zone
    do i = 2, st%IMAX
      write(unit, '(I5,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6)') &
        i, ',', &
        st%RO(i), ',', &     ! RO = mass density (g/cm³), not RHO = atomic density
        st%R(i), ',', &
        st%U(i), ',', &
        st%HP(i), ',', &
        st%HE(i), ',', &
        st%THETA(i)
    end do
    
  end subroutine write_csv_step_spatial

end module io_1959

