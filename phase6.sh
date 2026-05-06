# -----------------------------------------------------------------------------
# Phase 6 – MPI
# -----------------------------------------------------------------------------
phase6() {
    phase_start "PHASE 6: MPI (OpenMPI)" 6 "mpi" || return 0
    setup_build_env
	refresh_pkgconfig

    CURRENT_PACKAGE="openmpi"
    if ! is_installed openmpi "$NLAB_EXEC/bin/mpicc"; then
        download https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.10.tar.gz openmpi-5.0.10.tar.gz
        extract openmpi-5.0.10.tar.gz openmpi-5.0.10
        cd openmpi-5.0.10
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared --enable-static \
                    CC="$NLAB_EXEC/bin/gcc" \
                    CXX="$NLAB_EXEC/bin/g++" \
                    FC="$NLAB_EXEC/bin/gfortran" \
                    --enable-mpi-fortran=yes \
                    --with-hwloc=internal \
                    --with-libevent=internal \
                    --enable-mpi1-compatibility \
                    --without-verbs
        make -j$NPROC && make install
        
        # Verify MPI works
        $NLAB_EXEC/bin/mpicc --version
        mark_done openmpi
    fi
    phase_end
}