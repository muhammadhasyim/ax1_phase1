# AX-1 (1959)

A reproduction of the 1959 AX-1 coupled neutronics-hydrodynamics code from
Argonne National Laboratory report ANL-5977. The code simulates prompt
supercritical reactor transients, computing how nuclear heating causes
material expansion that eventually shuts down the chain reaction.

## The Physics

The simulation couples two physical processes. The neutronics module solves
the transport equation using S4 discrete ordinates to find the neutron flux
and the alpha-eigenvalue (inverse reactor period). The hydrodynamics module
uses Lagrangian coordinates where the mesh moves with the material, with
von Neumann-Richtmyer artificial viscosity to capture shocks. A linear
equation of state relates pressure to density and temperature.

## Source Files

    src/kinds.f90             Precision definitions
    src/types_1959.f90        Data structures for state and control variables
    src/neutronics_s4_1959.f90  S4 transport solver and alpha-eigenvalue iteration
    src/hydro_vnr_1959.f90    Lagrangian hydrodynamics with artificial viscosity
    src/time_control_1959.f90 Adaptive time stepping (W stability, NS4 adjustment)
    src/io_1959.f90           Input parsing and output formatting
    src/main_1959.f90         Main program and simulation loop

## Requirements

A Fortran compiler (gfortran recommended) and Make. On Ubuntu or Debian:

    sudo apt install gfortran make

For plotting, Python 3 with numpy, pandas, and matplotlib:

    pip install numpy pandas matplotlib

For the LaTeX document, a TeX distribution with pdflatex:

    sudo apt install texlive-latex-recommended texlive-fonts-recommended

## Building

    make -f Makefile.1959

This produces the executable `ax1_1959`.

## Running

    ./ax1_1959 inputs/geneve10_transient.inp

The Geneva 10 benchmark runs a 300 microsecond transient. Output files:

    output_time_series.csv      Time history of energy, power, alpha, k-eff
    output_spatial_t*.csv       Spatial profiles at selected times

To generate comparison plots against the 1959 reference data:

    python3 analysis/compare_geneva10.py

Figures are saved to `analysis/figures/`.

## Documentation

The report `AX1_Code_Analysis.tex` describes the implementation, the mapping
between modern code and original 1959 order numbers, and validation results.
Compile with:

    pdflatex AX1_Code_Analysis.tex

A pre-compiled PDF is included as `AX1_Code_Analysis.pdf`.

## Reference Materials

The `docs/` directory contains:

    ANL-5977_original.pdf       Original 1959 report (scanned)
    anl5977_scans/              OCR'd flow diagrams and Fortran listing
    all_pseudocode.txt          Extracted pseudocode from flow diagrams

## References

H. H. Hummel et al., "AX-1, A Computing Program for Coupled
Neutronics-Hydrodynamics Calculations on the IBM-704," ANL-5977,
Argonne National Laboratory, January 1959.
