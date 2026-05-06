# -----------------------------------------------------------------------------
# Phase 14 – Nuclear tools
# -----------------------------------------------------------------------------
phase14() {
    phase_start "PHASE 14: Nuclear Tools (ROOT, Geant4, OpenMC, MOOSE, PyNE)" 14 "clang" || return 0

    # MPI check
    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # =========================================================================
    # 14.0 DAGMC (Direct Accelerated Geometry Monte Carlo - NEEDS MOAB + MPI)
    # =========================================================================
    CURRENT_PACKAGE="dagmc"
    if ! is_installed dagmc "$NLAB_EXEC/lib/libdagmc.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d DAGMC ] && git clone https://github.com/svalinn/DAGMC.git
        cd DAGMC && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DMOAB_DIR="$NLAB_EXEC" \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done dagmc
        refresh_pkgconfig
    fi

    # =========================================================================
    # 14.1 ROOT (Data Analysis Framework - NEEDS MPI + Python + HDF5 + Qt5)
    # =========================================================================
    CURRENT_PACKAGE="root"
    if ! is_installed root "$NLAB_EXEC/bin/root"; then
        cd "$NLAB_SRC/git"
        [ ! -d root ] && git clone --branch v6-32-00 https://github.com/root-project/root.git root
        cd root && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -Dhdf5=ON \
            -Dmpi=ON \
            -Dpython=ON \
            -DPYTHON_EXECUTABLE="$NLAB_EXEC/bin/python3" \
            -Dcocoa=ON \
            -Dbuiltin_glew=ON \
            -Dminuit2=ON \
            -Droofit=ON \
            -Dtmva=ON \
            -Dxrootd=ON \
            -Druntime_cxxmodules=OFF \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        
        # Source ROOT environment for later builds
        if [ -f "$NLAB_EXEC/bin/thisroot.sh" ]; then
            source "$NLAB_EXEC/bin/thisroot.sh" 2>/dev/null || true
        fi
        mark_done root
        refresh_pkgconfig
    fi

    # =========================================================================
    # 14.2 Geant4 (Particle Transport - NEEDS ROOT + Qt5 + OpenGL/X11 + MPI)
    # =========================================================================
    CURRENT_PACKAGE="geant4"
    if ! is_installed geant4 "$NLAB_EXEC/bin/geant4-config"; then
        cd "$NLAB_SRC/tarballs"
        download https://geant4-data.web.cern.ch/geant4-data/releases/geant4-v11.3.1.tar.gz geant4-v11.3.1.tar.gz
        extract geant4-v11.3.1.tar.gz geant4-v11.3.1
        cd geant4-v11.3.1 && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DGEANT4_INSTALL_DATA=ON \
            -DGEANT4_USE_OPENGL_X11=ON \
            -DGEANT4_USE_QT=ON \
            -DQt5_DIR="$NLAB_EXEC/lib/cmake/Qt5" \
            -DGEANT4_USE_ROOT=ON \
            -DROOT_DIR="$NLAB_EXEC" \
            -DGEANT4_BUILD_MULTITHREADED=ON \
            -DGEANT4_USE_SYSTEM_EXPAT=OFF \
            -DGEANT4_USE_MPI=ON \
            -DGEANT4_USE_HDF5=ON \
            -DHDF5_ROOT="$NLAB_EXEC" \
            -DGEANT4_USE_GDML=ON \
            -DXERCESC_ROOT_DIR="$NLAB_EXEC" \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done geant4
        refresh_pkgconfig
    fi

    # =========================================================================
    # 14.3 OpenMC (Monte Carlo - NEEDS HDF5 + MPI)
    # =========================================================================
    CURRENT_PACKAGE="openmc"
    if ! is_installed openmc "$NLAB_EXEC/bin/openmc"; then
        cd "$NLAB_SRC/git"
        [ ! -d openmc ] && git clone https://github.com/openmc-dev/openmc.git
        cd openmc && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DHDF5_ROOT="$NLAB_EXEC" \
            -DOPENMC_USE_MPI=ON \
            -DOPENMC_USE_PYTHON=ON \
            -DPYTHON_EXECUTABLE="$NLAB_EXEC/bin/python3" \
            -DOPENMC_USE_DAGMC=OFF \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install

        # Install Python bindings
        $NLAB_EXEC/bin/pip3 install openmc
        
        # Download nuclear data if not present
        if [ ! -f "$NLAB_DATA/openmc/cross_sections.xml" ]; then
            echo "📥 Downloading OpenMC nuclear data (this may take a while)..."
            mkdir -p "$NLAB_DATA/openmc"
            $NLAB_EXEC/bin/openmc-ace-to-hdf5 --help 2>/dev/null || true
        fi
        mark_done openmc
        refresh_pkgconfig
    fi

    # =========================================================================
    # 14.4 MOOSE (Multiphysics Framework - NEEDS PETSc + libMesh + MPI)
    # =========================================================================
    CURRENT_PACKAGE="moose"
    if ! is_installed moose "$NLAB_EXEC/bin/moose-opt"; then
        cd "$NLAB_SRC/git"
        [ ! -d moose ] && git clone https://github.com/idaholab/moose.git
        cd moose
        setup_build_env mpi  

        export PETSC_DIR="$NLAB_EXEC"
        export LIBMESH_DIR="$NLAB_EXEC"
        export MOOSE_JOBS=$NPROC
        export METHOD=opt
        
        # Configure with all available dependencies
        ./configure --prefix="$NLAB_EXEC" \
            --with-petsc="$PETSC_DIR" \
            --with-libmesh="$LIBMESH_DIR" \
            CC="$MPICC" CXX="$MPICXX" FC="$MPIFC" \
            CFLAGS="$CFLAGS" \
            CXXFLAGS="-O3 -mcpu=apple-m2 -fPIC -I$NLAB_EXEC/include" \
            FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
        
        make -j$NPROC
        
        # Create symlinks for MOOSE binaries
        if [ -d "test" ]; then
            find . -name "moose-opt" -type f -exec ln -sf {} "$NLAB_EXEC/bin/" \; 2>/dev/null || true
        fi
        
        mark_done moose
        refresh_pkgconfig
    fi

    # =========================================================================
    # 14.5 KOMODO/ADPRES (Nuclear Reactor Simulator - NO MPI, Fortran only)
    # =========================================================================
    CURRENT_PACKAGE="komodo"
    if ! is_installed komodo "$NLAB_EXEC/bin/komodo"; then
        cd "$NLAB_SRC/git"
        [ ! -d ADPRES ] && git clone https://github.com/imronuke/ADPRES.git
        cd ADPRES
        
        setup_build_env
        # Build with Fortran compiler
        $FC -O3 -mcpu=apple-m2 -fPIC -o komodo *.f90
        cp komodo "$NLAB_EXEC/bin/"
        mark_done komodo
        refresh_pkgconfig
    fi

    # =========================================================================
    # 14.6 NJOY 2016 (Nuclear Data Processing - NO MPI, Fortran)
    # =========================================================================
    if [ -d "$NLAB_SRC/tarballs/NJOY2016" ]; then
        CURRENT_PACKAGE="njoy"
        if ! is_installed njoy "$NLAB_EXEC/bin/njoy"; then
            cd "$NLAB_SRC/tarballs/NJOY2016"
            setup_build_env  

            mkdir -p build && cd build
            cmake .. \
                -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
                -DCMAKE_Fortran_COMPILER="$FC" \
                -DCMAKE_Fortran_FLAGS="$FFLAGS"
            make -j$NPROC && make install
            mark_done njoy
            refresh_pkgconfig
        fi
    fi

    # =========================================================================
    # 14.7 MCNP2CAD (MCNP to CAD conversion - NEEDS MOAB + MPI)
    # =========================================================================
    CURRENT_PACKAGE="mcnp2cad"
    if ! is_installed mcnp2cad "$NLAB_EXEC/bin/mcnp2cad"; then
        cd "$NLAB_SRC/git"
        [ ! -d mcnp2cad ] && git clone https://github.com/svalinn/mcnp2cad.git
        cd mcnp2cad && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DMOAB_DIR="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done mcnp2cad
        refresh_pkgconfig
    fi

    # =========================================================================
    # 14.8 MCPL (Monte Carlo Particle Lists - NO MPI)
    # =========================================================================
    CURRENT_PACKAGE="mcpl"
    if ! is_installed mcpl "$NLAB_EXEC/bin/mcpl"; then
        cd "$NLAB_SRC/git"
        [ ! -d mcpl ] && git clone https://github.com/mctools/mcpl.git
        cd mcpl && rm -rf build && mkdir build && cd build
        setup_build_env  

        cmake .. \
            -DCMAKE_C_COMPILER="$CC" \
            -DCMAKE_CXX_COMPILER="$CXX" \
            -DCMAKE_Fortran_COMPILER="$FC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done mcpl
        refresh_pkgconfig
    fi

    echo "⚠️ MCNP requires manual download from RSICC (https://rsicc.ornl.gov)."

    # =========================================================================
    # 14.9 PyNE (Nuclear Engineering Toolkit - NEEDS MOAB + HDF5 + Python)
    # =========================================================================
    CURRENT_PACKAGE="pyne"
    if ! is_installed pyne "$NLAB_EXEC/bin/pyne"; then
        cd "$NLAB_SRC/git"
        [ ! -d pyne ] && git clone https://github.com/pyne/pyne.git
        cd pyne
        setup_build_env mpi  

        # Build and install PyNE
        $NLAB_EXEC/bin/python3 setup.py install \
            --prefix="$NLAB_EXEC" \
            --moab="$NLAB_EXEC" \
            --hdf5="$NLAB_EXEC" \
            --no-deps
        
        # Generate nuclear data if needed
        if [ ! -f "$NLAB_EXEC/share/pyne/nuc_data.h5" ]; then
            echo "📥 Generating PyNE nuclear data (this will take a while)..."
            $NLAB_EXEC/bin/nuc_data_make 2>/dev/null || true
        fi
        mark_done pyne
        refresh_pkgconfig
    fi

    phase_end
}