# -----------------------------------------------------------------------------
# Phase 8 – Linear algebra
# -----------------------------------------------------------------------------
phase8() {
    phase_start "PHASE 8: Linear Algebra (OpenBLAS, ScaLAPACK, FFTW, GSL, Eigen, SuiteSparse)" 8 "gcc" || return 0

    # MPI check (ScalAPACK and FFTW need it)
    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # =========================================================================
    # 8.1 OpenBLAS (NO MPI needed - base linear algebra)
    # =========================================================================
    CURRENT_PACKAGE="openblas"
    if ! is_installed openblas "$NLAB_EXEC/lib/libopenblas.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d OpenBLAS ] && git clone https://github.com/OpenMathLib/OpenBLAS.git
        cd OpenBLAS
        setup_build_env  # GCC, no MPI for OpenBLAS
        git checkout v0.3.29
        make clean
        # TARGET=VORTEX for Apple M-series, INTERFACE64 for 64-bit integers
        make -j$NPROC \
            TARGET=VORTEX \
            USE_THREAD=1 \
            NUM_THREADS=8 \
            INTERFACE64=1 \
            CC="$CC" \
            FC="$FC" \
            CFLAGS="-O3 -mcpu=native -fopenmp" \
            FFLAGS="-O3 -mcpu=native -fopenmp"
        make PREFIX="$NLAB_EXEC" install
        
        # Create pkg-config file for OpenBLAS
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/openblas.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenBLAS
Description: Optimized BLAS library for M2
Version: 0.3.29
Libs: -L\${libdir} -lopenblas
Cflags: -I\${includedir}
EOF
        mark_done openblas
		refresh_pkgconfig
    fi

    # =========================================================================
    # 8.2 ScaLAPACK (NEEDS MPI + OpenBLAS)
    # =========================================================================
    CURRENT_PACKAGE="scalapack"
    if ! is_installed scalapack "$NLAB_EXEC/lib/libscalapack.dylib"; then
        download https://github.com/Reference-ScaLAPACK/scalapack/archive/v2.2.2.tar.gz scalapack-2.2.2.tar.gz
        extract scalapack-2.2.2.tar.gz scalapack-2.2.2
        cd scalapack-2.2.2
        setup_build_env mpi  

        # Generate SLmake.inc with proper settings
        cat > SLmake.inc << EOF
FC            = $MPIFC
CC            = $MPICC
NOOPT         = -O0 -mcpu=apple-m2
FCFLAGS       = -O3 -mcpu=apple-m2 -fPIC
CCFLAGS       = -O3 -mcpu=apple-m2 -fPIC
FCLOADER      = $MPIFC
CCLOADER      = $MPICC
ARCH          = $AR
ARCHFLAGS     = cr
RANLIB        = $RANLIB
BLASLIB       = -L$NLAB_EXEC/lib -lopenblas
LAPACKLIB     = -L$NLAB_EXEC/lib -lopenblas
LIBS          = \$(LAPACKLIB) \$(BLASLIB)
EOF
# Create Bmake.inc for BLACS sub-build with implicit declaration fix
cat > BLACS/SRC/Bmake.inc << 'BLACSEOF'
CC       = /Volumes/nlab/exec/bin/mpicc
F77      = /Volumes/nlab/exec/bin/mpifort
CCFLAGS  = -O3 -mcpu=apple-m2 -fPIC -Wno-implicit-function-declaration -std=gnu89
F77FLAGS = -O3 -mcpu=apple-m2 -fPIC -fallow-argument-mismatch
BLASLIB   = -L/Volumes/nlab/exec/lib -lopenblas
LAPACKLIB = -L/Volumes/nlab/exec/lib -lopenblas
MPILIB    = -lmpi
ARCH      = /Volumes/nlab/exec/bin/gcc-ar
RANLIB    = /Volumes/nlab/exec/bin/gcc-ranlib
BLACSEOF
        make clean
        make -j1 
        make lib -j1

        # Determine archive tools
        if [ -x "$NLAB_EXEC/bin/gcc-ar" ]; then
            AR_TOOL="$NLAB_EXEC/bin/gcc-ar"
            RANLIB_TOOL="$NLAB_EXEC/bin/gcc-ranlib"
        else
            AR_TOOL="/usr/bin/ar"
            RANLIB_TOOL="/usr/bin/ranlib"
        fi

        # Merge object files into static library
        $AR_TOOL -r libscalapack.a PBLAS/SRC/*.o 2>/dev/null || true
        $AR_TOOL -r libscalapack.a REDIST/SRC/*.o 2>/dev/null || true
        $AR_TOOL -r libscalapack.a TOOLS/*.o 2>/dev/null || true
        $RANLIB_TOOL libscalapack.a

        # Create shared library for macOS
        $FC -dynamiclib -o "$NLAB_EXEC/lib/libscalapack.dylib" \
            -Wl,-all_load libscalapack.a \
            -L$NLAB_EXEC/lib -lopenblas \
            -install_name "$NLAB_EXEC/lib/libscalapack.dylib" \
            -Wl,-rpath,"$NLAB_EXEC/lib"

        # Install static library and headers
        cp libscalapack.a "$NLAB_EXEC/lib/"
        mkdir -p "$NLAB_EXEC/include/scalapack"
        cp PBLAS/SRC/*.h "$NLAB_EXEC/include/scalapack/" 2>/dev/null || true
        cp REDIST/SRC/*.h "$NLAB_EXEC/include/scalapack/" 2>/dev/null || true
        
        cd ..
        mark_done scalapack
		refresh_pkgconfig
    fi

    # =========================================================================
    # 8.3 FFTW (NEEDS MPI for parallel transforms)
    # =========================================================================
    CURRENT_PACKAGE="fftw"
    if ! is_installed fftw "$NLAB_EXEC/lib/libfftw3.dylib"; then
        download http://www.fftw.org/fftw-3.3.10.tar.gz fftw-3.3.10.tar.gz
        extract fftw-3.3.10.tar.gz fftw-3.3.10
        cd fftw-3.3.10
        setup_build_env mpi  

        # Build double precision (fftw3)
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared \
                    --enable-openmp \
                    --enable-mpi \
                    --enable-threads \
                    CC="$MPICC" \
                    F77="$MPIFC" \
                    MPICC="$MPICC" \
                    CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
                    FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
        make -j$NPROC && make install

        # Build single precision (fftw3f)
        make clean
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared \
                    --enable-openmp \
                    --enable-mpi \
                    --enable-threads \
                    --enable-float \
                    CC="$CC" \
                    F77="$FC" \
                    MPICC="$CC" \
                    CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
                    FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
        make -j$NPROC && make install

        # Build long double precision (fftw3l)
        make clean
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared \
                    --enable-openmp \
                    --enable-mpi \
                    --enable-threads \
                    --enable-long-double \
                    CC="$CC" \
                    F77="$FC" \
                    MPICC="$CC" \
                    CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
                    FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
        make -j$NPROC && make install

        mark_done fftw
		refresh_pkgconfig
    fi

    # =========================================================================
    # 8.4 GSL (GNU Scientific Library - NO MPI needed)
    # =========================================================================
    CURRENT_PACKAGE="gsl"
    if ! is_installed gsl "$NLAB_EXEC/lib/libgsl.dylib"; then
        download https://ftp.gnu.org/gnu/gsl/gsl-2.8.tar.gz gsl-2.8.tar.gz
        extract gsl-2.8.tar.gz gsl-2.8
        cd gsl-2.8
        setup_build_env  
        
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared --enable-static \
                    CC="$CC" \
                    CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
                    LDFLAGS="$LDFLAGS"
        make -j$NPROC && make install
        mark_done gsl
		refresh_pkgconfig
    fi

    # =========================================================================
    # 8.5 Eigen3 (Header-only - NO dependencies)
    # =========================================================================
    CURRENT_PACKAGE="eigen3"
    if ! is_installed eigen3 "$NLAB_EXEC/include/eigen3/Eigen/Core"; then
        download https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.gz eigen-3.4.0.tar.gz
        extract eigen-3.4.0.tar.gz eigen-3.4.0
        cd eigen-3.4.0
        rm -rf build && mkdir build && cd build
        setup_build_env
        
        cmake .. \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DINCLUDE_INSTALL_DIR="$NLAB_EXEC/include/eigen3" \
            -DCMAKE_C_COMPILER="$CC" \
            -DCMAKE_CXX_COMPILER="$CXX"
        make install
        mark_done eigen3
    fi

    # =========================================================================
    # 8.6 Eigen5 (Header-only - NO dependencies)
    # =========================================================================
    CURRENT_PACKAGE="eigen5"
    if ! is_installed eigen5 "$NLAB_EXEC/include/eigen5/Eigen/Core"; then
        download https://gitlab.com/libeigen/eigen/-/archive/5.0.0/eigen-5.0.0.tar.bz2 eigen-5.0.0.tar.bz2
        extract eigen-5.0.0.tar.bz2 eigen-5.0.0
        cd eigen-5.0.0
        rm -rf build && mkdir build && cd build
        setup_build_env
        
        cmake .. \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DINCLUDE_INSTALL_DIR="$NLAB_EXEC/include/eigen5" \
            -DCMAKE_C_COMPILER="$CC" \
            -DCMAKE_CXX_COMPILER="$CXX"
        make install
        mark_done eigen5
		refresh_pkgconfig
    fi

    # =========================================================================
    # 8.7 SuiteSparse (NEEDS OpenBLAS - NO MPI)
    # =========================================================================
    CURRENT_PACKAGE="suitesparse"
    if ! is_installed suitesparse "$NLAB_EXEC/lib/libsuitesparseconfig.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d SuiteSparse ] && git clone https://github.com/DrTimothyAldenDavis/SuiteSparse.git
        cd SuiteSparse
        rm -rf build && mkdir build && cd build
        setup_build_env  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=ON \
            -DSUITESPARSE_USE_OPENMP=ON \
            -DBLA_VENDOR=OpenBLAS \
            -DBLAS_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
            -DLAPACK_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DCMAKE_C_FLAGS="-O3 -mcpu=apple-m2 -fPIC -Wno-error=implicit-function-declaration" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS"  -DCMAKE_Fortran_FLAGS="$FFLAGS"

        cmake --build . -j$NPROC
        cmake --install .
        mark_done suitesparse
		refresh_pkgconfig
    fi

    # =========================================================================
    # 8.8 OpenFOAM 11 (NEEDS OpenMPI + OpenBLAS)
    # =========================================================================
 # CURRENT_PACKAGE="openfoam"
 # if ! is_installed openfoam "$NLAB_EXEC/OpenFOAM-11/etc/bashrc"; then
 #     cd "$NLAB_SRC/git"
 #     [ ! -d OpenFOAM-11 ] && git clone https://github.com/OpenFOAM/OpenFOAM-11.git
 #     [ ! -d ThirdParty-11 ] && git clone https://github.com/OpenFOAM/ThirdParty-11.git
 #
 #     cd OpenFOAM-11
 #     setup_build_env mpi  
 #
 #     # Set OpenFOAM environment
 #     export WM_PROJECT_INST_DIR="$NLAB_EXEC/OpenFOAM-11"
 #     export FOAM_INST_DIR="$NLAB_EXEC"
 #     export WM_COMPILER=Gcc
 #     export WM_MPLIB=SYSTEMOPENMPI
 #     export MPI_ARCH_FLAGS="-I$NLAB_EXEC/include"
 #     export MPI_ARCH_LIBS="-L$NLAB_EXEC/lib -lmpi"
 #     
 #     # Source OpenFOAM environment
 #     source etc/bashrc 2>/dev/null || {
 #         echo "⚠️  OpenFOAM bashrc has issues - continuing with manual setup"
 #         export FOAM_APPBIN="$WM_PROJECT_INST_DIR/platforms/darwin64GccDPInt32Opt/bin"
 #         export FOAM_LIBBIN="$WM_PROJECT_INST_DIR/platforms/darwin64GccDPInt32Opt/lib"
 #     }
 #
 #     # Compile
 #     ./Allwmake -j$NPROC 2>&1 | tee build.log
 #     
 #     # Create symlinks to binaries if build succeeded
 #     if [ -d "$WM_PROJECT_INST_DIR/platforms" ]; then
 #         find "$WM_PROJECT_INST_DIR/platforms" -name "bin" -type d | while read bindir; do
 #             ln -sf "$bindir"/* "$NLAB_EXEC/bin/" 2>/dev/null || true
 #         done
 #     fi
 #
 #     mark_done openfoam
 #		refresh_pkgconfig
 # fi
    phase_end
}
