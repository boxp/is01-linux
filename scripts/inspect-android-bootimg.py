#!/usr/bin/env python3
import argparse
import json
import struct
import sys
from pathlib import Path


HEADER_SIZE = 608
MAGIC = b"ANDROID!"


def parse_int(value: str) -> int:
    return int(value, 0)


def align(value: int, size: int) -> int:
    if size <= 0:
        raise ValueError("alignment must be positive")
    return ((value + size - 1) // size) * size


def parse_bootimg(path: Path, image_align_size: int | None) -> dict:
    data = path.read_bytes()
    if len(data) < HEADER_SIZE:
        raise ValueError(f"{path} is smaller than an Android boot image header")
    if data[:8] != MAGIC:
        raise ValueError(f"{path} does not start with Android boot image magic")

    fields = struct.unpack_from("<10I", data, 8)
    (
        kernel_size,
        kernel_addr,
        ramdisk_size,
        ramdisk_addr,
        second_size,
        second_addr,
        tags_addr,
        page_size,
        dt_size,
        unused,
    ) = fields
    if page_size <= 0:
        raise ValueError(f"{path} has page_size=0")

    section_align = image_align_size or page_size
    kernel_offset = align(HEADER_SIZE, section_align)
    ramdisk_offset = kernel_offset + align(kernel_size, section_align)
    second_offset = ramdisk_offset + align(ramdisk_size, section_align)
    dt_offset = second_offset + align(second_size, section_align)
    image_size = dt_offset + align(dt_size, section_align)

    name = data[48:64].split(b"\0", 1)[0].decode("ascii", "replace")
    cmdline = data[64:576].split(b"\0", 1)[0].decode("ascii", "replace")
    image_id = data[576:608].hex()

    return {
        "path": str(path),
        "file_size": len(data),
        "image_size": image_size,
        "image_align_size": section_align,
        "kernel_size": kernel_size,
        "kernel_addr": kernel_addr,
        "kernel_offset": kernel_offset,
        "ramdisk_size": ramdisk_size,
        "ramdisk_addr": ramdisk_addr,
        "ramdisk_offset": ramdisk_offset,
        "second_size": second_size,
        "second_addr": second_addr,
        "second_offset": second_offset,
        "tags_addr": tags_addr,
        "page_size": page_size,
        "dt_size": dt_size,
        "dt_offset": dt_offset,
        "unused": unused,
        "name": name,
        "cmdline": cmdline,
        "id": image_id,
    }


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def check_expectations(report: dict, args: argparse.Namespace) -> None:
    expectations = {
        "page_size": args.expect_page_size,
        "image_align_size": args.expect_align_size,
        "kernel_addr": args.expect_kernel_addr,
        "ramdisk_addr": args.expect_ramdisk_addr,
        "second_addr": args.expect_second_addr,
        "tags_addr": args.expect_tags_addr,
    }
    for key, expected in expectations.items():
        if expected is None:
            continue
        actual = report[key]
        if actual != expected:
            fail(f"{key} mismatch for {report['path']}: got 0x{actual:x}, expected 0x{expected:x}")

    if args.expect_cmdline_contains:
        cmdline = report["cmdline"]
        for needle in args.expect_cmdline_contains:
            if needle not in cmdline:
                fail(f"cmdline for {report['path']} does not contain {needle!r}: {cmdline}")


def print_text(report: dict) -> None:
    hex_keys = {"kernel_addr", "ramdisk_addr", "second_addr", "tags_addr"}
    for key in (
        "path",
        "file_size",
        "image_size",
        "page_size",
        "image_align_size",
        "kernel_size",
        "kernel_addr",
        "kernel_offset",
        "ramdisk_size",
        "ramdisk_addr",
        "ramdisk_offset",
        "second_size",
        "second_addr",
        "second_offset",
        "tags_addr",
        "dt_size",
        "dt_offset",
        "name",
        "cmdline",
    ):
        value = report[key]
        if key in hex_keys:
            value = f"0x{value:08x}"
        print(f"{key}: {value}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect an Android boot image v0.")
    parser.add_argument("boot_img")
    parser.add_argument("--image-align-size", type=parse_int, help="section alignment; defaults to header page_size")
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    parser.add_argument("--expect-page-size", type=parse_int)
    parser.add_argument("--expect-align-size", type=parse_int)
    parser.add_argument("--expect-kernel-addr", type=parse_int)
    parser.add_argument("--expect-ramdisk-addr", type=parse_int)
    parser.add_argument("--expect-second-addr", type=parse_int)
    parser.add_argument("--expect-tags-addr", type=parse_int)
    parser.add_argument("--expect-cmdline-contains", action="append")
    args = parser.parse_args()

    try:
        report = parse_bootimg(Path(args.boot_img), args.image_align_size)
    except ValueError as exc:
        fail(str(exc))

    check_expectations(report, args)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_text(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
