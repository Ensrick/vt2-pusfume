import struct
import unittest
import zlib

from tools import bsi_format


class BsiFormatTests(unittest.TestCase):
    def test_dump_is_deterministic_sdk_style_sjson(self):
        document = {
            "geometries": {
                "mesh": {
                    "enabled": True,
                    "name": "Pusfume",
                    "values": [0, 1.25, -0.0],
                }
            },
            "source_path": r"C:\art\pusfume.blend",
        }

        self.assertEqual(
            bsi_format.dumps(document),
            'geometries = {\n'
            '\tmesh = {\n'
            '\t\tenabled = true\n'
            '\t\tname = "Pusfume"\n'
            '\t\tvalues = [ 0 1.25 0 ]\n'
            '\t}\n'
            '}\n'
            'source_path = "C:\\\\art\\\\pusfume.blend"\n',
        )

    def test_bsiz_round_trip_and_header_size(self):
        raw = b"nodes = {}\n"
        payload = bsi_format.encode_bsiz(raw)

        self.assertEqual(payload[:4], b"bsiz")
        self.assertEqual(struct.unpack("<I", payload[4:8])[0], len(raw))
        self.assertEqual(zlib.decompress(payload[8:]), raw)
        self.assertEqual(bsi_format.decode_bsiz(payload), raw)

    def test_plain_payload_is_accepted(self):
        raw = b"source_path = \"test\"\n"
        self.assertIs(bsi_format.decode_bsiz(raw), raw)

    def test_non_finite_values_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "non-finite"):
            bsi_format.dumps({"bad": float("nan")})

    def test_non_identifier_keys_are_quoted(self):
        self.assertEqual(bsi_format.dumps({"mesh-name": {}}), '"mesh-name" = {}\n')


if __name__ == "__main__":
    unittest.main()
