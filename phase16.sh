# -----------------------------------------------------------------------------
# Phase 16 – Developer Tools (Unix utilities)
# -----------------------------------------------------------------------------
phase16() {
    phase_start "PHASE 16: Developer Tools (ripgrep, fd, bat, shellcheck, htop, tldr, tree)" 16 "gcc" || return 0

    # =========================================================================
    # 16.1 ripgrep (fast grep alternative)
    # =========================================================================
    CURRENT_PACKAGE="ripgrep"
    if ! is_installed ripgrep "$NLAB_EXEC/bin/rg"; then
        cd "$NLAB_SRC/tarballs"
        download https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-aarch64-apple-darwin.tar.gz ripgrep-14.1.0-aarch64-apple-darwin.tar.gz
        extract ripgrep-14.1.0-aarch64-apple-darwin.tar.gz ripgrep-14.1.0-aarch64-apple-darwin
        cp ripgrep-14.1.0-aarch64-apple-darwin/rg "$NLAB_EXEC/bin/"
        chmod +x "$NLAB_EXEC/bin/rg"
        mark_done ripgrep
        refresh_pkgconfig
    fi

    # =========================================================================
    # 16.2 fd (fast find alternative)
    # =========================================================================
    CURRENT_PACKAGE="fd"
    if ! is_installed fd "$NLAB_EXEC/bin/fd"; then
        cd "$NLAB_SRC/tarballs"
        download https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-aarch64-apple-darwin.tar.gz fd-v10.1.0-aarch64-apple-darwin.tar.gz
        extract fd-v10.1.0-aarch64-apple-darwin.tar.gz fd-v10.1.0-aarch64-apple-darwin
        cp fd-v10.1.0-aarch64-apple-darwin/fd "$NLAB_EXEC/bin/"
        chmod +x "$NLAB_EXEC/bin/fd"
        mark_done fd
        refresh_pkgconfig
    fi

    # =========================================================================
    # 16.3 bat (cat with syntax highlighting)
    # =========================================================================
    CURRENT_PACKAGE="bat"
    if ! is_installed bat "$NLAB_EXEC/bin/bat"; then
        cd "$NLAB_SRC/tarballs"
        download https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-v0.24.0-aarch64-apple-darwin.tar.gz bat-v0.24.0-aarch64-apple-darwin.tar.gz
        extract bat-v0.24.0-aarch64-apple-darwin.tar.gz bat-v0.24.0-aarch64-apple-darwin
        cp bat-v0.24.0-aarch64-apple-darwin/bat "$NLAB_EXEC/bin/"
        chmod +x "$NLAB_EXEC/bin/bat"
        mark_done bat
        refresh_pkgconfig
    fi

    # =========================================================================
    # 16.4 shellcheck (bash linter)
    # =========================================================================
    CURRENT_PACKAGE="shellcheck"
    if ! is_installed shellcheck "$NLAB_EXEC/bin/shellcheck"; then
        cd "$NLAB_SRC/tarballs"
        download https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.darwin.aarch64.tar.xz shellcheck-v0.10.0.darwin.aarch64.tar.xz
        extract shellcheck-v0.10.0.darwin.aarch64.tar.xz shellcheck-v0.10.0
        cp shellcheck-v0.10.0/shellcheck "$NLAB_EXEC/bin/"
        chmod +x "$NLAB_EXEC/bin/shellcheck"
        mark_done shellcheck
        refresh_pkgconfig
    fi

    # =========================================================================
    # 16.5 htop (process viewer, built from source)
    # =========================================================================
    CURRENT_PACKAGE="htop"
    if ! is_installed htop "$NLAB_EXEC/bin/htop"; then
        cd "$NLAB_SRC/tarballs"
        download https://github.com/htop-dev/htop/releases/download/3.3.0/htop-3.3.0.tar.xz htop-3.3.0.tar.xz
        extract htop-3.3.0.tar.xz htop-3.3.0
        cd htop-3.3.0
        ./configure --prefix="$NLAB_EXEC" CC="$CC"
        make -j$NPROC && make install
        mark_done htop
        refresh_pkgconfig
    fi

    # =========================================================================
    # 16.6 tldr (simplified man pages, via pip)
    # =========================================================================
    CURRENT_PACKAGE="tldr"
    if ! is_installed tldr "$NLAB_EXEC/bin/tldr"; then
        $NLAB_EXEC/bin/pip3 install tldr
        mark_done tldr
        refresh_pkgconfig
    fi

    # =========================================================================
    # 16.7 tree (directory visualizer)
    # =========================================================================
    CURRENT_PACKAGE="tree"
    if ! is_installed tree "$NLAB_EXEC/bin/tree"; then
        cd "$NLAB_SRC/tarballs"
        download https://oldmanprogrammer.net/tar/tree/tree-2.1.3.tgz tree-2.1.3.tgz
        extract tree-2.1.3.tgz tree-2.1.3
        cd tree-2.1.3
        make CC="$CC" CFLAGS="-O3 -mcpu=apple-m2" prefix="$NLAB_EXEC"
        make install prefix="$NLAB_EXEC"
        mark_done tree
        refresh_pkgconfig
    fi

    phase_end
}