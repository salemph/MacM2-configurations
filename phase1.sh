# -----------------------------------------------------------------------------
# Phase 1 – Compression & Crypto
# -----------------------------------------------------------------------------
phase1() {
    phase_start "PHASE 1: Compression & Crypto (zlib, openssl, curl, ncurses, libxslt, xerces-c)" 1 "gcc" || return 0
   	
    setup_build_env

    # 1.1 zlib-ng (NO dependencies)
    CURRENT_PACKAGE="zlib"
    if ! is_installed zlib "$NLAB_EXEC/lib/libz.dylib"; then
        cd "$NLAB_SRC/git"
        [ ! -d zlib-ng ] && git clone https://github.com/zlib-ng/zlib-ng.git
        cd zlib-ng && rm -rf build && mkdir build && cd build
        cmake .. -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" -DCMAKE_C_COMPILER="$CC" \
                 -DCMAKE_BUILD_TYPE=Release -DZLIB_COMPAT=ON -DWITH_NEON=ON \
                 -DBUILD_TESTING=OFF -DCMAKE_C_FLAGS="-O2 -fPIC"
        make -j$NPROC && make install
        # Create pkg-config file
        cat > "$NLAB_EXEC/lib/pkgconfig/zlib.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: zlib
Description: zlib-ng compression library
Version: 2.1.6
Requires: 
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
EOF
        mark_done zlib
    fi

    # 1.2 bzip2 (needs CC only)
    CURRENT_PACKAGE="bzip2"
    if ! is_installed bzip2 "$NLAB_EXEC/lib/libbz2.dylib"; then
        download https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz bzip2-1.0.8.tar.gz
        extract bzip2-1.0.8.tar.gz bzip2-1.0.8
        cd bzip2-1.0.8
        make -j$NPROC CC="$CC" CFLAGS="-O3 -fPIC"
        $CC -dynamiclib -o libbz2.1.0.8.dylib \
            blocksort.o huffman.o crctable.o randtable.o compress.o decompress.o bzlib.o \
            -install_name "$NLAB_EXEC/lib/libbz2.1.0.dylib" \
            -compatibility_version 1.0 -current_version 1.0.8
        make install PREFIX="$NLAB_EXEC"
        cp libbz2.1.0.8.dylib "$NLAB_EXEC/lib/"
        ln -sf libbz2.1.0.8.dylib "$NLAB_EXEC/lib/libbz2.1.0.dylib"
        ln -sf libbz2.1.0.dylib "$NLAB_EXEC/lib/libbz2.dylib"
        mark_done bzip2
		refresh_pkgconfig
    fi

    # 1.3 xz/lzma (needs CC only)
    CURRENT_PACKAGE="xz"
    if ! is_installed xz "$NLAB_EXEC/lib/liblzma.dylib"; then
        download https://tukaani.org/xz/xz-5.6.3.tar.gz xz-5.6.3.tar.gz
        extract xz-5.6.3.tar.gz xz-5.6.3
        cd xz-5.6.3
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static CC="$CC"
        make -j$NPROC && make install
        mark_done xz
		refresh_pkgconfig
    fi

    # 1.4 libiconv (needed by libxml2, gettext)
    CURRENT_PACKAGE="libiconv"
    if ! is_installed libiconv "$NLAB_EXEC/lib/libiconv.dylib"; then
        download https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.19.tar.gz libiconv-1.19.tar.gz
        extract libiconv-1.19.tar.gz libiconv-1.19
        cd libiconv-1.19
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static CC="$CC"
        make -j$NPROC && make install
        mark_done libiconv
		refresh_pkgconfig
    fi

    # 1.5 OpenSSL (needed by curl, Python, Qt)
    CURRENT_PACKAGE="openssl"
    if ! is_installed openssl "$NLAB_EXEC/lib/libssl.dylib"; then
        download https://www.openssl.org/source/openssl-3.2.1.tar.gz openssl-3.2.1.tar.gz
        extract openssl-3.2.1.tar.gz openssl-3.2.1
        cd openssl-3.2.1
        ./Configure --prefix="$NLAB_EXEC" darwin64-arm64 CC="$CC"
        make -j$NPROC && make install
        # Create pkg-config files (OpenSSL doesn't auto-create them)
        mkdir -p "$NLAB_EXEC/lib/pkgconfig"
        cat > "$NLAB_EXEC/lib/pkgconfig/openssl.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: OpenSSL
Description: Secure Sockets Layer and cryptography libraries
Version: 3.2.1
Requires: 
Libs: -L\${libdir} -lssl -lcrypto
Cflags: -I\${includedir}
EOF
        cat > "$NLAB_EXEC/lib/pkgconfig/libssl.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: OpenSSL-libssl
Description: Secure Sockets Layer library
Version: 3.2.1
Libs: -L\${libdir} -lssl
Cflags: -I\${includedir}
EOF
        cat > "$NLAB_EXEC/lib/pkgconfig/libcrypto.pc" << EOF
prefix=$NLAB_EXEC
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: OpenSSL-libcrypto
Description: OpenSSL cryptography library
Version: 3.2.1
Libs: -L\${libdir} -lcrypto
Cflags: -I\${includedir}
EOF
        mark_done openssl
		refresh_pkgconfig
    fi

    # 1.6 nghttp2 (needs OpenSSL, zlib)
    CURRENT_PACKAGE="nghttp2"
    if ! is_installed nghttp2 "$NLAB_EXEC/lib/libnghttp2.dylib"; then
        download https://github.com/nghttp2/nghttp2/releases/download/v1.64.0/nghttp2-1.64.0.tar.xz nghttp2-1.64.0.tar.xz
        extract nghttp2-1.64.0.tar.xz nghttp2-1.64.0
        cd nghttp2-1.64.0
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static --enable-lib-only \
                    --with-openssl="$NLAB_EXEC" --with-zlib="$NLAB_EXEC" CC="$CC"
        make -j$NPROC && make install
        mark_done nghttp2
    fi

    # 1.7 curl (needs OpenSSL, nghttp2, zlib)
    CURRENT_PACKAGE="curl"
    if ! is_installed curl "$NLAB_EXEC/bin/curl"; then
        download https://curl.se/download/curl-8.11.1.tar.xz curl-8.11.1.tar.xz
        extract curl-8.11.1.tar.xz curl-8.11.1
        cd curl-8.11.1
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static \
                    --with-openssl="$NLAB_EXEC" --with-nghttp2="$NLAB_EXEC" \
                    --with-zlib="$NLAB_EXEC" --without-libpsl --disable-debug CC="$CC"
        make -j$NPROC && make install
        mark_done curl
		refresh_pkgconfig
    fi

    # 1.8 gperf (needed by system builds, no NLAB deps)
    CURRENT_PACKAGE="gperf"
    if ! is_installed gperf "$NLAB_EXEC/bin/gperf"; then
        download https://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz gperf-3.1.tar.gz
        extract gperf-3.1.tar.gz gperf-3.1
        cd gperf-3.1
        sed -i.bak '/^extern char \*getenv ();/d' lib/getopt.c
        sed -i.bak '/^extern int strncmp ();/d'  lib/getopt.c
        sed -i.bak '/^extern int getopt ();/d'   lib/getopt.h
        sed -i.bak '/^#include "getopt.h"/a\
#include <stdlib.h>\
#include <string.h>' lib/getopt.c
        CFLAGS="-O2 -fPIC" CXXFLAGS="-O2 -fPIC" \
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static
        make -j$NPROC && make install
        mark_done gperf
		refresh_pkgconfig
    fi

    # 1.9 ncurses (needed by readline, Python)
    CURRENT_PACKAGE="ncurses"
    if ! is_installed ncurses "$NLAB_EXEC/lib/libncursesw.dylib"; then
        download https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz ncurses-6.5.tar.gz
        extract ncurses-6.5.tar.gz ncurses-6.5
        cd ncurses-6.5
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static \
                    --without-debug --enable-widec --enable-pc-files \
                    --with-pkg-config-libdir="$NLAB_EXEC/lib/pkgconfig" CC="$CC"
        make -j$NPROC && make install
        # Create symlinks for non-wide versions
        ln -sf libncursesw.dylib "$NLAB_EXEC/lib/libncurses.dylib"
        ln -sf libncursesw.a "$NLAB_EXEC/lib/libncurses.a"
        mark_done ncurses
		refresh_pkgconfig
    fi

    # 1.10 libxml2 (needs zlib, lzma, iconv)
    CURRENT_PACKAGE="libxml2"
    if ! is_installed libxml2 "$NLAB_EXEC/lib/libxml2.dylib"; then
        download https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.4.tar.xz libxml2-2.13.4.tar.xz
        extract libxml2-2.13.4.tar.xz libxml2-2.13.4
        cd libxml2-2.13.4
        ./configure --prefix="$NLAB_EXEC" --enable-shared \
                    --with-zlib="$NLAB_EXEC" --with-lzma="$NLAB_EXEC" \
                    --without-python CC="$CC" \
                    CPPFLAGS="-I$NLAB_EXEC/include -Diconv_open=libiconv_open -Diconv_close=libiconv_close -Diconv=libiconv" \
                    LDFLAGS="-L$NLAB_EXEC/lib -liconv"
        make -j$NPROC && make install
        # Create pkg-config if missing
        [ ! -f "$NLAB_EXEC/lib/pkgconfig/libxml-2.0.pc" ] && \
        cp libxml-2.0.pc "$NLAB_EXEC/lib/pkgconfig/" 2>/dev/null || true
        mark_done libxml2
		refresh_pkgconfig
    fi

    # 1.11 libxslt (needs libxml2)
    CURRENT_PACKAGE="libxslt"
    if ! is_installed libxslt "$NLAB_EXEC/lib/libxslt.dylib"; then
        download https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.39.tar.xz libxslt-1.1.39.tar.xz
        extract libxslt-1.1.39.tar.xz libxslt-1.1.39
        cd libxslt-1.1.39
        sed -i.bak '/xmlParserMaxDepth = value;/s/.*/;/' xsltproc/xsltproc.c
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static \
                    --with-libxml-prefix="$NLAB_EXEC" --without-python CC="$CC"
        make -j$NPROC && make install
        mark_done libxslt
		refresh_pkgconfig
    fi

    # 1.12 xerces-c (needs libiconv, libxml2 optional)
    CURRENT_PACKAGE="xerces-c"
    if ! is_installed xerces-c "$NLAB_EXEC/lib/libxerces-c.dylib"; then
        download https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-3.2.5.tar.gz xerces-c-3.2.5.tar.gz
        extract xerces-c-3.2.5.tar.gz xerces-c-3.2.5
        cd xerces-c-3.2.5
        ./configure --prefix="$NLAB_EXEC" --enable-shared --enable-static CC="$CC" \
                    CPPFLAGS="$CPPFLAGS" LDFLAGS="-L$NLAB_EXEC/lib"
        make -j$NPROC && make install
        mark_done xerces-c
		refresh_pkgconfig
    fi

    # 1.13 lz4 (needed by some packages, no NLAB deps)
    CURRENT_PACKAGE="lz4"
    if ! is_installed lz4 "$NLAB_EXEC/lib/liblz4.dylib"; then
        download https://github.com/lz4/lz4/archive/refs/tags/v1.10.0.tar.gz lz4-1.10.0.tar.gz
        extract lz4-1.10.0.tar.gz lz4-1.10.0
        cd lz4-1.10.0
        make -j$NPROC PREFIX="$NLAB_EXEC" CC="$CC"
        make install PREFIX="$NLAB_EXEC"
        mark_done lz4
		refresh_pkgconfig
    fi
	 phase_end
    phase_end
}