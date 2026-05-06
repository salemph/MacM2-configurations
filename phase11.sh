# -----------------------------------------------------------------------------
# Phase 11 – Mesh & Geometry
# -----------------------------------------------------------------------------
phase11() {
    phase_start "PHASE 11: Mesh Tools (MOAB, DAGMC, Mesquite, deal.ii)" 11 "mpi" || return 0

    # MPI check
    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi
	# =========================================================================
	    # 11.1 p4est (Parallel Adaptive Mesh Refinement - NEEDS MPI)
	    # =========================================================================
	    CURRENT_PACKAGE="p4est"
	    if ! is_installed p4est "$NLAB_EXEC/lib/libp4est.dylib"; then
	        cd "$NLAB_SRC/git"
	        [ ! -d p4est ] && git clone https://github.com/cburstedde/p4est.git
	        cd p4est && ./bootstrap && mkdir build && cd build
	        setup_build_env mpi

	        # p4est is traditionally built with autotools
	        ../configure --prefix="$NLAB_EXEC" \
	                     --enable-mpi \
	                     --enable-shared \
	                     --with-blas="$NLAB_EXEC/lib/libopenblas.dylib" \
	                     --with-lapack="$NLAB_EXEC/lib/libopenblas.dylib" \
	                     CC="$MPICC" CXX="$MPICXX" FC="$MPIFC"
	        make -j$NPROC && make install
	        mark_done p4est
	        refresh_pkgconfig
	    fi
    # =========================================================================
    # 11.2 MOAB (Mesh-Oriented datABase - NEEDS MPI + HDF5 + NetCDF)
    # =========================================================================
    CURRENT_PACKAGE="moab"
	if [[ -f "$NLAB_EXEC/lib/libMOAB.dylib" ]]; then
	        echo "✅ MOAB detected at $NLAB_EXEC/lib/libMOAB.dylib. Skipping build."
	        # Ensure the marker exists so phase 11 doesn't try to trigger again
	        [[ ! -f "$MARKER_DIR/moab" ]] && mark_done moab
	    else
	    cd "$NLAB_SRC/git/moab"
	    git pull 2>/dev/null || true
	    rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DMOAB_USE_MPI=ON \
            -DMOAB_USE_HDF5=ON \
            -DHDF5_ROOT="$NLAB_EXEC" \
            -DMOAB_USE_NETCDF=ON \
            -DMOAB_USE_PNETCDF=ON \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS"  -DCMAKE_Fortran_FLAGS="$FFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done moab
		refresh_pkgconfig
    fi

    # =========================================================================
    # 11.3 Mesquite (Mesh quality improvement - NEEDS MOAB + MPI)
    # =========================================================================
	#CURRENT_PACKAGE="mesquite"
	#if ! is_installed mesquite "$NLAB_EXEC/lib/libmesquite.dylib"; then
	#    cd "$NLAB_SRC/git"
	#    [ ! -d mesquite ] && git clone https://github.com/sandialabs/mesquite.git
	#    cd mesquite
	#    setup_build_env mpi
    #
	#    make distclean 2>/dev/null || true
	#    autoreconf -fi 2>/dev/null || true
    #
	#    ./configure \
	#        --prefix="$NLAB_EXEC" \
	#		--with-mpi \
	#		CXX="$MPICXX" \
	#		CC="$MPICC" \
	#		CFLAGS="$CFLAGS" \
	#        --host=aarch64-apple-darwin \
	#        --build=x86_64-apple-darwin \
	#        --enable-shared \
	#        --with-moab="$NLAB_EXEC" \
	#        --with-hdf5="$NLAB_EXEC" \
	#        --with-netcdf="$NLAB_EXEC" \
	#        CXXFLAGS="$CXXFLAGS -std=gnu++17 -I/Volumes/nlab/exec/include/c++/16.0.1 -I/Volumes/nlab/exec/include/c++/16.0.1/aarch64-apple-darwin21" \
	#        FFLAGS="$FFLAGS" \
	#        LDFLAGS="$LDFLAGS"
    #
	#    make -j$NPROC && make install
	#    mark_done mesquite
	#    refresh_pkgconfig
	#fi
    phase_end
}