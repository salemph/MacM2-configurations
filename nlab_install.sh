#!/usr/bin/env zsh
# =============================================================================
# NLAB COMPLETE MASTER BUILD SCRIPT
# =============================================================================
set -o pipefail
set -Ee

SCRIPT_DIR="${0:A:h}"
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared functions
source "$SCRIPT_DIR/functions.sh"

# =============================================================================
# CLI Parsing
# =============================================================================
list_phases() {
    echo "0   Build tools + gawk"
    echo "1   Core libs (zlib, openssl, curl, ncurses, libxslt, xerces-c)"
    echo "2   Graphics core (libpng, freetype, cairo, glib, gtk3)"
    echo "3   Graphics extras (libgd, poppler, swig)"
    echo "4   Python & scientific stack"
    echo "5   Qt + Graphviz"
    echo "6   MPI (OpenMPI)"
    echo "7   Extras (Doxygen, R)"
    echo "8   Linear algebra (OpenBLAS, ScaLAPACK, FFTW, GSL, Eigen, SuiteSparse)"
    echo "9   Partitioning (METIS, ParMETIS, hypre, Zoltan)"
    echo "10  I/O (HDF5, PnetCDF, NetCDF, CDF)"
    echo "11  Mesh (MOAB, Mesquite)"
    echo "12  High‑level solvers (SUNDIALS, PETSc, Trilinos, libMesh)"
    echo "13  VTK + ParaView, Octave"
    echo "14  Nuclear tools (DAGMC, ROOT, MOOSE, OpenMC, Geant4, …)"
    echo "15  MPS / ML acceleration"
    echo "16  Developer tools (ripgrep, fd, bat, htop, shellcheck, tree)"
}

usage() {
    cat <<EOF
NLAB Master Build Script – builds all required libraries from source.

Usage: $0 [OPTIONS]

Options:
  --help, -h        Show this help message.
  --list, -l        List all phases and exit.
  --resume-from N   Start from phase N (e.g., 3).
  --clean           Analyze and remove markers for packages that need rebuild.

Phases:
EOF
    list_phases
    exit 0
}

auto_clean() {
    echo "🔍 Analyzing installed packages for needed rebuilds..."
    local cleaned=0
    [ -f "$MARKER_DIR/icu" ] && { echo "   ICU: rebuild needed"; rm -f "$MARKER_DIR/icu"; cleaned=1; }
    [ -f "$MARKER_DIR/dbus" ] && { echo "   D-Bus: rebuild needed"; rm -f "$MARKER_DIR/dbus"; cleaned=1; }
    [ -f "$MARKER_DIR/qt5" ] && { echo "   Qt5: rebuild needed"; rm -f "$MARKER_DIR/qt5"; cleaned=1; }
    [ -f "$MARKER_DIR/graphviz" ] && { echo "   Graphviz: rebuild needed"; rm -f "$MARKER_DIR/graphviz"; cleaned=1; }
    [ -f "$MARKER_DIR/cairo" ] && ! otool -L "$NLAB_EXEC/lib/libcairo.dylib" 2>/dev/null | grep -q CoreGraphics && { echo "   Cairo: rebuild needed"; rm -f "$MARKER_DIR/cairo"; cleaned=1; }
    [ $cleaned -eq 1 ] && echo "" && echo "✅ Cleaned markers for packages needing rebuild" || echo "   All existing packages appear up-to-date"
    echo ""
}

START_PHASE=0
CLEAN_MODE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage ;;
        --list|-l) list_phases; exit 0 ;;
        --resume-from)
            [[ "$2" =~ ^[0-9]+$ ]] && { START_PHASE=$2; shift 2; } || { echo "Error: --resume-from requires a phase number." >&2; exit 1; } ;;
        --clean) CLEAN_MODE=1; shift ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Run clean mode if requested
if [ $CLEAN_MODE -eq 1 ]; then
    auto_clean
    echo "📋 To rebuild, run: $0 --resume-from 2"
    exit 0
fi
# =============================================================================
# Source all phase files (function definitions only, no execution)
# =============================================================================
for phase in {0..16}; do
	phase_file="$SCRIPT_DIR/nlab/phase${phase}.sh"
    [ -f "$phase_file" ] && source "$phase_file"
done


# =============================================================================
# Main
# =============================================================================
main() {
     echo "╔══════════════════════════════════════════════════════════════╗"
     echo "║     ✅ Nuclear Lab Environment Build Complete!               ║"
     echo "║  To activate:   source ~/.zshrc                              ║"
     
     echo ""
     echo "🔬 Nuclear Lab Build – Starting at phase $START_PHASE"
     echo "   Root: $NLAB_ROOT"
     echo "   Compiler: $CC"
     echo "🔬 Nuclear Lab Build – Starting at phase $START_PHASE"
     echo "   Root:     $NLAB_ROOT"
     echo "   SDK:      $SDKROOT"
	 echo "╚══════════════════════════════════════════════════════════════╝"
     echo ""
    # Run phases 0-16 with environment setup before each
      for phase in {0..16}; do
          if [ $phase -ge $START_PHASE ]; then
              run_phase $phase
          else
              echo "== Skipping phase $phase =="
          fi
      done

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     ✅ Nuclear Lab Environment Build Complete!              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  To activate your environment:                              ║"
    echo "║    source ~/.zshrc                                          ║"
    echo "║                                                             ║"
    echo "║  Key components installed:                                  ║"
    echo "║    Compiler:  GCC 16.0.1                                    ║"
    echo "║    MPI:       OpenMPI 5.0.10                                ║"
    echo "║    Python:    3.12.9                                        ║"
    echo "║    Qt:        5.15.15                                       ║"
    echo "║    ROOT:      6.32.00                                       ║"
    echo "║    Geant4:    11.3.1                                        ║"
    echo "║    OpenMC:    latest                                        ║"
    echo "║    MOOSE:     latest                                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}
main "$@"