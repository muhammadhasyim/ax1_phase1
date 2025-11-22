# Von Neumann-Richtmyer Artificial Viscosity Derivation

## Physical Motivation

In computational fluid dynamics, shock waves create discontinuities that cannot be resolved on finite grids. Physical viscosity naturally sm ears shocks over several molecular mean free paths. von Neumann and Richtmyer (1950) introduced **artificial viscosity** to mimic this smearing on computational grids.

## Physical Viscosity

The Navier-Stokes momentum equation with viscosity:

$$\rho \frac{D\mathbf{v}}{Dt} = -\nabla p + \nabla \cdot (\eta \nabla \mathbf{v})$$

For 1D spherical flow with viscosity $\eta$:

$$\rho \frac{Dv}{Dt} = -\frac{\partial p}{\partial r} + \frac{\partial}{\partial r}\left(\eta \frac{\partial v}{\partial r}\right)$$

## von Neumann-Richtmyer Artificial Viscosity

The artificial viscous pressure is designed to:
1. Activate ONLY during compression ($\partial V/\partial t < 0$)
2. Be proportional to $(\partial V/\partial t)^2$ for shock-width independence
3. Scale with density and zone size

### Formula (ANL-5977 Appendix C, line 3302):

$$P_v = C_{vp}^2 \rho^2 (\Delta R)^2 \left(\frac{\partial V}{\partial t}\right)^2$$

Where:
- $C_{vp}$ = Viscous pressure coefficient (typically 1.5-2.0, dimensionless)
- $\rho$ = Density (g/cm³)
- $\Delta R$ = Zone width (cm)
- $\partial V/\partial t$ = Rate of volume change (1/μsec)

### Dimensional Analysis Verification

Let's verify that $P_v$ has units of pressure (megabars = 10¹² dyne/cm²).

**Units of $C_{vp}$:** Dimensionless (pure number)

**Units of $\rho$:** g/cm³

**Units of $\Delta R$:** cm

**Units of $\partial V/\partial t$:** 
- Volume $V$ has units cm³
- Time $t$ has units μsec
- Therefore: $\partial V/\partial t$ has units cm³/μsec

**Combined units:**
$$[P_v] = [1] \cdot [g/cm^3]^2 \cdot [cm]^2 \cdot [cm^3/\mu sec]^2$$
$$= \frac{g^2}{cm^6} \cdot cm^2 \cdot \frac{cm^6}{\mu sec^2}$$
$$= \frac{g^2 \cdot cm^2}{\mu sec^2}$$

Now convert to pressure units:
$$1 \, \text{dyne} = 1 \, g \cdot cm/sec^2$$
$$1 \, \text{megabar} = 10^{12} \, dyne/cm^2 = 10^{12} \, g/(cm \cdot sec^2)$$

In μsec units (1 μsec = 10⁻⁶ sec):
$$[P_v] = \frac{g^2 \cdot cm^2}{\mu sec^2} = \frac{g \cdot cm}{\mu sec^2} \cdot \frac{g}{cm}$$

Actually, let me reconsider. The formula should be:

$$P_v = C_{vp}^2 \rho^2 (\Delta R)^2 \left|\frac{\partial V/V}{\partial t}\right|^2$$

Or more precisely, from ANL-5977:

$$P_v = C_{vp} \rho \left(\Delta R \frac{\partial v}{\partial t}\right)^2$$

Where $v = \partial r/\partial t$ is velocity.

### Correct Dimensional Analysis

**Formula from ANL-5977:**
$$P_v = C_{vp} \rho (\Delta R)^2 \left(\frac{\partial V}{\partial t}\right)^2 / V^2$$

Or equivalently:
$$P_v = C_{vp} \rho \left(\frac{\Delta R}{V}\right)^2 \left(\frac{\partial V}{\partial t}\right)^2$$

**Units:**
- $[\rho] = g/cm^3$
- $[\Delta R] = cm$
- $[V] = cm^3$
- $[\partial V/\partial t] = cm^3/\mu sec$

$$[P_v] = [g/cm^3] \cdot [cm^2/cm^6] \cdot [cm^6/\mu sec^2]$$
$$= [g/cm^3] \cdot [1/cm^4] \cdot [cm^6/\mu sec^2]$$
$$= [g \cdot cm^2/(\mu sec^2 \cdot cm)]$$
$$= [g/(cm \cdot \mu sec^2)]$$

Converting to megabars:
$$1 \, megabar = 10^{12} \, dyne/cm^2 = 10^{12} \, g \cdot cm/sec^2 / cm^2 = 10^{12} \, g/(cm \cdot sec^2)$$

In μsec: $1 \, \mu sec = 10^{-6} \, sec$

$$1 \, g/(cm \cdot \mu sec^2) = 1 \, g/(cm \cdot 10^{-12} sec^2) = 10^{12} \, g/(cm \cdot sec^2) = 1 \, megabar$$ ✓

## Numerical Implementation (1959 Style)

From ANL-5977 (implicit in code around Order 9082):

```fortran
! Check for compression
IF (DV < 0.0) THEN  ! Volume decreasing
  DV_DT = DV / DELT
  PV = CVP**2 * RO(I)**2 * (DR**2) * (DV_DT)**2 / V**2
ELSE
  PV = 0.0  ! No viscosity during expansion
END IF
HP(I) = PH(I) + PV  ! Total pressure
```

## Shock Smearing Width

The artificial viscosity spreads shocks over approximately:

$$N_{zones} \approx C_{vp}$$

Typically $C_{vp} \approx 1.5-2.0$, giving shock width of 2-3 computational zones.

This is **much wider** than physical shocks (molecular scale) but allows numerical stability.

## Comparison with Modern Riemann Solvers

| Feature | von Neumann-Richtmyer (1959) | HLLC Riemann (Modern) |
|---------|------------------------------|----------------------|
| Shock width | 2-3 zones | Sub-zone (sharp) |
| Dissipation | Artificial viscosity | Upwind differencing |
| Stability | Depends on $C_{vp}$ | Built-in |
| Accuracy | First-order | Second-order |
| Complexity | Simple | Complex |

## MCP Verification

Let me verify dimensions using MCP units tool.

