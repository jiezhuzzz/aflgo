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
export CFLAGS="$CFLAGS $ADDITIONAL"
export CXXFLAGS="$CXXFLAGS $ADDITIONAL"
export LDFLAGS="$LDFLAGS -lpthread"
"$TARGET/build.sh"
cp $TARGET/repo/*.0.0.*.bc $OUT/

echo "Function targets"
cat $OUT/Ftargets.txt


echo "## Generate Distance"
cat $OUT/BBnames.txt | grep -v "^$"| rev | cut -d: -f2- | rev | sort | uniq > $OUT/BBnames2.txt && mv $OUT/BBnames2.txt $OUT/BBnames.txt
cat $OUT/BBcalls.txt | grep -Ev "^[^,]*$|^([^,]*,){2,}[^,]*$"| sort | uniq > $OUT/BBcalls2.txt && mv $OUT/BBcalls2.txt $OUT/BBcalls.txt
$FUZZER/repo/distance/gen_distance_fast.py $OUT $OUT

echo "Distance values:"
head -n5 $OUT/distance.cfg.txt


echo "## Instrument the subject"
export CFLAGS="$COPY_CFLAGS -distance=$OUT/distance.cfg.txt"
export CXXFLAGS="$COPY_CXXFLAGS -distance=$OUT/distance.cfg.txt"
"$TARGET/build.sh"