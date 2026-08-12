import json
import pathlib
import sys
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))

import pusfume_atlas_layout as atlas


class PusfumeAtlasLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with (TOOLS / "pusfume_atlas_layout.json").open(encoding="utf-8") as layout_file:
            cls.layout = json.load(layout_file)

    def test_tile_allocations_are_disjoint_and_inside_atlas(self):
        allocations = []
        atlas_size = self.layout["atlas_size"]
        for name, tile in self.layout["tiles"].items():
            left, bottom = tile["origin"]
            right = left + tile["size"][0] * tile["grid"][0]
            top = bottom + tile["size"][1] * tile["grid"][1]
            self.assertGreaterEqual(left, 0, name)
            self.assertGreaterEqual(bottom, 0, name)
            self.assertLessEqual(right, atlas_size, name)
            self.assertLessEqual(top, atlas_size, name)
            allocations.append((name, left, bottom, right, top))

        for index, first in enumerate(allocations):
            for second in allocations[index + 1 :]:
                separated = (
                    first[3] <= second[1]
                    or second[3] <= first[1]
                    or first[4] <= second[2]
                    or second[4] <= first[2]
                )
                self.assertTrue(separated, f"atlas tiles overlap: {first[0]} and {second[0]}")

    def test_materials_reference_valid_tiles_and_insets(self):
        tiles = self.layout["tiles"]
        for material, binding in self.layout["materials"].items():
            self.assertIn(binding["tile"], tiles, material)
        for name, tile in tiles.items():
            inset = tile["inset"]
            self.assertGreaterEqual(inset, 0, name)
            self.assertLess(inset * 2, min(tile["size"]), name)
            self.assertEqual({"df", "nm", "s"}, set(tile["sources"]), name)

        self.assertEqual("generic_cloth_dirty_df", tiles["ammo_a"]["sources"]["df"])
        self.assertEqual("pup_ammo_box_limited_df", tiles["ammo_b"]["sources"]["df"])
        self.assertIsNone(tiles["eye"]["sources"]["nm"])
        self.assertIsNone(tiles["eye"]["sources"]["s"])

    def test_runtime_regions_derive_from_manifest(self):
        self.assertEqual(self.layout["atlas_size"], atlas.ATLAS_SIZE)
        self.assertEqual(set(self.layout["materials"]), set(atlas.ATLAS_REGIONS))
        self.assertEqual((1008, 1008), atlas.ATLAS_REGIONS["p_glob"]["size"])
        self.assertLess(atlas.ATLAS_REGIONS["p_glob"]["allowed_min"][0], 0)
        self.assertGreater(atlas.ATLAS_REGIONS["p_glob"]["allowed_max"][0], 1)

    def test_only_dedicated_whiskers_retain_diffuse_alpha(self):
        self.assertEqual(["df"], self.layout["force_opaque_suffixes"])
        self.assertNotIn("p_whiskers", self.layout["materials"])


if __name__ == "__main__":
    unittest.main()
