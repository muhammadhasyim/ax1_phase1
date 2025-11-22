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
    read(unit, '(A)') line  ! Skip "RADII"
    do i = 1, st%IMAX + 1
      read(unit, *) st%R(i)
    end do
    st%R(0) = 0._rk  ! Center always at r=0
    st%R(1) = 0._rk
    
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
      
      ! Fission spectrum
      read(unit, '(A)') line  ! Skip "CHI"
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
    end do
    
    print *, "Materials read: ", nmat, " materials,", st%IG, " groups"
    
  end subroutine read_materials_block

  ! ===========================================================================
  ! Initialize state arrays
  ! ===========================================================================
  subroutine initialize_state(st, ctrl)
    type(State_1959), intent(inout) :: st
    type(Control_1959), intent(in) :: ctrl
    
    integer :: i, imat
    
    ! Initialize velocities to zero
    st%U = 0._rk
    
    ! Compute neutronic densities from hydrodynamic densities
    do i = 2, st%IMAX
      imat = st%K(i)
      st%RHO(i) = st%RO(i) / st%mat(imat)%ROLAB
    end do
    
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
    
    ! Initialize flux to flat guess
    st%N = 1._rk
    
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
    
    write(unit, '(F9.6,2ES12.4,F12.6,F10.6,ES12.4,F8.4,F10.4)') &
      st%TIME, st%Q, st%TOTAL_POWER, st%ALPHA, st%AKEFF, &
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
    write(unit, '(A,ES14.6,A)') "Final energy:            ", st%Q, " × 10¹² ergs"
    write(unit, '(A,ES14.6,A)') "Final KE:                ", st%TOTKE, " × 10¹² ergs"
    write(unit, '(A,ES14.6,A)') "Final IE:                ", st%TOTIEN, " × 10¹² ergs"
    write(unit, '(A,F12.4,A)') "Final radius:            ", st%R(st%IMAX), " cm"
    write(unit, '(A,F12.4,A)') "Final max temp:          ", maxval(st%THETA(2:st%IMAX)), " keV"
    write(unit, '(A,ES14.6,A)') "Final max pressure:      ", maxval(st%HP(2:st%IMAX)), " megabars"
    write(unit, '(A)') "========================================="
    
  end subroutine write_summary

end module io_1959

