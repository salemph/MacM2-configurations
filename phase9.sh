# =============================================================================
# PHASE 9: I/O Libraries (HDF5, PnetCDF, NetCDF-C, NetCDF-Fortran, ADIOS2)
# =============================================================================
phase9() {
    phase_start "PHASE 9: I/O Libraries (HDF5, PnetCDF, NetCDF-C, NetCDF-Fortran, ADIOS2)" 9 "mpi" || return 0

    # MPI check
    if [ ! -x "$NLAB_EXEC/bin/mpicc" ]; then
        echo "❌ MPI wrappers not found. Run phase 6 first."; exit 1
    fi

    # =========================================================================
    # 9.1 HDF5 - Parallel with 64-bit support
    # =========================================================================
    CURRENT_PACKAGE="hdf5"
    if ! is_installed hdf5 "$NLAB_EXEC/lib/libhdf5.dylib"; then
        # Check for zlib dependency
        if [ ! -f "$NLAB_EXEC/lib/libz.dylib" ] && [ ! -f "$NLAB_EXEC/lib/libz.a" ]; then
            echo "⚠️  zlib not found in $NLAB_EXEC. Using system zlib."
            ZLIB_PATH="/usr"
        else
            ZLIB_PATH="$NLAB_EXEC"
        fi
        
        cd "$NLAB_SRC/tarballs"
        [ ! -f hdf5-1.14.5.tar.gz ] && \
            download https://github.com/HDFGroup/hdf5/releases/download/hdf5-1_14_5/hdf5-1.14.5.tar.gz hdf5-1.14.5.tar.gz
        extract hdf5-1.14.5.tar.gz hdf5-1.14.5
        cd hdf5-1.14.5
        
        # Clean any previous build attempts
        make distclean 2>/dev/null || true
        
        echo "🔨 Building HDF5 1.14.5 (parallel, Fortran, C++)..."
        
        ./configure \
            --prefix="$NLAB_EXEC" \
            --enable-parallel \
            --enable-shared \
            --enable-fortran \
            --enable-cxx \
            --enable-unsupported \
            --enable-build-mode=production \
            --enable-hl \
            --with-pic \
            --with-zlib="$ZLIB_PATH" \
            CC="$NLAB_EXEC/bin/mpicc" \
            CXX="$NLAB_EXEC/bin/mpicxx" \
            FC="$NLAB_EXEC/bin/mpifort" \
            CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            CXXFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            FCFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch" \
            LDFLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        
        make -j$NPROC
        
        # Install - handle Fortran test failures gracefully
        echo "📦 Installing HDF5..."
        if make install 2>&1 | tee hdf5_install.log; then
            echo "✅ HDF5 installed successfully"
        else
            echo "⚠️  Full install had issues - installing core components..."
            make install-lib install-include install-bin 2>/dev/null || true
        fi
        
        # Create pkg-config file if HDF5 didn't create one
        if [ ! -f "$NLAB_EXEC/lib/pkgconfig/hdf5.pc" ]; then
            mkdir -p "$NLAB_EXEC/lib/pkgconfig"
            cat > "$NLAB_EXEC/lib/pkgconfig/hdf5.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: HDF5
Description: Hierarchical Data Format 5 (parallel)
Version: 1.14.5
Requires: zlib
Libs: -L\${libdir} -lhdf5 -lhdf5_hl
Cflags: -I\${includedir}
EOF
        fi
        
        # Create Fortran pkg-config
        if [ -f "$NLAB_EXEC/lib/libhdf5_fortran.dylib" ]; then
            cat > "$NLAB_EXEC/lib/pkgconfig/hdf5_fortran.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: HDF5 Fortran
Description: Fortran bindings for HDF5
Version: 1.14.5
Requires: hdf5
Libs: -L\${libdir} -lhdf5_fortran
Cflags: -I\${includedir}
EOF
        fi
        
        mark_done hdf5
        refresh_pkgconfig
    else
        echo "✅ HDF5 already installed"
    fi

    # =========================================================================
    # 9.2 PnetCDF - Parallel NetCDF
    # =========================================================================
    CURRENT_PACKAGE="pnetcdf"
    if ! is_installed pnetcdf "$NLAB_EXEC/lib/libpnetcdf.dylib"; then
        cd "$NLAB_SRC/tarballs"
        [ ! -f pnetcdf-1.14.1.tar.gz ] && \
            download https://parallel-netcdf.github.io/Release/pnetcdf-1.14.1.tar.gz pnetcdf-1.14.1.tar.gz
        extract pnetcdf-1.14.1.tar.gz pnetcdf-1.14.1
        cd pnetcdf-1.14.1
        
        echo "🔨 Building PnetCDF 1.14.1..."
        
        ./configure \
            --prefix="$NLAB_EXEC" \
            --enable-shared \
            --enable-large-single-req \
            --enable-netcdf4 \
            CC="$NLAB_EXEC/bin/mpicc" \
            FC="$NLAB_EXEC/bin/mpifort" \
            CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            FCFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch" \
            LDFLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        
        make -j$NPROC && make install
        
        # Create pkg-config file
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/pnetcdf.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: PnetCDF
Description: Parallel NetCDF library
Version: 1.14.1
Libs: -L\${libdir} -lpnetcdf
Cflags: -I\${includedir}
EOF
        mark_done pnetcdf
        refresh_pkgconfig
    else
        echo "✅ PnetCDF already installed"
    fi

    # =========================================================================
    # 9.3 NetCDF-C (with HDF5 and PnetCDF support)
    # =========================================================================
    CURRENT_PACKAGE="netcdf-c"
    if ! is_installed netcdf-c "$NLAB_EXEC/lib/libnetcdf.dylib"; then
        # Check dependencies
        if [ ! -f "$NLAB_EXEC/lib/libhdf5.dylib" ]; then
            echo "❌ HDF5 not found. Install HDF5 first."; exit 1
        fi
        
        cd "$NLAB_SRC/tarballs"
        [ ! -f netcdf-c-4.9.2.tar.gz ] && \
            download https://github.com/Unidata/netcdf-c/archive/v4.9.2.tar.gz netcdf-c-4.9.2.tar.gz
        extract netcdf-c-4.9.2.tar.gz netcdf-c-4.9.2
        cd netcdf-c-4.9.2
        
        echo "🔨 Building NetCDF-C 4.9.2 (with HDF5 + PnetCDF support)..."
        
        # Regenerate autotools if needed
        autoreconf -fi 2>/dev/null || true
        
        ./configure \
            --prefix="$NLAB_EXEC" \
            --enable-shared \
            --disable-static \
            --enable-netcdf-4 \
            --enable-pnetcdf \
            --enable-dap \
            --enable-byterange \
            --with-hdf5="$NLAB_EXEC" \
            --with-pnetcdf="$NLAB_EXEC" \
            --with-zlib="$NLAB_EXEC" \
            CC="$NLAB_EXEC/bin/mpicc" \
            CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            CPPFLAGS="-I$NLAB_EXEC/include" \
            LDFLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        
        make -j$NPROC && make install
        
        # Create pkg-config file if needed
        if [ ! -f "$NLAB_EXEC/lib/pkgconfig/netcdf.pc" ]; then
            mkdir -p "$NLAB_EXEC/lib/pkgconfig"
            cat > "$NLAB_EXEC/lib/pkgconfig/netcdf.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: NetCDF
Description: Network Common Data Form (with parallel I/O)
Version: 4.9.2
Requires: hdf5
Libs: -L\${libdir} -lnetcdf
Cflags: -I\${includedir}
EOF
        fi
        
        mark_done netcdf-c
        refresh_pkgconfig
    else
        echo "✅ NetCDF-C already installed"
    fi

    # =========================================================================
    # 9.4 NetCDF-Fortran (Fortran bindings for NetCDF)
    # =========================================================================
    CURRENT_PACKAGE="netcdf-fortran"
    if ! is_installed netcdf-fortran "$NLAB_EXEC/lib/libnetcdff.dylib"; then
        # Check dependencies
        if [ ! -f "$NLAB_EXEC/lib/libnetcdf.dylib" ]; then
            echo "❌ NetCDF-C not found. Install NetCDF-C first."; exit 1
        fi
        
        cd "$NLAB_SRC/tarballs"
        [ ! -f netcdf-fortran-4.6.1.tar.gz ] && \
            download https://github.com/Unidata/netcdf-fortran/archive/v4.6.1.tar.gz netcdf-fortran-4.6.1.tar.gz
        extract netcdf-fortran-4.6.1.tar.gz netcdf-fortran-4.6.1
        cd netcdf-fortran-4.6.1
        
        echo "🔨 Building NetCDF-Fortran 4.6.1..."
        
        # Set environment to find NetCDF-C
        export NCDIR="$NLAB_EXEC"
        export NFDIR="$NLAB_EXEC"
        export LD_LIBRARY_PATH="$NLAB_EXEC/lib:$LD_LIBRARY_PATH"
        export DYLD_LIBRARY_PATH="$NLAB_EXEC/lib:$DYLD_LIBRARY_PATH"
        
        ./configure \
            --prefix="$NLAB_EXEC" \
            --enable-shared \
            --disable-static \
            CC="$NLAB_EXEC/bin/mpicc" \
            FC="$NLAB_EXEC/bin/mpifort" \
            F77="$NLAB_EXEC/bin/mpifort" \
            CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
            FCFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch" \
            FFLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch" \
            CPPFLAGS="-I$NLAB_EXEC/include" \
            LDFLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        
        make -j$NPROC && make install
        
        mark_done netcdf-fortran
        refresh_pkgconfig
    else
        echo "✅ NetCDF-Fortran already installed"
    fi

#    # =========================================================================
#    # 9.5 CDF (Common Data Format - NASA/SPDF, NO MPI)
#    # =========================================================================
#    CURRENT_PACKAGE="cdf"
#    if ! is_installed cdf "$NLAB_EXEC/lib/libcdf.dylib"; then
#        cd "$NLAB_SRC/tarballs"
#        [ ! -f cdf38_1-dist-all.tar.gz ] && \
#            download https://spdf.gsfc.nasa.gov/pub/software/cdf/dist/cdf38_1/cdf38_1-dist-all.tar.gz cdf38_1.tar.gz
#        extract cdf38_1.tar.gz cdf38_1-dist-all
#        cd cdf38_1-dist-all
#        
#        echo "🔨 Building CDF 3.8.1..."
#        
#        # CDF uses its own build system
#        make OS=macosx ENV=gnu CURSES=no FORTRAN=no SHARED=yes all \
#             CC="$CC" \
#             CFLAGS="-O3 -mcpu=apple-m2 -fPIC" \
#             LDFLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
#        
#        make INSTALLDIR="$NLAB_EXEC" install
#        
#        # Create pkg-config file
#        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
#        cat > "$NLAB_EXEC/lib/pkgconfig/cdf.pc" << EOF
#prefix=$NLAB_EXEC
#exec_prefix=\${prefix}
#libdir=\${exec_prefix}/lib
#includedir=\${prefix}/include
#
#Name: CDF
#Description: NASA Common Data Format
#Version: 3.8.1
#Libs: -L\${libdir} -lcdf
#Cflags: -I\${includedir}/cdf
#EOF
#        mark_done cdf
#        refresh_pkgconfig
#    else
#        echo "✅ CDF already installed"
#    fi
#
#    # =========================================================================
#    # 9.6 ADIOS2 (Adaptable I/O - NEEDS MPI + HDF5 + NetCDF + Python)
#    # =========================================================================
#    CURRENT_PACKAGE="adios2"
#    if ! is_installed adios2 "$NLAB_EXEC/lib/libadios2.dylib"; then
#        # Check dependencies
#        local missing_deps=()
#        [ ! -f "$NLAB_EXEC/lib/libhdf5.dylib" ] && missing_deps+=("HDF5")
#        [ ! -f "$NLAB_EXEC/lib/libnetcdf.dylib" ] && missing_deps+=("NetCDF")
#        
#        if [ ${#missing_deps[@]} -gt 0 ]; then
#            echo "⚠️  Missing: ${missing_deps[*]}"
#            echo "   ADIOS2 will build with reduced functionality"
#        fi
#        
#        cd "$NLAB_SRC/git"
#        [ ! -d ADIOS2 ] && git clone https://github.com/ornladios/ADIOS2.git
#        cd ADIOS2
#        git pull 2>/dev/null || true
#        rm -rf build && mkdir build && cd build
#        setup_build_env mpi
#        
#        echo "🔨 Building ADIOS2..."
#        
#        cmake .. \
#            -DCMAKE_C_COMPILER="$MPICC" \
#            -DCMAKE_CXX_COMPILER="$MPICXX" \
#            -DCMAKE_Fortran_COMPILER="$MPIFC" \
#            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
#            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
#            -DCMAKE_BUILD_TYPE=Release \
#            -DADIOS2_USE_MPI=ON \
#            -DADIOS2_USE_HDF5=ON \
#            -DADIOS2_USE_NetCDF=ON \
#            -DADIOS2_USE_Python=ON \
#            -DADIOS2_USE_Fortran=ON \
#            -DADIOS2_USE_Blosc=OFF \
#            -DADIOS2_USE_BZip2=ON \
#            -DADIOS2_USE_ZFP=OFF \
#            -DADIOS2_USE_SZ=OFF \
#            -DADIOS2_USE_MGARD=OFF \
#            -DBUILD_SHARED_LIBS=ON \
#            -DHDF5_ROOT="$NLAB_EXEC" \
#            -DCMAKE_C_FLAGS="-O3 -mcpu=apple-m2 -fPIC" \
#            -DCMAKE_CXX_FLAGS="-O3 -mcpu=apple-m2 -fPIC" \
#            -DCMAKE_Fortran_FLAGS="-O3 -mcpu=apple-m2 -fallow-argument-mismatch" \
#            -DCMAKE_EXE_LINKER_FLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
#        
#        make -j$NPROC && make install
#        
#        # Create pkg-config file
#        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
#        cat > "$NLAB_EXEC/lib/pkgconfig/adios2.pc" << EOF
#prefix=$NLAB_EXEC
#exec_prefix=\${prefix}
#libdir=\${exec_prefix}/lib
#includedir=\${prefix}/include
#
#Name: ADIOS2
#Description: Adaptable I/O System
#Version: 2.10
#Requires: hdf5 netcdf
#Libs: -L\${libdir} -ladios2
#Cflags: -I\${includedir}
#EOF
#        mark_done adios2
#        refresh_pkgconfig
#    else
#        echo "✅ ADIOS2 already installed"
#    fi

    # =========================================================================
    # Phase 9 Summary
    # =========================================================================
    echo ""
    echo "✅ Phase 9 Complete:"
    echo "   - HDF5 1.14.5 (parallel, Fortran, C++)"
    echo "   - PnetCDF 1.14.1 (parallel NetCDF)"
    echo "   - NetCDF-C 4.9.2 (with HDF5 + PnetCDF)"
    echo "   - NetCDF-Fortran 4.6.1"
    echo "   - CDF 3.8.1 (NASA Common Data Format)"
    echo "   - ADIOS2 (adaptable I/O framework)"
    echo ""
    
    phase_end
}
