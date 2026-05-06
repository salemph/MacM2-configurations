# -----------------------------------------------------------------------------
# Phase 4 – Python
# -----------------------------------------------------------------------------
phase4() {
    phase_start "PHASE 4: Python & Scientific Stack" 4 "gcc" || return 0

    setup_build_env

    # Verify OpenSSL is available
    check_nlab_dep "ssl" || echo "⚠️  OpenSSL not found - Python will build without SSL support"

    # Python 3.12.9
    CURRENT_PACKAGE="python"
    if ! is_installed python "$NLAB_EXEC/bin/python3"; then
        download https://www.python.org/ftp/python/3.12.9/Python-3.12.9.tgz Python-3.12.9.tgz
        extract Python-3.12.9.tgz Python-3.12.9
        cd Python-3.12.9
        ./configure --prefix="$NLAB_EXEC" \
                    --enable-shared \
                    --enable-static \
                    --enable-optimizations \
                    --with-openssl="$NLAB_EXEC" \
                    --with-ensurepip=install \
                    --with-readline=yes \
                    --with-ncurses=yes \
                    LDFLAGS="$LDFLAGS" \
                    CPPFLAGS="$CPPFLAGS" \
                    CC="$CC"
        make -j$NPROC && make install
        mark_done python
		refresh_pkgconfig
    fi

    # Core scientific packages
    CURRENT_PACKAGE="pip-packages"
    if ! is_installed pip-packages "$NLAB_EXEC/bin/cython"; then
        export PATH="$NLAB_EXEC/bin:$PATH"
        
        $NLAB_EXEC/bin/python3 -m pip install --upgrade pip setuptools wheel
        
        # ===== CORE SCIENTIFIC =====
        $NLAB_EXEC/bin/pip3 install \
            numpy scipy pandas matplotlib Pillow \
            h5py cython numba
        
        # ===== PARALLEL/DISTRIBUTED =====
        $NLAB_EXEC/bin/pip3 install \
            mpi4py dask[complete]
        
        # ===== MACHINE LEARNING =====
        $NLAB_EXEC/bin/pip3 install \
            scikit-learn tensorflow-macos tensorflow-metal \
            torch keras jax lightgbm
        
        # ===== STATISTICAL ANALYSIS =====
        $NLAB_EXEC/bin/pip3 install \
            seaborn plotly statsmodels \
            imbalanced_learn markovify
        
        # ===== JUPYTER ECOSYSTEM =====
        $NLAB_EXEC/bin/pip3 install \
            jupyter jupyterlab ipython ipykernel \
            ipywidgets notebook nbconvert
        
        # ===== WEB SCRAPING & AUTOMATION =====
        $NLAB_EXEC/bin/pip3 install \
            requests beautifulsoup4 lxml html5lib \
            selenium playwright scrapy
        
        # ===== NATURAL LANGUAGE (for report parsing) =====
        $NLAB_EXEC/bin/pip3 install \
            nltk textblob vaderSentiment \
            editdistance regex
        
        # ===== MESH/GEOMETRY =====
        $NLAB_EXEC/bin/pip3 install gmsh pygmsh meshio
        
        # ===== DOCUMENTATION =====
        $NLAB_EXEC/bin/pip3 install \
            sphinx pygments cryptography \
            pytest python-docx pdfminer.six
        
        # ===== GUI TOOLS =====
        $NLAB_EXEC/bin/pip3 install PyQt5 QtPy
        
        # ===== NETWORK & API =====
        $NLAB_EXEC/bin/pip3 install \
            tornado flask fastapi uvicorn \
            Jinja2 Werkzeug requests-toolbelt
        
        # ===== UTILITIES =====
        $NLAB_EXEC/bin/pip3 install \
            tqdm pytz python-dateutil \
            pyyaml toml configparser
        
        # ===== NUCLEAR/ASTRO =====
        $NLAB_EXEC/bin/pip3 install \
            astropy uncertainties periodictable
        
        # ===== GRAPH & NETWORK ANALYSIS =====
        $NLAB_EXEC/bin/pip3 install \
            networkx igraph graphviz
        
        # ===== IMAGE PROCESSING =====
        $NLAB_EXEC/bin/pip3 install \
            opencv-python scikit-image imageio
        
        mark_done pip-packages
    fi
		phase_end
    phase_end
}
