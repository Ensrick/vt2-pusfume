"""Build the Track D spliced-child payload from the installed game data.

Extracts the game's compiled mtr_outfit child material from the donor bundle
and patches exactly its three texture ids to Pusfume's atlas texture ids. The
output payload is written under .build and is never committed: it derives
from Fatshark game data (a 768-byte binding table - parent hash, slot keys,
texture ids - with no embedded shader payload).

Each mapping must match exactly once; anything else aborts, so a game patch
that changes the child's layout fails the build instead of shipping garbage.

Usage:
  py make_spliced_child.py --game-bundle <path> --resource hash:<16-hex> \
      --map OLDHEX=NEWHEX [--map ...] --out <payload file>
"""

import argparse
import struct
import sys

import importlib.util
import pathlib

_HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(
    "splice_bundle_resource", _HERE / "splice_bundle_resource.py")
_splice = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_splice)


def main():
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--game-bundle",
                        help="installed game bundle containing the donor "
                             "child (zlib formats only)")
    source.add_argument("--extracted",
                        help="raw resource payload already extracted (e.g. by "
                             "the Rust unpacker, which also reads the 2023 "
                             "zstd game format)")
    parser.add_argument("--type", default="material")
    parser.add_argument("--resource", required=True,
                        help="resource path, or hash:<16-hex-digit id>")
    parser.add_argument("--map", action="append", required=True,
                        metavar="OLDHEX=NEWHEX",
                        help="u64 id replacement, repeatable")
    parser.add_argument("--expect-size", type=int, default=None,
                        help="require the extracted payload to be exactly "
                             "this many bytes")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    type_hash = _splice.murmur64a(args.type.encode())
    name_hash = _splice.parse_name(args.resource)

    if args.extracted:
        with open(args.extracted, "rb") as extracted:
            payload = bytearray(extracted.read())
    else:
        fmt, _, data = _splice.read_bundle(args.game_bundle)
        _, _, records = _splice.walk(data, fmt)
        matches = [r for r in records
                   if r["type"] == type_hash and r["name"] == name_hash]
        if len(matches) != 1 or matches[0]["version_count"] != 1:
            print(f"resource {name_hash:016X} not found exactly once with one "
                  f"version in {args.game_bundle}", file=sys.stderr)
            return 1
        version = matches[0]["versions"][0]
        payload = bytearray(
            data[version["payload_offset"]:
                 version["payload_offset"] + version["size"]])

    print(f"extracted ({args.type}, {name_hash:016X}) = {len(payload)} bytes")
    if args.expect_size is not None and len(payload) != args.expect_size:
        print(f"payload is {len(payload)} bytes, expected "
              f"{args.expect_size}; the game data layout may have changed",
              file=sys.stderr)
        return 1

    for mapping in args.map:
        old_hex, _, new_hex = mapping.partition("=")
        old = struct.pack("<Q", int(old_hex, 16))
        new = struct.pack("<Q", int(new_hex, 16))
        count = payload.count(old)
        if count != 1:
            print(f"id {old_hex.upper()} occurs {count} time(s) in the "
                  f"payload; need exactly 1", file=sys.stderr)
            return 1
        payload = payload.replace(old, new)
        print(f"patched {old_hex.upper()} -> {new_hex.upper()}")

    with open(args.out, "wb") as out:
        out.write(bytes(payload))
    print(f"wrote {len(payload)} bytes to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
