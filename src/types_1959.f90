! ##############################################################################
! types_1959.f90
!
! 1959 AX-1 Data Structures - Faithful Reproduction of ANL-5977
!
! Based on: ANL-5977, "AX-1, A Computing Program for Coupled Neutronics-
!           Hydrodynamics Calculations on the IBM-704", H. H. Hummel, et al.,
!           January 1959
!
! This module implements the EXACT data structures from the 1959 implementation:
!   - NO delayed neutrons (explicitly ignored in 1959)
!   - NO temperature-dependent cross sections
!   - Linear equation of state ONLY
!   - S4 discrete ordinates ONLY
!   - Von Neumann-Richtmyer artificial viscosity
!
! All variable names match ANL-5977 Fortran listing where possible.
! ##############################################################################

module types_1959
  use kinds
  implicit none

  ! ===========================================================================
  ! Constants from 1959 implementation
  ! ===========================================================================
  integer, parameter :: GMAX_1959 = 7       ! Maximum energy groups
  integer, parameter :: SHELLMAX_1959 = 256 ! Maximum spatial zones (IMAX)
  integer, parameter :: MU_S4 = 2           ! S4 has 2 directions per hemisphere

  ! ===========================================================================
  ! Material_1959: Nuclear and thermodynamic properties
  ! ===========================================================================
  type :: Material_1959
     ! -----------------------------------------------------------------------
     ! Neutron cross sections (temperature-INDEPENDENT)
     ! -----------------------------------------------------------------------
     integer :: num_groups = 6                   ! Standard 6-group structure
     real(rk) :: sig_f(GMAX_1959) = 0._rk       ! Fission cross section (barns)
     real(rk) :: nu_sig_f(GMAX_1959) = 0._rk    ! ν·σ_f (barns)
     real(rk) :: sig_s(GMAX_1959, GMAX_1959) = 0._rk  ! Scattering g'→g (barns)
     real(rk) :: chi(GMAX_1959) = 0._rk         ! Fission spectrum
     
     ! -----------------------------------------------------------------------
     ! Equation of State: P_H = ALPHA * rho + BETA * theta + TAU
     ! (ANL-5977 Order 6833, line 1413)
     ! -----------------------------------------------------------------------
     real(rk) :: ALPHA = 0._rk   ! EOS constant (cm²/μsec²)
     real(rk) :: BETA = 0._rk    ! EOS constant (g/(cm·μsec²·keV))
     real(rk) :: TAU = 0._rk     ! EOS constant (megabars)
     
     ! -----------------------------------------------------------------------
     ! Specific heat: C_v = ACV + BCV * theta
     ! (ANL-5977 Order 6835, line 1415)
     ! -----------------------------------------------------------------------
     real(rk) :: ACV = 1._rk     ! Specific heat constant (cm²/(μsec²·keV))
     real(rk) :: BCV = 0._rk     ! Specific heat constant (cm²/(μsec²·keV²))
     
     ! -----------------------------------------------------------------------
     ! Conversion factor: ROLAB = grams/atom × 10²⁴
     ! (ANL-5977 Sheet 4, line 847)
     ! Converts between neutronics density (atoms/cc × 10⁻²⁴) and
     ! hydrodynamic density (g/cc)
     ! -----------------------------------------------------------------------
     real(rk) :: ROLAB = 1._rk   ! Mass per atom × 10²⁴ (g)
  end type Material_1959

  ! ===========================================================================
  ! Control_1959: Convergence criteria and time stepping
  ! ===========================================================================
  type :: Control_1959
     ! -----------------------------------------------------------------------
     ! Eigenvalue mode control
     ! -----------------------------------------------------------------------
     character(len=8) :: eigmode = "alpha"   ! "alpha" or "k"
     integer :: ICNTRL = 0                   ! 0: alpha specified, 1: adjust R
     integer :: KCNTRL = 0                   ! 0: alpha mode, 1: k-eff mode
     
     ! -----------------------------------------------------------------------
     ! Convergence criteria (ANL-5977 symbols)
     ! -----------------------------------------------------------------------
     real(rk) :: EPSA = 1.0e-5_rk   ! Alpha convergence (μsec⁻¹)
     real(rk) :: EPSK = 1.0e-5_rk   ! K-eff convergence
     real(rk) :: EPSR = 1.0e-3_rk   ! Radius convergence (cm)
     real(rk) :: ETA1 = 1.0e-3_rk   ! Pressure iteration convergence
     real(rk) :: ETA2 = 0.1_rk      ! Power change control
     real(rk) :: ETA3 = 0.05_rk     ! NS4 adjustment control
     real(rk) :: EPSI = 1.0e-6_rk   ! Small pressure (megabars)
     
     ! -----------------------------------------------------------------------
     ! Stability and time stepping (ANL-5977 Appendix C)
     ! -----------------------------------------------------------------------
     real(rk) :: CSC = 2.0_rk       ! Courant stability constant ≈ γ(γ-1)
     real(rk) :: CVP = 1.7_rk       ! Viscous pressure coefficient (typically 1.5-2.0)
     
     ! -----------------------------------------------------------------------
     ! Time control
     ! -----------------------------------------------------------------------
     real(rk) :: DELT = 1.0e-3_rk   ! Time step (μsec)
     real(rk) :: DELTP = 1.0e-3_rk  ! Previous time step for velocity
     real(rk) :: DELT_min = 1.0e-8_rk  ! Minimum time step
     real(rk) :: DELT_max = 1.0_rk     ! Maximum time step
     real(rk) :: t_end = 1.0_rk        ! End time (μsec)
     
     ! -----------------------------------------------------------------------
     ! Neutronics frequency control (ANL-5977 Order numbers ~9014-9050)
     ! -----------------------------------------------------------------------
     integer :: NS4 = 1             ! Hydro cycles per neutronics calculation
     integer :: NS4R = 0            ! Hydro cycle counter
     integer :: NLMax = 10          ! Max hydro cycles before DELT doubling
     
     ! -----------------------------------------------------------------------
     ! VJ-OK-1 test parameters (ANL-5977 Appendix A)
     ! -----------------------------------------------------------------------
     real(rk) :: VJ = 0._rk         ! Jankus reactivity coefficient
     real(rk) :: OK1 = 0.01_rk      ! VJ-OK-1 threshold
     real(rk) :: PTEST = 0._rk      ! Pressure test threshold (megabars)
     
     ! -----------------------------------------------------------------------
     ! Iteration limits
     ! -----------------------------------------------------------------------
     integer :: max_source_iter = 200   ! Maximum source iterations
     integer :: max_pressure_iter = 50  ! Maximum pressure iterations (modified Euler)
     
     ! -----------------------------------------------------------------------
     ! Output control
     ! -----------------------------------------------------------------------
     integer :: output_freq = 1     ! Output every N neutronics cycles
     character(len=256) :: output_file = "ax1_1959.out"
     logical :: print_input = .true.  ! Print input echo
  end type Control_1959

  ! ===========================================================================
  ! State_1959: System state variables
  ! ===========================================================================
  type :: State_1959
     ! -----------------------------------------------------------------------
     ! Spatial mesh
     ! -----------------------------------------------------------------------
     integer :: IMAX = 1                           ! Number of zones
     real(rk) :: R(0:SHELLMAX_1959) = 0._rk       ! Radii (cm), R(1)=0 always
     real(rk) :: RL(0:SHELLMAX_1959) = 0._rk      ! Lagrangian coordinates
     
     ! -----------------------------------------------------------------------
     ! Hydrodynamic variables
     ! -----------------------------------------------------------------------
     real(rk) :: U(0:SHELLMAX_1959) = 0._rk       ! Velocities (cm/μsec)
     real(rk) :: RO(SHELLMAX_1959) = 0._rk        ! Hydrodynamic density (g/cc)
     real(rk) :: RHO(SHELLMAX_1959) = 0._rk       ! Neutronic density (atoms/cc × 10⁻²⁴)
     real(rk) :: HP(0:SHELLMAX_1959) = 0._rk      ! Total pressure P_H + P_v (megabars)
     real(rk) :: THETA(SHELLMAX_1959) = 0._rk     ! Temperature (keV)
     real(rk) :: HE(SHELLMAX_1959) = 0._rk        ! Specific internal energy (10¹² ergs/g)
     real(rk) :: HMASS(SHELLMAX_1959) = 0._rk     ! Zone mass (factor 4π/3 omitted)
     
     ! -----------------------------------------------------------------------
     ! Material assignment
     ! -----------------------------------------------------------------------
     integer :: K(SHELLMAX_1959) = 1               ! Material label per zone
     integer :: Nmat = 0                           ! Number of materials
     type(Material_1959), allocatable :: mat(:)    ! Material properties
     
     ! -----------------------------------------------------------------------
     ! Neutronics
     ! -----------------------------------------------------------------------
     integer :: IG = 6                             ! Number of energy groups
     real(rk) :: N(GMAX_1959, SHELLMAX_1959) = 0._rk  ! Neutron flux (group, zone)
     real(rk) :: ENN(SHELLMAX_1959, 5) = 0._rk    ! Angular flux components (S4)
     
     ! S4 quadrature (fixed for 1959)
     real(rk) :: MU_S4(MU_S4) = [0.2958759_rk, 0.9082483_rk]  ! Angular directions
     real(rk) :: W_S4(MU_S4) = [1._rk/3._rk, 1._rk/3._rk]     ! Weights
     
     ! -----------------------------------------------------------------------
     ! S4 constants (ANL-5977 lines 1090-1104)
     ! -----------------------------------------------------------------------
     real(rk) :: AM(5) = [1.0_rk, 2._rk/3._rk, 1._rk/6._rk, 1._rk/3._rk, 5._rk/6._rk]
     real(rk) :: AMBAR(5) = [0.0_rk, 5._rk/6._rk, 1._rk/3._rk, 1._rk/6._rk, 2._rk/3._rk]
     real(rk) :: B_CONST(5) = [0.0_rk, 5._rk/3._rk, 11._rk/3._rk, 11._rk/3._rk, 5._rk/3._rk]
     
     ! -----------------------------------------------------------------------
     ! Eigenvalues and power
     ! -----------------------------------------------------------------------
     real(rk) :: ALPHA = 0._rk      ! Inverse period (μsec⁻¹)
     real(rk) :: ALPHAP = 0._rk     ! Previous alpha
     real(rk) :: ALPHAO = 0._rk     ! Alpha for VJ-OK-1 test
     real(rk) :: AKEFF = 1._rk      ! k-effective
     real(rk) :: AK(4) = 1._rk      ! k-eff iteration array
     real(rk) :: POWER = 0._rk      ! Power (arbitrary units)
     real(rk) :: Q = 0._rk          ! Total energy (10¹² ergs, lacking 4π/3)
     real(rk) :: QPRIME = 0._rk     ! Previous Q
     
     ! -----------------------------------------------------------------------
     ! Energetics
     ! -----------------------------------------------------------------------
     real(rk) :: TOTKE = 0._rk      ! Total kinetic energy (10¹² ergs)
     real(rk) :: TOTIEN = 0._rk     ! Total internal energy (10¹² ergs)
     real(rk) :: FBAR = 1._rk       ! Average fission rate
     
     ! -----------------------------------------------------------------------
     ! Time
     ! -----------------------------------------------------------------------
     real(rk) :: TIME = 0._rk       ! Current time (μsec)
     integer :: NH = 0              ! Hydro cycle counter
     
     ! -----------------------------------------------------------------------
     ! Stability and diagnostics
     ! -----------------------------------------------------------------------
     real(rk) :: W = 0._rk          ! Stability function
     real(rk) :: ERRLCL = 0._rk     ! Local energy error
     real(rk) :: CHECK = 0._rk      ! Energy balance check
     
     ! -----------------------------------------------------------------------
     ! Iteration counters
     ! -----------------------------------------------------------------------
     integer :: AITCT = 0           ! Total S4 iterations
  end type State_1959

  ! ===========================================================================
  ! Utility type for S4 transport sweep
  ! ===========================================================================
  type :: S4Transport
     real(rk) :: H(SHELLMAX_1959) = 0._rk         ! Helper array for transport
     real(rk) :: SO(SHELLMAX_1959) = 0._rk        ! Source array
     real(rk) :: T(SHELLMAX_1959) = 0._rk         ! Volume array (1/3 * ΔR³)
     real(rk) :: WN(SHELLMAX_1959) = 0._rk        ! Weight function
     real(rk) :: FE(SHELLMAX_1959) = 0._rk        ! Fission rate
     real(rk) :: FEP(SHELLMAX_1959) = 0._rk       ! Previous fission rate
  end type S4Transport

contains

  ! ===========================================================================
  ! Initialize State_1959 with default values
  ! ===========================================================================
  subroutine init_state_1959(st, nshell, ngroups, nmaterials)
    type(State_1959), intent(inout) :: st
    integer, intent(in) :: nshell, ngroups, nmaterials
    
    st%IMAX = nshell
    st%IG = ngroups
    st%Nmat = nmaterials
    
    ! Allocate material array
    if (allocated(st%mat)) deallocate(st%mat)
    allocate(st%mat(nmaterials))
    
    ! Initialize arrays
    st%R = 0._rk
    st%RL = 0._rk
    st%U = 0._rk
    st%RO = 0._rk
    st%RHO = 0._rk
    st%HP = 0._rk
    st%THETA = 0._rk
    st%HE = 0._rk
    st%HMASS = 0._rk
    st%N = 0._rk
    st%ENN = 0._rk
    st%K = 1
    
    ! Set central boundary
    st%R(1) = 0._rk
    st%U(1) = 0._rk
    
  end subroutine init_state_1959

  ! ===========================================================================
  ! Verify 1959 constants match ANL-5977 exactly
  ! ===========================================================================
  subroutine verify_1959_constants(st)
    type(State_1959), intent(in) :: st
    real(rk), parameter :: tol = 1.0e-7_rk
    
    print *, "==================================="
    print *, "Verifying 1959 S4 Constants"
    print *, "==================================="
    print *, "AM(1) =", st%AM(1), " (expect 1.0)"
    print *, "AM(2) =", st%AM(2), " (expect 0.6666667)"
    print *, "AM(3) =", st%AM(3), " (expect 0.1666667)"
    print *, "AM(4) =", st%AM(4), " (expect 0.3333333)"
    print *, "AM(5) =", st%AM(5), " (expect 0.8333333)"
    print *, ""
    print *, "AMBAR(1) =", st%AMBAR(1), " (expect 0.0)"
    print *, "AMBAR(2) =", st%AMBAR(2), " (expect 0.8333333)"
    print *, "AMBAR(3) =", st%AMBAR(3), " (expect 0.3333333)"
    print *, "AMBAR(4) =", st%AMBAR(4), " (expect 0.1666667)"
    print *, "AMBAR(5) =", st%AMBAR(5), " (expect 0.6666667)"
    print *, ""
    print *, "B(1) =", st%B_CONST(1), " (expect 0.0)"
    print *, "B(2) =", st%B_CONST(2), " (expect 1.6666667)"
    print *, "B(3) =", st%B_CONST(3), " (expect 3.6666667)"
    print *, "B(4) =", st%B_CONST(4), " (expect 3.6666667)"
    print *, "B(5) =", st%B_CONST(5), " (expect 1.6666667)"
    print *, "==================================="
    
    ! Verify MCP-confirmed values
    if (abs(st%AM(2) - 2._rk/3._rk) > tol) then
      print *, "WARNING: AM(2) mismatch!"
    end if
    if (abs(st%AMBAR(2) - 5._rk/6._rk) > tol) then
      print *, "WARNING: AMBAR(2) mismatch!"
    end if
    if (abs(st%B_CONST(2) - 5._rk/3._rk) > tol) then
      print *, "WARNING: B(2) mismatch!"
    end if
    
  end subroutine verify_1959_constants

end module types_1959

