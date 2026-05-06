# -----------------------------------------------------------------------------
# Phase 9 – Partitioning
# -----------------------------------------------------------------------------
phase9() {
    phase_start "PHASE 9: Partitioning (METIS, ParMETIS, hypre, Zoltan)" 9 "mpi" || return 0

    # MPI check
    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # =========================================================================
    # 9.1 METIS (Serial partitioning - NO MPI needed)
    # =========================================================================
    CURRENT_PACKAGE="metis"
    if ! is_installed metis "$NLAB_EXEC/lib/libmetis.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d METIS ] && git clone https://github.com/KarypisLab/METIS.git
        cd METIS
        setup_build_env  

        make distclean 2>/dev/null || true
        rm -rf build CMakeCache.txt CMakeFiles libmetis/CMakeFiles 2>/dev/null

        # Build with shared library support
        make config shared=1 prefix="$NLAB_EXEC" cc="$CC" arch=armv8.5-a
        make -j$NPROC && make install
        
        # Create pkg-config file
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/metis.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: METIS
Description: Serial Graph Partitioning and Fill-reducing Matrix Ordering
Version: 5.2.1
Libs: -L\${libdir} -lmetis
Cflags: -I\${includedir}
EOF
        mark_done metis
		refresh_pkgconfig
    fi

# =========================================================================
# 9.2 ParMETIS (Parallel partitioning - NEEDS MPI + METIS)
# =========================================================================
CURRENT_PACKAGE="parmetis"
if ! is_installed parmetis "$NLAB_EXEC/lib/libparmetis.dylib"; then
    cd "$NLAB_SRC/git"
    [ ! -d ParMETIS ] && git clone https://github.com/KarypisLab/ParMETIS.git
    cd ParMETIS
    setup_build_env mpi  

    make distclean 2>/dev/null || true
    
    # ParMETIS needs METIS headers
    make config shared=1 prefix="$NLAB_EXEC" cc="$CC" \
         CFLAGS="$CFLAGS" \
         LDFLAGS="$LDFLAGS"
    make -j$NPROC && make install

    # Create pkg-config file
    cat > "$NLAB_EXEC/lib/pkgconfig/parmetis.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: ParMETIS
Description: Parallel Graph Partitioning and Fill-reducing Matrix Ordering
Version: 4.0.3
Requires: metis
Libs: -L\${libdir} -lparmetis -lmetis
Cflags: -I\${includedir}
EOF
        mark_done parmetis
		refresh_pkgconfig
    fi

 # =========================================================================
 # 9.3 Scotch (Partitioning - NEEDS MPI, optional)
 # =========================================================================
	CURRENT_PACKAGE="scotch"
	if ! is_installed scotch "$NLAB_EXEC/lib/libscotch.dylib"; then
	    download https://gitlab.inria.fr/scotch/scotch/-/archive/v7.0.11/scotch-v7.0.11.tar.gz scotch-v7.0.11.tar.gz
	    extract scotch-v7.0.11.tar.gz scotch-v7.0.11
	    cd scotch-v7.0.11/src   
	    setup_build_env mpi
		
     make distclean 2>/dev/null || true
     
     # Generate proper Makefile.inc for macOS with GCC
     cat > Makefile.inc << EOF
EXE             =
LIB             = .dylib
OBJ             = .o
MAKE            = make
AR              = $AR
CAT             = cat
CCS             = $CC
CCP             = $CC
CCD             = $CC
CFLAGS          = -O3 -mcpu=apple-m2 -fPIC -I$NLAB_EXEC/include  -DCOMMON_FILE_COMPRESS_GZ -DCOMMON_PTHREAD  -DCOMMON_RANDOM_FIXED_SEED -DSCOTCH_RENAME -DCOMMON_TIMING_OLD  -D_SC_NPROCESSORS_CONF=_SC_NPROCESSORS_ONLN
CLIBFLAGS       = -shared -fPIC
LDFLAGS         = -L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib -lz -lm -lpthread
CP              = cp
LEX             = flex
LN              = ln
MKDIR           = mkdir -p
MV              = mv
RANLIB          = $RANLIB
YACC            = bison -y
prefix          = $NLAB_EXEC
bindir          = \$(prefix)/bin
includedir      = \$(prefix)/include
libdir          = \$(prefix)/lib
datarootdir     = \$(prefix)/share
mandir          = \$(datarootdir)/man
EOF

        make -j$NPROC
        make install prefix="$NLAB_EXEC"
        mark_done scotch
		refresh_pkgconfig
    fi

 # =========================================================================
 # 9.4 hypre (Parallel solvers/preconditioners - NEEDS MPI + OpenBLAS)
 # =========================================================================
 CURRENT_PACKAGE="hypre"
 if ! is_installed hypre "$NLAB_EXEC/lib/libHYPRE.dylib"; then
     download https://github.com/hypre-space/hypre/archive/refs/tags/v2.31.0.tar.gz hypre-2.31.0.tar.gz
     extract hypre-2.31.0.tar.gz hypre-2.31.0
     cd hypre-2.31.0/src
     setup_build_env mpi 

		./configure \
		    --prefix=/Volumes/nlab/exec \
		    --enable-shared \
		    --with-MPI \
		    --with-blas-libs="-lopenblas" \
		    --with-blas-lib-dirs="/Volumes/nlab/exec/lib" \
		    --with-lapack-libs="-lopenblas" \
		    --with-lapack-lib-dirs="/Volumes/nlab/exec/lib" \
		    --with-scalapack-libs="-lscalapack" \
		    --with-scalapack-lib-dirs="/Volumes/nlab/exec/lib" \
		    CC=/Volumes/nlab/exec/bin/mpicc \
		    CXX=/Volumes/nlab/exec/bin/mpicxx \
		    F77=/Volumes/nlab/exec/bin/mpifort \
		    CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
		    CXXFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
		    FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
		
     make -j$NPROC && make install
     mark_done hypre
 fi

 # =========================================================================
 # 9.5 Zoltan (Dynamic load balancing - NEEDS MPI)
 # =========================================================================
 CURRENT_PACKAGE="zoltan"
 if ! is_installed zoltan "$NLAB_EXEC/lib/libzoltan.dylib"; then
   #download https://github.com/sandialabs/Zoltan/archive/refs/tags/v3.901.tar.gz zoltan-3.901.tar.gz
   #extract zoltan-3.901.tar.gz zoltan-3.901
   #cd zoltan-3.901
   #rm -rf build && mkdir build && cd build
     setup_build_env mpi  
		cd /Volumes/nlab/source/tarballs

		# Check what directory was actually created
		ls -d Zoltan* zoltan* 2>/dev/null

		# The GitHub archive likely extracts to Zoltan-3.901 (capital Z)
		# Fix: rename to lowercase or cd to the actual name
		if [ -d "Zoltan-3.901" ]; then
		    mv Zoltan-3.901 zoltan-3.901
		fi

		# Now build
		cd zoltan-3.901
		rm -rf build && mkdir build && cd build
		setup_build_env mpi

		../configure \
		    --prefix=/Volumes/nlab/exec \
		    --enable-shared --enable-static \
		    --enable-mpi --with-gnumake \
		    --with-scotch \
		    --with-scotch-incdir="/Volumes/nlab/exec/include" \
		    --with-scotch-libdir="/Volumes/nlab/exec/lib" \
		    CC="$MPICC" CXX="$MPICXX" FC="$MPIFC" \
		    CFLAGS="-O3 -mcpu=apple-m2 -fPIC -I/Volumes/nlab/exec/include" \
		    CXXFLAGS="-O3 -mcpu=apple-m2 -fPIC -I/Volumes/nlab/exec/include" \
		    FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch" \
		    LDFLAGS="-L/Volumes/nlab/exec/lib -Wl,-rpath,/Volumes/nlab/exec/lib"

		make -j$(sysctl -n hw.perflevel0.logicalcpu) everything && make install
		touch /Volumes/nlab/exec/.nlab_installed/zoltan
		echo "✅ Zoltan installed"
     mark_done zoltan
		refresh_pkgconfig
 fi

 # =========================================================================
 # 9.6 JUBE (Benchmarking environment - Python, NO MPI needed)
 # =========================================================================
 CURRENT_PACKAGE="jube"
	cd /Volumes/nlab/source/tarballs

	# You have JUBE-2.7.1, not jube-2.5.2
	if [ -d "JUBE-2.7.1" ]; then
	    cd JUBE-2.7.1
	    setup_build_env
	    /Volumes/nlab/exec/bin/python3 setup.py install --prefix=/Volumes/nlab/exec
	    touch /Volumes/nlab/exec/.nlab_installed/jube
	    echo "✅ JUBE 2.7.1 installed"
	fi
    phase_end
}
