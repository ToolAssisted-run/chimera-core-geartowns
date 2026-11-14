#!/usr/bin/env python3
# make-media.py <towns-ipl.bin> <out dir>: the disks the media tests use.
#
#   disk1.hdm              a 1232 KB 2HD floppy (77 cylinders, 2 sides,
#                          8 sectors of 1024 bytes), the boot program in the
#                          first sector, disk number 1, a raw image
#   disk2.d88              the same with disk number 2, as a D88 image (the
#                          format FM Towns floppies are most often kept in),
#                          marked write-protected, so a program that reads
#                          the drive's status can tell it from disk 1
#   disc.iso               a CD of 64 sectors of 2048 bytes, the boot program
#                          in the first, disk number 3
#
# The rest of each is a pattern, so a disk is never all zeros.
import os
import sys

ipl = open(sys.argv[1], "rb").read()
out = sys.argv[2]
assert len(ipl) == 1024 and ipl[:4] == b"IPL4", "towns-ipl.bin must be one 1024-byte IPL4 sector"
DISK_ID = 1020
os.makedirs(out, exist_ok=True)


def image(size, sector, disk):
    data = bytearray((i * 7 + disk) & 0xFF for i in range(size))
    boot = bytearray(ipl)
    boot[DISK_ID] = disk
    data[0:sector] = bytes(boot) + bytes(sector - len(boot))
    return bytes(data)


open(os.path.join(out, "disk1.hdm"), "wb").write(image(77 * 2 * 8 * 1024, 1024, 1))


def d88(raw, name, protect):
    """the same 2HD disk, sector by sector, in a D88 file"""
    tracks = []
    for cyl in range(77):
        for head in range(2):
            t = bytearray()
            for sec in range(1, 9):
                off = ((cyl * 2 + head) * 8 + (sec - 1)) * 1024
                t += bytes([cyl, head, sec, 3]) + (8).to_bytes(2, "little") + bytes([0, 0, 0]) + bytes(5) \
                    + (1024).to_bytes(2, "little") + raw[off:off + 1024]
            tracks.append(bytes(t))
    header = bytearray(0x2B0)
    header[0:len(name)] = name
    header[0x1A] = 0x10 if protect else 0x00
    header[0x1B] = 0x20  # 2HD
    pos = len(header)
    for i, t in enumerate(tracks):
        header[0x20 + i * 4:0x24 + i * 4] = pos.to_bytes(4, "little")
        pos += len(t)
    header[0x1C:0x20] = pos.to_bytes(4, "little")
    return bytes(header) + b"".join(tracks)


open(os.path.join(out, "disk2.d88"), "wb").write(d88(image(77 * 2 * 8 * 1024, 1024, 2), b"GEARTOWNS TEST", True))
open(os.path.join(out, "disc.iso"), "wb").write(image(64 * 2048, 2048, 3))
print("disk1.hdm disk2.d88 disc.iso")
