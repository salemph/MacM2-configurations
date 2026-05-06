# -----------------------------------------------------------------------------
# Phase 13 – VTK + ParaView
# -----------------------------------------------------------------------------
phase13() {
    phase_start "PHASE 13: Visualization (VTK, ParaView)" 13 "clang" || return 0

    # MPI check
    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # =========================================================================
    # 13.1 VTK (NEEDS MPI + Qt5 for GUI)
    # =========================================================================
    CURRENT_PACKAGE="vtk"
    if ! is_installed vtk "$NLAB_EXEC/lib/libvtkCommonCore-9.2.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d VTK ] && git clone https://gitlab.kitware.com/vtk/vtk.git VTK
        cd VTK && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DBUILD_SHARED_LIBS=ON \
            -DVTK_GROUP_ENABLE_MPI=YES \
            -DVTK_GROUP_ENABLE_Qt=YES \
            -DVTK_QT_VERSION=5 \
            -DQt5_DIR="$NLAB_EXEC/lib/cmake/Qt5" \
            -DVTK_GROUP_ENABLE_Web=NO \
            -DVTK_USE_EXTERNAL_HDF5=ON \
            -DHDF5_ROOT="$NLAB_EXEC" \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"

        make -j$NPROC && make install
        mark_done vtk
        refresh_pkgconfig
    fi

    # =========================================================================
    # 13.2 ParaView (NEEDS VTK + MPI + Qt5)
    # =========================================================================
    CURRENT_PACKAGE="paraview"
    if ! is_installed paraview "$NLAB_EXEC/bin/paraview"; then
        cd "$NLAB_SRC/git"
        [ ! -d paraview ] && git clone --recursive https://gitlab.kitware.com/paraview/paraview.git
        cd paraview && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DPARAVIEW_USE_QT=ON \
            -DQt5_DIR="$NLAB_EXEC/lib/cmake/Qt5" \
            -DPARAVIEW_USE_MPI=ON \
            -DPARAVIEW_USE_PYTHON=ON \
            -DPython3_ROOT_DIR="$NLAB_EXEC" \
            -DPARAVIEW_BUILD_SHARED_LIBS=ON \
            -DVTK_DIR="$NLAB_EXEC/lib/cmake/vtk-9.2" \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"

        make -j$NPROC && make install
        mark_done paraview
        refresh_pkgconfig
    fi

    # =========================================================================
    # 13.3 Octave (needs OpenBLAS, FFTW - will skip if not available)
    # =========================================================================
    CURRENT_PACKAGE="octave"
    if ! is_installed octave "$NLAB_EXEC/bin/octave"; then
        download https://ftp.gnu.org/gnu/octave/octave-9.2.0.tar.gz octave-9.2.0.tar.gz
        extract octave-9.2.0.tar.gz octave-9.2.0
        cd octave-9.2.0
       
        # Build flags depending on what's available
        local CONFIGURE_ARGS="--prefix=$NLAB_EXEC --disable-gui"
       
        if [ -f "$NLAB_EXEC/lib/libopenblas.dylib" ]; then
            CONFIGURE_ARGS="$CONFIGURE_ARGS --with-blas='-L$NLAB_EXEC/lib -lopenblas'"
        fi
        if [ -f "$NLAB_EXEC/lib/libfftw3.dylib" ]; then
            CONFIGURE_ARGS="$CONFIGURE_ARGS --with-fftw3='-L$NLAB_EXEC/lib -lfftw3'"
            CONFIGURE_ARGS="$CONFIGURE_ARGS --with-fftw3f='-L$NLAB_EXEC/lib -lfftw3f'"
        fi
       
        ./configure $CONFIGURE_ARGS \
            CC="$CC" CXX="$CXX" FC="$FC" \
            CPPFLAGS="$CPPFLAGS" \
            LDFLAGS="$LDFLAGS"
        make -j$NPROC && make install
        mark_done octave
        refresh_pkgconfig
    fi

    phase_end
}