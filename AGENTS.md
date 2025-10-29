# AGENTS.md

Instructions for automated agents (e.g. ChatGPT Codex, GitHub Copilot Agents, Codespaces)
to set up, build, and test the AX-1 Phase 1 Fortran project.

## Dependencies

- `gfortran` (Fortran 2008 compiler)
- `make`
- `cmake` (optional)

## Installation

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y gfortran make cmake
```

### macOS (Homebrew)
```bash
brew install gcc cmake
```

### Windows (MSYS2)
```bash
pacman -S mingw-w64-x86_64-gcc-fortran make cmake
```

## Build

Option A: Using Make
```bash
make
```

Option B: Using CMake
```bash
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . -j
```

## Run

```bash
./ax1 inputs/sample_phase1.deck
```

## Run Tests

```bash
./tests/smoke_test.sh
```

---

This file exists to give agents clear, step-by-step instructions so they can
set up the environment, build the code, and run validation without guessing.
