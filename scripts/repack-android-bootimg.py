#!/usr/bin/env python3
import argparse
import hashlib
import os
import struct
from pathlib import Path


BOOT_MAGIC = b"ANDROID!"
HEADER_FORMAT = "<8s10I16s512s8I"
HEADER_SIZE = struct.calcsize(HEADER_FORMAT)


def fail(message):
    raise SystemExit(f"error: {message}")


def align(value, page_size):
    return ((value + page_size - 1) // page_size) * page_size


def pad(data, page_size):
    return data + (b"\0" * (align(len(data), page_size) - len(data)))


def parse_bootimg(path, image_align_size=None):
    data = path.read_bytes()
    if len(data) < HEADER_SIZE:
        fail(f"{path} is smaller than an Android boot image header")

    fields = struct.unpack_from(HEADER_FORMAT, data, 0)
    if fields[0] != BOOT_MAGIC:
        fail(f"{path} does not start with Android boot image magic")

    header = {
        "kernel_size": fields[1],
        "kernel_addr": fields[2],
        "ramdisk_size": fields[3],
        "ramdisk_addr": fields[4],
        "second_size": fields[5],
        "second_addr": fields[6],
        "tags_addr": fields[7],
        "page_size": fields[8],
        "dt_size": fields[9],
        "unused": fields[10],
        "name": fields[11],
        "cmdline": fields[12],
    }
    page_size = header["page_size"]
    if page_size == 0:
        fail(f"{path} has page_size=0")
    if image_align_size is None:
        image_align_size = page_size
    if image_align_size <= 0:
        fail(f"{path} has invalid image alignment: {image_align_size}")

    cursor = align(HEADER_SIZE, image_align_size)
    kernel = data[cursor : cursor + header["kernel_size"]]
    cursor += align(header["kernel_size"], image_align_size)
    ramdisk = data[cursor : cursor + header["ramdisk_size"]]
    cursor += align(header["ramdisk_size"], image_align_size)
    second = data[cursor : cursor + header["second_size"]]
    cursor += align(header["second_size"], image_align_size)
    dt = data[cursor : cursor + header["dt_size"]]

    expected = align(HEADER_SIZE, image_align_size)
    for size in (
        header["kernel_size"],
        header["ramdisk_size"],
        header["second_size"],
        header["dt_size"],
    ):
        expected += align(size, image_align_size)
    if expected > len(data):
        fail(f"{path} header describes {expected} bytes, but file has {len(data)} bytes")

    return header, kernel, ramdisk, second, dt


def build_bootimg(header, kernel, ramdisk, second, dt, image_align_size):
    page_size = header["page_size"]

    image_id = hashlib.sha1()
    image_blobs = (kernel, ramdisk, second)
    if dt:
        image_blobs += (dt,)
    for blob in image_blobs:
        image_id.update(blob)
        image_id.update(struct.pack("<I", len(blob)))
    digest = image_id.digest()
    id_words = struct.unpack("<5I", digest) + (0, 0, 0)

    packed_header = struct.pack(
        HEADER_FORMAT,
        BOOT_MAGIC,
        len(kernel),
        header["kernel_addr"],
        len(ramdisk),
        header["ramdisk_addr"],
        len(second),
        header["second_addr"],
        header["tags_addr"],
        page_size,
        len(dt),
        header["unused"],
        header["name"],
        header["cmdline"],
        *id_words,
    )

    return (
        pad(packed_header, image_align_size)
        + pad(kernel, image_align_size)
        + pad(ramdisk, image_align_size)
        + pad(second, image_align_size)
        + pad(dt, image_align_size)
    )


def main():
    parser = argparse.ArgumentParser(
        description="Repack an Android boot image while preserving header addresses and cmdline."
    )
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--kernel", type=Path)
    parser.add_argument("--ramdisk", type=Path)
    parser.add_argument(
        "--cmdline",
        help="override the Android boot image cmdline; defaults to preserving the source cmdline",
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--image-align-size",
        type=int,
        help="alignment used between Android boot image sections; defaults to header page_size",
    )
    args = parser.parse_args()

    header, kernel, ramdisk, second, dt = parse_bootimg(args.source, args.image_align_size)
    if args.kernel is not None:
        kernel = args.kernel.read_bytes()
    if args.ramdisk is not None:
        ramdisk = args.ramdisk.read_bytes()
    if args.cmdline is not None:
        cmdline = args.cmdline.encode("ascii")
        if len(cmdline) > 512:
            fail("cmdline is longer than Android boot image v0 512-byte field")
        header["cmdline"] = cmdline + (b"\0" * (512 - len(cmdline)))

    image_align_size = args.image_align_size or header["page_size"]
    output = build_bootimg(header, kernel, ramdisk, second, dt, image_align_size)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    tmp_output = args.output.with_name(f".{args.output.name}.tmp.{os.getpid()}")
    try:
        tmp_output.write_bytes(output)
        tmp_output.replace(args.output)
    finally:
        try:
            tmp_output.unlink()
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    main()
