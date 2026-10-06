#!/usr/bin/env bash
# Builds rtn with its bundled SeqLib (htslib, bwa, fermi-lite) on Linux with current compilers and
# autotools. The steps in README.md fail there; this script regenerates the autotools files, names
# the system type for htslib's configure, and builds bwa and fermi-lite with -fcommon.
# (macOS on Apple Silicon needs more: SeqLib's bwa, fermi-lite and SSW code use x86 SSE instructions.)
#
# Needs git, make, autoconf, automake, a C/C++ compiler, zlib, bzip2, xz (liblzma) and jsoncpp.
# Libraries outside the compiler's default paths: PREFIX=/their/prefix ./build.sh (e.g. $CONDA_PREFIX).
# rtn is optimised for the build machine (-march=native); for a binary that runs elsewhere, set
# MARCH, e.g. MARCH=-march=x86-64-v2 ./build.sh
set -euo pipefail
cd "$(dirname "$0")"
git submodule update --init --recursive

CPPFLAGS=""; LDFLAGS=""
if [ -n "${PREFIX:-}" ]; then
    CPPFLAGS="-I$PREFIX/include"; LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
fi
export CPPFLAGS LDFLAGS

# htslib 1.5 names an unknown host "unknown-<system>", which current autoconf rejects: name it
(cd SeqLib/htslib && autoreconf -fi && T=$(sh ./config.guess) && ./configure --build="$T" --host="$T" --disable-libcurl --disable-s3 --disable-gcs && make)
(cd SeqLib/bwa && make CFLAGS="-g -Wall -Wno-unused-function -O2 -fcommon $CPPFLAGS")
(cd SeqLib/fermi-lite && make CFLAGS="-g -Wall -O2 -Wno-unused-function -fcommon $CPPFLAGS")
(cd SeqLib && autoreconf -fi && ./configure --build="$(sh ./config.guess)" && make)
${CXX:-g++} -Wall -std=c++11 -DDEBUG=0 ${MARCH:--march=native} -Ofast -Wl,-rpath,"$PWD/SeqLib/htslib" \
    -ISeqLib -ISeqLib/htslib $CPPFLAGS -LSeqLib/src -LSeqLib/bwa -LSeqLib/htslib $LDFLAGS \
    -o rtn rtn.c -lseqlib -lbwa -lhts -llzma -lz -lbz2 -lpthread -ljsoncpp
echo "built: $PWD/rtn"
