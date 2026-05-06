phase10() {
    phase_start "PHASE 10: I/O Libraries (HDF5, PnetCDF, NetCDF, CDF, ADIOS2)" 10 "mpi" || return 0

    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # 10.1 xtl
    CURRENT_PACKAGE="xtl"
    if ! is_installed xtl "$NLAB_EXEC/include/xtl/xtl_config.hpp"; then
        cd "$NLAB_SRC/git"
        [ ! -d xtl ] && git clone https://github.com/xtensor-stack/xtl.git
        cd xtl && rm -rf build && mkdir build && cd build
        setup_build_env
        cmake .. -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC"
        make install && mark_done xtl && refresh_pkgconfig
    fi

    # 10.2 xtensor
    CURRENT_PACKAGE="xtensor"
    if ! is_installed xtensor "$NLAB_EXEC/include/xtensor/xtensor_config.hpp"; then
        cd "$NLAB_SRC/git"
        [ ! -d xtensor ] && git clone https://github.com/xtensor-stack/xtensor.git
        cd xtensor && rm -rf build && mkdir build && cd build
        setup_build_env
        cmake .. -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" -DCMAKE_PREFIX_PATH="$NLAB_EXEC"
        make install && mark_done xtensor
    fi

    # 10.3 HDF5
    CURRENT_PACKAGE="hdf5"
    if ! is_installed hdf5 "$NLAB_EXEC/lib/libhdf5.dylib"; then
        cd "$NLAB_SRC/tarballs"
        extract hdf5-1.14.5.tar.gz hdf5-1.14.5
        cd hdf5-1.14.5
        setup_build_env mpi
        ./configure --prefix="$NLAB_EXEC" --enable-parallel --enable-shared \
                    --enable-fortran --enable-cxx --with-zlib="$NLAB_EXEC"
        make -j$NPROC && make install
        mark_done hdf5 && refresh_pkgconfig
    fi

    # 10.4 PnetCDF
    CURRENT_PACKAGE="pnetcdf"
    if ! is_installed pnetcdf "$NLAB_EXEC/lib/libpnetcdf.dylib"; then
        cd "$NLAB_SRC/tarballs"
        extract pnetcdf-1.14.1.tar.gz pnetcdf-1.14.1
        cd pnetcdf-1.14.1
        setup_build_env mpi
        ./configure --prefix="$NLAB_EXEC" --enable-shared
        make -j$NPROC && make install
        mark_done pnetcdf && refresh_pkgconfig
    fi

    # 10.5 NetCDF-C
    CURRENT_PACKAGE="netcdf-c"
    if ! is_installed netcdf-c "$NLAB_EXEC/lib/libnetcdf.dylib"; then
        cd "$NLAB_SRC/tarballs/netcdf-c-4.9.2"
        setup_build_env mpi
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-netcdf-4 \
                    --enable-pnetcdf --with-hdf5="$NLAB_EXEC" --with-zlib="$NLAB_EXEC"
        make -j$NPROC && make install
        mark_done netcdf-c && refresh_pkgconfig
    fi

    # 10.6 NetCDF-Fortran
    CURRENT_PACKAGE="netcdf-fortran"
    if ! is_installed netcdf-fortran "$NLAB_EXEC/lib/libnetcdff.dylib"; then
        cd "$NLAB_SRC/tarballs/netcdf-fortran-4.6.1"
        setup_build_env mpi
        ./configure --prefix="$NLAB_EXEC"
        make -j$NPROC && make install
        mark_done netcdf-fortran && refresh_pkgconfig
    fi

    # 10.8 ADIOS2
    CURRENT_PACKAGE="adios2"
    if ! is_installed adios2 "$NLAB_EXEC/lib/libadios2.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d adios2 ] && git clone https://github.com/ornladios/ADIOS2.git adios2
        cd adios2 && rm -rf build && mkdir build && cd build
        setup_build_env mpi
        cmake .. -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
                 -DADIOS2_USE_MPI=ON -DADIOS2_USE_HDF5=ON -DADIOS2_USE_NetCDF=ON \
                 -DHDF5_ROOT="$NLAB_EXEC" -DBUILD_SHARED_LIBS=ON  -DADIOS2_USE_Python=ON -DADIOS2_USE_Fortran=ON 
        make -j$NPROC && make install
        mark_done adios2 && refresh_pkgconfig
    fi
    phase_end
   
}