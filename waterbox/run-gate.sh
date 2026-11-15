#!/bin/bash
# The core's test script: the sandboxed core must give the same picture,
# sound, lag count and memory as the native reference build (the same
# cinterface.cpp, compiled for the host), and must give them again with a
# savestate saved and loaded around every frame.
#
# The test program is tests/free/towns-test.asm, our own, built as the
# system ROM (tests/free/build.sh, needs nasm): it boots every FM Towns model
# Geartowns emulates, with no Fujitsu firmware. What it does each frame is
# written at its top. It reads the pad, the mouse and the keyboard, draws,
# and plays the FM chip, so each of those is part of what is compared. The
# disk tests use floppy and CD images the script makes, holding our own boot
# program (tests/free/towns-ipl.asm, make-media.py); the CD is booted with
# the Free FM Towns Project's compatible system ROM, built from source when
# GEARTOWNS_COMPAT_ROM_SRC names a checkout of tests/free/compat-rom.ref.
#
# Usage: ./waterbox/run-gate.sh [-n <native build dir>] [-g <guest build dir>]
# Environment: CHIMERA_ROOT, a Chimera checkout with build/dll/chimera-run and
# this core's package in build/Cores, for the test through Chimera's engine;
# GEARTOWNS_COMPAT_ROM_SRC for the CD boot test. Each says SKIP without.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
nat="$root/build/meson-native"
gst="$root/build/meson-guest"
while getopts "n:g:" opt; do
	case "$opt" in
		n) nat="$OPTARG" ;;
		g) gst="$OPTARG" ;;
		*) exit 2 ;;
	esac
done

[ -x "$nat/run-native" ] && [ -x "$nat/run-wbx" ] || {
	echo "native build missing: meson setup build/meson-native -Dminibox_dir=<miniBox> && ninja -C build/meson-native" >&2; exit 1; }
[ -f "$gst/core.wbx" ] || {
	echo "guest build missing: sh waterbox/setup-guest.sh -m <miniBox> && ninja -C build/meson-guest core.wbx" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
digests() { grep -E '^(frames|vsync|videoHash|audioHash|audioSamples|audioNonzero|lagFrames|domain\[)'; }
# what a turbo run can be held to: all but the whole-run picture hash
turboDigests() { grep -E '^(frames|vsync|tailVideoHash|audioHash|audioSamples|lagFrames|domain\[)'; }
field() { sed -n "s/^$1=//p" "$2"; }

ok=0
failed=0
report() { printf "%-26s %-6s %s\n" "$1" "$2" "$3"; case "$2" in PASS) ok=$((ok+1)) ;; *) failed=$((failed+1)) ;; esac; }
printf "%-26s %-6s %s\n" "Check" "Result" "Detail"
printf "%-26s %-6s %s\n" "-----" "------" "------"

# the wire index of a control, from the package's own declaration
index_of() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['input']['buttons'].index(sys.argv[2]))" "$here/waterbox.config" "$1"; }

# ---- the free firmware ----
fw="$work/fw"
if ! sh "$root/tests/free/build.sh" "$fw" > "$work/fw.log" 2>&1; then
	report "free-rom:build" FAIL "$(tail -1 "$work/fw.log")"
	echo ""; echo "$ok ok, $failed failed"; exit 1
fi
echo "# $(tail -1 "$work/fw.log")"

# workdir <name> <settings json>: the firmware, the settings and no media
workdir() {
	local wd="$work/$1"
	rm -rf "$wd"
	mkdir -p "$wd"
	cp "$fw"/*.ROM "$wd/"
	printf '%s' "$2" > "$wd/settings"
	echo "$wd"
}

FRAMES=300
models=(model1_2 1f_2f 10f_20f cx ux ug hg hr ur me ma mx mf_fresh marty)
names=("FM Towns (Model 1/2)" "FM Towns 1F/2F" "FM Towns 10F/20F" "FM Towns II CX" "FM Towns II UX"
	"FM Towns II UG" "FM Towns II HG" "FM Towns II HR" "FM Towns II UR" "FM Towns II ME" "FM Towns II MA"
	"FM Towns II MX" "FM Towns II MF / Fresh" "FM Towns Marty")

# ---- every model: native == sandbox, and == sandbox with a savestate saved
# and loaded before every frame. The machine each one reports building must
# be the model asked for, in both, so a setting that did not arrive cannot
# pass as two runs of the default.
for i in "${!models[@]}"; do
	m="${models[$i]}"
	wd="$(workdir "$m" "{\"model\":\"$m\"}")"
	args=(--frames "$FRAMES" --exercise)
	if ! "$nat/run-native" "$wd" "${args[@]}" 2>"$work/n.err" | digests > "$work/n.txt"; then
		report "$m:equivalence" FAIL "native runner error: $(grep -m1 -v '^\[' "$work/n.err")"; continue
	fi
	if ! "$nat/run-wbx" "$gst/core.wbx" "$wd" "${args[@]}" 2>"$work/b.err" | digests > "$work/b.txt"; then
		report "$m:equivalence" FAIL "sandbox runner error: $(grep -m1 -v '^\[' "$work/b.err")"; continue
	fi
	cp "$work/b.txt" "$work/box.$m.txt"
	want="machine: ${names[$i]},"
	if ! grep -qF "$want" "$work/n.err" || ! grep -qF "$want" "$work/b.err"; then
		report "$m:equivalence" FAIL "the machine built is not the ${names[$i]}: $(grep -h 'machine:' "$work/n.err" | head -1)"
		continue
	fi
	if ! cmp -s "$work/n.txt" "$work/b.txt"; then
		report "$m:equivalence" FAIL "$(diff "$work/n.txt" "$work/b.txt" | tr '\n' ' ' | head -c 140)"; continue
	fi
	report "$m:equivalence" PASS "$FRAMES frames, native == sandbox, $(field vsync "$work/b.txt") Hz"
	if "$nat/run-wbx" "$gst/core.wbx" "$wd" "${args[@]}" --rerecord 2>/dev/null | digests > "$work/r.txt" \
		&& cmp -s "$work/b.txt" "$work/r.txt"; then
		report "$m:savestate" PASS "a save and a load before every frame change nothing"
	else
		report "$m:savestate" FAIL "$(diff "$work/b.txt" "$work/r.txt" | tr '\n' ' ' | head -c 140)"
	fi
done

# the models must not all be one machine: the 386SX, the 486s and the Marty
# each run the program differently
distinct="$(cat "$work"/box.*.txt 2>/dev/null | grep '^domain\[Main RAM\]\|^audioSamples\|^vsync' | sort -u | wc -l)"
if [ "$distinct" -ge 6 ]; then
	report "models:distinct" PASS "$distinct different RAM, sound and rate results across the models"
else
	report "models:distinct" FAIL "only $distinct different results across ${#models[@]} models"
fi

# ---- the rest on the Model 1/2 ----
base="$(workdir base '{"model":"model1_2"}')"
"$nat/run-wbx" "$gst/core.wbx" "$base" --frames "$FRAMES" 2>/dev/null | digests > "$work/idle.txt"

# The program reads its controls on 15 frames of 16 and draws, so a frame
# nobody read must be counted as lag, and only those.
lag="$(field lagFrames "$work/idle.txt")"
if [ -n "$lag" ] && [ "$lag" -ge $((FRAMES / 16 - 2)) ] && [ "$lag" -le $((FRAMES / 16 + 4)) ]; then
	report "lag:count" PASS "$lag lag frames in $FRAMES, the frames the program leaves unread"
else
	report "lag:count" FAIL "lagFrames=${lag:-missing} in $FRAMES frames, expected about $((FRAMES / 16))"
fi

# The sound: the program clicks every 32 frames, so the sound is not
# silence, and its length is the chip's rate over the frame rate.
nz="$(field audioNonzero "$work/idle.txt")"
samples="$(field audioSamples "$work/idle.txt")"
rate="$(field vsync "$work/idle.txt")"
if python3 -c "
import sys; n,d=map(int,'$rate'.split('/')); s=int('$samples'); want=44100*$FRAMES*d/n
sys.exit(0 if int('$nz')>0 and abs(s-want)<want*0.01 else 1)" 2>/dev/null; then
	report "sound:rate" PASS "$samples samples in $FRAMES frames at $rate Hz is 44100 a second; $nz not silent"
else
	report "sound:rate" FAIL "samples=$samples nonzero=$nz rate=$rate"
fi

# Each control must reach the machine: the run with it differs from the
# idle run, and native == sandbox for it.
control_leg() {
	local tag="$1" settings="$2"
	shift 2
	local wd
	wd="$(workdir "$tag" "$settings")"
	"$nat/run-native" "$wd" --frames "$FRAMES" "$@" 2>/dev/null | digests > "$work/cn.txt"
	"$nat/run-wbx" "$gst/core.wbx" "$wd" --frames "$FRAMES" "$@" 2>/dev/null | digests > "$work/cb.txt"
	if ! [ -s "$work/cb.txt" ] || ! cmp -s "$work/cn.txt" "$work/cb.txt"; then
		report "$tag" FAIL "native and sandbox differ: $(diff "$work/cn.txt" "$work/cb.txt" | tr '\n' ' ' | head -c 120)"
	elif cmp -s "$work/cb.txt" "$work/idle.txt"; then
		report "$tag" FAIL "the machine is the idle one: the control did not reach it"
	else
		report "$tag" PASS "reaches the machine, native == sandbox"
	fi
}
control_leg "input:pad" '{"model":"model1_2"}' --hold "$(index_of 'P1 Right')"
control_leg "input:pad-button" '{"model":"model1_2"}' --hold "$(index_of 'P1 A')"
control_leg "input:keyboard" '{"model":"model1_2"}' --press "$(index_of 'Key A')" 100
control_leg "input:reset" '{"model":"model1_2"}' --press "$(index_of 'Reset')" 100
control_leg "input:mouse-button" '{"model":"model1_2"}' --hold "$(index_of 'Mouse Left')"

# The mouse is read through game port B, which the portB setting makes a
# mouse by default: with nothing there the same schedule must be another
# machine, else the setting or the mouse never arrived.
wd="$(workdir mouseoff '{"model":"model1_2","portB":"none"}')"
"$nat/run-wbx" "$gst/core.wbx" "$wd" --frames "$FRAMES" --exercise 2>/dev/null | digests > "$work/mo.txt"
"$nat/run-native" "$wd" --frames "$FRAMES" --exercise 2>/dev/null | digests > "$work/mon.txt"
if ! [ -s "$work/mo.txt" ] || ! cmp -s "$work/mo.txt" "$work/mon.txt"; then
	report "settings:portB" FAIL "native and sandbox differ with portB=none"
elif cmp -s "$work/mo.txt" "$work/box.model1_2.txt"; then
	report "settings:portB" FAIL "portB=none built the machine the default builds"
else
	report "settings:portB" PASS "portB=none unplugs the mouse the program reads"
fi

# Turbo: drawing off for the first half and on for the second must leave the
# machine, the sound and the second half's pictures as they were. The
# whole-run picture hash must differ, or nothing was skipped.
"$nat/run-wbx" "$gst/core.wbx" "$base" --frames "$FRAMES" --exercise 2>/dev/null > "$work/tn.raw"
"$nat/run-wbx" "$gst/core.wbx" "$base" --frames "$FRAMES" --exercise --turbo 2>/dev/null > "$work/tt.raw"
turboDigests < "$work/tn.raw" > "$work/tn.txt"
turboDigests < "$work/tt.raw" > "$work/tt.txt"
if ! [ -s "$work/tt.txt" ] || ! cmp -s "$work/tn.txt" "$work/tt.txt"; then
	report "turbo" FAIL "$(diff "$work/tn.txt" "$work/tt.txt" | tr '\n' ' ' | head -c 120)"
elif [ "$(field videoHash "$work/tn.raw")" = "$(field videoHash "$work/tt.raw")" ]; then
	report "turbo" FAIL "the turbo run drew every frame"
else
	report "turbo" PASS "half the frames undrawn, the same machine and the same later pictures"
fi

# Save data: the CMOS comes out the same from both builds.
mkdir -p "$work/sd.n" "$work/sd.b"
"$nat/run-native" "$base" --frames 60 --savedata-out "$work/sd.n" > /dev/null 2>&1
"$nat/run-wbx" "$gst/core.wbx" "$base" --frames 60 --savedata-out "$work/sd.b" > /dev/null 2>&1
nf="$(find "$work/sd.n" -type f | wc -l)"
if [ "$nf" -ge 1 ] && diff -r "$work/sd.n" "$work/sd.b" > /dev/null 2>&1; then
	report "savedata:export" PASS "$nf file(s), native == sandbox"
else
	report "savedata:export" FAIL "$nf file(s) natively; the two exports differ or are empty"
fi

# ---- disks ----
# The floppies and the CD the test scripts make (tests/free/make-media.py):
# disk 1 a raw image, disk 2 a write-protected D88, the CD an ISO, each
# starting with towns-ipl.asm, our own boot program.
media="$work/media"
if ! nasm -f bin -o "$work/ipl.bin" "$root/tests/free/towns-ipl.asm" > "$work/media.log" 2>&1 \
	|| ! python3 "$root/tests/free/make-media.py" "$work/ipl.bin" "$media" >> "$work/media.log" 2>&1; then
	report "media:build" FAIL "$(tail -1 "$work/media.log")"
fi

# media_leg <tag> <workdir> <what it must not be: a digests file> <options>:
# native == sandbox == sandbox with a savestate every frame, and not the
# machine of the other file
media_leg() {
	local tag="$1" wd="$2" unlike="$3"
	shift 3
	"$nat/run-native" "$wd" --frames "$FRAMES" "$@" 2>"$work/mn.err" | digests > "$work/mn.txt"
	"$nat/run-wbx" "$gst/core.wbx" "$wd" --frames "$FRAMES" "$@" 2>/dev/null | digests > "$work/mb.txt"
	"$nat/run-wbx" "$gst/core.wbx" "$wd" --frames "$FRAMES" "$@" --rerecord 2>/dev/null | digests > "$work/mr.txt"
	if ! [ -s "$work/mb.txt" ] || ! cmp -s "$work/mn.txt" "$work/mb.txt"; then
		report "$tag" FAIL "native and sandbox differ: $(grep -m1 -v '^\[' "$work/mn.err") $(diff "$work/mn.txt" "$work/mb.txt" | tr '\n' ' ' | head -c 100)"
	elif ! cmp -s "$work/mb.txt" "$work/mr.txt"; then
		report "$tag" FAIL "a savestate every frame changes the run"
	elif cmp -s "$work/mb.txt" "$unlike"; then
		report "$tag" FAIL "the machine is the one without this disk"
	else
		report "$tag" PASS "native == sandbox == savestate every frame, and the disk is seen"
	fi
	cp "$work/mb.txt" "$work/media.$tag.txt"
}

# floppy drive 1, which the test program reads the status of every frame:
# with disk 1 in it, it is ready; Next Floppy Disk puts in disk 2, which is
# write-protected
wd="$(workdir floppy1 '{"model":"model1_2"}')"
cp "$media/disk1.hdm" "$media/disk2.d88" "$wd/"
printf '{"floppy":["disk1.hdm","disk2.d88"]}' > "$wd/slots"
media_leg "floppy:inserted" "$wd" "$work/idle.txt"
media_leg "floppy:next-disk" "$wd" "$work/media.floppy:inserted.txt" --press "$(index_of 'Next Floppy Disk')" 100

# the CD, booted: the Free FM Towns Project's compatible system ROM, built
# from its source at the commit tests/free/compat-rom.ref names, reads the
# disc's first sector and runs our boot program, which notes the drive it
# came from. (That ROM cannot boot a floppy on Geartowns: it waits about
# 20 ms for the drive's motor, and Geartowns' drive takes 363 ms to spin up,
# as a real one does.)
if [ -z "${GEARTOWNS_COMPAT_ROM_SRC:-}" ]; then
	printf "%-26s %-6s %s\n" "cd:boot" SKIP "needs GEARTOWNS_COMPAT_ROM_SRC (a checkout of tests/free/compat-rom.ref) and nasm"
elif ! sh "$root/tests/free/build-compat-rom.sh" "$GEARTOWNS_COMPAT_ROM_SRC" "$work/compat" > "$work/compat.log" 2>&1; then
	report "cd:boot" FAIL "the compatible ROM did not build: $(tail -1 "$work/compat.log")"
else
	echo "# $(tail -1 "$work/compat.log")"
	wd="$work/cd"
	rm -rf "$wd" && mkdir -p "$wd"
	cp "$work/compat"/*.ROM "$media/disc.iso" "$wd/"
	printf '{"model":"model1_2"}' > "$wd/settings"
	# the same machine with no CD in the drive, for the boot to differ from
	nocd="$work/nocd"
	rm -rf "$nocd" && mkdir -p "$nocd"
	cp "$work/compat"/*.ROM "$nocd/"
	cp "$wd/settings" "$nocd/"
	"$nat/run-wbx" "$gst/core.wbx" "$nocd" --frames "$FRAMES" --exercise 2>/dev/null | digests > "$work/nocd.txt"
	printf '{"cdrom":["disc.iso"]}' > "$wd/slots"
	media_leg "cd:boot" "$wd" "$work/nocd.txt" --exercise
	"$nat/run-wbx" "$gst/core.wbx" "$wd" --frames "$FRAMES" --dump-domain "Main RAM" "$work/cd.ram" > /dev/null 2>&1
	booted="$(python3 -c "import sys; d=open(sys.argv[1],'rb').read(); print(d[0x600:0x607].hex())" "$work/cd.ram" 2>/dev/null)"
	if [ "$booted" = "424f4f54080003" ]; then
		report "cd:booted-from" PASS "the boot program ran from the CD (drive kind 8, disk 3)"
	else
		report "cd:booted-from" FAIL "the boot program's note is '${booted:-none}', not BOOT from the CD"
	fi
fi

# ---- through Chimera's engine: each read of the controls is reported to
# Chimera as it happens (chimera#344), and counting them moves nothing.
runner="${CHIMERA_ROOT:-}/build/dll/chimera-run"
package="${CHIMERA_ROOT:-}/build/Cores/geartowns.chimeraCore"
if [ -n "${CHIMERA_ROOT:-}" ] && [ -x "$runner" ] && [ -f "$package" ]; then
	fwargs=()
	for f in FMT_SYS FMT_DOS FMT_FNT FMT_DIC; do fwargs+=(--firmware "$f.ROM=$fw/$f.ROM"); done
	# a project of no game file, to record 300 idle frames in, then one with
	# those frames as its movie
	: > "$work/none.txt"
	"$runner" --new-project "$work/none.chimeraProject" "$package" --movie "$work/none.txt" \
		--settings '{"model":"model1_2"}' "${fwargs[@]}" > "$work/none.make.log" 2>&1
	"$runner" --project "$work/none.chimeraProject" "$package" "${fwargs[@]}" \
		--frames 300 --record "$work/idle.txt" > "$work/idle.log" 2>&1
	"$runner" --new-project "$work/p.chimeraProject" "$package" --movie "$work/idle.txt" \
		--settings '{"model":"model1_2"}' "${fwargs[@]}" > "$work/p.make.log" 2>&1
	"$runner" --project "$work/p.chimeraProject" "$package" "${fwargs[@]}" \
		--dump "Main RAM=$work/plain.ram" > "$work/plain.log" 2>&1
	"$runner" --project "$work/p.chimeraProject" "$package" "${fwargs[@]}" --count-input-polls \
		--dump "Main RAM=$work/polls.ram" --meta "$work/polls.meta" > "$work/polls.log" 2>&1
	polls=$(sed -n 's/^inputPolls=//p' "$work/polls.meta" 2> /dev/null)
	lags=$(sed -n 's/^lagFrames=//p' "$work/polls.meta" 2> /dev/null)
	frames=$(sed -n 's/^frames=//p' "$work/polls.meta" 2> /dev/null)
	if [ "${polls:-none}" != none ] && [ "${frames:-0}" = 300 ] && [ "${lags:-300}" -lt 300 ] \
		&& [ "${polls:-0}" -ge $(( 300 - ${lags:-300} )) ] && [ -s "$work/plain.ram" ] && cmp -s "$work/plain.ram" "$work/polls.ram"; then
		report "engine:input-polls" PASS "$polls reads of the controls in 300 frames, $lags lag frames; Main RAM as without counting"
	else
		report "engine:input-polls" FAIL "inputPolls=${polls:-missing} frames=${frames:-?} lagFrames=${lags:-?}; $(tail -1 "$work/polls.log" 2> /dev/null)"
	fi

	# the core's own tool, Make a Blank Floppy Disk: a 1232 KB (2HD) D88
	# image, formatted - all 154 tracks of eight 1024-byte sectors, a boot
	# sector and an empty file table - which the core takes in drive 1 like
	# any floppy (the test program reads the drive's status)
	rm -f "$work/blank.d88"
	"$runner" --run-tool blank_floppy "$package" --output "disk=$work/blank.d88" > "$work/tool.log" 2>&1
	d88="$(python3 -c "
import struct,sys
d=open(sys.argv[1],'rb').read()
t0=struct.unpack_from('<I',d,0x20)[0] if len(d)>0x2B0 else 0
ok=(len(d)==0x2B0+154*8*(16+1024) and d[0x1B]==0x20 and struct.unpack_from('<I',d,0x1C)[0]==len(d)
    and d[0:8]==b'USERDISK' and d[t0+16:t0+20]==b'IPL4' and d[t0+16+1040:t0+16+1043]==bytes((0xFE,0xFF,0xFF)))
print('ok' if ok else 'bad')" "$work/blank.d88" 2>/dev/null)"
	if [ "$d88" != ok ]; then
		report "tool:blank-floppy" FAIL "no formatted 2HD D88 image made: $(tail -1 "$work/tool.log")"
	else
		wd="$(workdir blankfd '{"model":"model1_2"}')"
		cp "$work/blank.d88" "$wd/"
		printf '{"floppy":["blank.d88"]}' > "$wd/slots"
		media_leg "tool:blank-floppy" "$wd" "$work/idle.txt"
	fi
else
	printf "%-26s %-6s %s\n" "engine:input-polls" SKIP "needs CHIMERA_ROOT with build/dll/chimera-run and build/Cores/geartowns.chimeraCore"
	printf "%-26s %-6s %s\n" "tool:blank-floppy" SKIP "needs CHIMERA_ROOT, as above"
fi

echo ""
echo "$ok ok, $failed failed"
[ "$failed" -gt 0 ] && exit 1
exit 0
