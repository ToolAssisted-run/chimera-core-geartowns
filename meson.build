# chimera-core-geartowns: Geartowns (FM Towns) in miniBox's sandbox, as a
# Chimera core.
#
# Native reference build (run-native and run-wbx; run-wbx links miniBox's host
# library out of its meson-cpp build folder):
#     meson setup build/meson-native -Dminibox_dir=<miniBox> && ninja -C build/meson-native
# Guest (core.wbx) build, through the cross file waterbox/setup-guest.sh
# writes (needs miniBox's C++ guest toolchain, build/meson-cpp):
#     sh waterbox/setup-guest.sh -m <miniBox> && ninja -C build/meson-guest core.wbx
#
# The source list is upstream's libretro core's (platforms/libretro/
# Makefile.common) without libretro.cpp and GNU
# lightning: the interpreter runs, the recompiler is not built
# (GT_DISABLE_DYNAREC). The defines are the libretro build's. Both flavours
# compile the same waterbox/cinterface.cpp; only emulibc.h differs.
project('chimera-core-geartowns', ['c', 'cpp'],
  default_options: ['c_std=gnu99', 'cpp_std=c++11', 'optimization=2', 'debug=false', 'warning_level=0'])

gt = 'extern/geartowns'
src = gt / 'src'
deps = gt / 'platforms/shared/dependencies'

# the submodule is upstream's commit; the patches go on its working tree
run_command(files('waterbox/apply-patches.sh'), check: true)

mb = get_option('minibox_dir')
if mb == ''
  mb_candidate = meson.current_source_dir() / '../chimera/extern/chimera-common-minibox'
  if import('fs').is_dir(mb_candidate)
    mb = mb_candidate
  else
    error('pass -Dminibox_dir=<miniBox checkout> (or keep one at ../chimera/extern/chimera-common-minibox)')
  endif
endif

defs = [
  '-DNDEBUG',
  '-D__LIBRETRO__',
  '-DGT_DISABLE_DYNAREC',
  '-DGT_DISABLE_DISASSEMBLER',
  '-DGT_DISABLE_VGMRECORDER',
  '-DGT_CHIMERA_NO_TOWNS_OS_CODE',
  '-DZ7_ST',
  '-DZSTD_DISABLE_ASM',
  '-DEMULATOR_BUILD="1.0.6"',
]
quiet = ['-fno-strict-aliasing', '-w']
add_project_arguments(defs + quiet, language: ['c', 'cpp'])
add_project_arguments(['-fno-rtti'], language: 'cpp')
# GCC on aarch64 fuses a multiply and an add into one rounding unless told
# not to; the guest is built with -ffp-contract=off, so the reference is too.
if not meson.is_cross_build() and host_machine.cpu_family() == 'aarch64'
  add_project_arguments('-ffp-contract=off', language: ['c', 'cpp'])
endif

inc = include_directories(
  'waterbox',
  src,
  gt / 'platforms/libretro',
  deps / 'miniz',
  deps / 'minivorbis',
  deps / 'libchdr/include',
  deps / 'zstd',
  deps / 'lzma/include',
  deps / 'bochs_fpu',
)

core_sources = files(
  deps / 'miniz/miniz.c',
  deps / 'libchdr/src/libchdr_bitstream.c',
  deps / 'libchdr/src/libchdr_cdrom.c',
  deps / 'libchdr/src/libchdr_chd.c',
  deps / 'libchdr/src/libchdr_flac.c',
  deps / 'libchdr/src/libchdr_huffman.c',
  deps / 'lzma/src/LzFind.c',
  deps / 'lzma/src/LzmaEnc.c',
  deps / 'lzma/src/LzmaDec.c',
  deps / 'lzma/src/CpuArch.c',
  deps / 'minivorbis/minivorbis.c',
  deps / 'bochs_fpu/bochs_fpu.cpp',
  src / 'geartowns_core.cpp',
  src / 'common/profiler.cpp',
  src / 'common/trace_logger.cpp',
  src / 'audio/audio.cpp',
  src / 'audio/pcm16.cpp',
  src / 'audio/rf5c68.cpp',
  src / 'audio/ym3438.cpp',
  src / 'audio/vgm_recorder.cpp',
  src / 'cdrom/cdrom.cpp',
  src / 'cdrom/cdrom_audio.cpp',
  src / 'cdrom/cdrom_chd_image.cpp',
  src / 'cdrom/cdrom_cuebin_image.cpp',
  src / 'cdrom/cdrom_image.cpp',
  src / 'cdrom/cdrom_media.cpp',
  src / 'drive/fdc.cpp',
  src / 'drive/mb8877.cpp',
  src / 'drive/scsi_controller.cpp',
  src / 'drive/scsi_disk.cpp',
  src / 'drive/hard_disk_image.cpp',
  src / 'drive/floppy_disk.cpp',
  src / 'drive/floppy_image.cpp',
  src / 'drive/memory_card.cpp',
  src / 'i386/i386.cpp',
  src / 'i386/i386_486.cpp',
  src / 'i386/i386_bus.cpp',
  src / 'i386/i386_disassembler.cpp',
  src / 'i386/i386_dynarec.cpp',
  src / 'i386/i386_dynarec_emit.cpp',
  src / 'i386/i386_encoding.cpp',
  src / 'i386/i386_functors.cpp',
  src / 'i386/i386_memory.cpp',
  src / 'i386/i386_opcodes.cpp',
  src / 'i386/i386_opcodes_0f.cpp',
  src / 'i386/i386_opcodes_groups.cpp',
  src / 'i386/i386_opcodes_string.cpp',
  src / 'i386/i386_opcodes_transfer.cpp',
  src / 'i386/i386_protected.cpp',
  src / 'i386/i386_protected_transfer.cpp',
  src / 'i386/i386_task.cpp',
  src / 'i386/exec_memory.cpp',
  src / 'i386/x87.cpp',
  src / 'input/input.cpp',
  src / 'input/keyboard.cpp',
  src / 'media/chd_file_adapter.cpp',
  src / 'media/firmware.cpp',
  src / 'media/media.cpp',
  src / 'media/media_file.cpp',
  src / 'media/media_file_libretro.cpp',
  src / 'media/media_file_native.cpp',
  src / 'media/ogg_vorbis_decoder.cpp',
  src / 'system/i8253.cpp',
  src / 'system/i8259.cpp',
  src / 'system/io.cpp',
  src / 'system/memory.cpp',
  src / 'system/pic.cpp',
  src / 'system/pit.cpp',
  src / 'system/msm58321.cpp',
  src / 'system/scheduler.cpp',
  src / 'system/system_control.cpp',
  src / 'system/upd71071.cpp',
  src / 'system/load_detector.cpp',
  src / 'video/hires_crtc.cpp',
  src / 'video/sprite.cpp',
  src / 'video/video.cpp',
  gt / 'platforms/libretro/libretro_vfs_file.cpp',
  'waterbox/cinterface.cpp',
)

if meson.is_cross_build()
  # ---- the guest: core.wbx --------------------------------------------------
  # miniBox's musl and libstdc++ toolchain arrive through the cross file; the
  # link is the C++ guest kit's (cxxglue for the unwinder, the pthread
  # functions libgcc_eh asks for kept), as chimera-core-snes9x links.
  mbdir = meson.get_external_property('minibox_dir')
  mbuild = meson.get_external_property('minibox_build')
  sr = meson.get_external_property('guest_sysroot')

  executable('core', core_sources,
    name_suffix: 'wbx',
    include_directories: inc,
    link_args: [
      '-static', '-no-pie',
      '-Wl,--eh-frame-hdr', '-Wl,-O2', '-Wl,--no-relax', '-Wl,-z,stack-size=8388608',
      '-T', mbdir / 'source/guest/linkscript.T',
      '-Wl,-u,pthread_once', '-Wl,-u,pthread_cond_wait',
      '-Wl,-u,pthread_cond_broadcast', '-Wl,-u,pthread_key_create',
      mbuild / 'source/guest/cxxglue.c.o',
      mbuild / 'source/guest/emulibc.c.o',
      '-L' + sr / 'lib', '-lstdc++', '-lgcc', '-lgcc_eh', '-lc'])
else
  # ---- the native reference -------------------------------------------------
  m = meson.get_compiler('c').find_library('m', required: false)
  executable('run-native', core_sources + files('waterbox/run-native.c'),
    include_directories: [include_directories('waterbox/native-shim'), inc],
    c_args: ['-I' + mb / 'source/guest/include', '-I' + mb / 'extern/jsmn'],
    cpp_args: ['-I' + mb / 'source/guest/include', '-I' + mb / 'extern/jsmn'],
    dependencies: [m])

  # the host library from the same miniBox build folder the guest toolchain
  # is in: meson-cpp, the C++ guest kit's
  mbhost = mb / 'build/meson-cpp/source/host'
  executable('run-wbx', files('waterbox/run-wbx.c'),
    c_args: ['-I' + mb / 'source/host'],
    link_args: [mbhost / 'libminiboxhost.so', '-Wl,-rpath,' + mbhost])
endif
