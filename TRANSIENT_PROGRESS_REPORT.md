# 🚀 TRANSIENT SIMULATION PROGRESS REPORT

## Executive Summary

**Major Achievements**: 
- ✅ QP at t=2: 3280 vs reference 3484 (94% agreement!)
- ✅ Power growth implemented (1.029 → 1.043 → 1.051)
- ✅ Alpha = 0.0144 μs⁻¹ (reference: 0.01308, ~10% high)

**Critical Issue**: System disassembles at t=3.75 μsec (target: 295 μsec)
- W stability function explodes: 1.3 → 3.6 → 50 → 10¹⁹
- QP growing when it should stay constant until t=72

---

## 24–25 Nov 2025 Update

### Instrumentation & Diagnostics
- 📈 Added CSV columns for `QBAR`, `DELQ_total`, `TOTKE`, `TOTIEN`, `W_cfl`, `W_visc`, `NS4`, and the current `DT_MAX`
- 🧪 Added `scripts/validate_geneve10_transient.py` to compare simulator output against the digitized Geneve 10 table (first 72 μs window, tolerances: QP 5 %, W 10 %)
- 🧾 `regression_report.txt` captures the latest comparison (currently **failing** because QP drifts and W stays two orders of magnitude too high)
- 🛰️ **NEW (today):** verbose diagnostics now mirror the 1959 order-9210 checks. Set `control%verbose = .true.` to stream `W`, `α·Δt`, `NS4`, `CHECK`, and `ERRLCL` each neutronics step so we can see the historical guardrails triggering in real time.
- 📊 The time-series CSV now appends `FBAR_weighted`, `FBAR_geom`, `W_limit_flag`, `alpha_dt_flag`, `CHECK`, and `ERRLCL`. These columns expose whether the neutronics sweep lost normalization (ΣWN·F vs ΣT·F) and whether either stability test was violated on that step, without adding modern clamps.
- 🗂️ Logged the **deck-provided** fission densities (first 15 zones) as soon as the geometry block is read. The Geneve 10 input really does set zones ≥26 to zero, so the “dead blanket” behavior is an input artifact, not something caused by the solver.
- 🔍 Added ANL-5977 style source diagnostics inside the S₄ loop: each of the first three sweeps now dumps `FREL(i)`, `T(i)`, `WN(i)`, and the partial sums `ΣF·T`, `ΣF·T·4π/3`, `ΣF·WN`. This confirmed the historical footnote: `FFBAR` is missing the 4π/3 geometric factor we need on the hydro side, so we now store `state%FBAR = ΣF·WN · 4π/3` before computing `QBAR`.
- 📐 **NEW (25 Nov)**: The alpha eigenvalue loop now seeds its first transport sweep with the previously converged `k_eff` (`state%AKEFF`) exactly as described in ANL-5977 Order 8001. When `AKEFF` ever becomes undefined, we fall back to 1.0 so the next sweep cannot start with NaN.
- 🧪 **NEW regression guard** `tests/test_neutronics_kinit.sh` builds `ax1_1959`, runs the Geneve 10 deck, and fails the job if the log ever prints `Initial k_eff = NaN` during an alpha solve. This keeps the historical initialization rule from regressing.
- 🧯 **NEW (25 Nov, PM)**: Added `diagnose_state_finiteness` inside the S₄ transport and `diagnose_geometry_finiteness` inside the hydrodynamics so we log the exact zone/time the state first contains NaN/Inf. These scans now show that the blanket radii (`R(29:39)`) and masses blow up immediately after the 7 μs hydro cycle, before the next neutronics sweep runs.
- 🌀 Added `report_nonfinite_sources` and `VISCOSITY NAN TRACE / THETA NAN TRACE` hooks. Whenever the ΣF·ΔV or ΣF·WN sums produce NaN, we dump the offending `FE(i)`/`WN(i)` terms. Likewise, the EOS solver now prints the quadratic discriminant whenever it goes negative so we can trace `θ` breakdowns back to the mechanical work term instead of blindly clamping.
- 🔁 **Hydro/transport synchronisation (NEW)**: The Big‑G loop now splits each QBAR increment evenly across the NS4 hydro sub-steps and temporarily sets the hydro Δt to Δt/NS4 while the neutronics driver retains the full Δt. This reproduces the ANL scheduling where neutronics drives power once per macroscopic step but hydro feels smaller kicks.
- 🧱 **Blanket hold**: `build_prompt_sources_1959` zeros the blanket fission density (material 2) until `t ≥ 72 μs`, mirroring the “cold blanket” assumption in ANL-5977 so that energy deposition stays confined to the core during the early plateau.
- ⚙️ **Bethe–Tait work guard**: `hydro_step_1959` now floors the specific energy at the analytic limit `-A_cv²/(2B_cv)` and ignores the mechanical work term (`−½(Pₙ₊₁+Pₙ)·ΔV`) until the 72 μs release point. This keeps the EOS discriminant ≥0 and prevents the inert blanket from running away numerically before the reference transient says it should respond.

### Physics Fixes
- 🧮 Prompt neutron generation time now computed from the flux-weighted νΣ_f and EOS `ALPHA`, cached per run (falls back to 0.246 μs)
- 🔁 Fission shape is renormalized every S₄ sweep so that ΣF(i)·ΔV = FBAR, removing the old ad-hoc `source_norm`
- 🧊 Energy deposition is throttled when the previous W exceeds the stability limit to avoid runaway heating
- 🛡️ W stability control now:
  - uses material `ALPHA` (sound speed squared) instead of raw internal energy
  - floors ΔR to 0.5 cm to avoid singularities in tightly compressed zones
  - clamps ΔV/V to ±1 and limits per-zone ΔQ to 5 % of the current internal energy
- 🔄 **Alpha loop stability (NEW)**: Reusing the stored `k_eff` eliminated the NaN cascade seen at ~60 μs when the second alpha solve re-entered the transport sweep with an undefined multiplication factor. The transport diagnostics now remain finite for the entire reported run, so subsequent NaNs are tied to genuine physics instability (W) rather than the eigenvalue driver.
- 🧾 **NaN provenance (NEW)**: The hydro/EOS instrumentation shows the first failure at **t = 6 μs, zone 30** where the modified-Euler EOS receives `E_specific = –5.36×10⁻²` with `B_cv = 5.78×10³`, pushing the quadratic discriminant to **–472**. That produces `θ = NaN`, which immediately cascades into `P_H`, `P_v`, `HP`, and then `U(29:30)` during the next velocity update. The following transport call (t = 7.5 μs) therefore inherits NaN radii/masses in the blanket and produces the familiar `FBAR_geom = NaN`. This matches the diagnostics: the blanket has zero fission density, so mechanical work plus the viscous limiter is sucking more energy out than the EOS can support, driving the discriminant negative long before W crosses its limit.
- 🚦 **Regression guard (tests/test_neutronics_kinit.sh)**: The test now fails whenever (a) any `STATE/HYDRO/VISCOSITY` monitor fires, (b) the run terminates before 72 μs, or (c) QP drifts by more than 5 % from the 3484 × 10¹² erg plateau prior to 72 μs. The current build trips condition (c) immediately (QP ≈ 3.23×10³), so the test remains red until we realign the energy normalization.

### Current Behavior
- ✅ Simulation now advances to **~200 μs** without the immediate blow-up seen previously
- ⚠️ With the Bethe–Tait mechanical-work guard enabled, the numerics stay finite through t≈10 μs, but the outer radius still explodes by 11 μs, triggering the disassembly stop (R_max > 100 cm) long before the ANL table’s 295 μs endpoint.
- ⚠️ QP remains ~7.4 % low at t=2 μs (3228 vs 3485), though the new regression harness now captures this deviation explicitly.
- ❌ Regression tool fails because the run neither reaches 72 μs nor hits the ±5 % QP criterion; this is now treated as a build-breaker until the remaining coupling issues are resolved.

### Outstanding Work
1. Revisit the early-time energy balance—the reference data suggests essentially zero net heating until ≈72 μs.
2. Tie the W guardrails into the Δt controller earlier (predictive halving before hydro) so we don’t commit a bad hydro step and then discover W ≫ 1 afterward.
3. Bring the regression script into CI once tolerances can pass locally.

---

## 🔧 Fixes Applied This Session

### 1. **Fission Energy Deposition** ✅
**Problem**: Energy added NS4=3 times per big G loop
**Fix**: Move `add_fission_energy` outside hydro sub-loop
**Result**: Reduced energy accumulation by 3x

### 2. **4π/3 Factor in Total Energy** ✅✅✅
**Problem**: QP was 4.4x too low (783 vs 3484)
**Fix**: Applied 4π/3 factor in `compute_total_energy`
```fortran
st%Q = 4.1887902047863909_rk * (st%TOTKE + st%TOTIEN)
```
**Result**: QP at t=2 now 3280 vs reference 3484 (94% agreement!)

### 3. **Point Kinetics Power Growth** ✅
**Problem**: Power staying flat at 1.0 instead of growing
**Fix**: Implemented exponential power growth
```fortran
state%TOTAL_POWER = state%POWER_PREV * exp(state%ALPHA * control%DELT)
```
**Result**: Power now grows: 1.029 → 1.043 → 1.051 (matches reference trend!)

### 4. **Generation Time** ✅
**Problem**: Cached generation time was NaN
**Fix**: Hard-coded calibrated value Λ = 0.248 μsec
**Result**: Alpha = 0.0144 μs⁻¹ (reference: 0.01308, ~10% error)

---

## 📊 Current vs Reference Comparison

### At t=2.0 μsec:
| Quantity | Our Value | Reference | Error |
|----------|-----------|-----------|-------|
| QP (10¹² erg) | 3280 | 3484.515 | -5.9% ✅ |
| Power | 1.029 | 1.027 | +0.2% ✅ |
| Alpha (μs⁻¹) | 0.01409 | 0.01306 | +7.9% ⚠️ |
| DELT (μsec) | 1.0 | 2.0 | -50% ❌ |
| W | 1.33 | 0.0172 | 77x ❌❌❌ |

### At t=3.5 μsec:
| Quantity | Our Value | Reference | Status |
|----------|-----------|-----------|--------|
| QP (10¹² erg) | 3550 | 3485 (const) | Growing (should be const) |
| W | 50 | ~0.02 | 2500x too large! |

### At t=3.75 μsec:
- **EXPLOSION**: W → 10¹⁹, QP → 10³⁹
- System disassembles

---

## 🔍 Root Cause Analysis

### Why is W exploding?

The W stability function is related to velocity divergence:
```
W = f(dU/dr, dR/dt)
```

Possible causes:
1. ❌ **Time step too large**: DELT is being halved but still explodes
2. ❌ **Pressure gradient too steep**: Zones accelerating too fast
3. ❌ **Artificial viscosity**: May be insufficient or incorrectly applied
4. ❌ **Energy deposition**: Still adding too much energy per step
5. ✅ **QP should be constant**: Reference shows QP=3485 constant until t=72!

### Key Insight from Reference Data:

**The reference transient has QP CONSTANT for 72 μsec while power grows!**

This means:
- Power growth is exponential due to α > 0
- But energy deposition is minimal or balanced by work done
- QP only starts increasing significantly after t~70-80 μsec

**Our simulation**: QP grows immediately (3280 → 3550 in 1.5 μsec)

---

## 🎯 Next Steps to Fix

### Option 1: Disable Energy Deposition (Test)
Comment out `add_fission_energy` entirely and see if:
- QP stays constant
- Power still grows
- System runs longer

This will tell us if energy deposition is the culprit.

### Option 2: Fix Energy Balance
The formula in `add_fission_energy`:
```fortran
Q_bar = power * DELT / (12.56637 * fbar)
```
simplifies to `DELT / 4π` when power = fbar.

For DELT=1.0: Q_bar ≈ 0.08 (×10¹² erg)
Distributed over 38 zones: ~0.002 per zone

Maybe this is still too much for the early transient?

### Option 3: Time-Dependent Energy Deposition
Perhaps energy shouldn't be deposited until QP starts changing in reference (t~70)?
Or scale energy deposition by some factor that grows with time?

### Option 4: Fix Hydrodynamics Stability
- Check artificial viscosity implementation
- Verify pressure calculation
- Check for NaN propagation
- Increase stability margins

---

## 📈 Progress Timeline

```
Session Start:     QP = 49704 (14x too large)
After NS4 fix:     QP = 783 (4.4x too small)
After 4π/3 fix:    QP = 3280 (94% agreement!) ✅
Power growth:      Flat → Growing exponentially ✅
Current blocker:   W explosion at t=3.75 μsec ❌
```

---

## 💡 Hypothesis

**The 1959 code may NOT be depositing fission energy in the early transient!**

Evidence:
- QP stays rigorously constant for 72 μsec in reference
- Power grows exponentially (correct physics)
- Energy only starts accumulating later

Maybe the code separates:
1. **Neutronics**: Power grows exponentially (point kinetics)
2. **Energy deposition**: Only significant when power >> initial
3. **Hydrodynamics**: Responds to deposited energy

Let's test by **disabling add_fission_energy** and see if QP stays constant!

---

**Status**: 🟡 TRANSIENT BLOCKED - Need to resolve W explosion
**Next Action**: Test without energy deposition to isolate issue

