import importlib.util
import pathlib
import struct
import sys
import tempfile
import unittest
import zlib

TOOL = pathlib.Path(__file__).resolve().parent.parent / "tools" / "strip_bundle_resource.py"
spec = importlib.util.spec_from_file_location("strip_bundle_resource", TOOL)
strip = importlib.util.module_from_spec(spec)
spec.loader.exec_module(strip)


def build_fake_bundle(path, payload):
    out = bytearray()
    out += struct.pack("<II", strip.VT2_FORMAT, len(payload))
    out += b"\x00\x00\x00\x00"
    for start in range(0, len(payload), strip.BLOCK_RAW_SIZE):
        block = zlib.compress(payload[start : start + strip.BLOCK_RAW_SIZE], 9)
        out += struct.pack("<I", len(block))
        out += block
    path.write_bytes(bytes(out))


class StripBundleResourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.bundle = pathlib.Path(self.tmp.name) / "test.mod_bundle"

    def tearDown(self):
        self.tmp.cleanup()

    def make_payload(self, pair, occurrences, size=200_000):
        filler = bytes(range(256)) * (size // 256)
        chunk = size // (occurrences + 1)
        payload = bytearray()
        for i in range(occurrences):
            payload += filler[i * chunk : (i + 1) * chunk]
            payload += pair
        payload += filler[occurrences * chunk :]
        return bytes(payload)

    def test_known_murmur(self):
        known = b"units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/mtr_outfit"
        self.assertEqual(strip.murmur64a(known), 0x90BDF3BAC6F81BA8)

    def test_roundtrip_without_change_is_identical_content(self):
        payload = self.make_payload(b"\xAA" * 16, 0)
        build_fake_bundle(self.bundle, payload)
        _, _, data = strip.read_bundle(self.bundle)
        self.assertEqual(data, payload)

    def test_pairs_replaced_across_block_boundaries(self):
        type_hash = strip.murmur64a(b"material")
        old_hash = strip.murmur64a(b"old/path")
        pair = struct.pack("<QQ", type_hash, old_hash)
        # place one pair straddling the 64 KiB block boundary
        payload = bytearray(b"\x11" * (strip.BLOCK_RAW_SIZE - 8))
        payload += pair
        payload += b"\x22" * 4096
        payload += pair
        build_fake_bundle(self.bundle, bytes(payload))

        argv = sys.argv
        sys.argv = [
            "strip_bundle_resource.py", str(self.bundle),
            "--type", "material", "--old", "old/path", "--new", "new/path",
            "--expect", "2",
        ]
        try:
            self.assertEqual(strip.main(), 0)
        finally:
            sys.argv = argv

        _, _, data = strip.read_bundle(self.bundle)
        new_pair = struct.pack("<QQ", type_hash, strip.murmur64a(b"new/path"))
        self.assertEqual(data.count(pair), 0)
        self.assertEqual(data.count(new_pair), 2)
        self.assertEqual(len(data), len(payload))

    def test_bare_hash_rename_with_literal_new_hash(self):
        old_hash = strip.murmur64a(b"textures/pusfume/pusfume_atlas_df")
        old_needle = struct.pack("<Q", old_hash)
        donor_id = 0xDD74D8319F514D96
        new_needle = struct.pack("<Q", donor_id)
        # bare occurrences: one inside a (type, name) pair, one standalone
        # material reference, one straddling the block boundary, plus a
        # PREEXISTING donor id that must be counted, not clobbered
        type_pair = struct.pack("<QQ", strip.murmur64a(b"texture"), old_hash)
        payload = bytearray(b"\x44" * (strip.BLOCK_RAW_SIZE - 4))
        payload += old_needle
        payload += type_pair
        payload += b"\x55" * 512
        payload += old_needle
        payload += b"\x66" * 128
        payload += new_needle
        build_fake_bundle(self.bundle, bytes(payload))

        argv = sys.argv
        sys.argv = [
            "strip_bundle_resource.py", str(self.bundle),
            "--type", "texture", "--bare",
            "--old", "textures/pusfume/pusfume_atlas_df",
            "--new-hash", "DD74D8319F514D96",
            "--expect", "3",
        ]
        try:
            self.assertEqual(strip.main(), 0)
        finally:
            sys.argv = argv

        _, _, data = strip.read_bundle(self.bundle)
        self.assertEqual(data.count(old_needle), 0)
        self.assertEqual(data.count(new_needle), 4)
        self.assertEqual(len(data), len(payload))

    def test_bare_and_pair_modes_count_independently(self):
        old_hash = strip.murmur64a(b"some/texture")
        pair = struct.pack("<QQ", strip.murmur64a(b"texture"), old_hash)
        payload = self.make_payload(pair, 2)
        build_fake_bundle(self.bundle, payload)

        argv = sys.argv
        # pair mode sees 2; bare mode also sees 2 (the name halves of the pairs)
        sys.argv = [
            "strip_bundle_resource.py", str(self.bundle),
            "--type", "texture", "--bare",
            "--old", "some/texture", "--new-hash", "0123456789ABCDEF",
            "--expect", "2", "--dry-run",
        ]
        try:
            self.assertEqual(strip.main(), 0)
        finally:
            sys.argv = argv

    def test_expect_mismatch_fails(self):
        payload = self.make_payload(b"\x33" * 16, 0)
        build_fake_bundle(self.bundle, payload)

        argv = sys.argv
        sys.argv = [
            "strip_bundle_resource.py", str(self.bundle),
            "--type", "material", "--old", "old/path", "--new", "new/path",
            "--expect", "3",
        ]
        try:
            self.assertEqual(strip.main(), 1)
        finally:
            sys.argv = argv


if __name__ == "__main__":
    unittest.main()
