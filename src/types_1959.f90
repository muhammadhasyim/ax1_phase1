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
  real(rk), parameter :: ENERGY_RELEASE_TIME_1959 = 72._rk ! Blanket heating delay (μsec)

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
     real(rk) :: sig_tr(GMAX_1959) = 0._rk      ! Transport cross section (barns)
     real(rk) :: chi(GMAX_1959) = 0._rk         ! Fission spectrum
     real(rk) :: V(GMAX_1959) = 169.5_rk        ! Neutron velocity (cm/μsec) per group
     
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
     integer :: ICNTRL = 0                   ! 0: calc alpha, 1: fit radii to alpha
     integer :: KCNTRL = 0                   ! 0: alpha mode after init, 1: k-eff mode first
     integer :: KCALC = 0                    ! 0: alpha mode (transient), 1: k mode (initial)
     real(rk) :: ALPHA_TARGET = 0.0_rk      ! Target alpha for ICNTRL=1 (μsec⁻¹)
     
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
     real(rk) :: W_LIMIT = 0.3_rk   ! Maximum allowed W stability function
     real(rk) :: MIN_ZONE_WIDTH = 0.5_rk ! Minimum ΔR used in W estimate (cm)
     real(rk) :: ALPHA_DELTA_LIMIT = 0.2_rk  ! Maximum α·Δt for stability
     real(rk) :: POWER_DELTA_LIMIT = 0.2_rk  ! Maximum power change per step
     
     ! -----------------------------------------------------------------------
     ! Time control
     ! -----------------------------------------------------------------------
     real(rk) :: DELT = 1.0e-3_rk   ! Time step (μsec)
     real(rk) :: DELTP = 1.0e-3_rk  ! Previous time step for velocity
     real(rk) :: DT_MAX = 0.1_rk    ! Maximum time step (μsec)
     real(rk) :: T_END = 1.0_rk     ! Simulation end time (μsec)
     real(rk) :: R_MAX_DISASSEMBLY = 200.0_rk  ! Max radius for termination (cm)
     real(rk) :: DELT_min = 1.0e-8_rk  ! Minimum time step
     real(rk) :: DELT_max = 1.0_rk     ! Maximum time step
     
     ! -----------------------------------------------------------------------
     ! Neutronics frequency control (ANL-5977 Order numbers ~9014-9050)
     ! -----------------------------------------------------------------------
     integer :: NS4 = 1             ! Hydro cycles per neutronics calculation
     integer :: NS4R = 0            ! Hydro cycle counter
     integer :: NL = 64             ! NL countdown counter for DELT doubling (Order 9270)
     integer :: NLMax = 64          ! Max hydro cycles before DELT doubling (NLMAX)
     integer :: HYDRO_PER_NEUT = 1  ! Hydro steps per neutron step
     integer :: HYDRO_PER_NEUT_MAX = 200  ! Maximum NS4
     logical :: halve_delt_flag = .false.  ! SENSE LIGHT 3 equivalent (force halve)
     
     ! -----------------------------------------------------------------------
     ! VJ-OK-1 test parameters (ANL-5977 Appendix A)
     ! -----------------------------------------------------------------------
     real(rk) :: VJ = 0._rk         ! Jankus reactivity coefficient
     real(rk) :: OK1 = 0.01_rk      ! VJ-OK-1 threshold (CONST < OK1: skip)
     real(rk) :: OK2 = 0.1_rk       ! VJ-OK-2 threshold (CONST > OK2: NS4=1)
     real(rk) :: PTEST = 0._rk      ! Pressure test threshold (megabars)
     real(rk) :: POWNGL = 1.0e-10_rk  ! Low power threshold for NS4 boost (Order 9335)
     logical :: low_power_boosted = .false.  ! SENSE LIGHT 4 equivalent (prevent repeat boost)
     
     ! -----------------------------------------------------------------------
     ! Iteration limits
     ! -----------------------------------------------------------------------
     integer :: max_source_iter = 200   ! Maximum source iterations
     integer :: max_pressure_iter = 50  ! Maximum pressure iterations (modified Euler)
     
     ! -----------------------------------------------------------------------
     ! Output control
     ! -----------------------------------------------------------------------
     integer :: output_freq = 10    ! Output every N neutronics cycles (for comparison plots)
     character(len=256) :: output_file = "ax1_1959.out"
     logical :: print_input = .true.  ! Print input echo
     logical :: verbose = .false.     ! Verbose output for debugging
     logical :: skip_neutronics = .false.  ! Skip neutronics (hydro-only test)
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
     real(rk) :: ROSN(SHELLMAX_1959) = 0._rk      ! Density snapshot for S₄ (ROSN in 1959)
     real(rk) :: RO_PREV(SHELLMAX_1959) = 0._rk   ! Previous hydrodynamic density
     real(rk) :: HP_PREV(0:SHELLMAX_1959) = 0._rk ! Previous pressure (before viscosity)
     real(rk) :: HP(0:SHELLMAX_1959) = 0._rk      ! Total pressure P_H + P_v (megabars)
     real(rk) :: THETA(SHELLMAX_1959) = 0._rk     ! Temperature (keV)
     real(rk) :: HE(SHELLMAX_1959) = 0._rk        ! Specific internal energy (10¹² ergs/g)
     real(rk) :: HEO(SHELLMAX_1959) = 0._rk       ! Cold internal energy reference (ANL-5977 6812)
     real(rk) :: HMASS(SHELLMAX_1959) = 0._rk     ! Zone mass (factor 4π/3 omitted)
     real(rk) :: FREL(SHELLMAX_1959) = 0._rk      ! Relative fission density F(I)
     
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
    real(rk) :: TOTAL_POWER = 0._rk  ! Total system power
    real(rk) :: POWER_PREV = 0._rk   ! Previous power for change detection
    real(rk) :: LAMBDA_INITIAL = 0._rk  ! Initial generation time (μsec) - cached
    real(rk) :: Q = 0._rk          ! Total energy (10¹² ergs, lacking 4π/3)
    real(rk) :: QPRIME = -1._rk    ! Previous Q (init to -1 so Q>QPRIME initially)
    real(rk) :: QBAR = 0._rk       ! Energy increment per cycle (10¹² ergs)
    real(rk) :: QBAR_LAST = 0._rk   ! Cached QBAR for diagnostics
    real(rk) :: DELQ_TOTAL = 0._rk  ! Total fission energy deposited this cycle
    
    ! -----------------------------------------------------------------------
    ! Alpha-mode iteration variables (ANL-5977 lines 277-311)
    ! -----------------------------------------------------------------------
    real(rk) :: FFBAR = 0._rk      ! Σ WN(I)*F(I) - current fission rate
    real(rk) :: FFBARP = 0._rk     ! Previous FFBAR
    real(rk) :: FEBAR = 0._rk      ! Σ WN(I)*E(I) - current escape rate
    real(rk) :: FEBARP = 0._rk     ! Previous FEBAR  
    real(rk) :: FENBAR = 0._rk     ! Σ WN(I)*ENNN(I) for alpha update
    real(rk) :: ENNN(SHELLMAX_1959) = 0._rk  ! ENNN(I) = Σ EN(IG,I)/V(IG)
    real(rk) :: F_OLD(SHELLMAX_1959) = 0._rk  ! F(I) from previous Big G loop
    real(rk) :: E_OLD(SHELLMAX_1959) = 0._rk  ! E(I) from previous Big G loop
     
     ! -----------------------------------------------------------------------
     ! Energetics
     ! -----------------------------------------------------------------------
     real(rk) :: TOTKE = 0._rk      ! Total kinetic energy (10¹² ergs)
     real(rk) :: TOTIEN = 0._rk     ! Total internal energy (10¹² ergs)
     real(rk) :: FBAR = 1._rk       ! Flux-weighted fission rate (ΣWN·F)
     real(rk) :: FBAR_GEOM = 1._rk  ! Geometric fission sum (ΣT·F)
     
     ! -----------------------------------------------------------------------
     ! Time
     ! -----------------------------------------------------------------------
     real(rk) :: TIME = 0._rk       ! Current time (μsec)
     integer :: NH = 0              ! Hydro cycle counter
     
     ! -----------------------------------------------------------------------
     ! Stability and diagnostics
     ! -----------------------------------------------------------------------
     real(rk) :: W = 0._rk          ! Stability function
    real(rk) :: W_CFL = 0._rk      ! CFL contribution to W
    real(rk) :: W_VISC = 0._rk     ! Viscous contribution to W
    real(rk) :: DELV_MAX(SHELLMAX_1959) = 0._rk  ! Max specific volume change per zone (for W calc)
     real(rk) :: ERRLCL = 0._rk     ! Local energy error
     real(rk) :: CHECK = 0._rk      ! Energy balance check
     real(rk) :: FLAG1 = 0._rk      ! Power termination flag
     logical :: RHO_DELV_LARGE = .false.  ! ANL-5977 line 9068: density change too large
     
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
     real(rk) :: FE(SHELLMAX_1959) = 0._rk        ! Fission rate F(I) = ν·Σf · φ
     real(rk) :: FEP(SHELLMAX_1959) = 0._rk       ! Previous fission rate
     real(rk) :: EE(SHELLMAX_1959) = 0._rk        ! Escape/absorption rate E(I) = Σ_s→g · φ
     real(rk) :: EEP(SHELLMAX_1959) = 0._rk       ! Previous escape rate
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
    st%ROSN = 0._rk
    st%RO_PREV = 0._rk
    st%HP_PREV = 0._rk
    st%HP = 0._rk
    st%THETA = 0._rk
    st%HE = 0._rk
    st%HEO = 0._rk
    st%HMASS = 0._rk
    st%FREL = 0._rk
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

