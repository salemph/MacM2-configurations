# -----------------------------------------------------------------------------
# Phase 8 – Linear Algebra (Fixed)
# -----------------------------------------------------------------------------
phase8() {
    phase_start "PHASE 8: Linear Algebra (OpenBLAS, ScaLAPACK, FFTW, GSL, Eigen3, SuiteSparse)" 8 "gcc" || return 0

    # MPI check (ScaLAPACK and FFTW need it)
    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # =========================================================================
    # 8.1 OpenBLAS (NO MPI - base linear algebra, 64-bit interface)
    # =========================================================================
    CURRENT_PACKAGE="openblas"
    if ! is_installed openblas "$NLAB_EXEC/lib/libopenblas.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d OpenBLAS ] && git clone https://github.com/OpenMathLib/OpenBLAS.git
        cd OpenBLAS
        setup_build_env  # Serial compiler, no MPI
        
        git checkout v0.3.29
        make clean 2>/dev/null || true
        
        echo "🔨 Building OpenBLAS with 64-bit interface for Apple M2..."
        
        # TARGET=VORTEX for M-series, INTERFACE64=1 for 64-bit BLAS
        make -j$NPROC \
            TARGET=VORTEX \
            USE_THREAD=1 \
            NUM_THREADS=8 \
            INTERFACE64=1 \
            SYMBOLSUFFIX= \
            CC="$CC" \
            FC="$FC" \
            CFLAGS="-O3 -mcpu=apple-m2 -fPIC -fopenmp" \
            FFLAGS="-O3 -mcpu=apple-m2 -fPIC -fopenmp" \
            NO_LAPACK=0 \
            NO_AFFINITY=1
        
        make PREFIX="$NLAB_EXEC" install
        
        # Create symlinks for LAPACK compatibility (some codes look for liblapack)
        cd "$NLAB_EXEC/lib"
        ln -sf libopenblas.dylib libblas.dylib 2>/dev/null || true
        ln -sf libopenblas.dylib liblapack.dylib 2>/dev/null || true
        ln -sf libopenblas.a libblas.a 2>/dev/null || true
        ln -sf libopenblas.a liblapack.a 2>/dev/null || true
        
        # Create pkg-config file
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/openblas.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenBLAS
Description: Optimized BLAS library for Apple M2 (64-bit interface)
Version: 0.3.29
Libs: -L\${libdir} -lopenblas
Cflags: -I\${includedir}
EOF
        mark_done openblas
        refresh_pkgconfig
    fi

    # =========================================================================
    # 8.2 ScaLAPACK (NEEDS MPI + OpenBLAS, 64-bit compatible)
    # =========================================================================
    CURRENT_PACKAGE="scalapack"
    if ! is_installed scalapack "$NLAB_EXEC/lib/libscalapack.dylib"; then
        # Check dependency
        if [ ! -f "$NLAB_EXEC/lib/libopenblas.dylib" ]; then
            echo "❌ OpenBLAS not found. Install OpenBLAS first."; exit 1
        fi
        
        download https://github.com/Reference-ScaLAPACK/scalapack/archive/v2.2.2.tar.gz scalapack-2.2.2.tar.gz
        extract scalapack-2.2.2.tar.gz scalapack-2.2.2
        cd scalapack-2.2.2
        setup_build_env mpi  

        echo "🔨 Building ScaLAPACK with CMake for 64-bit compatibility..."
        
        # Use CMake build (more reliable than makefile for macOS)
        rm -rf build && mkdir build && cd build

		cmake .. \
		     -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
		     -DCMAKE_C_COMPILER="$MPICC" \
		     -DCMAKE_Fortran_COMPILER="$MPIFC" \
		     -DBUILD_SHARED_LIBS=ON \
		     -DBUILD_STATIC_LIBS=ON \
		     -DCMAKE_C_FLAGS="-O3 -mcpu=apple-m2 -fPIC -std=gnu89 -Wno-error=implicit-function-declaration -Wno-implicit-function-declaration -Wno-error=implicit-int" \
		     -DCMAKE_Fortran_FLAGS="-O3 -mcpu=apple-m2 -fPIC -fallow-argument-mismatch" \
		     -DLAPACK_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
		     -DBLAS_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib"
		   
        make -j$NPROC
        make install
        
        # Fix library names if CMake adds prefix
        if [ -f "$NLAB_EXEC/lib/libscalapack.dylib" ]; then
            :
        elif [ -f "$NLAB_EXEC/lib/libscalapack.2.2.2.dylib" ]; then
            cd "$NLAB_EXEC/lib"
            ln -sf libscalapack.2.2.2.dylib libscalapack.dylib 2>/dev/null || true
        fi
        
        # Create pkg-config file
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/scalapack.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: ScaLAPACK
Description: Scalable LAPACK for distributed memory systems
Version: 2.2.2
Requires: openblas
Libs: -L\${libdir} -lscalapack
Cflags: -I\${includedir}/scalapack
EOF
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

        echo "🔨 Building FFTW3 (double precision with MPI)..."
        
        # Double precision with MPI
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

        echo "🔨 Building FFTW3f (single precision with MPI)..."
        
        # Single precision with MPI
        make clean
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared \
                    --enable-openmp \
                    --enable-mpi \
                    --enable-threads \
                    --enable-float \
                    CC="$MPICC" \
                    F77="$MPIFC" \
                    MPICC="$MPICC" \
                    CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
                    FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
        make -j$NPROC && make install

        echo "🔨 Building FFTW3l (long double precision)..."
        
        # Long double precision (no MPI needed for this variant)
        make clean
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared \
                    --enable-openmp \
                    --enable-threads \
                    --enable-long-double \
                    CC="$CC" \
                    F77="$FC" \
                    CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
                    FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
        make -j$NPROC && make install

        # Create pkg-config files
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        for precision in 3 3f 3l; do
            cat > "$NLAB_EXEC/lib/pkgconfig/fftw${precision}.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: FFTW${precision}
Description: Fast Fourier Transform library
Version: 3.3.10
Libs: -L\${libdir} -lfftw${precision}
Cflags: -I\${includedir}
EOF
        done
        
        mark_done fftw
        refresh_pkgconfig
    fi

    # =========================================================================
    # 8.4 GSL (GNU Scientific Library - NO MPI)
    # =========================================================================
    CURRENT_PACKAGE="gsl"
    if ! is_installed gsl "$NLAB_EXEC/lib/libgsl.dylib"; then
        download https://ftp.gnu.org/gnu/gsl/gsl-2.8.tar.gz gsl-2.8.tar.gz
        extract gsl-2.8.tar.gz gsl-2.8
        cd gsl-2.8
        setup_build_env  # Serial only
        
        echo "🔨 Building GSL..."
        
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared \
                    --disable-static \
                    CC="$CC" \
                    CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
                    LDFLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        make -j$NPROC && make install
        
        # Create pkg-config file
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/gsl.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: GSL
Description: GNU Scientific Library
Version: 2.8
Libs: -L\${libdir} -lgsl -lgslcblas -lm
Cflags: -I\${includedir}
EOF
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
            -DCMAKE_CXX_COMPILER="$CXX" \
            -DBUILD_TESTING=OFF
        make install
        mark_done eigen3
        refresh_pkgconfig
    fi

    # =========================================================================
    # 8.6 Eigen5 (Header-only - NO dependencies)
    # =========================================================================
    CURRENT_PACKAGE="eigen5"
    if ! is_installed eigen5 "$NLAB_EXEC/include/eigen5/Eigen/Core"; then
        # Added download check for robustness
        if [ ! -f eigen-5.0.0.tar.bz2 ]; then
            download https://gitlab.com/libeigen/eigen/-/archive/5.0.0/eigen-5.0.0.tar.bz2 eigen-5.0.0.tar.bz2
        fi
        extract eigen-5.0.0.tar.bz2 eigen-5.0.0
        cd eigen-5.0.0
        rm -rf build && mkdir build && cd build
        setup_build_env
        
        cmake .. \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DINCLUDE_INSTALL_DIR="$NLAB_EXEC/include/eigen5" \
            -DCMAKE_C_COMPILER="$CC" \
            -DCMAKE_CXX_COMPILER="$CXX" \
            -DBUILD_TESTING=OFF
        make install
        mark_done eigen5
        refresh_pkgconfig
    fi
	
    # =========================================================================
      # 8.7 SuiteSparse (NEEDS OpenBLAS - NO MPI, GCC 16)
      # Includes: GraphBLAS, LAGraph, and all sparse matrix libraries
      # =========================================================================
      CURRENT_PACKAGE="suitesparse"
      if ! is_installed suitesparse "$NLAB_EXEC/lib/libsuitesparseconfig.dylib"; then
          # Check dependency
          if [ ! -f "$NLAB_EXEC/lib/libopenblas.dylib" ]; then
              echo "❌ OpenBLAS not found. Install OpenBLAS first."; exit 1
          fi
        
          cd "$NLAB_SRC/git"
          [ ! -d SuiteSparse ] && git clone https://github.com/DrTimothyAldenDavis/SuiteSparse.git
          cd SuiteSparse
          rm -rf build && mkdir build && cd build
          setup_build_env  # Serial compiler, GCC 16, NO MPI!

          echo "🔨 Building SuiteSparse with 64-bit BLAS (GCC 16)..."

          cmake .. \
              -DCMAKE_C_COMPILER="$CC" \
              -DCMAKE_CXX_COMPILER="$CXX" \
              -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
              -DCMAKE_BUILD_TYPE=Release \
              -DBUILD_SHARED_LIBS=ON \
              -DBUILD_STATIC_LIBS=OFF \
              -DSUITESPARSE_USE_STRICT=OFF \
              -DSUITESPARSE_USE_CUDA=OFF \
              -DSUITESPARSE_USE_OPENMP=ON \
              -DSUITESPARSE_USE_64BIT_BLAS=ON \
              -DBLA_VENDOR=OpenBLAS \
              -DBLAS_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
              -DLAPACK_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
              -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
              -DCMAKE_C_FLAGS="-O3 -mcpu=apple-m2 -fPIC -Wno-error=implicit-function-declaration -Wno-implicit-function-declaration" \
              -DCMAKE_CXX_FLAGS="-O3 -mcpu=apple-m2 -fPIC" \
              -DCMAKE_Fortran_FLAGS="-O3 -mcpu=apple-m2 -fPIC -fallow-argument-mismatch" \
              -DCMAKE_EXE_LINKER_FLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib" \
              -DCMAKE_SHARED_LINKER_FLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"

          cmake --build . -j$NPROC
          cmake --install .
        
          # FIXED: Verify libraries exist before creating symlinks
          # The old code had a dead symlink check that did nothing
          cd "$NLAB_EXEC/lib"
          echo "   Verifying SuiteSparse libraries..."
          for lib in libsuitesparseconfig libamd libbtf libcamd libccolamd \
                     libcholmod libcolamd libcxsparse libklu libldl \
                     libspqr libumfpack libgraphblas liblagraph; do
              if [ -f "${lib}.dylib" ]; then
                  echo "   ✅ ${lib}.dylib"
              elif [ -f "${lib}.so" ]; then
                  echo "   ✅ ${lib}.so"
              else
                  echo "   ⚠️  ${lib} not found - may not have been built"
              fi
          done
        
          # Create pkg-config for SuiteSparse components
          mkdir -p "$NLAB_EXEC/lib/pkgconfig"
          cat > "$NLAB_EXEC/lib/pkgconfig/suitesparse.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: SuiteSparse
Description: Suite of sparse matrix software (with GraphBLAS, LAGraph)
Version: 7.8.0
Requires: openblas
Libs: -L\${libdir} -lsuitesparseconfig -lamd -lbtf -lcamd -lccolamd -lcholmod -lcolamd -lcxsparse -lklu -lldl -lspqr -lumfpack -lgraphblas -llagraph
Cflags: -I\${includedir}/suitesparse
EOF
          mark_done suitesparse
          refresh_pkgconfig
      else
          echo "✅ SuiteSparse already installed"
      fi


	     # =========================================================================
	       # Phase 8 Summary
	       # =========================================================================
	       echo ""
	       echo "✅ Phase 8 Complete (ALL built with GCC 16):"
	       echo "   - OpenBLAS 0.3.29 (64-bit, VORTEX optimized)"
	       echo "   - ScaLAPACK 2.2.2 (parallel, CMake build)"
	       echo "   - FFTW 3.3.10 (double/single/long double, with MPI)"
	       echo "   - GSL 2.8 (GNU Scientific Library)"
	       echo "   - Eigen3 3.4.0 (header-only C++ templates)"
	       echo "   - Eigen5 5.0.0 (header-only C++ templates)"
	       echo "   - SuiteSparse 7.8.0 (with GraphBLAS, LAGraph)"

	       echo ""
   
    phase_end
}
