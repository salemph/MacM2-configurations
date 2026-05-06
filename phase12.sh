# -----------------------------------------------------------------------------
# Phase 12 – High‑level solvers + libMesh
# -----------------------------------------------------------------------------
phase12() {
    phase_start "PHASE 12: High-Level Solvers (SUNDIALS, PETSc, Trilinos, libMesh, STRUMPACK)" 12 "mpi" || return 0

    # MPI check
    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # =========================================================================
    # 12.1 PETSc (NEEDS MPI + OpenBLAS + HDF5 + METIS + ParMETIS)
    # =========================================================================
	CURRENT_PACKAGE="petsc"
	if ! is_installed petsc "$NLAB_EXEC/lib/libpetsc.dylib"; then
	    cd "$NLAB_SRC/git"
	    [ ! -d petsc ] && git clone -b release https://gitlab.com/petsc/petsc.git petsc
	    cd petsc
		export PETSC_DIR=$PWD
		export PETSC_ARCH=arch-darwin-c-opt
			
	    export PETSC_DIR=$PWD
	    export PETSC_ARCH=arch-darwin-c-opt
	    setup_build_env mpi  
		./configure \
		    --prefix="$NLAB_EXEC" \
		    --with-blas-lapack-lib="-L$NLAB_EXEC/lib -lopenblas" \
		    --with-scalapack-lib="-L$NLAB_EXEC/lib -lscalapack" \
		    --with-ptscotch=1 \
		    --with-ptscotch-lib="-L$NLAB_EXEC/lib -lptscotch -lptscotcherr -lscotch -lscotcherr" \
		    --with-ptscotch-include="$NLAB_EXEC/include" \
		    --with-shared-libraries=1 \
		    --with-mpi=1 \
		    --with-64-bit-indices=1 \
		    --with-cc="$MPICC" \
		    --with-cxx="$MPICXX" \
		    --with-fc="$MPIFC" \
		    --with-hdf5-dir="$NLAB_EXEC" \
		    --with-metis-dir="$NLAB_EXEC" \
		    --with-parmetis-dir="$NLAB_EXEC" \
			--download-metis=1 \
			--download-parmetis=1 \
		    --with-zlib-dir="$NLAB_EXEC" \
		    COPTFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
		    CXXOPTFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
		    FOPTFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
    
	    make -j$NPROC all
	    make PETSC_DIR="$PETSC_DIR" PETSC_ARCH="$PETSC_ARCH" install
    
	    # Install Python bindings  --with-64-bit-indices=0 \
	    $NLAB_EXEC/bin/pip3 install petsc4py
    
	    mark_done petsc
	    refresh_pkgconfig
	fi

    # =========================================================================
    # 12.2 SLEPc (NEEDS PETSc)
    # =========================================================================
    CURRENT_PACKAGE="slepc"
    if ! is_installed slepc "$NLAB_EXEC/lib/libslepc.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d slepc ] && git clone https://gitlab.com/slepc/slepc.git
        cd slepc
        git checkout main 2>/dev/null || true
        setup_build_env mpi  

        export SLEPC_DIR="$PWD"
        export PETSC_DIR="$NLAB_EXEC"

        ./configure --prefix="$NLAB_EXEC" \
                    --with-petsc-dir="$PETSC_DIR" \
                    CC="$MPICC" CXX="$MPICXX" FC="$MPIFC"
        make -j$NPROC && make install

        # Python bindings
        $NLAB_EXEC/bin/pip3 install slepc4py

        mark_done slepc
        refresh_pkgconfig
    fi
    export SLEPC_DIR="$NLAB_EXEC"
    
    # =========================================================================
    # 12.3 Trilinos (NEEDS MPI + OpenBLAS + METIS + ParMETIS + Zoltan)
    # =========================================================================
    CURRENT_PACKAGE="trilinos"
    if ! is_installed trilinos "$NLAB_EXEC/lib/libteuchos.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d Trilinos ] && git clone https://github.com/trilinos/Trilinos.git
        cd Trilinos
        git checkout trilinos-release-16-0-0 2>/dev/null || true
        rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
			-DCMAKE_INSTALL_RPATH="$NLAB_EXEC/lib" \
			-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
			-DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DCMAKE_BUILD_TYPE=Release \
            -DTPL_ENABLE_MPI=ON \
            -DTrilinos_ENABLE_ALL_PACKAGES=OFF \
            -DTrilinos_ENABLE_Teuchos=ON \
            -DTrilinos_ENABLE_Epetra=ON \
            -DTrilinos_ENABLE_AztecOO=ON \
            -DTrilinos_ENABLE_ML=ON \
            -DTrilinos_ENABLE_Zoltan=ON \
            -DTrilinos_ENABLE_Ifpack=ON \
            -DTrilinos_ENABLE_Amesos=ON \
            -DTPL_ENABLE_BLAS=ON \
            -DTPL_BLAS_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
            -DTPL_ENABLE_LAPACK=ON \
            -DTPL_LAPACK_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
            -DTPL_ENABLE_HDF5=ON \
            -DHDF5_INCLUDE_DIRS="$NLAB_EXEC/include" \
            -DHDF5_LIBRARY_DIRS="$NLAB_EXEC/lib" \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done trilinos
        refresh_pkgconfig
    fi

    # =========================================================================
    # 12.4 SUNDIALS (NEEDS MPI for parallel solvers)
    # =========================================================================
    CURRENT_PACKAGE="sundials"
    if ! is_installed sundials "$NLAB_EXEC/lib/libsundials_core.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d sundials ] && git clone https://github.com/LLNL/sundials.git
        cd sundials && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
			-DCMAKE_INSTALL_RPATH="$NLAB_EXEC/lib" \
			-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
			-DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DENABLE_MPI=ON \
            -DENABLE_OPENMP=ON \
            -DBUILD_SHARED_LIBS=ON \
            -DENABLE_PETSC=ON \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done sundials
        refresh_pkgconfig
    fi

    # =========================================================================
    # 12.5 DOLFIN (FEniCS - NEEDS PETSc + MPI)
    # =========================================================================
    CURRENT_PACKAGE="dolfin"
    if ! is_installed dolfin "$NLAB_EXEC/lib/libdolfin.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d dolfin ] && git clone https://github.com/FEniCS/dolfin.git
        cd dolfin && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
			-DCMAKE_INSTALL_RPATH="$NLAB_EXEC/lib" \
			-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
			-DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DPETSC_DIR="$NLAB_EXEC" \
            -DDOLFIN_ENABLE_MPI=ON \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done dolfin
        refresh_pkgconfig
    fi

    # =========================================================================
    # 12.6 libMesh (NEEDS PETSc + MOAB + MPI)
    # =========================================================================
    CURRENT_PACKAGE="libmesh"
    if ! is_installed libmesh "$NLAB_EXEC/lib/libmesh_opt.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d libmesh ] && git clone https://github.com/libMesh/libmesh.git
        cd libmesh
        setup_build_env mpi  

        git submodule update --init --recursive
        rm -rf build && mkdir build && cd build
        
        ../configure --prefix="$NLAB_EXEC" \
            --with-methods=opt \
            --enable-shared \
            --disable-static \
            --with-petsc="$NLAB_EXEC" \
            --with-moab="$NLAB_EXEC" \
            --with-hdf5="$NLAB_EXEC" \
            CC="$MPICC" CXX="$MPICXX" FC="$MPIFC" \
            CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            CXXFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch"
        make -j$NPROC && make install
        mark_done libmesh
        refresh_pkgconfig
    fi

    # =========================================================================
    # 12.7 STRUMPACK (NEEDS MPI + METIS + ParMETIS + Scotch)
    # =========================================================================
    CURRENT_PACKAGE="strumpack"
    if ! is_installed strumpack "$NLAB_EXEC/lib/libstrumpack.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d strumpack ] && git clone https://github.com/pghysels/STRUMPACK.git strumpack
        cd strumpack && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
			-DCMAKE_INSTALL_RPATH="$NLAB_EXEC/lib" \
			-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
			-DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DSTRUMPACK_USE_MPI=ON \
            -DSTRUMPACK_USE_OPENMP=ON \
            -DSTRUMPACK_USE_SCOTCH=ON \
            -DSTRUMPACK_USE_METIS=ON \
            -DSTRUMPACK_USE_PARMETIS=ON \
            -DBUILD_SHARED_LIBS=ON \
            -DTPL_BLAS_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
            -DTPL_LAPACK_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        export STRUMPACK_DIR="$NLAB_EXEC"
        mark_done strumpack
        refresh_pkgconfig
    fi

    # =========================================================================
    # 12.8 preCICE (Coupling library - NEEDS MPI + PETSc + Python)
    # =========================================================================
    CURRENT_PACKAGE="precice"
    if ! is_installed precice "$NLAB_EXEC/lib/libprecice.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d precice ] && git clone https://github.com/precice/precice.git
        cd precice && rm -rf build && mkdir build && cd build
        setup_build_env mpi  
        export PYTHONPATH="$NLAB_EXEC/lib/python3.12/site-packages:$PYTHONPATH"

        cmake .. \
			-DCMAKE_INSTALL_RPATH="$NLAB_EXEC/lib" \
			-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
			-DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE \
            -DCMAKE_C_COMPILER="$MPICC" \
            -DCMAKE_CXX_COMPILER="$MPICXX" \
            -DCMAKE_Fortran_COMPILER="$MPIFC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DPRECICE_USE_MPI=ON \
            -DPRECICE_USE_PETSC=ON \
            -DPETSC_DIR="$NLAB_EXEC" \
            -DPRECICE_USE_PYTHON=ON \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_Fortran_FLAGS="$FFLAGS"

        make -j$NPROC && make install

        # Install Python bindings
        $NLAB_EXEC/bin/pip3 install pybind11
        if [ -d "../bindings/python" ]; then
            cd ../bindings/python
            $NLAB_EXEC/bin/pip3 install --prefix="$NLAB_EXEC" .
            cd ../../build
        fi

        mark_done precice
        refresh_pkgconfig
    fi
    export PRECICE_ROOT="$NLAB_EXEC"

    # =========================================================================
    # 12.9 deal.II (Finite element library - NEEDS MPI + PETSc + Trilinos + HDF5)
    # =========================================================================
    CURRENT_PACKAGE="dealii"
    if ! is_installed dealii "$NLAB_EXEC/lib/libdeal_II.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d dealii ] && git clone https://github.com/dealii/dealii.git
        cd dealii && rm -rf build && mkdir build && cd build
        setup_build_env mpi  

        cmake .. \
			-DCMAKE_INSTALL_RPATH="$NLAB_EXEC/lib" \
			-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
			-DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE \
             -DCMAKE_C_COMPILER="$MPICC" \
             -DCMAKE_CXX_COMPILER="$MPICXX" \
             -DCMAKE_Fortran_COMPILER="$MPIFC" \
             -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
             -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
             -DDEAL_II_WITH_MPI=ON \
             -DDEAL_II_WITH_PETSC=ON \
			 -DPETSC_DIR="$NLAB_SRC/git/petsc" \
			 -DPETSC_ARCH="arch-darwin-c-opt" \
             -DDEAL_II_WITH_P4EST=ON \
             -DP4EST_DIR="$NLAB_EXEC" \
             -DDEAL_II_WITH_TRILINOS=ON \
             -DTRILINOS_DIR="$NLAB_EXEC" \
             -DDEAL_II_WITH_HDF5=ON \
             -DDEAL_II_WITH_METIS=ON \
             -DDEAL_II_WITH_LAPACK=ON \
             -DBLAS_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
             -DLAPACK_LIBRARIES="$NLAB_EXEC/lib/libopenblas.dylib" \
             -DCMAKE_C_FLAGS="$CFLAGS" \
             -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
             -DCMAKE_Fortran_FLAGS="$FFLAGS"
        make -j$NPROC && make install
        mark_done dealii
        refresh_pkgconfig
    fi
    export DEAL_II_DIR="$NLAB_EXEC"

    phase_end
}