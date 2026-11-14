#!/bin/sh
# build.sh <out dir>: the free firmware the test scripts boot.
#
# FMT_SYS.ROM is towns-test.asm, our own test program built as a system ROM
# (nasm). The OS, font and dictionary ROMs a machine also needs are blank:
# the test program never reads them. Marty's extension ROMs are not needed
# either, because the test program is the whole boot. Nothing here is
# Fujitsu's, and none of it goes in the package.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
out="$1"
command -v nasm >/dev/null 2>&1 || { echo "no nasm: install nasm" >&2; exit 1; }
mkdir -p "$out"
nasm -f bin -o "$out/FMT_SYS.ROM" "$here/towns-test.asm"
[ "$(wc -c < "$out/FMT_SYS.ROM")" -eq 262144 ] || { echo "FMT_SYS.ROM is not 256 KB" >&2; exit 1; }
blank() { python3 -c "import sys; open(sys.argv[1], 'wb').write(b'\xff' * int(sys.argv[2]))" "$out/$1" "$2"; }
blank FMT_DOS.ROM 524288
blank FMT_FNT.ROM 262144
blank FMT_DIC.ROM 524288
echo "FMT_SYS.ROM: sha1 $(sha1sum "$out/FMT_SYS.ROM" | cut -c1-40), built with $(nasm -v)"
