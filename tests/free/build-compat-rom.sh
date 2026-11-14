#!/bin/sh
# build-compat-rom.sh <source checkout> <out dir>: the Free FM Towns Project's
# compatible system ROM, for the media tests.
#
# Kasanova's FM Towns compatible system ROM, continued by CaptainYS (Soji
# Yamakawa) in github.com/captainys/TOWNSROM, boots a floppy, a CD or a hard
# disk with no code of Fujitsu's. Its terms allow it to be changed and passed
# on with its notice (FMT_SYS/about.txt and LICENSE.md there). This builds it
# from the commit compat-rom.ref names, as its own build does (FMT_SYS/src/
# nasm.py): nasm assembles the boot code, and the ROM is the parts in
# FMT_SYS/parts in order. It also makes blank OS, font and dictionary ROMs,
# which a boot from disk does not read.
#
# For the tests only: nothing of it is in the package.
set -eu
src="$1"
out="$2"
here="$(cd "$(dirname "$0")" && pwd)"
want="$(sed -n 's/^commit //p' "$here/compat-rom.ref")"
have="$(git -C "$src" rev-parse HEAD 2>/dev/null || echo "not a git checkout")"
if [ "$have" != "$want" ]; then
	echo "the source is at $have, not at $want (tests/free/compat-rom.ref)" >&2
	exit 1
fi
command -v nasm >/dev/null 2>&1 || { echo "no nasm: install nasm" >&2; exit 1; }
rm -rf "$out"
mkdir -p "$out/src"
cp -a "$src/FMT_SYS/." "$out/src/"
(cd "$out/src/src" && nasm -O3 -f bin sys.asm -o ../parts/fmt_sys6.prg)
p="$out/src/parts"
cat "$p/FMT_SYS0.F12" "$p/FMT_SYS1.EXB" "$p/FMT_SYS2.ICN" "$p/FMT_SYS3.DMY" "$p/FMT_SYS4.LGO" "$p/FMT_SYS5.IC2" \
	"$p/fmt_sys6.prg" > "$out/FMT_SYS.ROM"
[ "$(wc -c < "$out/FMT_SYS.ROM")" -eq 262144 ] || { echo "FMT_SYS.ROM is not 256 KB" >&2; exit 1; }
blank() { python3 -c "import sys; open(sys.argv[1], 'wb').write(b'\xff' * int(sys.argv[2]))" "$out/$1" "$2"; }
blank FMT_DOS.ROM 524288
blank FMT_FNT.ROM 262144
blank FMT_DIC.ROM 524288
rm -rf "$out/src"
echo "compatible FMT_SYS.ROM: sha1 $(sha1sum "$out/FMT_SYS.ROM" | cut -c1-40), built with $(nasm -v)"
