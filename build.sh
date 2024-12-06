#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

if [ ! -d "$FUZZER/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

cd "$FUZZER/repo"
export CXX=`which clang++`
export CC=`which clang`
export LLVM_CONFIG=`which llvm-config`

pushd afl-2.57b
make clean all
popd

pushd instrument
make clean all
popd

pushd distance/distance_calculator
cmake ./
cmake --build ./
popd

./instrument/afl-clang-fast++ $CXXFLAGS -std=c++11 -c "afl_driver.cpp" -fPIC -o "$OUT/afl_driver.o"
echo -e '\x1b[0;36mAFLGo (yeah!) \x1b[0;32mbuild is done \x1b[0m'
#########   cCYA   #############    cGRN   ############# cRST ###
