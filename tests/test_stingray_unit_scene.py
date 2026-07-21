import struct
import tempfile
import unittest
from pathlib import Path

from tools.stingray_unit_scene import read_scene_graph, short_hash


class StingrayUnitSceneTests(unittest.TestCase):
    def make_unit(self, version=189):
        node_name = "j_lefthand"
        local = tuple(float(value) for value in range(15))
        world = tuple(float(value) for value in range(16))
        return b"".join(
            (
                struct.pack("<I", version),
                struct.pack("<I", 0),  # mesh geometries
                struct.pack("<I", 0),  # skins
                struct.pack("<I", 0),  # simple animation bytes
                struct.pack("<I", 0),  # animation groups
                struct.pack("<I", 1),  # scene nodes
                struct.pack("<15f", *local),
                struct.pack("<16f", *world),
                struct.pack("<HH", 1, 0),
                struct.pack("<I", short_hash(node_name)),
            )
        )

    def parse(self, payload):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe.unit"
            path.write_bytes(payload)
            return read_scene_graph(path)

    def test_reads_version_189_scene_graph(self):
        result = self.parse(self.make_unit())

        self.assertEqual(result["version"], 189)
        self.assertEqual(result["geometry_count"], 0)
        self.assertEqual(result["skin_count"], 0)
        self.assertEqual(result["skins"], [])
        self.assertEqual(len(result["nodes"]), 1)
        self.assertEqual(result["nodes"][0]["name_hash"], short_hash("j_lefthand"))
        self.assertEqual(result["nodes"][0]["parent"], (1, 0))
        self.assertEqual(result["nodes"][0]["world"][12:15], (12.0, 13.0, 14.0))

    def test_rejects_other_unit_versions(self):
        with self.assertRaisesRegex(ValueError, "version 189"):
            self.parse(self.make_unit(version=188))


if __name__ == "__main__":
    unittest.main()
