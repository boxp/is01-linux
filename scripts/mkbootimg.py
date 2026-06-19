#!/usr/bin/env python3
import argparse
import hashlib
import struct
from pathlib import Path


def parse_u32(value: str) -> int:
    return int(value, 0)


def pad(data: bytes, page_size: int) -> bytes:
    remainder = len(data) % page_size
    if remainder == 0:
        return data
    return data + (b"\0" * (page_size - remainder))


def main() -> int:
    parser = argparse.ArgumentParser(description="Create an Android boot image v0.")
    parser.add_argument("--kernel", required=True)
    parser.add_argument("--ramdisk", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--kernel-addr", type=parse_u32, required=True)
    parser.add_argument("--ramdisk-addr", type=parse_u32, required=True)
    parser.add_argument("--second-addr", type=parse_u32, required=True)
    parser.add_argument("--tags-addr", type=parse_u32, required=True)
    parser.add_argument("--page-size", type=parse_u32, required=True)
    parser.add_argument(
        "--image-align-size",
        type=parse_u32,
        help="alignment used between Android boot image sections; defaults to page size",
    )
    parser.add_argument("--cmdline", required=True)
    parser.add_argument("--name", default="")
    args = parser.parse_args()
    image_align_size = args.image_align_size or args.page_size

    kernel = Path(args.kernel).read_bytes()
    ramdisk = Path(args.ramdisk).read_bytes()
    second = b""

    if len(args.name.encode("ascii")) > 15:
        raise SystemExit("boot image name must fit in 15 ASCII bytes")
    if len(args.cmdline.encode("ascii")) > 511:
        raise SystemExit("cmdline must fit in 511 ASCII bytes")

    image_id = hashlib.sha1()
    for blob in (kernel, ramdisk, second):
        image_id.update(blob)
        image_id.update(struct.pack("<I", len(blob)))
    digest = image_id.digest()
    id_words = struct.unpack("<5I", digest) + (0, 0, 0)

    header = struct.pack(
        "<8s10I16s512s8I",
        b"ANDROID!",
        len(kernel),
        args.kernel_addr,
        len(ramdisk),
        args.ramdisk_addr,
        len(second),
        args.second_addr,
        args.tags_addr,
        args.page_size,
        0,
        0,
        args.name.encode("ascii").ljust(16, b"\0"),
        args.cmdline.encode("ascii").ljust(512, b"\0"),
        *id_words,
    )

    output = pad(header, image_align_size) + pad(kernel, image_align_size) + pad(ramdisk, image_align_size)
    Path(args.output).write_bytes(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
