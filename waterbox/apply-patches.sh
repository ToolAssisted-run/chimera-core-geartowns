#!/bin/sh
# Applies patches/ to the extern/geartowns submodule's working tree.
# The submodule stays at upstream's own commit; the patches are all-or-nothing:
# a clean tree gets the whole series, a tree with the first patch's marker is
# taken to have them all. Run at every meson configure.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
sub="$root/extern/geartowns"

# a submodule that was never checked out is an empty folder, and git there
# answers for this repository instead
[ "$(git -C "$sub" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$sub" && pwd -P)" ] || {
	echo "extern/geartowns is not checked out: git submodule update --init" >&2; exit 1; }

if grep -q 'Chimera: "." is the folder' "$sub/src/common/common.h" 2>/dev/null; then
	exit 0
fi

for p in "$root"/patches/*.patch; do
	git -C "$sub" apply "$p"
	echo "applied $(basename "$p")"
done
