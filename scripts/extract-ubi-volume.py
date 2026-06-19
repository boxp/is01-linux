#!/usr/bin/env python3
import argparse
import os
import struct
import sys
from pathlib import Path

PEB_SIZE_DEFAULT = 128 * 1024
UBI_EC_MAGIC = 0x55424923
UBI_VID_MAGIC = 0x55424921


def fail(message):
    raise SystemExit(f"error: {message}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Extract a logical volume payload from a raw UBI image."
    )
    parser.add_argument("--vol-id", type=int, default=0, help="UBI volume id to extract")
    parser.add_argument(
        "--peb-size",
        type=int,
        default=PEB_SIZE_DEFAULT,
        help="physical eraseblock size in bytes",
    )
    parser.add_argument(
        "--trim-android-bootimg",
        action="store_true",
        help="trim extracted data to the Android boot image size from its header",
    )
    parser.add_argument(
        "--android-bootimg-align-size",
        type=int,
        help="alignment used between Android boot image sections; defaults to header page_size",
    )
    parser.add_argument("ubi_image", type=Path)
    parser.add_argument("output", type=Path)
    return parser.parse_args()


def read_u32_be(buf, offset):
    return struct.unpack_from(">I", buf, offset)[0]


def parse_ec_header(block):
    if len(block) < 64 or read_u32_be(block, 0) != UBI_EC_MAGIC:
        return None
    return {
        "vid_hdr_offset": read_u32_be(block, 16),
        "data_offset": read_u32_be(block, 20),
    }


def parse_vid_header(block, offset):
    if len(block) < offset + 64 or read_u32_be(block, offset) != UBI_VID_MAGIC:
        return None
    return {
        "vol_id": read_u32_be(block, offset + 8),
        "lnum": read_u32_be(block, offset + 12),
        "data_size": read_u32_be(block, offset + 20),
    }


def extract_volume(data, peb_size, vol_id):
    logical_blocks = {}
    saw_ubi = False
    data_offset = None

    for offset in range(0, len(data), peb_size):
        block = data[offset : offset + peb_size]
        if block == b"\xff" * len(block):
            continue

        ec_header = parse_ec_header(block)
        if ec_header is None:
            continue
        saw_ubi = True
        data_offset = ec_header["data_offset"]

        vid_header = parse_vid_header(block, ec_header["vid_hdr_offset"])
        if vid_header is None or vid_header["vol_id"] != vol_id:
            continue

        payload = block[ec_header["data_offset"] :]
        data_size = vid_header["data_size"]
        if data_size:
            payload = payload[:data_size]
        logical_blocks[vid_header["lnum"]] = payload

    if not saw_ubi:
        fail("no UBI eraseblock headers found")
    if not logical_blocks:
        fail(f"volume id {vol_id} was not found")

    expected = list(range(max(logical_blocks) + 1))
    missing = [lnum for lnum in expected if lnum not in logical_blocks]
    if missing:
        fail(f"volume id {vol_id} is missing logical blocks: {missing}")

    return b"".join(logical_blocks[lnum] for lnum in expected)


def trim_android_bootimg(data, image_align_size=None):
    if len(data) < 48 or data[:8] != b"ANDROID!":
        fail("extracted volume does not start with an Android boot image header")
    kernel_size = struct.unpack_from("<I", data, 8)[0]
    ramdisk_size = struct.unpack_from("<I", data, 16)[0]
    second_size = struct.unpack_from("<I", data, 24)[0]
    page_size = struct.unpack_from("<I", data, 36)[0]
    dt_size = struct.unpack_from("<I", data, 40)[0]
    if page_size == 0:
        fail("Android boot image header has page_size=0")
    if image_align_size is None:
        image_align_size = page_size

    def align(value):
        return ((value + image_align_size - 1) // image_align_size) * image_align_size

    image_size = align(608) + align(kernel_size) + align(ramdisk_size) + align(second_size)
    if dt_size:
        image_size += align(dt_size)
    if image_size > len(data):
        fail(f"Android boot image header size exceeds extracted volume: {image_size} > {len(data)}")
    return data[:image_size]


def main():
    args = parse_args()
    data = args.ubi_image.read_bytes()
    if len(data) < args.peb_size:
        fail(f"{args.ubi_image} is smaller than one PEB")
    volume = extract_volume(data, args.peb_size, args.vol_id)
    if args.trim_android_bootimg:
        volume = trim_android_bootimg(volume, args.android_bootimg_align_size)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    tmp_output = args.output.with_name(f".{args.output.name}.tmp.{os.getpid()}")
    try:
        tmp_output.write_bytes(volume)
        tmp_output.replace(args.output)
    finally:
        try:
            tmp_output.unlink()
        except FileNotFoundError:
            pass
    print(f"extracted volume {args.vol_id}: {args.output} ({len(volume)} bytes)")


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        sys.exit(1)
