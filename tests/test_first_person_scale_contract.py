import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
PREPARE = ROOT / "tools" / "prepare_pusfume_1p_blend.py"


class FirstPersonScaleContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = PREPARE.read_text(encoding="utf-8")

    def test_positions_are_pre_scaled_without_armature_object_counter_scale(self):
        function = self.source.split(
            "def apply_stingray_basis_counter_scale", 1
        )[1].split("def main", 1)[0]

        self.assertIn("edit_bone.head *= factor", function)
        self.assertIn("edit_bone.tail *= factor", function)
        self.assertNotIn("armature.scale =", function)
        self.assertIn("maximum_mesh_delta > 0.0001", function)

    def test_fbx_metadata_counters_stingray_basis_multiplier(self):
        self.assertIn("global_scale=0.01", self.source)
        self.assertIn('apply_scale_options="FBX_SCALE_ALL"', self.source)


if __name__ == "__main__":
    unittest.main()
