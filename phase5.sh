# -----------------------------------------------------------------------------
# Phase 5 – QT5 + Graphviz
# -----------------------------------------------------------------------------
phase5() {
    phase_start "PHASE 5: Qt + Graphviz" 5 "clang" || return 0
    setup_build_env
    refresh_pkgconfig

    # 5.1 D-Bus (needed by Qt5 for desktop integration)
    CURRENT_PACKAGE="dbus"
    if ! is_installed dbus "$NLAB_EXEC/lib/libdbus-1.dylib"; then
        download https://dbus.freedesktop.org/releases/dbus/dbus-1.15.8.tar.xz dbus-1.15.8.tar.xz
        extract dbus-1.15.8.tar.xz dbus-1.15.8
        cd dbus-1.15.8
        rm -rf build && mkdir build && cd build

        setup_build_env
        meson setup .. \
            --prefix=/Volumes/nlab/exec \
            --buildtype=release \
            -Dlaunchd=disabled \
            -Dsystemd=disabled \
            -Dx11_autolaunch=enabled \
            --wrap-mode=nofallback
        
        ninja -j$NPROC && ninja install
        mark_done dbus
        refresh_pkgconfig
    fi

    # 5.2 ICU (needed by Qt5 for internationalization)
    CURRENT_PACKAGE="icu"
    if ! is_installed icu "$NLAB_EXEC/lib/libicui18n.dylib"; then
        download https://github.com/unicode-org/icu/releases/download/release-74-2/icu4c-74_2-src.tgz icu4c-74_2-src.tgz
        extract icu4c-74_2-src.tgz icu4c-74_2-src
        cd icu/source  
        setup_clang_env
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-static --enable-shared \
                    --with-data-packaging=library \
                    CC="$CC" CXX="$CXX" \
                    CFLAGS="-O3 -mcpu=apple-m2" \
                    CXXFLAGS="-O3 -mcpu=apple-m2"
        make -j$NPROC && make install
        mark_done icu
        refresh_pkgconfig

        # Create pkg-config files
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/icu-uc.pc" << 'EOF'
prefix=/Volumes/nlab/exec
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include
Name: ICU-uc
Description: International Components for Unicode
Version: 74.2
Libs: -L${libdir} -licuuc -licudata
Cflags: -I${includedir}
EOF
    fi

	# 5.3 Qt5 base (with framework detection)
	CURRENT_PACKAGE="qt5"

	# Check if Qt5 framework already exists (from previous build)
	if [ -d "$NLAB_EXEC/lib/QtCore.framework" ]; then
	    echo "✅ Qt5 framework found, creating symlinks..."
	    create_framework_symlinks QtCore QtGui QtWidgets QtNetwork QtSql QtConcurrent QtDBus QtTest QtXml
	    mark_done qt5
	    refresh_pkgconfig
	    echo "✅ Qt5 symlinks created, skipping rebuild"
    
	# Check if Qt5 dylib already exists (from Homebrew or other)
	elif [ -f "$NLAB_EXEC/lib/libQt5Core.dylib" ]; then
	    echo "✅ Qt5 already installed, marking done"
	    mark_done qt5
	    refresh_pkgconfig
    
	# Otherwise build Qt5 from source
	elif ! is_installed qt5 "$NLAB_EXEC/lib/libQt5Core.dylib"; then
	    echo "🔨 Building Qt5 from source..."
	    download https://download.qt.io/archive/qt/5.15/5.15.15/submodules/qtbase-everywhere-opensource-src-5.15.15.tar.xz qtbase-5.15.15.tar.xz
	    extract qtbase-5.15.15.tar.xz qtbase-everywhere-src-5.15.15
	    cd qtbase-everywhere-src-5.15.15
    
	    setup_clang_env
    
	    ./configure -prefix "$NLAB_EXEC" \
	        -opensource -confirm-license \
	        -nomake examples -nomake tests \
	        -release \
	        -no-glib \
	        -no-gui -no-widgets -no-opengl \
	        -no-dbus -no-icu -no-fontconfig \
	        -qt-zlib -qt-pcre -qt-libpng -qt-libjpeg
    
	    make -j$NPROC
	    make install
    
	    # Create symlinks after build
	    create_framework_symlinks QtCore QtGui QtWidgets QtNetwork QtSql QtConcurrent QtDBus QtTest QtXml
    
	    mark_done qt5
	    refresh_pkgconfig
	fi

    # 5.4 Graphviz
    CURRENT_PACKAGE="graphviz"
    if ! is_installed graphviz "$NLAB_EXEC/bin/dot"; then
        download https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/12.2.1/graphviz-12.2.1.tar.xz graphviz-12.2.1.tar.xz
        extract graphviz-12.2.1.tar.xz graphviz-12.2.1
        cd graphviz-12.2.1
        setup_build_env
        
        export PYTHON="$NLAB_EXEC/bin/python3"
        export PYTHON_INCLUDES="-I$NLAB_EXEC/include/python3.12"
        export PYTHON_LIBS="-L$NLAB_EXEC/lib -lpython3.12"
        
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared --disable-static \
                    --with-cairo --with-pango --with-gdk-pixbuf \
                    --with-freetype2 --with-fontconfig \
                    --without-x \
                    --without-gd --without-libgd --disable-gd \
                    --with-python3 \
                    --without-qt \
                    PYTHON="$PYTHON" \
                    PYTHON_CPPFLAGS="$PYTHON_INCLUDES" \
                    PYTHON_LIBS="$PYTHON_LIBS" \
                    LDFLAGS="$LDFLAGS" \
                    CPPFLAGS="$CPPFLAGS" \
                    CC="$CC"
        
        # Fix Python linking if needed
        if [ -f plugin/python3/Makefile ]; then
            sed -i.bak 's/^LIBS = /LIBS = -lpython3.12 /' plugin/python3/Makefile
        fi
        
        make -j$NPROC && make install
        mark_done graphviz
        refresh_pkgconfig
    fi
    
    phase_end
}