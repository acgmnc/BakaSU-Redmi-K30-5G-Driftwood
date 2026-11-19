#!/usr/bin/env python3
"""
Repack an Android boot image (header v2) replacing the kernel and optionally
the dtb section. The original ramdisk / second / recovery_dtbo / cmdline are
preserved byte-for-byte.

Usage:
    repack_boot.py <stock_boot.img> <new_Image> <out_boot.img> [new_dtb]
"""
import struct
import sys

PAGE = 4096
SECTIONS = ("kernel", "ramdisk", "second", "recovery_dtbo", "dtb")


def align(x, a=PAGE):
    return (x + a - 1) // a * a


def parse(data):
    if data[:8] != b"ANDROID!":
        sys.exit("not an Android boot image")
    u32 = lambda o: struct.unpack_from("<I", data, o)[0]
    h = {
        "kernel_size":        u32(0x08),
        "ramdisk_size":       u32(0x10),
        "second_size":        u32(0x18),
        "page_size":          u32(0x24),
        "header_version":     u32(0x28),
        "recovery_dtbo_size": u32(0x660),
        "header_size":        u32(0x66C),
        "dtb_size":           u32(0x670),
    }
    ps = h["page_size"]
    off = align(h["header_size"], ps)
    parts = {}
    for name in SECTIONS:
        size = h[name + "_size"]
        parts[name] = data[off:off + size]
        off = align(off + size, ps)
    return h, parts


def main():
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)
    stock_path, image_path, out_path = sys.argv[1:4]
    new_dtb_path = sys.argv[4] if len(sys.argv) == 5 else None

    data = open(stock_path, "rb").read()
    h, parts = parse(data)
    ps = h["page_size"]
    hsize_pages = align(h["header_size"], ps)

    new_kernel = open(image_path, "rb").read()
    blobs = {
        "kernel": new_kernel,
        "ramdisk": parts["ramdisk"],
        "second": parts["second"],
        "recovery_dtbo": parts["recovery_dtbo"],
        "dtb": parts["dtb"],
    }

    hdr = bytearray(data[:hsize_pages])          # keep original header bytes
    struct.pack_into("<I", hdr, 0x08, len(new_kernel))
    print("kernel: %d -> %d bytes" % (h["kernel_size"], len(new_kernel)))

    if new_dtb_path:
        new_dtb = open(new_dtb_path, "rb").read()
        blobs["dtb"] = new_dtb
        struct.pack_into("<I", hdr, 0x670, len(new_dtb))
        print("dtb:    %d -> %d bytes" % (h["dtb_size"], len(new_dtb)))
    else:
        print("dtb:    keeping stock (%d bytes)" % h["dtb_size"])

    with open(out_path, "wb") as f:
        f.write(hdr)
        for name in SECTIONS:
            blob = blobs[name]
            if not blob:
                continue
            f.write(blob)
            f.write(b"\x00" * (align(len(blob), ps) - len(blob)))

    out = open(out_path, "rb").read()
    cmd = out[0x40:0x40 + 512].split(b"\x00")[0]
    print("magic ok:", out[:8] == b"ANDROID!")
    print("cmdline:", cmd[:50].decode(errors="replace"))
    print("size: %d (%.1f MB)" % (len(out), len(out) / 1048576))
    print("written:", out_path)


if __name__ == "__main__":
    main()
