# 1959 AX-1 Equations Extracted from ANL-5977

## Document: ANL-5977, "AX-1, A Computing Program for Coupled Neutronics-Hydrodynamics Calculations on the IBM-704"
## Authors: H. H. Hummel, et al.
## Date: January 1959

---

## S4 Discrete Ordinates Constants

From lines 1090-1104 of ANL-5977 Fortran listing:

```fortran
AM(1) = 1.0
AM(2) = 0.6666667  = 2/3
AM(3) = 0.1666667  = 1/6
AM(4) = 0.3333333  = 1/3
AM(5) = 0.8333333  = 5/6

AMBAR(1) = 0.0
AMBAR(2) = 0.8333333  = 5/6
AMBAR(3) = 0.3333333  = 1/3
AMBAR(4) = 0.1666667  = 1/6
AMBAR(5) = 0.6666667  = 2/3

B(1) = 0.0
B(2) = 1.6666667  = 5/3
B(3) = 3.6666667  = 11/3
B(4) = 3.6666667  = 11/3
B(5) = 1.6666667  = 5/3
```

**Physical Meaning:**
- AM(J) = μⱼ-related constants for spherical S4 transport
- AMBAR(J) = Modified angular constants for angular redistribution
- B(J) = Boundary/geometry constants for spherical coordinates

**S4 Angular Directions (inferred from references):**
- μ₁ = 0.2958759  (cosine of polar angle for first direction)
- μ₂ = 0.9082483  (cosine of polar angle for second direction)
- Weights: w₁ = w₂ = 1/3 for each of 2 directions per hemisphere

---

## Equation of State (Linear)

From lines 1413 (Order 6833):

```fortran
HP(I) = MAX(0.0, ALPH(M)*RO(I) + BETA(M)*THETA(I) + TAU(M))
```

**Mathematical Form:**
$$P_H = \alpha \rho + \beta \theta + \tau$$

Where:
- $P_H$ = Hydrodynamic pressure (megabars)
- $\alpha$ = ALPH(M) coefficient (cm²/μsec²)
- $\rho$ = RO(I) density (g/cm³)
- $\beta$ = BETA(M) coefficient (g/(cm·μsec²·keV))
- $\theta$ = THETA(I) temperature (keV)
- $\tau$ = TAU(M) constant (megabars)

**Constraint:** $P_H \geq 0$ (no negative pressure allowed)

---

## Specific Heat

From line 1415 (Order 6835):

```fortran
HE(I) = ACV(M)*THETA(I) + 0.5*BCV(M)*THETA(I)**2
```

**Mathematical Form:**
$$C_v = A_{cv} + B_{cv} \theta$$

$$E_{internal} = \int C_v d\theta = A_{cv} \theta + \frac{1}{2} B_{cv} \theta^2$$

Where:
- $C_v$ = Specific heat at constant volume (cm²/(μsec²·keV))
- $A_{cv}$ = ACV(M) constant coefficient
- $B_{cv}$ = BCV(M) temperature-dependent coefficient
- $E_{internal}$ = HE(I) specific internal energy (10¹² ergs/g)

---

## Lagrangian Coordinates

From line 1400 (Order 6818):

```fortran
RL(I) = CUBERTF(RL(I-1)**3 + RO(I)*(R(I)**3 - R(I-1)**3))
```

**Mathematical Form:**
$$R_L(I)^3 = R_L(I-1)^3 + \rho(I) \left[R(I)^3 - R(I-1)^3\right]$$

**Mass Conservation:**
$$\rho R^2 dR = R_L^2 dR_L = constant$$

Where:
- $R_L(I)$ = Lagrangian (mass) coordinate
- $\rho(I)$ = Density at zone I
- $R(I)$ = Eulerian (spatial) radius

---

## Hydrodynamic Velocity Update

From Appendix B, Order ~9066 (lines 872-894):

**Mathematical Form:**
$$U^{n+1/2}(I) = U^{n-1/2}(I) - \Delta t \frac{1}{\rho_{Hyd}} \frac{\partial P_H}{\partial R}$$

**In Lagrangian Coordinates:**
$$U^{n+1/2}(I) = U^{n-1/2}(I) - \Delta t \frac{R^2(I)}{R_L^2(I)} \frac{P_H(I+1) - P_H(I)}{\frac{1}{2}\left[R_L(I+1) - R_L(I-1)\right]}$$

Where:
- $U$ = Velocity (cm/μsec)
- $\Delta t$ = Time step (μsec)
- Pressure gradient taken in Lagrangian coordinates

---

## Position Update

**Mathematical Form:**
$$R^{n+1}(I) = R^n(I) + U^{n+1/2}(I) \cdot \Delta t$$

---

## Density from Lagrangian Coordinates

**Mathematical Form:**
$$\rho = \frac{R_L^2}{R^2} \frac{\partial R}{\partial R_L}$$

---

## Von Neumann-Richtmyer Artificial Viscosity

From Appendix C (line 3302):

**Mathematical Form:**
$$P_v = C_{vp}^2 \rho^2 (\Delta R)^2 \left(\frac{\partial V}{\partial t}\right)^2$$

**Applied Only for Compression:**
- If $\Delta V < 0$ (compression): $P_v$ is calculated
- If $\Delta V \geq 0$ (expansion): $P_v = 0$

**Total Pressure:**
$$P_{total} = P_H + P_v$$

Where:
- $C_{vp}$ = CVP = Viscous pressure coefficient (typically 1.5-2.0)
- $\rho$ = Density
- $\Delta R$ = Zone width
- $\partial V/\partial t$ = Rate of volume change

---

## Courant Stability Criterion

From Appendix C (line 3294):

**Mathematical Form:**
$$C_{sc} E \frac{(\Delta t)^2}{(\Delta R)^2} < 1$$

**Enhanced Criterion (line 3298):**
$$W = C_{sc} E \frac{(\Delta t)^2}{(\Delta R)^2} + 4 C_{vp} \frac{|\Delta V|}{V} < 0.3$$

Where:
- $C_{sc}$ = CSC = Courant stability constant $\approx \gamma(\gamma-1)$
- $E$ = Specific internal energy
- $\Delta t$ = Time step
- $\Delta R$ = Zone width
- $W$ = Stability function

**Action:** If $W > 0.3$, then $\Delta t \rightarrow \Delta t/2$

---

## Alpha Eigenvalue (Prompt Neutronics)

From Appendix A and main code:

**Point Kinetics Approximation:**
$$\alpha = \frac{k_{ex}}{\Lambda} = \frac{k - 1}{\Lambda}$$

Where:
- $\alpha$ = ALPHA = Inverse period (μsec⁻¹)
- $k$ = k-effective (multiplication factor)
- $k_{ex}$ = Excess reactivity = $k - 1$
- $\Lambda$ = Prompt neutron generation time (μsec)

**Reactivity:**
$$\rho = k_{ex} = k - 1$$

**Power Evolution:**
$$P(t) = P_0 e^{\alpha t}$$

---

## Power Change Control

From line 1402 (Order 6820):

**Criterion:**
$$\alpha \cdot \Delta t < 4 \eta_2$$

Where:
- $\eta_2$ = ETA2 = Maximum fractional power change tolerance
- If violated: $\Delta t \rightarrow \Delta t/2$

---

## VJ-OK-1 Test (Neutronics Frequency Control)

From Appendix A (line 3229):

**Mathematical Form:**
$$VJ \cdot (\Delta t)^2 \cdot (N_{S4})^2 \cdot \int p \, dV < OK_1$$

Where:
$$VJ = \left(\frac{\sqrt{q}}{b}\right)^5 \times \frac{1}{\alpha_{max} \cdot \ell \cdot s}$$

- $VJ$ = Jankus reactivity coefficient
- $N_{S4}$ = NS4 = Number of hydro cycles per neutronics calculation
- $\int p \, dV$ = Integrated pressure
- $OK_1$ = Threshold (typically 0.01)
- $q$ = Flux ratio (edge/center)
- $b$ = Core radius (cm)
- $\alpha_{max}$ = Maximum anticipated alpha (μsec⁻¹)
- $\ell$ = Prompt neutron lifetime (μsec)
- $s$ = Core density (g/cm³)

**Purpose:** Reduce $N_{S4}$ when burst begins (rapid power rise)

---

## Time Step Adaptation

**Doubling Criterion:**
If hydrocycles since last adjustment $\geq N_{Lmax}$ AND $W$ small AND $\alpha \Delta t$ small:
$$\Delta t \rightarrow 2 \Delta t$$

**Halving Criterion:**
If $W > 0.3$ OR $\alpha \Delta t > 4\eta_2$:
$$\Delta t \rightarrow \Delta t/2$$

**Velocity Time Adjustment:**
When halving: $\Delta t' \rightarrow \frac{3}{4} \Delta t$ (maintains velocity at half-interval position)

---

## Energy Conservation

From lines 1416-1428:

**Kinetic Energy:**
$$E_{kinetic} = \sum_{i=2}^{IMAX} HMASS(I) \cdot \frac{1}{4}\left[U(I)^2 + U(I-1)^2\right]$$

**Internal Energy:**
$$E_{internal} = \sum_{i=2}^{IMAX} HMASS(I) \cdot HE(I)$$

**Total Energy:**
$$E_{total} = E_{kinetic} + E_{internal}$$

**Energy Addition (from fission):**
$$\Delta E = P \cdot \Delta t$$

Where:
- $HMASS(I) = R_L(I)^3 - R_L(I-1)^3$ (lacking factor $4\pi/3$)
- Output multiplied by $4\pi/3 = 4.18879$ for printing

---

## Boundary Conditions

**Free Surface (line 1426):**
$$P(IMAX+1) = -P(IMAX)$$

Ensures zero pressure at outer boundary.

**Central Boundary:**
$R(1) = 0$ always (center of sphere)
$U(1)$ handled specially at coordinate singularity

---

## Convergence Criteria

**Alpha Convergence (EPSA):**
$$|\alpha_{new} - \alpha_{old}| < EPSA$$

**K-effective Convergence (EPSK):**
$$|k_{eff,new} - k_{eff,old}| < EPSK$$

**Radius Convergence (EPSR):**
$$|R(IMAX)_{new} - R(IMAX)_{old}| < EPSR$$

**Pressure Iteration (ETA1):**
$$|P_H^{new} - P_H^{guess}| < ETA1 \cdot (P_H + EPSI)$$

Where EPSI is small pressure to avoid division by zero.

---

## Unit System (1959 Specific)

- **Time:** microseconds (μsec)
- **Length:** centimeters (cm)
- **Energy:** keV (temperature), 10¹² ergs (total energy)
- **Pressure:** megabars (1 megabar = 10¹² dyne/cm²)
- **Density:** grams/cm³
- **Velocity:** cm/μsec
- **Cross sections:** barns (10⁻²⁴ cm²)
- **Neutron density:** atoms/cc × 10⁻²⁴

---

## Critical Differences from Modern Implementation

1. **NO DELAYED NEUTRONS:** All fission neutrons assumed prompt
   - Fission source: $Q_{fiss} = \chi(g) \cdot \nu\Sigma_f \cdot \phi / k$
   - NO reduction by $(1-\beta)$ factor

2. **Prompt-only kinetics:** $\alpha = \rho/\Lambda$ (no delayed denominator)

3. **Von Neumann-Richtmyer viscosity** instead of modern Riemann solvers

4. **S4 only** (no S6, S8 options)

5. **Temperature-independent cross sections**

6. **Linear EOS only** (no tabular EOS)

---

## Files for MCP Verification

Next steps:
1. Verify S4 constants with MCP symbolic algebra
2. Verify EOS thermodynamic consistency
3. Verify Lagrangian coordinate transformations
4. Verify stability criterion derivation
5. Verify unit conversions

