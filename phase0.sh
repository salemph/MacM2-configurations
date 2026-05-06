#--------------------------------------------------------------------------
# Phase 0 – Build tools + gawk
# -----------------------------------------------------------------------------
phase0() {
    phase_start "PHASE 0: Description" 0 || return 0
	
    setup_build_env
	refresh_pkgconfig
    
    # gawk
    CURRENT_PACKAGE="gawk"
    if ! is_installed gawk "$NLAB_EXEC/bin/gawk"; then
        download https://ftp.gnu.org/gnu/gawk/gawk-5.3.0.tar.xz gawk-5.3.0.tar.xz
        extract gawk-5.3.0.tar.xz gawk-5.3.0
        cd gawk-5.3.0
        sed -i.bak '/^extern char \*getenv ();/d' support/getopt.c
        sed -i.bak '/^extern int getopt ();/d'   support/getopt.h
        CFLAGS="-O2 -fPIC" ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static --without-included-getopt
        make -j$NPROC && make install
        mark_done gawk
		refresh_pkgconfig
    fi

    # cmake (pre-built binary)
    CURRENT_PACKAGE="cmake"
    if ! is_installed cmake "$NLAB_EXEC/bin/cmake"; then
        download https://github.com/Kitware/CMake/releases/download/v3.31.0/cmake-3.31.0-macos-universal.tar.gz cmake-3.31.0-macos-universal.tar.gz
        extract cmake-3.31.0-macos-universal.tar.gz cmake-3.31.0-macos-universal
        cp -r cmake-3.31.0-macos-universal/CMake.app/Contents/bin/* "$NLAB_EXEC/bin/"
        cp -r cmake-3.31.0-macos-universal/CMake.app/Contents/share/* "$NLAB_EXEC/share/"
        mark_done cmake
		refresh_pkgconfig
    fi

    # pkg-config
    CURRENT_PACKAGE="pkg-config"
    if ! is_installed pkg-config "$NLAB_EXEC/bin/pkg-config"; then
        download https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz pkg-config-0.29.2.tar.gz
        extract pkg-config-0.29.2.tar.gz pkg-config-0.29.2
        cd pkg-config-0.29.2
        CFLAGS="-O2 -fPIC -std=gnu11" \
        ac_cv_header_CoreServices_h=no \
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static --with-internal-glib
        sed -i.bak '/#include <CoreServices\/CoreServices.h>/s/^/\/\/ /' glib/glib/gunicollate.c
        sed -i.bak '/#include <CoreServices\/CoreServices.h>/s/^/\/\/ /' glib/glib/gutils.c
        make -j$NPROC && make install
        mark_done pkg-config
		refresh_pkgconfig
    fi

    # ninja (via pip, needed for meson builds later)
    CURRENT_PACKAGE="ninja"
    if ! is_installed ninja "$NLAB_EXEC/bin/ninja"; then
        pip3 install ninja --target="$NLAB_EXEC/lib/python3.12/site-packages"
        ln -sf "$NLAB_EXEC/lib/python3.12/site-packages/ninja" "$NLAB_EXEC/bin/ninja" 2>/dev/null || true
        mark_done ninja
		refresh_pkgconfig
    fi
    
    # meson (needed for many Phase 2+ builds)
    CURRENT_PACKAGE="meson"
    if ! is_installed meson "$NLAB_EXEC/bin/meson"; then
        pip3 install meson --target="$NLAB_EXEC/lib/python3.12/site-packages"
        ln -sf "$NLAB_EXEC/lib/python3.12/site-packages/meson.py" "$NLAB_EXEC/bin/meson" 2>/dev/null || true
        mark_done meson
		refresh_pkgconfig
    fi
}