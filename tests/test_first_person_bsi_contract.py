import ast
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
PREPARE = ROOT / "tools" / "prepare_pusfume_1p_bsi.py"
BUILD = ROOT / "tools" / "Build-NativePusfume.ps1"


class FirstPersonBsiContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = PREPARE.read_text(encoding="utf-8")
        cls.build = BUILD.read_text(encoding="utf-8")

    def test_tool_is_valid_python(self):
        ast.parse(self.source)

    def test_inverse_binds_share_donor_rebound_scene(self):
        self.assertIn("rebind_to_donor_rest", self.source)
        self.assertIn("build_skin(", self.source)
        self.assertIn("build_geometry(", self.source)
        self.assertNotIn("apply_stingray_basis_counter_scale", self.source)

    def test_build_defaults_to_direct_bsi_with_fbx_fallback(self):
        self.assertIn('[ValidateSet("bsi", "fbx")]', self.build)
        self.assertIn('[string]$FirstPersonFormat = "bsi"', self.build)
        self.assertIn("prepare_pusfume_1p_bsi.py", self.build)
        self.assertIn("prepare_pusfume_1p_blend.py", self.build)

    def test_integrated_fur_cannot_silently_fall_back(self):
        self.assertIn("model contains p_fur; rebuild with -IntegratedFur", self.build)


if __name__ == "__main__":
    unittest.main()
