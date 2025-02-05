#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA: path to Magma support files
# - env OUT: path to directory where artifacts are stored
# - env CFLAGS and CXXFLAGS must be set to link against Magma instrumentation
##

# build magma

"$MAGMA/build.sh"

export CC=$FUZZER/repo/instrument/aflgo-clang
export CXX=$FUZZER/repo/instrument/aflgo-clang++


(	
	echo "## Set Target"
    pushd $TARGET/repo
	echo "## Get Target"
	echo "targets"
	grep -nr MAGMA_LOG | cut -f1,2 -d':' | grep -v ".orig:"  | grep -v "Binary file" > $OUT/BBtargets.txt

	cat $OUT/BBtargets.txt
	popd
)


echo "## Build Target"
export CC=$FUZZER/repo/instrument/aflgo-clang
export CXX=$FUZZER/repo/instrument/aflgo-clang++
export LIBS="$LIBS -l:afl_driver.o -lstdc++"

# Set aflgo-instrumentation flags
export COPY_CFLAGS=$CFLAGS
export COPY_CXXFLAGS=$CXXFLAGS
export ADDITIONAL="-targets=$OUT/BBtargets.txt -outdir=$OUT -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
export LDFLAGS="$LDFLAGS -lpthread"

case "$(basename $TARGET)" in
"openssl")
    echo "TARGET openssl"
    export CONFIGURE_FLAGS="$ADDITIONAL no-asm"
    ;;
# "lua")
#     LDFLAGS="$LDFLAGS -flto"
#     sed -i '/\$(CC) -o \$@ \$(LDFLAGS) \$(MYLDFLAGS) \$(LUA_O) \$(CORE_T) \$(LIBS) \$(MYLIBS) \$(DL)/ s/\$(CC) -o/\$(CC) \$(CFLAGS) -o/' $TARGET/repo/makefile
#     CFLAGS="$COPY_CFLAGS $ADDITIONAL"
#     CXXFLAGS="$COPY_CXXFLAGS $ADDITIONAL"
#     ;;
*)
    CFLAGS="$COPY_CFLAGS $ADDITIONAL"
    CXXFLAGS="$COPY_CXXFLAGS $ADDITIONAL"
    ;;
esac

"$TARGET/build.sh"

(
    pushd $TARGET/repo

    case "$(basename $TARGET)" in
    "libsndfile")
        cp ossfuzz/sndfile_fuzzer* $OUT/
        ;;
    "libtiff")
        cp tools/tiffcp* $OUT/
        ;;
    "libxml2")
        cp xmllint* $OUT/
        ;;
        # "lua")
        # sed -i '/\$(CC) \$(CFLAGS) -o \$@ \$(LDFLAGS) \$(MYLDFLAGS) \$(LUA_O) \$(CORE_T) \$(LIBS) \$(MYLIBS) \$(DL)/ s/\$(CC) \$(CFLAGS) -o/\$(CC) -o/' makefile
        # cp lua* $OUT/
        # ;;
    "openssl")
        fuzzers=$(find fuzz -executable -type f '!' -name \*.py '!' -name \*-test '!' -name \*.pl \( -name "asn1" -o -name "asn1parse" -o -name "bignum" -o -name "server" -o -name "client" -o -name "x509" \))
        for f in $fuzzers; do
            cp $f* $OUT/
        done
        ;;
    # "php")
    #     fuzzers="php-fuzz-json php-fuzz-exif php-fuzz-mbstring php-fuzz-unserialize php-fuzz-parser"
    #     for f in $fuzzers; do
    #         cp sapi/fuzzer/$f* "$OUT/${f/php-fuzz-/}"
    #     done
    #     ;;
    "poppler")
        cp "$TARGET/work/poppler/utils/"{pdfimages*,pdftoppm*} $OUT/
        ;;
    *)
        echo "$(basename $TARGET)"
        ;;
    esac
    popd
)

echo "Function targets"
cat $OUT/Ftargets.txt


echo "## Generate Distance"
cat $OUT/BBnames.txt | grep -v "^$"| rev | cut -d: -f2- | rev | sort | uniq > $OUT/BBnames2.txt && mv $OUT/BBnames2.txt $OUT/BBnames.txt
cat $OUT/BBcalls.txt | grep -Ev "^[^,]*$|^([^,]*,){2,}[^,]*$"| sort | uniq > $OUT/BBcalls2.txt && mv $OUT/BBcalls2.txt $OUT/BBcalls.txt
$FUZZER/repo/distance/gen_distance_fast.py $OUT $OUT

echo "Distance values:"
head -n5 $OUT/distance.cfg.txt


echo "## Instrument the subject"

if [ "$(basename $TARGET)" == "openssl" ]; then
    echo "clean CONFIGURE_FLAGS"
    CONFIGURE_FLAGS="-distance=$OUT/distance.cfg.txt"
    CFLAGS="$COPY_CFLAGS" CXXFLAGS="$COPY_CXXFLAGS"
else
    CFLAGS="$COPY_CFLAGS -distance=$OUT/distance.cfg.txt" CXXFLAGS="$COPY_CXXFLAGS -distance=$OUT/distance.cfg.txt"
fi

"$TARGET/build.sh"