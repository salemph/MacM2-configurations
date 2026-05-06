# MacM2-configurations
Physics and Nuclear Engineering  setup tools for Mac M2
# NLAB Nuclear Engineering Build System

## Overview

This is a **professional-grade HPC build system** for nuclear engineering software on Apple M2/M3/M4 Macs. It builds over 100 scientific packages from source, including compilers, MPI, linear algebra libraries, mesh tools, nuclear simulation codes, and machine learning frameworks.

## System Architecture

```
nlab/
├── nlab_install.sh          # Main script (CLI parsing, orchestrates phases)
├── nlab_lib/
│   ├── functions.sh         # Shared functions (setup_build_env, setup_clang_env, etc.)
│   ├── phase0.sh            # Core build tools
│   ├── phase1.sh            # Compression & Crypto
│   ├── phase2.sh            # Graphics Core
│   ├── phase3.sh            # Graphics Extras
│   ├── phase4.sh            # Python & Scientific Stack
│   ├── phase5.sh            # Qt + Graphviz
│   ├── phase6.sh            # MPI (OpenMPI)
│   ├── phase7.sh            # Extras (Doxygen, R, Octave)
│   ├── phase8.sh            # Linear Algebra
│   ├── phase9.sh            # Partitioning
│   ├── phase10.sh           # I/O Libraries
│   ├── phase11.sh           # Mesh Tools
│   ├── phase12.sh           # High-Level Solvers
│   ├── phase13.sh           # Visualization
│   ├── phase14.sh           # Nuclear Tools
│   ├── phase15.sh           # MPS / ML Acceleration
│   └── phase16.sh           # Developer Tools
```

## Installation

### Prerequisites

1. **External 2TB drive** mounted at `/Volumes/nlab`
2. **Xcode Command Line Tools** (for system headers)
3. **Homebrew** (optional, for CMake fallback)

### Setup

```bash
# 1. Clone or create the directory structure
mkdir -p /Volumes/nlab/{exec,source,data,scratch}
mkdir -p /Volumes/nlab/source/{tarballs,git}

# 2. Source your environment
source ~/.zshrc

# 3. Run the build
cd nlab
./nlab_install.sh
```

## Compiler Selection by Phase

| Phase | Description | Default Compiler | Reason |
|-------|-------------|-----------------|--------|
| 0 | Core Build Tools | `gcc` | Build tools (gawk, cmake) |
| 1 | Compression & Crypto | `gcc` | Standard C libraries |
| 2 | Graphics Core | `gcc` | Most graphics libs fine with GCC |
| 3 | Graphics Extras | `gcc` | libgd, poppler, swig |
| 4 | Python & Scientific | `gcc` | Python and numpy need GCC |
| 5 | Qt + Graphviz | `clang` | **Qt needs Cocoa/AppKit frameworks** |
| 6 | MPI (OpenMPI) | `mpi` | MPI wrappers required |
| 7 | Extras | `gcc` | Doxygen, R, Octave |
| 8 | Linear Algebra | `gcc` | OpenBLAS, FFTW (ScaLAPACK needs MPI sub-shell) |
| 9 | Partitioning | `mpi` | METIS, ParMETIS need MPI |
| 10 | I/O Libraries | `mpi` | HDF5, NetCDF parallel versions |
| 11 | Mesh Tools | `mpi` | MOAB, DAGMC need MPI |
| 12 | High-Level Solvers | `mpi` | PETSc, Trilinos need MPI |
| 13 | Visualization | `clang` | **VTK/ParaView need Cocoa/Metal** |
| 14 | Nuclear Tools | `clang` | **ROOT/Geant4 need Cocoa frameworks** |
| 15 | MPS/ML | `gcc` | TensorFlow, PyTorch (Metal via Python) |
| 16 | Developer Tools | `gcc` | ripgrep, fd, bat, htop |

## Per-Package Compiler Overrides

Some packages need different compilers than their phase default:

| Package | Phase | Default | Actual | Reason |
|---------|-------|---------|--------|--------|
| ScaLAPACK | 8 | `gcc` | `mpi` | Needs MPI wrappers |
| Cairo | 2 | `gcc` | `clang` | Quartz/CoreText frameworks |
| gobject-introspection | 2 | `gcc` | `clang` | Apple framework dependencies |
| atk/gdk-pixbuf/pango/gtk | 2 | `gcc` | `clang` | Quartz backends |
| boost | 3 | `gcc` | `clang` | Better M2 compatibility with Clang |
| ROOT | 14 | `clang` | `mpi` | Needs MPI + Clang for Cocoa |
| Geant4 | 14 | `clang` | `mpi` | Needs MPI + Clang |

### Mixed Compiler Pattern Example

```bash
# Phase 8 - Linear Algebra
phase8() {
    phase_start "PHASE 8: Linear Algebra" 8 "gcc" || return 0
    
    # OpenBLAS - GCC (default)
    CURRENT_PACKAGE="openblas"
    if ! is_installed openblas "..."; then
        make -j$NPROC && make install
    fi
    
    # ScaLAPACK - needs MPI (isolated sub-shell)
    CURRENT_PACKAGE="scalapack"
    if ! is_installed scalapack "..."; then
        (
            setup_build_env mpi
            refresh_pkgconfig
            ./configure --prefix="$NLAB_EXEC"
            make -j$NPROC && make install
        )
        # Environment automatically restored to GCC
    fi
    
    # SuiteSparse - back to GCC
    CURRENT_PACKAGE="suitesparse"
    if ! is_installed suitesparse "..."; then
        make -j$NPROC && make install
    fi
}
```

## Issues Encountered and Solutions

### 1. **External Drive nosuid Restriction**
- **Problem**: macOS kernel blocks execution from external APFS drives
- **Symptoms**: CMake crashes with `Killed: 9` (signal 137)
- **Solution**: Use Clang to build CMake, or install via Homebrew

### 2. **GCC + macOS SDK Incompatibility**
- **Problem**: GCC cannot parse Clang-specific `xnu_static_assert` macros
- **Symptoms**: Hundreds of `expected constructor, destructor, or type conversion` errors
- **Solution**: Use Clang for packages that need Apple frameworks (Qt, VTK, ROOT, Geant4)

### 3. **environ Variable Not Found**
- **Problem**: GCC on macOS doesn't expose `environ` by default
- **Symptoms**: `'environ' was not declared in this scope`
- **Solution**: Add `-D_GNU_SOURCE -D_DARWIN_C_SOURCE` to CFLAGS

### 4. **CMake Build Failures with GCC**
- **Problem**: CMake's bootstrap script fails with GCC on external drive
- **Symptoms**: Build errors in `cmFindProgramCommand.cxx`
- **Solution**: Use Clang to build CMake, or use pre-built universal binary

### 5. **Duplicate Phase Headers**
- **Problem**: `sed`/`perl` commands applied multiple times
- **Symptoms**: Each line appears twice, duplicate function definitions
- **Solution**: Use the cleanup script provided in `clean_duplicates.sh`

### 6. **Boost on M2**
- **Problem**: Boost has architecture detection issues with GCC on Apple Silicon
- **Symptoms**: `error: unknown type name 'uintptr_t'`
- **Solution**: Use Clang with `-stdlib=libc++` for Boost

### 7. **pkg-config Not Finding Libraries**
- **Problem**: Newly installed libraries not detected
- **Symptoms**: `configure: error: Package requirement ... not met`
- **Solution**: Always call `refresh_pkgconfig` after `mark_done`

## Usage Commands

```bash
# Source environment first
source ~/.zshrc

# Run full build (from phase 0)
./nlab_install.sh

# Resume from specific phase (e.g., after fixing an error)
./nlab_install.sh --resume-from 8

# Clean mode - remove markers for packages needing rebuild
./nlab_install.sh --clean

# List all phases with descriptions
./nlab_install.sh --list

# Show help
./nlab_install.sh --help
```

## Phase Descriptions

| Phase | Packages | Compiler | Approx Time |
|-------|----------|----------|-------------|
| 0 | gawk, cmake, pkg-config, ninja, meson | GCC | 10 min |
| 1 | zlib, openssl, curl, ncurses, libxslt, xerces-c | GCC | 15 min |
| 2 | libpng, freetype, cairo, glib, gtk3, harfbuzz, pango | GCC/Clang | 30 min |
| 3 | libgd, poppler, swig, boost, gts | GCC/Clang | 30 min |
| 4 | Python 3.12, numpy, scipy, pandas, h5py, mpi4py | GCC | 20 min |
| 5 | Qt5, Graphviz | Clang | 45 min |
| 6 | OpenMPI 5.0.x | MPI | 10 min |
| 7 | Doxygen, R, Octave | GCC | 25 min |
| 8 | OpenBLAS, ScaLAPACK, FFTW, GSL, Eigen, SuiteSparse | GCC/MPI | 35 min |
| 9 | METIS, ParMETIS, hypre, Zoltan | MPI | 15 min |
| 10 | HDF5, PnetCDF, NetCDF, CDF, ADIOS2 | MPI | 20 min |
| 11 | MOAB, DAGMC, Mesquite, deal.ii | MPI | 25 min |
| 12 | SUNDIALS, PETSc, Trilinos, libMesh, STRUMPACK | MPI | 60 min |
| 13 | VTK, ParaView | Clang | 45 min |
| 14 | ROOT, Geant4, OpenMC, MOOSE, PyNE | Clang/MPI | 90 min |
| 15 | TensorFlow, PyTorch, Metal | GCC | 15 min |
| 16 | ripgrep, fd, bat, htop, shellcheck, tree | GCC | 5 min |

## Troubleshooting

### Build Fails at Specific Package

```bash
# Delete the marker for that package
rm /Volumes/nlab/exec/.nlab_installed/<package_name>

# Resume from the phase
./nlab_install.sh --resume-from <phase_number>
```

### CMake Still Crashing

```bash
# Use Homebrew CMake as fallback
brew install cmake
ln -sf $(brew --prefix cmake)/bin/cmake /Volumes/nlab/exec/bin/cmake
```

### pkg-config Can't Find Library

```bash
# Force refresh
refresh_pkgconfig

# Or manually set
export PKG_CONFIG_PATH="/Volumes/nlab/exec/lib/pkgconfig:$PKG_CONFIG_PATH"
```

### Compiler Mismatch

Always use sub-shell `( ... )` when switching compilers within a phase:

```bash
# Good - isolated
(
    setup_clang_env
    refresh_pkgconfig
    ./configure --prefix="$NLAB_EXEC"
    make -j$NPROC && make install
)

# Bad - pollution
setup_clang_env
./configure --prefix="$NLAB_EXEC"
make -j$NPROC && make install
# Environment now stuck in Clang mode!
```

## Key Lessons Learned

1. **Never fight the SDK** - Use Clang for packages needing Apple frameworks
2. **Isolate compiler switches** - Always use subshells `( ... )` when changing compilers
3. **Refresh pkg-config after each install** - Otherwise dependencies won't be found
4. **Test sed/perl commands on one file first** - Avoid mass duplication
5. **Backup before automated edits** - `cp phase*.sh ../phase_backup/`
6. **Use `phase_start` and `phase_end`** - Consistent phase structure
7. **Markers are your friends** - They make builds idempotent

## License

For academic/research use in nuclear engineering.

---

**Built and tested on:** macOS 15.x (Sequoia) with Apple M2/M3/M4
**GCC version:** 15.2 / 16.0.1
**Target applications:** OpenMC, Geant4, ROOT, MOOSE, PETSc, Trilinos
