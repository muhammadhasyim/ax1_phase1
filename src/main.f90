program ax1
  use kinds
  use types
  use io_mod
  use input_parser
  use neutronics_s4_alpha
  use thermo
  use hydro
  use controls
  implicit none

  type(State)   :: st
  type(Control) :: ctrl
  integer :: step, i, j, nh
  real(rk) :: alpha_prev=0._rk, power_prev=0._rk
  real(rk) :: dtE, dE_spec, W, c_vp
  real(rk) :: k, alpha

  character(len=256) :: deck
  if (command_argument_count()>=1) then
    call get_command_argument(1, deck)
  else
    deck = "inputs/sample_phase1.deck"
  end if

  call banner()
  call load_deck(deck, st, ctrl)
  call set_S4_quadrature(st)
  call ensure_neutronics_arrays(st)
  c_vp = 1.0_rk
  k = 1.0_rk

  step = 0
  do while (st%time < 0.2_rk)   ! demo end time
    step = step + 1

    if (trim(ctrl%eigmode) == "alpha") then
      call solve_alpha_by_root(st, alpha, k)
      st%alpha = alpha
      call finalize_power_and_alpha(st, k, include_delayed=.true.)
    else
      call sweep_spherical_k(st, k, alpha=0._rk, tol=1.0e-5_rk, itmax=200)
      call finalize_power_and_alpha(st, k, include_delayed=.false.)
      ! alpha via prompt Λ (optional): left out; alpha remains from previous or zero
    end if

    call step_line(st, ctrl, "[neutronics]")

    ! THERMO + HYDRO for Ns4 sub-steps
    nh = ctrl%hydro_per_neut
    dtE = st%total_power * ctrl%dt
    do i=1, nh
       ! update delayed precursors
       call update_precursors(st, ctrl%dt)
       do j=1, st%Nshell
         dE_spec = dtE * st%power_frac(j) / max(st%sh(j)%mass, 1.0e-30_rk)
         call update_thermo(st, j, dE_spec)
       end do
       call hydro_step(st, ctrl, c_vp)
       st%time = st%time + ctrl%dt
       call step_line(st, ctrl, "[hydro]")
    end do

    call compute_W_metric(st, W)
    call adapt(st, ctrl, alpha_prev, power_prev, W)
    alpha_prev = st%alpha
    power_prev = st%total_power
  end do

  print *, "Done."
end program ax1
