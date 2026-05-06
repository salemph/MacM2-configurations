# -----------------------------------------------------------------------------
# Phase 7 – Extras (Java, Doxygen, R)
# -----------------------------------------------------------------------------
phase7() {
    phase_start "PHASE 7: Extras (Doxygen, R, Octave)" 7 "gcc" || return 0
	
	# JDK 25 - Latest GA (General Availability) for 2026
	#    CURRENT_PACKAGE="jdk25"
	#    if ! is_installed jdk25 "$NLAB_EXEC/jdk-25"; then
	#        download  https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.3%2B9/OpenJDK25U-jdk-sources_25.0.3_9.tar.gz OpenJDK25U-jdk-sources_25.0.3_9.tar.gz
	#        extract OpenJDK25U-jdk-sources_25.0.3_9.tar.gz OpenJDK25U-jdk-sources_25.0.3_9
	#        # Moving to ensure clean naming inside NLAB
	#        rm -rf "$NLAB_EXEC/jdk-25"
	#        mv jdk-25* "$NLAB_EXEC/jdk-25"
	#        mark_done jdk25
	#    fi
    #
	#    # JDK 11 - Still required for many legacy Nuclear legacy codes/GUI tools
	#    CURRENT_PACKAGE="jdk11"
	#    if ! is_installed jdk11 "$NLAB_EXEC/jdk-11"; then
	#        download https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.31%2B11/OpenJDK11U-jdk-sources_11.0.31_11.tar.gz OpenJDK11U-jdk-sources_11.0.31_11.tar.gz 
	#        extract OpenJDK11U-jdk-sources_11.0.31_11.tar.gz OpenJDK11U-jdk-sources_11.0.31_11
	#        rm -rf "$NLAB_EXEC/jdk-11"
	#        mv jdk-11* "$NLAB_EXEC/jdk-11"
	#        mark_done jdk11
	#    fi
    #
	#    # Set Java environment for the remainder of the script
	#    export JAVA_HOME="$NLAB_EXEC/jdk-25/Contents/Home"
	#    export PATH="$JAVA_HOME/bin:$PATH"
    #
	#    CURRENT_PACKAGE="luyten"
	#    if ! is_installed luyten "$NLAB_EXEC/bin/luyten.jar"; then
	#        # Deathmarine's Luyten 0.5.4 remains the stable standard for Java de-compilation
	#        cd "$NLAB_EXEC/bin"
	#        curl -L -o luyten.jar https://github.com/deathmarine/Luyten/releases/download/v0.5.4/luyten-0.5.4.jar
	#        mark_done luyten
	#    fi

    # 7.1 Doxygen
     CURRENT_PACKAGE="doxygen"
     if ! is_installed doxygen "$NLAB_EXEC/bin/doxygen"; then
         download https://www.doxygen.nl/files/doxygen-1.13.2.src.tar.gz doxygen-1.13.2.src.tar.gz
         extract doxygen-1.13.2.src.tar.gz doxygen-1.13.2
         cd doxygen-1.13.2 && mkdir -p build && cd build
         cmake .. \
             -DCMAKE_C_COMPILER="$CC" \
             -DCMAKE_CXX_COMPILER="$CXX" \
             -DCMAKE_INSTALL_PREFIX="$NLAB_EXEC" \
             -Dbuild_doc=OFF \
             -Dbuild_gui=OFF
         make -j$NPROC && make install
         mark_done doxygen
		 refresh_pkgconfig
     fi

     # 7.2 R (needs OpenBLAS from phase 8 - will skip if not available)
     CURRENT_PACKAGE="R"
     if ! is_installed R "$NLAB_EXEC/bin/R"; then
         # Check if OpenBLAS exists yet (from phase 8)
         if [ -f "$NLAB_EXEC/lib/libopenblas.dylib" ]; then
             BLAS_LIB="-L$NLAB_EXEC/lib -lopenblas"
         else
             echo "⚠️  OpenBLAS not found - R will use reference BLAS (slower)"
             BLAS_LIB=""
         fi
        
         download https://cran.r-project.org/src/base/R-4/R-4.5.1.tar.gz R-4.5.1.tar.gz
         extract R-4.5.1.tar.gz R-4.5.1
         cd R-4.5.1
		 make distclean 2>/dev/null || true
		 rm -f /Volumes/nlab/exec/.nlab_installed/R

		 export CC=/usr/bin/clang
		 export CXX=/usr/bin/clang++
		 export FC=/Volumes/nlab/exec/bin/gfortran

		 ./configure \
		     --prefix=/Volumes/nlab/exec \
		     --with-blas="-L/Volumes/nlab/exec/lib -lopenblas" \
		     --with-lapack \
		     --enable-R-shlib \
		     --with-x=no \
		     --with-aqua=no \
		     --without-cairo \
		     CPPFLAGS="-I/Volumes/nlab/exec/include" \
		     LDFLAGS="-L/Volumes/nlab/exec/lib -Wl,-rpath,/Volumes/nlab/exec/lib"

		 make -j$(sysctl -n hw.perflevel0.logicalcpu) && make install
		 touch /Volumes/nlab/exec/.nlab_installed/R
		 echo "✅ R installed"
     fi

       export JAVA_HOME="$NLAB_EXEC/jdk-25/Contents/Home"
       export PATH="$JAVA_HOME/bin:$PATH"
    phase_end
}