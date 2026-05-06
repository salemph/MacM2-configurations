# -----------------------------------------------------------------------------
# Phase 3 – Graphics extras
# -----------------------------------------------------------------------------
phase3() {
    phase_start "PHASE 3: Graphics Extras (libgd, poppler, swig)" 3 "gcc" || return 0
    phase_start "PHASE 3: Graphics Extras" 3 "gcc" || return 0
    
    setup_build_env

    # 3.1 libtiff (needs zlib, libjpeg from Phase 2)
    CURRENT_PACKAGE="libtiff"
    if ! is_installed libtiff "$NLAB_EXEC/lib/libtiff.dylib"; then
        download https://download.osgeo.org/libtiff/tiff-4.6.0.tar.gz tiff-4.6.0.tar.gz
        extract tiff-4.6.0.tar.gz tiff-4.6.0
        cd tiff-4.6.0
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static \
                    CC="$CC" \
                    CPPFLAGS="$CPPFLAGS" \
                    LDFLAGS="$LDFLAGS"
        make -j$NPROC && make install
        mark_done libtiff
		refresh_pkgconfig
    fi

    # 3.2 libgd (needs libpng, libjpeg, freetype, fontconfig from Phase 2)
    CURRENT_PACKAGE="libgd"
    if ! is_installed libgd "$NLAB_EXEC/lib/libgd.dylib"; then
        download https://github.com/libgd/libgd/releases/download/gd-2.3.3/libgd-2.3.3.tar.xz libgd-2.3.3.tar.xz
        extract libgd-2.3.3.tar.xz libgd-2.3.3
        cd libgd-2.3.3
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static \
                    --with-png="$NLAB_EXEC" \
                    --with-jpeg="$NLAB_EXEC" \
                    --with-freetype="$NLAB_EXEC" \
                    --with-fontconfig="$NLAB_EXEC" \
                    CC="$CC" \
                    CPPFLAGS="$CPPFLAGS" \
                    LDFLAGS="$LDFLAGS"
        make -j$NPROC && make install
        mark_done libgd
		refresh_pkgconfig
    fi

	# 3.3 boost - try GCC, fallback to Clang
	CURRENT_PACKAGE="boost"
	if ! is_installed boost "$NLAB_EXEC/lib/libboost_system.dylib"; then
	    download https://archives.boost.io/release/1.86.0/source/boost_1_86_0.tar.bz2 boost_1_86_0.tar.bz2
	    extract boost_1_86_0.tar.bz2 boost_1_86_0
	    cd boost_1_86_0
    
	    # Try GCC first
	    setup_build_env
	    echo "using gcc : : $NLAB_EXEC/bin/g++ ;" > user-config.jam
	    ./bootstrap.sh --prefix="$NLAB_EXEC" --with-toolset=gcc
    
	    if ! ./b2 --prefix="$NLAB_EXEC" --user-config=user-config.jam --with-system -j$NPROC linkflags="-L$NLAB_EXEC/lib" 2>&1 | tee /tmp/boost_build.log; then
	        echo "⚠️ GCC build failed, trying Clang..."
	        setup_clang_env
	        echo "using clang : : $CXX : <cxxflags>\"-std=c++14 -stdlib=libc++\" ;" > user-config.jam
	        ./bootstrap.sh --prefix="$NLAB_EXEC" --with-toolset=clang --with-libraries=system,filesystem,program_options,regex,thread,date_time,iostreams,serialization,test
	    fi
    
	    ./b2 --prefix="$NLAB_EXEC" \
	         --user-config=user-config.jam \
	         --with-system \
	         --with-filesystem \
	         --with-program_options \
	         --with-regex \
	         --with-thread \
	         --with-date_time \
	         --with-iostreams \
	         --with-serialization \
	         --with-test \
	         -j$NPROC \
	         cxxflags="-O3 -mcpu=apple-m2 -fPIC ${CXXFLAGS}" \
	         linkflags="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib" \
	         install
	    mark_done boost
	    refresh_pkgconfig
	fi

    # 3.4 poppler (PDF library - needs libtiff, libpng, libjpeg, boost)
    CURRENT_PACKAGE="poppler"
    if ! is_installed poppler "$NLAB_EXEC/lib/libpoppler.dylib"; then
        download https://poppler.freedesktop.org/poppler-24.12.0.tar.xz poppler-24.12.0.tar.xz
        extract poppler-24.12.0.tar.xz poppler-24.12.0
        cd poppler-24.12.0
        rm -rf build && mkdir build && cd build
        
        cmake -G "Unix Makefiles" \
            -DCMAKE_C_COMPILER="$CC" \
            -DCMAKE_CXX_COMPILER="$CXX" \
            -DCMAKE_Fortran_COMPILER="$FC" \
            -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
            -DCMAKE_PREFIX_PATH="$NLAB_EXEC" \
            -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_QT5=OFF \
            -DENABLE_QT6=OFF \
            -DENABLE_GLIB=OFF \
            -DENABLE_GOBJECT_INTROSPECTION=OFF \
            -DENABLE_NSS3=OFF \
            -DENABLE_GPGME=OFF \
            -DENABLE_LCMS=OFF \
            -DENABLE_BOOST=OFF \
            -DWITH_JPEG=ON \
            -DWITH_PNG=ON \
            -DWITH_TIFF=ON \
            -DJPEG_LIBRARY="$NLAB_EXEC/lib/libjpeg.dylib" \
            -DJPEG_INCLUDE_DIR="$NLAB_EXEC/include" \
            -DPNG_LIBRARY="$NLAB_EXEC/lib/libpng.dylib" \
            -DPNG_INCLUDE_DIR="$NLAB_EXEC/include" \
            -DTIFF_LIBRARY="$NLAB_EXEC/lib/libtiff.dylib" \
            -DTIFF_INCLUDE_DIR="$NLAB_EXEC/include" \
            -DZLIB_LIBRARY="$NLAB_EXEC/lib/libz.dylib" \
            -DZLIB_INCLUDE_DIR="$NLAB_EXEC/include" \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS"  -DCMAKE_Fortran_FLAGS="$FFLAGS" \
            -DCMAKE_EXE_LINKER_FLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib" \
            -DCMAKE_SHARED_LINKER_FLAGS="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib" \
            ..
        
        make -j$NPROC && make install
        mark_done poppler
		refresh_pkgconfig
    fi

    # 3.5 SWIG (interface generator - needed by many scientific Python bindings)
    CURRENT_PACKAGE="swig"
    if ! is_installed swig "$NLAB_EXEC/bin/swig"; then
        download https://github.com/swig/swig/archive/refs/tags/v4.3.0.tar.gz swig-4.3.0.tar.gz
        extract swig-4.3.0.tar.gz swig-4.3.0
        cd swig-4.3.0
        ./autogen.sh
        ./configure --prefix="$NLAB_EXEC" \
                    --without-pcre \
                    CC="$CC" CXX="$CXX" \
                    CPPFLAGS="$CPPFLAGS" \
                    LDFLAGS="$LDFLAGS"
        make -j$NPROC && make install
        mark_done swig
		refresh_pkgconfig
    fi

    # 3.6 GTS (GNU Triangulated Surface library - needed by some mesh tools)
    CURRENT_PACKAGE="gts"
    if ! is_installed gts "$NLAB_EXEC/lib/libgts.dylib"; then
        download https://gts.sourceforge.net/tarballs/gts-snapshot-121130.tar.gz gts-snapshot-121130.tar.gz
        extract gts-snapshot-121130.tar.gz gts-snapshot-121130
        cd gts-snapshot-121130
        [ -f Makefile ] && make distclean 2>/dev/null || true
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared --enable-static \
                    CC="$CC" \
                    CPPFLAGS="$CPPFLAGS" \
                    LDFLAGS="$LDFLAGS"
        make -j$NPROC && make install
        mark_done gts
		refresh_pkgconfig
    fi
	
}

