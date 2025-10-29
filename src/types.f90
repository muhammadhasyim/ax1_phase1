module types
  use kinds
  implicit none
  integer, parameter :: GMAX=7, MUMAX=4, SHELLMAX=256, DGRP=6

  type :: Shell
     real(rk) :: r_in=0._rk, r_out=0._rk, rbar=0._rk
     real(rk) :: vel=0._rk, mass=0._rk, rho=0._rk
     real(rk) :: eint=0._rk, temp=0._rk
     real(rk) :: p_hyd=0._rk, p_visc=0._rk, p=0._rk
     integer  :: mat=1
  end type
  type :: EOS
     real(rk) :: a=0._rk, b=0._rk, c=1._rk
     real(rk) :: Acv=1._rk, Bcv=0._rk
     logical  :: tabular = .false.
     character(len=256) :: table_path = ""
  end type
  type :: Control
     character(len=8) :: eigmode="k"  ! "k" or "alpha"
     real(rk) :: dt=1.0e-3_rk, dt_max=1.0e-1_rk, dt_min=1.0e-6_rk
     integer  :: hydro_per_neut=1, hydro_per_neut_max=200
     real(rk) :: w_limit=0.3_rk, alpha_delta_limit=0.2_rk, power_delta_limit=0.2_rk
     real(rk) :: cfl = 0.8_rk
  end type
  type :: XSecGroup
     real(rk) :: sig_t=0._rk
     real(rk) :: nu_sig_f=0._rk
     real(rk) :: chi=0._rk
  end type
  type :: Material
     integer :: num_groups=1
     type(XSecGroup) :: groups(GMAX)
     real(rk) :: sig_s(GMAX, GMAX) = 0._rk  ! from g'->g
     ! delayed neutrons:
     real(rk) :: beta(DGRP) = 0._rk
     real(rk) :: lambda(DGRP) = 0._rk
  end type
  type :: State
     integer :: Nshell=1
     type(Shell), allocatable :: sh(:)
     type(EOS),   allocatable :: eos(:)
     integer :: G=1
     integer, allocatable :: mat_of_shell(:)
     integer :: nmat=0
     type(Material), allocatable :: mat(:)
     ! neutronics quadrature
     real(rk), allocatable :: mu(:), w(:)
     integer :: Nmu=0
     real(rk) :: vbar=1._rk
     real(rk) :: k_eff=1._rk, alpha=0._rk, time=0._rk, total_power=0._rk

     real(rk), allocatable :: phi(:,:)       ! (G,Nshell)
     real(rk), allocatable :: q_scatter(:,:) ! (G,Nshell)
     real(rk), allocatable :: q_fiss(:,:)    ! (G,Nshell) prompt
     real(rk), allocatable :: q_delay(:,:)   ! (G,Nshell) delayed source
     real(rk), allocatable :: power_frac(:)  ! per shell

     ! delayed precursors per shell and delayed group
     real(rk), allocatable :: C(:,:,:) ! (DGRP, G, Nshell) lumped per energy group for now
  end type
end module types
