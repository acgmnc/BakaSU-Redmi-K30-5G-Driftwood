#!/usr/bin/env python3
"""
Repack an Android boot image (header v2), replacing the kernel and optionally
the DTB section while preserving the ramdisk, second stage, recovery DTBO and
kernel command line.

Usage:
    repack_boot.py <stock_boot.img> <new_Image> <out_boot.img> [new_dtb]
"""
import hashlib
import struct
import sys

MAGIC = b"ANDROID!"
HEADER_VERSION = 2
HEADER_SIZE = 1660
HEADER_MIN_SIZE = 0x67C
SECTIONS = ("kernel", "ramdisk", "second", "recovery_dtbo", "dtb")


def align(value, boundary):
    return (value + boundary - 1) // boundary * boundary


def require(condition, message):
    if not condition:
        raise ValueError(message)


def parse(data):
    require(len(data) >= HEADER_MIN_SIZE, "boot image is too small for a v2 header")
    require(data[:8] == MAGIC, "not an Android boot image")

    u32 = lambda offset: struct.unpack_from("<I", data, offset)[0]
    header = {
        "kernel_size": u32(0x08),
        "ramdisk_size": u32(0x10),
        "second_size": u32(0x18),
        "page_size": u32(0x24),
        "header_version": u32(0x28),
        "recovery_dtbo_size": u32(0x660),
        "recovery_dtbo_offset": struct.unpack_from("<Q", data, 0x664)[0],
        "header_size": u32(0x66C),
        "dtb_size": u32(0x670),
    }

    require(header["header_version"] == HEADER_VERSION,
            "only Android boot header version 2 is supported")
    page_size = header["page_size"]
    require(page_size >= HEADER_MIN_SIZE and page_size & (page_size - 1) == 0,
            "invalid boot image page size")
    require(header["header_size"] == HEADER_SIZE,
            "invalid v2 header_size: expected 1660 bytes")
    require(len(data) >= page_size, "boot image does not contain a complete header page")

    offset = page_size
    parts = {}
    for name in SECTIONS:
        size = header[name + "_size"]
        if name == "recovery_dtbo":
            if size:
                require(header["recovery_dtbo_offset"] == offset,
                        "recovery_dtbo_offset does not match the section layout")
            else:
                require(header["recovery_dtbo_offset"] == 0,
                        "recovery_dtbo_offset must be zero when recovery_dtbo is empty")

        end = offset + size
        require(end <= len(data), name + " section extends past end of boot image")
        parts[name] = data[offset:end]
        offset = align(end, page_size)

    return header, parts


def image_id(blobs):
    digest = hashlib.sha1()
    for name in SECTIONS:
        blob = blobs[name]
        digest.update(blob)
        digest.update(struct.pack("<I", len(blob)))
    return digest.digest()


def main():
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)

    stock_path, image_path, out_path = sys.argv[1:4]
    new_dtb_path = sys.argv[4] if len(sys.argv) == 5 else None

    with open(stock_path, "rb") as source:
        data = source.read()
    header, parts = parse(data)

    with open(image_path, "rb") as source:
        new_kernel = source.read()
    require(new_kernel, "replacement kernel is empty")

    blobs = {
        "kernel": new_kernel,
        "ramdisk": parts["ramdisk"],
        "second": parts["second"],
        "recovery_dtbo": parts["recovery_dtbo"],
        "dtb": parts["dtb"],
    }

    if new_dtb_path:
        with open(new_dtb_path, "rb") as source:
            new_dtb = source.read()
        require(new_dtb, "replacement DTB is empty")
        blobs["dtb"] = new_dtb

    page_size = header["page_size"]
    header_page_size = align(header["header_size"], page_size)
    hdr = bytearray(data[:header_page_size])

    try:
        struct.pack_into("<I", hdr, 0x08, len(blobs["kernel"]))
        struct.pack_into("<I", hdr, 0x670, len(blobs["dtb"]))
    except struct.error as error:
        raise ValueError("kernel or DTB is too large for the v2 header") from error

    # Recompute the recovery DTBO position after changing the kernel size.
    recovery_offset = page_size
    for name in ("kernel", "ramdisk", "second"):
        recovery_offset = align(recovery_offset + len(blobs[name]), page_size)
    struct.pack_into("<Q", hdr, 0x664,
                     recovery_offset if blobs["recovery_dtbo"] else 0)

    # Android mkbootimg hashes each section followed by its 32-bit byte length.
    hdr[0x240:0x260] = image_id(blobs).ljust(32, b"\x00")

    with open(out_path, "wb") as output:
        output.write(hdr)
        for name in SECTIONS:
            blob = blobs[name]
            output.write(blob)
            output.write(b"\x00" * (align(len(blob), page_size) - len(blob)))

    with open(out_path, "rb") as output:
        rebuilt = output.read()
    rebuilt_header, rebuilt_parts = parse(rebuilt)
    require(rebuilt_header["recovery_dtbo_offset"] ==
            (recovery_offset if blobs["recovery_dtbo"] else 0),
            "rebuilt recovery_dtbo_offset validation failed")
    for name in SECTIONS:
        require(rebuilt_parts[name] == blobs[name],
                "rebuilt " + name + " section validation failed")
    require(rebuilt[0x240:0x254] == image_id(blobs),
            "rebuilt boot image ID validation failed")

    cmdline = rebuilt[0x40:0x40 + 512].split(b"\x00")[0]
    print("kernel: %d -> %d bytes" %
          (header["kernel_size"], len(blobs["kernel"])))
    if new_dtb_path:
        print("dtb:    %d -> %d bytes" %
              (header["dtb_size"], len(blobs["dtb"])))
    else:
        print("dtb:    keeping stock (%d bytes)" % header["dtb_size"])
    print("cmdline:", cmdline[:50].decode(errors="replace"))
    print("size: %d (%.1f MB)" % (len(rebuilt), len(rebuilt) / 1048576))
    print("written:", out_path)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, struct.error) as error:
        sys.exit(str(error))
