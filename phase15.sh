# -----------------------------------------------------------------------------
# Phase 15 – MPS / ML Acceleration
# -----------------------------------------------------------------------------
phase15() {
    phase_start "PHASE 15: MPS / ML Acceleration (TensorFlow, PyTorch, Metal)" 15 "gcc" || return 0

    # =========================================================================
    # 15.1 TensorFlow with Metal support (M2 GPU acceleration)
    # =========================================================================
    CURRENT_PACKAGE="mps"
    if ! is_installed mps "$NLAB_EXEC/lib/python3.12/site-packages/tensorflow"; then
        $NLAB_EXEC/bin/pip3 install tensorflow-macos tensorflow-metal
        
        # Verify Metal is available
        $NLAB_EXEC/bin/python3 -c "import tensorflow as tf; print('TF devices:', tf.config.list_physical_devices())" 2>/dev/null || \
            echo "⚠️  TensorFlow installed but Metal may not be available"
        
        mark_done mps
        refresh_pkgconfig
    fi

    # =========================================================================
    # 15.2 FEniCSx (Modern FEniCS - Python-based finite element)
    # =========================================================================
    CURRENT_PACKAGE="fenicsx"
    if ! is_installed fenicsx "$NLAB_EXEC/lib/python3.12/site-packages/dolfinx/__init__.py"; then
        $NLAB_EXEC/bin/pip3 install fenics-dolfinx fenics-basix fenics-ffcx fenics-ufl
        mark_done fenicsx
        refresh_pkgconfig
    fi

    # =========================================================================
    # 15.3 Additional ML/Nuclear Python packages
    # =========================================================================
    CURRENT_PACKAGE="ml-extras"
    if ! is_installed ml-extras "$NLAB_EXEC/lib/python3.12/site-packages/scikit_learn"; then
        $NLAB_EXEC/bin/pip3 install \
            scikit-learn \
            scikit-image \
            matplotlib \
            seaborn \
            plotly \
            xarray \
            netCDF4 \
            h5py \
            astropy \
            uncertainties \
            periodictable \
            openmc
        mark_done ml-extras
        refresh_pkgconfig
    fi

    phase_end
}