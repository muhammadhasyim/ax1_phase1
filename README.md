# AX-1 (Modern Fortran) — Phase 1 Upgrades (Real‑world Track)

This release implements **Phase 1** toward real‑world usefulness:

- **α‑eigenvalue solver** via root‑finding on k(α): modify Σ_t′ = Σ_t + α/v, find α so that k_eff(α)=1.
- **Delayed neutrons** (6 groups): precursor evolution and delayed source in transport.
- **Controls**: W‑criterion proxy + **CFL** stability enforcement.
- **EOS tables**: optional CSV tables (ρ, T) → (P, Cv) with bilinear interpolation.
- **Tests/CI hooks**: smoke test and simple checks for α, CFL.

## Build & Run
```bash
make
./ax1 input/sample_phase1.deck
```

For α‑eigen runs, set `eigmode alpha` in the deck (see samples). For EOS tables, supply `eos_table <path>`.

## Notes
- The α solve uses **secant** on k(α)=1 with a diffusion‑synthetic‑like iteration tolerance.
- Delayed source is included with χ_d = χ (configurable later); explicit Euler update per hydro substep.
- CFL uses c ≈ sqrt(max(a,eps)) from EOS and shell velocity; W combines |ΔU| and |ΔP|/P changes.
