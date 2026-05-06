#!/usr/bin/env zsh
# =============================================================================
# NLAB Shared Functions — sourced by nlab_install.sh
# =============================================================================

# Ensure START_PHASE is defined (set in main script)
if [ -z "$START_PHASE" ]; then
    export START_PHASE=0
fi

# --- Environment ---
export NLAB_ROOT="${NLAB_ROOT:-/Volumes/nlab}"
export NLAB_EXEC="${NLAB_EXEC:-$NLAB_ROOT/exec}"
export NLAB_SRC="${NLAB_SRC:-$NLAB_ROOT/source}"
export NLAB_DATA="${NLAB_DATA:-$NLAB_ROOT/data}"
export NLAB_SCRATCH="${NLAB_SCRATCH:-$NLAB_ROOT/scratch}"

# SDK setup - only if Xcode exists on external drive
if [ -d "/Volumes/nlab/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR="${DEVELOPER_DIR:-/Volumes/nlab/Applications/Xcode.app/Contents/Developer}"
    export SDKROOT=$(DEVELOPER_DIR="$DEVELOPER_DIR" xcrun --sdk macosx --show-sdk-path 2>/dev/null)
    
    if [ -z "$SDKROOT" ] || [ ! -d "$SDKROOT" ]; then
        SDKROOT="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.4.sdk"
        if [ ! -d "$SDKROOT" ]; then
            SDKROOT=$(ls -1d "$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX"*.sdk 2>/dev/null | sort -V | tail -1)
        fi
    fi
else
    export DEVELOPER_DIR=""
    export SDKROOT=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)
fi
export SDKROOT
echo "📦 Using SDK: $SDKROOT"

export NPROC=$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null || echo 4)
export NPROC_PERF=$NPROC

# MPI compiler variables (defined after OpenMPI is built)
export MPICC="/path/to//bin/mpicc"
export MPICXX="/path/to//bin/mpicxx"
export MPIFC="/path/to//bin/mpifort"
export MPIF90="/path/to//bin/mpifort"

MARKER_DIR="/path/to//.nlab_installed"
mkdir -p "$NLAB_SRC/tarballs" "$NLAB_SRC/git" "/path/to//bin" "/path/to//lib" "/path/to//include" "/path/to//share" "$MARKER_DIR"

CURRENT_PHASE="none"
CURRENT_PACKAGE="none"

# =============================================================================
# Path Setup
# =============================================================================
setup_nlab_paths() {
    export CPATH="/path/to//include:/usr/include:/usr/local/include:$CPATH"
    export C_INCLUDE_PATH="/path/to//include:/usr/include:/usr/local/include:$C_INCLUDE_PATH"
    export CPLUS_INCLUDE_PATH="/path/to//include:/usr/include:/usr/local/include:$CPLUS_INCLUDE_PATH"
    export LIBRARY_PATH="/path/to//lib:/usr/lib:/usr/local/lib:$LIBRARY_PATH"
    export PKG_CONFIG_PATH="/path/to//lib/pkgconfig:/path/to//share/pkgconfig:/opt/X11/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
    export CMAKE_PREFIX_PATH="/path/to/:$CMAKE_PREFIX_PATH"
    export CMAKE_LIBRARY_PATH="/path/to//lib:/usr/lib:/usr/local/lib:$CMAKE_LIBRARY_PATH"
    export CMAKE_INCLUDE_PATH="/path/to//include:/usr/include:/usr/local/include:$CMAKE_INCLUDE_PATH"
    export LD_LIBRARY_PATH="/path/to//lib:/usr/lib:/usr/local/lib:$LD_LIBRARY_PATH"
    export DYLD_LIBRARY_PATH="/path/to//lib:/usr/lib:/usr/local/lib:$DYLD_LIBRARY_PATH"
    export DYLD_FALLBACK_LIBRARY_PATH="/path/to//lib:/usr/lib:/usr/local/lib:$DYLD_FALLBACK_LIBRARY_PATH"
    export PATH="/path/to//bin:$PATH"
}

# =============================================================================
# Compiler Flags
# =============================================================================
export CPPFLAGS="-I/path/to//include -I/opt/X11/include"
export CFLAGS="-O3 -mcpu=apple-m2 -Wno-error=implicit-function-declaration -fPIC $CPPFLAGS"
export CXXFLAGS="$CFLAGS"
export FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch -fPIC $CPPFLAGS"
export LDFLAGS="-L/path/to//lib -Wl,-rpath,/path/to//lib -L/opt/X11/lib"

# =============================================================================
# Build Environments
# =============================================================================
setup_build_env() {
    # Only perform setup if it hasn't been done in this session
    if [[ "$NLAB_ENV_SET" == "1" && "$1" != "force" ]]; then return 0; fi
    
    if [ -z "$SDKROOT" ]; then
        echo "❌ SDKROOT not set. Please source your .zshrc first."
        return 1
    fi
    
    setup_nlab_paths
    
    # Clean duplicate paths
    export PKG_CONFIG_PATH=$(echo "$PKG_CONFIG_PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')
    
    if [ "$1" = "mpi" ]; then
        export CC="$MPICC"
        export CXX="$MPICXX"
        export FC="$MPIFC"
        export F77="$MPIFC"
        export F90="$MPIFC"
        echo "🔧 Build environment: MPI wrappers"
    else
        export CC="/path/to//bin/gcc"
        export CXX="/path/to//bin/g++"
        export FC="/path/to//bin/gfortran"
        export F77="/path/to//bin/gfortran"
        export F90="/path/to//bin/gfortran"
        echo "🔧 Build environment: GCC"
    fi
    
    export NLAB_ENV_SET=1
}

setup_clang_env() {
    setup_nlab_paths
    export CC="/usr/bin/clang"
    export CXX="/usr/bin/clang++"
    export CFLAGS="-O3 -mcpu=apple-m2 -fPIC -I/path/to//include -I/opt/X11/include"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-L/path/to//lib -Wl,-rpath,/path/to//lib -L/opt/X11/lib"
    echo "🍎 Build environment: System Clang (for Apple frameworks)"
}

# =============================================================================
# Dependency Checks
# =============================================================================
check_nlab_dep() {
    local dep_name=$1 found=0
    [ -f "/path/to//lib/lib${dep_name}.dylib" ] && found=1
    [ -f "/path/to//lib/lib${dep_name}.a" ] && found=1
    [ -f "/path/to//lib/pkgconfig/${dep_name}.pc" ] && found=1
    [ -d "/path/to//include/${dep_name}" ] && found=1
    [ -f "/opt/X11/lib/lib${dep_name}.dylib" ] && found=1
    [ -f "/usr/local/lib/lib${dep_name}.dylib" ] && found=1
    [ -f "/usr/lib/lib${dep_name}.dylib" ] && found=1
    [ -d "/System/Library/Frameworks/${dep_name}.framework" ] && found=1
    [ -d "$SDKROOT/System/Library/Frameworks/${dep_name}.framework" ] && found=1
    [ -f "/opt/X11/lib/pkgconfig/${dep_name}.pc" ] && found=1
    [ -f "/usr/local/lib/pkgconfig/${dep_name}.pc" ] && found=1
    
    if [ $found -eq 0 ]; then
        echo "⚠️  WARNING: $dep_name not found. Build may fail."
        return 1
    fi
    return 0
}

# =============================================================================
# Helpers
# =============================================================================
is_installed() {
    local marker="$1" target="$2"
    [ -f "$MARKER_DIR/$marker" ] && [ -e "$target" ] && return 0
    return 1
}

mark_done() { touch "$MARKER_DIR/$1"; echo "✅ $1 installed and marked."; }

download() {
    local url="$1" filename="$2"
    mkdir -p "$NLAB_SRC/tarballs"
    cd "$NLAB_SRC/tarballs" || return 1
    if [ ! -f "$filename" ]; then
        echo "⬇️  Downloading $filename from $url ..."
        wget -nc "$url" -O "$filename" || curl -L -f "$url" -o "$filename"
        [ $? -ne 0 ] && { echo "❌ Download failed for $filename"; return 1; }
    else
        echo "📦 $filename already present."
    fi
}

extract() {
    local archive="$1" target_dir="$2"
    cd "$NLAB_SRC/tarballs"
    if [ ! -d "$target_dir" ]; then
        echo "📂 Extracting $archive ..."
        case "$archive" in
            *.tar.gz|*.tgz) gunzip -c "$archive" | tar xvf - ;;
            *.tar.bz2)      bunzip2 -c "$archive" | tar xvf - ;;
            *.tar.xz)       xz -dc "$archive" | tar xvf - ;;
            *.tar)          tar xvf "$archive" ;;
            *.zip)          unzip -q "$archive" ;;
            *) echo "❌ Unknown archive format: $archive"; exit 1 ;;
        esac
    else
        echo "📁 $target_dir already extracted."
    fi
}

refresh_pkgconfig() {
    local paths="/path/to//lib/pkgconfig:/path/to//share/pkgconfig:/opt/X11/lib/pkgconfig:/usr/local/lib/pkgconfig"
    export PKG_CONFIG_PATH=$(echo "$paths" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')
    echo "  ✅ pkg-config path refreshed"
}
# =============================================================================
# Framework to Dylib Symlink Helper
# =============================================================================
# Creates symlinks from .framework bundles to .dylib files that packages expect
# Usage: create_framework_symlinks <framework_name> [framework_name2...]
# Example: create_framework_symlinks QtCore QtGui QtWidgets
create_framework_symlinks() {
    local lib_dir="/path/to//lib"
    local created=0
    
    for fw in "$@"; do
        if [ -d "$lib_dir/${fw}.framework" ] && [ ! -f "$lib_dir/lib${fw}.dylib" ]; then
            ln -sf "$lib_dir/${fw}.framework/${fw}" "$lib_dir/lib${fw}.dylib"
            echo "   ✅ Created symlink: lib${fw}.dylib -> ${fw}.framework/${fw}"
            created=1
        elif [ -d "$lib_dir/${fw}.framework" ] && [ -f "$lib_dir/lib${fw}.dylib" ]; then
            echo "   ℹ️  lib${fw}.dylib already exists"
        fi
    done
    
    return $created
}

# =============================================================================
# Generic Framework Installer
# =============================================================================
# Checks if a framework is installed and creates symlinks
# Usage: ensure_framework_installed <package_name> <framework_name> <library_path>
ensure_framework_installed() {
    local pkg_name="$1"
    local fw_name="$2"
    local lib_path="$3"
    
    # Check if framework exists
    if [ -d "/path/to//lib/${fw_name}.framework" ]; then
        # Create symlink if needed
        if [ ! -f "$lib_path" ] && [ -f "/path/to//lib/${fw_name}.framework/${fw_name}" ]; then
            ln -sf "/path/to//lib/${fw_name}.framework/${fw_name}" "$lib_path"
            echo "   ✅ Created symlink for ${pkg_name}"
        fi
        
        # Mark as installed if not already
        if [ ! -f "$MARKER_DIR/$pkg_name" ]; then
            mark_done "$pkg_name"
        fi
        refresh_pkgconfig
        return 0
    fi
    
    return 1
}
# =============================================================================
# Phase Helpers
# =============================================================================
phase_start() {
    local phase_name="$1"
    local phase_num="$2"
    local compiler_type="${3:-gcc}"   # gcc, mpi, or clang
    
    CURRENT_PHASE="$phase_name"
    
    # Check if we should skip this phase
    if [ $START_PHASE -gt $phase_num ]; then
        echo "== Skipping phase $phase_num =="
        return 1
    fi
    
    echo "=== $phase_name ==="
    
    # Setup environment based on compiler type
    if [ "$compiler_type" = "mpi" ]; then
        setup_build_env mpi
    elif [ "$compiler_type" = "clang" ]; then
        setup_clang_env
    else
        setup_build_env   # GCC default
    fi
    refresh_pkgconfig
    
    return 0
}

phase_end() {
    echo "✅ Phase $CURRENT_PHASE completed"
}

# =============================================================================
# Compiler Switching Helpers
# =============================================================================
switch_compiler() {
    local compiler="$1"
    case "$compiler" in
        gcc)   setup_build_env ;;
        mpi)   setup_build_env mpi ;;
        clang) setup_clang_env ;;
        *) echo "❌ Unknown compiler: $compiler"; return 1 ;;
    esac
    refresh_pkgconfig
    echo "   🔄 Switched to $compiler compiler"
}

with_compiler() {
    local compiler="$1"
    shift
    
    local saved_CC="$CC"
    local saved_CXX="$CXX"
    local saved_FC="$FC"
    local saved_CFLAGS="$CFLAGS"
    local saved_LDFLAGS="$LDFLAGS"
    
    switch_compiler "$compiler"
    
    "$@"
    local result=$?
    
    export CC="$saved_CC"
    export CXX="$saved_CXX"
    export FC="$saved_FC"
    export CFLAGS="$saved_CFLAGS"
    export LDFLAGS="$saved_LDFLAGS"
    refresh_pkgconfig
    
    return $result
}

# =============================================================================
# Phase Runner
# =============================================================================
run_phase() {
    local phase_num=$1
    local phase_func="phase${phase_num}"
    
    if command -v "$phase_func" >/dev/null 2>&1; then
        $phase_func
    else
        echo "⚠️  Warning: $phase_func not defined"
    fi
}

# =============================================================================
# Error Handler
# =============================================================================
on_error() {
    local lineno=$1
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ ERROR at line $lineno during phase ${CURRENT_PHASE:-?}"
    echo "   Package: ${CURRENT_PACKAGE:-unknown}"
    echo "   Source:  $(pwd)"
    echo ""
    echo "💡 To RECOVER: fix the error, then re-run:"
    echo "      $0 --resume-from ${CURRENT_PHASE#phase}"
    echo "   Or delete marker: rm $MARKER_DIR/${CURRENT_PACKAGE:-<pkg>}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
}
trap 'on_error $LINENO' ERR
