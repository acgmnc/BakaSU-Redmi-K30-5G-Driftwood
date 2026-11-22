#!/usr/bin/env python3
"""
Repack a stock boot.img with a new kernel Image, for Redmi K30 5G (picasso).

- Kernel is gzip-compressed (matching the stock A17 boot image format).
- ramdisk / second / recovery_dtbo / dtb / cmdline are preserved.
- `ramoops_memreserve=4M` is appended to the cmdline (for pstore crash logs).

Usage:
    python3 scripts/pack-boot.py <stock_boot.img> <Image> <out_boot.img>
"""
import gzip
import struct
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import repack_boot as rb  # noqa: E402


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    stock, image, out = sys.argv[1:4]

    raw = open(image, 'rb').read()
    gz = gzip.compress(raw, 6, mtime=0)

    data = open(stock, 'rb').read()
    h, parts = rb.parse(data)
    ps = h['page_size']
    hdr = bytearray(data[:rb.align(h['header_size'], ps)])

    blobs = {
        'kernel': gz,
        'ramdisk': parts['ramdisk'],
        'second': parts['second'],
        'recovery_dtbo': parts['recovery_dtbo'],
        'dtb': parts['dtb'],
    }
    struct.pack_into('<I', hdr, 0x08, len(gz))

    cmd = bytes(hdr[0x40:0x40 + 512]).split(b'\0')[0]
    if b'ramoops_memreserve' not in cmd:
        cmd += b' ramoops_memreserve=4M'
    hdr[0x40:0x40 + 512] = cmd.ljust(512, b'\0')[:512]

    with open(out, 'wb') as f:
        f.write(hdr)
        for name in rb.SECTIONS:
            b = blobs[name]
            if not b:
                continue
            f.write(b)
            f.write(b'\0' * (rb.align(len(b), ps) - len(b)))

    print('Image   : %d bytes (gzip %d)' % (len(raw), len(gz)))
    print('written : %s (%d bytes)' % (out, os.path.getsize(out)))


if __name__ == '__main__':
    main()
