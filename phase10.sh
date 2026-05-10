# =============================================================================
# PHASE 10: Partitioning (METIS, ParMETIS, Scotch, Zoltan, hypre, JUBE)
# =============================================================================
phase10() {
    phase_start "PHASE 10: Partitioning (METIS, ParMETIS, Scotch, Zoltan, hypre, JUBE)" 10 "mpi" || return 0

    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # =========================================================================
    # 10.1 METIS - SERIAL (Use GCC 16, NOT MPI)
    # =========================================================================
    CURRENT_PACKAGE="metis"
    if ! is_installed metis "$NLAB_EXEC/lib/libmetis.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d METIS ] && git clone https://github.com/KarypisLab/METIS.git
        cd METIS
        rm -rf build && mkdir build && cd build
        
        echo "🔨 Building METIS (serial, GCC 16)..."
        
        # CRITICAL: METIS is serial - use $CC (GCC 16), NOT mpicc!
        # BUT use the SAME GCC 16 that everything else uses!
        cmake .. \
            -DCMAKE_C_COMPILER="$CC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DGKLIB_PATH="../GKlib" \
            -DSHARED=ON \
            -DOPENMP=OFF \
            -DCMAKE_C_FLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            -DCMAKE_EXE_LINKER_FLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        
        make -j$NPROC && make install
        
        # Create pkg-config
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/metis.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: METIS
Description: Serial Graph Partitioning (GCC 16)
Version: 5.2.1
Libs: -L\${libdir} -lmetis
Cflags: -I\${includedir}
EOF
        mark_done metis
        refresh_pkgconfig
    else
        echo "✅ METIS already installed"
    fi

    # =========================================================================
    # 10.2 ParMETIS - PARALLEL (Uses MPI wrappers → GCC 16)
    # =========================================================================
    CURRENT_PACKAGE="parmetis"
    if ! is_installed parmetis "$NLAB_EXEC/lib/libparmetis.dylib"; then
        if [ ! -f "$NLAB_EXEC/lib/libmetis.dylib" ]; then
            echo "❌ METIS not found. Install METIS first."; exit 1
        fi
        
        cd "$NLAB_SRC/git"
        [ ! -d ParMETIS ] && git clone https://github.com/KarypisLab/ParMETIS.git
        cd ParMETIS
        rm -rf build && mkdir build && cd build
        
        echo "🔨 Building ParMETIS (parallel, GCC 16 via MPI)..."
        
        # MPI wrappers ($MPICC) wrap GCC 16 - consistent ABI!
        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DMETIS_PATH="$NLAB_EXEC" \
            -DGKLIB_PATH="$NLAB_SRC/git/METIS/GKlib" \
            -DSHARED=ON \
            -DOPENMP=OFF \
            -DCMAKE_C_FLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            -DCMAKE_EXE_LINKER_FLAGS="-L$NLAB_EXEC/lib -lmetis -Wl,-rpath,$NLAB_EXEC/lib"
        
        make -j$NPROC && make install
        
        # Create pkg-config
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/parmetis.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: ParMETIS
Description: Parallel Graph Partitioning (GCC 16, MPI)
Version: 4.0.3
Requires: metis
Libs: -L\${libdir} -lparmetis -lmetis
Cflags: -I\${includedir}
EOF
        mark_done parmetis
        refresh_pkgconfig
    else
        echo "✅ ParMETIS already installed"
    fi

    # =========================================================================
    # 10.3 Scotch & PT-Scotch (GCC 16 + MPI for parallel)
    # =========================================================================
    CURRENT_PACKAGE="scotch"
    if ! is_installed scotch "$NLAB_EXEC/lib/libscotch.dylib"; then
        cd "$NLAB_SRC/tarballs"
        [ ! -f scotch-v7.0.11.tar.gz ] && \
            download https://gitlab.inria.fr/scotch/scotch/-/archive/v7.0.11/scotch-v7.0.11.tar.gz scotch-v7.0.11.tar.gz
        extract scotch-v7.0.11.tar.gz scotch-v7.0.11
        cd scotch-v7.0.11/src
        
        echo "🔨 Building Scotch & PT-Scotch 7.0.11 (64-bit, GCC 16)..."
        
        make realclean 2>/dev/null || true
        rm -f Makefile.inc
        
        cat > Makefile.inc << EOF
EXE             =
LIB             = .dylib
OBJ             = .o

MAKE            = make
AR              = $AR         
CAT             = cat
CCS             = $CC         
CCP             = $MPICC      
CCD             = $CC         
RANLIB          = $RANLIB     
CP              = cp
LEX             = flex
LN              = ln
MKDIR           = mkdir -p
MV              = mv
YACC            = bison -y

CFLAGS          = -O3 -mcpu=apple-m2 -fPIC \
                 -I$NLAB_EXEC/include \
                 -DCOMMON_FILE_COMPRESS_GZ \
                 -DCOMMON_PTHREAD \
                 -DCOMMON_RANDOM_FIXED_SEED \
                 -DSCOTCH_RENAME \
                 -DCOMMON_TIMING_OLD \
                 -D_SC_NPROCESSORS_CONF=_SC_NPROCESSORS_ONLN \
                 -DIDXSIZE64 \
                 -DINTSIZE64

CLIBFLAGS       = -dynamiclib
LDFLAGS         = -L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib -lz -lm -lpthread

prefix          = $NLAB_EXEC
bindir          = \$(prefix)/bin
includedir      = \$(prefix)/include
libdir          = \$(prefix)/lib
datarootdir     = \$(prefix)/share
mandir          = \$(datarootdir)/man
EOF

        # Build serial Scotch (GCC 16)
        echo "   Building Scotch (serial, GCC 16)..."
        make -j$NPROC scotch
        
        # Build parallel PT-Scotch (GCC 16 via MPI)
        echo "   Building PT-Scotch (parallel, GCC 16 via MPI)..."
        make -j$NPROC ptscotch
        
        # Install
        make install prefix="$NLAB_EXEC"
        
        mark_done scotch
        refresh_pkgconfig
    else
        echo "✅ Scotch already installed"
    fi

    # =========================================================================
    # 10.4 Zoltan (GCC 16 via MPI)
    # =========================================================================
    CURRENT_PACKAGE="zoltan"
    if ! is_installed zoltan "$NLAB_EXEC/lib/libzoltan.dylib"; then
        cd "$NLAB_SRC/tarballs"
        [ ! -f zoltan-3.901.tar.gz ] && \
            download https://github.com/sandialabs/Zoltan/archive/refs/tags/v3.901.tar.gz zoltan-3.901.tar.gz
        extract zoltan-3.901.tar.gz zoltan-3.901
        
        [ -d "Zoltan-3.901" ] && mv Zoltan-3.901 zoltan-3.901 2>/dev/null || true
        
        cd zoltan-3.901
        rm -rf build && mkdir build && cd build
        
        echo "🔨 Building Zoltan 3.901 (GCC 16 via MPI)..."
        
        ../configure \
            --prefix="$NLAB_EXEC" \
            --enable-shared \
            --enable-mpi \
            --with-gnumake \
            CC="$MPICC" \
            CXX="$MPICXX" \
            FC="$MPIFC" \
            CFLAGS="-O3 -mcpu=apple-m2 -fPIC -I$NLAB_EXEC/include" \
            CXXFLAGS="-O3 -mcpu=apple-m2 -fPIC -I$NLAB_EXEC/include" \
            FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch" \
            LDFLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        
        make -j$NPROC everything
        make install
        
        mark_done zoltan
        refresh_pkgconfig
    else
        echo "✅ Zoltan already installed"
    fi

    # =========================================================================
    # 10.5 hypre (GCC 16 via MPI)
    # =========================================================================
    CURRENT_PACKAGE="hypre"
    if ! is_installed hypre "$NLAB_EXEC/lib/libHYPRE.dylib"; then
        if [ ! -f "$NLAB_EXEC/lib/libopenblas.dylib" ]; then
            echo "❌ OpenBLAS not found. Run Phase 8 first."; exit 1
        fi
        
        cd "$NLAB_SRC/tarballs"
        [ ! -f hypre-2.31.0.tar.gz ] && \
            download https://github.com/hypre-space/hypre/archive/refs/tags/v2.31.0.tar.gz hypre-2.31.0.tar.gz
        extract hypre-2.31.0.tar.gz hypre-2.31.0
        cd hypre-2.31.0/src
        setup_build_env mpi

        echo "🔨 Building hypre 2.31.0 (GCC 16 via MPI)..."
        
        make distclean 2>/dev/null || true
        
        ./configure \
            --prefix="$NLAB_EXEC" \
            --enable-shared \
            --with-MPI \
            --with-openmp \
            --with-blas-libs="-lopenblas" \
            --with-blas-lib-dirs="$NLAB_EXEC/lib" \
            --with-lapack-libs="-lopenblas" \
            --with-lapack-lib-dirs="$NLAB_EXEC/lib" \
            CC="$MPICC" \
            CXX="$MPICXX" \
            F77="$MPIFC" \
            CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            CXXFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch" \
            LDFLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        
        make -j$NPROC && make install
        
        mark_done hypre
        refresh_pkgconfig
    else
        echo "✅ hypre already installed"
    fi

    # =========================================================================
    # 10.6 JUBE (Python-based, NO compiler needed)
    # =========================================================================
    CURRENT_PACKAGE="jube"
    if ! is_installed jube "$NLAB_EXEC/bin/jube"; then
        cd "$NLAB_SRC/tarballs"
        
        for dir in JUBE-* jube-*; do
            if [ -d "$dir" ]; then
                echo "🔨 Installing JUBE from $dir..."
                cd "$dir"
                "$NLAB_EXEC/bin/python3" -m pip install . --prefix="$NLAB_EXEC" 2>/dev/null || \
                "$NLAB_EXEC/bin/python3" setup.py install --prefix="$NLAB_EXEC" 2>/dev/null || {
                    echo "⚠️  JUBE installation failed - not critical"
                }
                break
            fi
        done
        
        mark_done jube
        refresh_pkgconfig
    else
        echo "✅ JUBE already installed"
    fi

    # =========================================================================
    # Phase 10 Summary
    # =========================================================================
    echo ""
    echo "✅ Phase 10 Complete (ALL built with GCC 16 ABI):"
    echo "   - METIS 5.2.1 (serial, GCC 16)"
    echo "   - ParMETIS 4.0.3 (parallel, GCC 16 via MPI)"
    echo "   - Scotch/PT-Scotch 7.0.11 (64-bit, GCC 16)"
    echo "   - Zoltan 3.901 (GCC 16 via MPI)"
    echo "   - hypre 2.31.0 (GCC 16 via MPI)"
    echo "   - JUBE (Python, no compiler)"
    echo ""
    
    phase_end
}
