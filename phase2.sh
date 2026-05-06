# -----------------------------------------------------------------------------
# Phase 2 – Graphics core
# -----------------------------------------------------------------------------
phase2() {
    phase_start "PHASE 2: Graphics Core (libpng, freetype, cairo, glib, gtk3)" 2 "gcc" || return 0
   
	refresh_pkgconfig

    # 2.1 libpng (needs zlib)
    CURRENT_PACKAGE="libpng"
    if ! is_installed libpng "$NLAB_EXEC/lib/libpng.dylib"; then
        download https://download.sourceforge.net/libpng/libpng-1.6.43.tar.xz libpng-1.6.43.tar.xz
        extract libpng-1.6.43.tar.xz libpng-1.6.43
        cd libpng-1.6.43
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static CC="$CC" \
                    CPPFLAGS="$CPPFLAGS" LDFLAGS="-L$NLAB_EXEC/lib"
        make -j$NPROC && make install
        mark_done libpng
		refresh_pkgconfig
    fi

    # 2.2 libjpeg-turbo (needs nothing from NLAB)
    CURRENT_PACKAGE="libjpeg-turbo"
    if ! is_installed libjpeg-turbo "$NLAB_EXEC/lib/libjpeg.dylib"; then
        download https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.4.1/libjpeg-turbo-3.1.4.1.tar.gz libjpeg-turbo-3.1.4.1.tar.gz
        extract libjpeg-turbo-3.1.4.1.tar.gz libjpeg-turbo-3.1.4.1
        cd libjpeg-turbo-3.1.4.1 && rm -rf build && mkdir build && cd build
        cmake .. -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" -DCMAKE_BUILD_TYPE=Release \
                 -DENABLE_STATIC=ON -DENABLE_SHARED=ON -DCMAKE_C_COMPILER="$CC"
        make -j$NPROC && make install
        mark_done libjpeg-turbo
		refresh_pkgconfig
    fi

    # 2.3 freetype (needs zlib, libpng)
    CURRENT_PACKAGE="freetype"
    if ! is_installed freetype "$NLAB_EXEC/lib/libfreetype.dylib"; then
        download https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz freetype-2.13.3.tar.xz
        extract freetype-2.13.3.tar.xz freetype-2.13.3
        cd freetype-2.13.3
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static CC="$CC" \
                    CPPFLAGS="$CPPFLAGS" LDFLAGS="-L$NLAB_EXEC/lib"
        make -j$NPROC && make install
        mark_done freetype
		refresh_pkgconfig
    fi

    # 2.4 fontconfig (needs freetype, libxml2)
    CURRENT_PACKAGE="fontconfig"
    if ! is_installed fontconfig "$NLAB_EXEC/lib/libfontconfig.dylib"; then
        download https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz fontconfig-2.15.0.tar.xz
        extract fontconfig-2.15.0.tar.xz fontconfig-2.15.0
        cd fontconfig-2.15.0
        ./configure --prefix="$NLAB_EXEC" --enable-shared --disable-docs CC="$CC" \
                    --with-freetype-config="$NLAB_EXEC/bin/freetype-config" \
                    CPPFLAGS="$CPPFLAGS" LDFLAGS="-L$NLAB_EXEC/lib"
        make -j$NPROC && make install
        mark_done fontconfig
		refresh_pkgconfig
    fi

    # 2.5 gettext (needed by glib, atk, gtk; needs libiconv, ncurses)
    CURRENT_PACKAGE="gettext"
    if ! is_installed gettext "$NLAB_EXEC/lib/libintl.dylib"; then
        download https://ftp.gnu.org/pub/gnu/gettext/gettext-0.22.5.tar.xz gettext-0.22.5.tar.xz
        extract gettext-0.22.5.tar.xz gettext-0.22.5
        cd gettext-0.22.5
        ./configure --prefix="$NLAB_EXEC" --enable-shared CC="$CC" \
                    --with-libiconv-prefix="$NLAB_EXEC" \
                    CPPFLAGS="$CPPFLAGS" LDFLAGS="-L$NLAB_EXEC/lib"
        make -j$NPROC && make install
        mark_done gettext
		refresh_pkgconfig
    fi

    # 2.6 pixman (needed by cairo; no NLAB deps)
    CURRENT_PACKAGE="pixman"
    if ! is_installed pixman "$NLAB_EXEC/lib/libpixman-1.dylib"; then
        download https://www.cairographics.org/releases/pixman-0.44.2.tar.gz pixman-0.44.2.tar.gz
        extract pixman-0.44.2.tar.gz pixman-0.44.2
        cd pixman-0.44.2
        rm -rf _build
        meson setup _build --prefix="$NLAB_EXEC" --buildtype=release -Ddefault_library=shared
        ninja -C _build -j$NPROC && ninja -C _build install
        mark_done pixman
		refresh_pkgconfig
    fi

	# 2.7 Cairo - 🍎 CLANG (needs Quartz/CoreText frameworks)
	    CURRENT_PACKAGE="cairo"
	    if ! is_installed cairo "$NLAB_EXEC/lib/libcairo.dylib"; then
	        cd "$NLAB_SRC/tarballs"
	        download https://www.cairographics.org/snapshots/cairo-1.17.8.tar.xz cairo-1.17.8.tar.xz
	        extract cairo-1.17.8.tar.xz cairo-1.17.8
	        cd cairo-1.17.8
	        rm -rf _build
			# 🍎 System Clang for Quartz support
        
	        setup_clang_env  
        
			meson setup _build \
			    --prefix="$NLAB_EXEC" \
			    --buildtype=release \
			    -Dquartz=enabled \
			    -Dxlib=enabled \
			    -Dfontconfig=enabled \
			    -Dfreetype=enabled \
			    -Dglib=enabled \
			    -Dtests=disabled \
			    -Dpng=enabled \
			    -Dc_args="-O3 -mcpu=apple-m2 -I$NLAB_EXEC/include -I/opt/X11/include" \
			    -Dc_link_args="-L$NLAB_EXEC/lib -L/opt/X11/lib -Wl,-rpath,$NLAB_EXEC/lib -F/System/Library/Frameworks -framework CoreGraphics -framework CoreText -framework ApplicationServices"
	        
	        ninja -C _build -j$NPROC
	        ninja -C _build install
        
	        mark_done cairo
			refresh_pkgconfig
	    fi
    # 2.8 glib (needs gettext, libiconv, zlib; CRITICAL for GTK)
    CURRENT_PACKAGE="glib"
    if ! is_installed glib "$NLAB_EXEC/lib/libglib-2.0.dylib"; then
		download https://download.gnome.org/sources/glib/2.82/glib-2.82.5.tar.xz glib-2.82.5.tar.xz
		extract glib-2.82.5.tar.xz glib-2.82.5
		cd glib-2.82.5
        rm -rf _build
        meson setup _build --prefix="$NLAB_EXEC" --buildtype=release \
              -Dc_args="-O3 -mcpu=apple-m2 -I$NLAB_EXEC/include" \
              -Dc_link_args="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib"
        ninja -C _build -j$NPROC && ninja -C _build install
        # Patch out CoreServices if needed
        find "$NLAB_EXEC/include/glib-2.0" -name "*.h" -exec sed -i.bak '/#include <CoreServices\/CoreServices.h>/s/^/\/\/ /' {} + 2>/dev/null || true
        mark_done glib
		refresh_pkgconfig
    fi

    # 2.9 harfbuzz (needs freetype, glib)
    CURRENT_PACKAGE="harfbuzz"
    if ! is_installed harfbuzz "$NLAB_EXEC/lib/libharfbuzz.dylib"; then
        download https://github.com/harfbuzz/harfbuzz/releases/download/10.4.0/harfbuzz-10.4.0.tar.xz harfbuzz-10.4.0.tar.xz
        extract harfbuzz-10.4.0.tar.xz harfbuzz-10.4.0
        cd harfbuzz-10.4.0
        rm -rf _build
        meson setup _build --prefix="$NLAB_EXEC" --buildtype=release \
              -Dc_args="-O3 -mcpu=apple-m2 -I$NLAB_EXEC/include" \
              -Dc_link_args="-L$NLAB_EXEC/lib"
        ninja -C _build -j$NPROC && ninja -C _build install
        mark_done harfbuzz
		refresh_pkgconfig
    fi

    # 2.10 fribidi (needed by pango)
    CURRENT_PACKAGE="fribidi"
    if ! is_installed fribidi "$NLAB_EXEC/lib/libfribidi.dylib"; then
        download https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz fribidi-1.0.16.tar.xz
        extract fribidi-1.0.16.tar.xz fribidi-1.0.16
        cd fribidi-1.0.16
        rm -rf _build
        meson setup _build --prefix="$NLAB_EXEC" --buildtype=release
        ninja -C _build -j$NPROC && ninja -C _build install
        mark_done fribidi
		refresh_pkgconfig
    fi

		# 2.11 gobject-introspection - 🍎 CLANG
		CURRENT_PACKAGE="gobject-introspection"
		    if ! is_installed gobject-introspection "$NLAB_EXEC/bin/g-ir-scanner"; then
		        download https://download.gnome.org/sources/gobject-introspection/1.80/gobject-introspection-1.80.1.tar.xz gobject-introspection-1.80.1.tar.xz
		        extract gobject-introspection-1.80.1.tar.xz gobject-introspection-1.80.1
		        cd gobject-introspection-1.80.1
		        rm -rf _build
        
		        setup_clang_env
        
		        meson setup _build \
		            --prefix="$NLAB_EXEC" \
		            --buildtype=release \
		            -Dc_args="-O3 -mcpu=apple-m2 -I$NLAB_EXEC/include -D__BLOCKS__=0" \
		            -Dc_link_args="-L$NLAB_EXEC/lib -Wl,-rpath,$NLAB_EXEC/lib" \
		            --wrap-mode=nofallback
        
		        ninja -C _build -j$NPROC && ninja -C _build install
        
		        # ENSURE .pc file exists
		        if [ ! -f "$NLAB_EXEC/lib/pkgconfig/gobject-introspection-1.0.pc" ]; then
		            cat > "$NLAB_EXEC/lib/pkgconfig/gobject-introspection-1.0.pc" << 'EOPC'
prefix=/Volumes/nlab/exec
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: gobject-introspection
Description: GObject Introspection
Version: 1.80.1
Requires: glib-2.0 gobject-2.0
Libs: -L${libdir} -lgirepository-1.0
Cflags: -I${includedir}/gobject-introspection-1.0
EOPC
		        fi
        
		        refresh_pkgconfig "gobject-introspection-1.0"
		        mark_done gobject-introspection
				refresh_pkgconfig
		    fi
	# 2.12 atk - 🍎 CLANG
	    CURRENT_PACKAGE="atk"
	    if ! is_installed atk "$NLAB_EXEC/lib/libatk-1.0.dylib"; then
	        download https://download.gnome.org/sources/atk/2.38/atk-2.38.0.tar.xz atk-2.38.0.tar.xz
	        extract atk-2.38.0.tar.xz atk-2.38.0
	        cd atk-2.38.0
	        rm -rf _build
       # 🍎 System Clang
	        setup_clang_env  
       
	        meson setup _build --prefix="$NLAB_EXEC" --buildtype=release \
	              -Dc_args="-O3 -mcpu=apple-m2 -I$NLAB_EXEC/include" \
	              -Dc_link_args="-L$NLAB_EXEC/lib -lintl"
	        ninja -C _build -j$NPROC && ninja -C _build install
	        mark_done atk
	    fi
		# 2.13 gdk-pixbuf - 🍎 CLANG
		    CURRENT_PACKAGE="gdk-pixbuf"
		    if ! is_installed gdk-pixbuf "$NLAB_EXEC/lib/libgdk_pixbuf-2.0.dylib"; then
		        download https://download.gnome.org/sources/gdk-pixbuf/2.42/gdk-pixbuf-2.42.12.tar.xz gdk-pixbuf-2.42.12.tar.xz
		        extract gdk-pixbuf-2.42.12.tar.xz gdk-pixbuf-2.42.12
		        cd gdk-pixbuf-2.42.12
		        rm -rf _build
        
		        setup_clang_env  
        
		        meson setup _build --prefix="$NLAB_EXEC" --buildtype=release \
		              -Dc_args="-O3 -mcpu=apple-m2 -I$NLAB_EXEC/include" \
		              -Dc_link_args="-L$NLAB_EXEC/lib"
		        ninja -C _build -j$NPROC && ninja -C _build install
		        mark_done gdk-pixbuf
				refresh_pkgconfig
		    fi
	# 2.14 pango - 🍎 CLANG (depends on Cairo-Quartz)
	    CURRENT_PACKAGE="pango"
	    if ! is_installed pango "$NLAB_EXEC/lib/libpango-1.0.dylib"; then
	        download https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz pango-1.54.0.tar.xz
	        extract pango-1.54.0.tar.xz pango-1.54.0
	        cd pango-1.54.0
	        rm -rf _build
        
	        setup_clang_env  
        
	        meson setup _build --prefix="$NLAB_EXEC" --buildtype=release \
	              -Dc_args="-O3 -mcpu=apple-m2 -I$NLAB_EXEC/include" \
	              -Dc_link_args="-L$NLAB_EXEC/lib"
	        ninja -C _build -j$NPROC && ninja -C _build install
	        mark_done pango
			refresh_pkgconfig
	    fi
    # 2.15 GTK3 (the big one - needs ALL of the above)
	CURRENT_PACKAGE="gtk"
	    if ! is_installed gtk "$NLAB_EXEC/lib/libgtk-3.dylib"; then
	        download https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.43.tar.xz gtk+-3.24.43.tar.xz
	        extract gtk+-3.24.43.tar.xz gtk+-3.24.43
	        cd gtk+-3.24.43
	        rm -rf _build
        
	        setup_clang_env
        
	        meson setup _build --prefix="$NLAB_EXEC" --buildtype=release \
	              -Dx11_backend=true -Dquartz_backend=true \
	              -Dwayland_backend=false \
	              -Dintrospection=false \
	              -Ddemos=false -Dgtk_doc=false -Dexamples=false -Dtests=false \
	              -Dc_args="-O3 -mcpu=apple-m2 -I$NLAB_EXEC/include" \
	              -Dc_link_args="-L$NLAB_EXEC/lib -lintl -Wl,-rpath,$NLAB_EXEC/lib"
	        ninja -C _build -j$NPROC && ninja -C _build install
	        refresh_pkgconfig
	        mark_done gtk
	    fi

    # 2.16 openjpeg (needed for JPEG2000 support)
    CURRENT_PACKAGE="openjpeg"
    if ! is_installed openjpeg "$NLAB_EXEC/lib/libopenjp2.dylib"; then
        download https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.3.tar.gz openjpeg-2.5.3.tar.gz
        extract openjpeg-2.5.3.tar.gz openjpeg-2.5.3
        cd openjpeg-2.5.3
        rm -rf build && mkdir build && cd build
        cmake .. -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" -DCMAKE_BUILD_TYPE=Release \
                 -DCMAKE_C_COMPILER="$CC"
        make -j$NPROC && make install
        mark_done openjpeg
		refresh_pkgconfig
    fi
}