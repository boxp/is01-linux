#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path

UBI_EC_MAGIC = 0x55424923


def parse_args():
    parser = argparse.ArgumentParser(description="Check raw UBI eraseblock layout.")
    parser.add_argument("--peb-size", type=int, default=128 * 1024)
    parser.add_argument("--expect-vid-offset", type=int, required=True)
    parser.add_argument("--expect-data-offset", type=int, required=True)
    parser.add_argument("--expect-pebs", type=int)
    parser.add_argument("ubi_image", type=Path)
    return parser.parse_args()


def read_u32_be(buf, offset):
    return struct.unpack_from(">I", buf, offset)[0]


def main():
    args = parse_args()
    data = args.ubi_image.read_bytes()
    checked = 0

    for offset in range(0, len(data), args.peb_size):
        block = data[offset : offset + args.peb_size]
        if block == b"\xff" * len(block):
            continue
        if len(block) < 64 or read_u32_be(block, 0) != UBI_EC_MAGIC:
            raise SystemExit(f"error: PEB {offset // args.peb_size} is neither erased nor a UBI eraseblock")

        peb = offset // args.peb_size
        vid_offset = read_u32_be(block, 16)
        data_offset = read_u32_be(block, 20)
        if vid_offset != args.expect_vid_offset:
            raise SystemExit(
                f"error: PEB {peb} VID header offset is {vid_offset}, "
                f"expected {args.expect_vid_offset}"
            )
        if data_offset != args.expect_data_offset:
            raise SystemExit(
                f"error: PEB {peb} data offset is {data_offset}, "
                f"expected {args.expect_data_offset}"
            )
        checked += 1

    if checked == 0:
        raise SystemExit("error: no UBI eraseblock headers found")
    if args.expect_pebs is not None and checked != args.expect_pebs:
        raise SystemExit(f"error: UBI image has {checked} PEBs, expected {args.expect_pebs}")
    print(
        f"UBI layout verified: {args.ubi_image} "
        f"(PEBs={checked}, vid_offset={args.expect_vid_offset}, data_offset={args.expect_data_offset})"
    )


if __name__ == "__main__":
    main()
