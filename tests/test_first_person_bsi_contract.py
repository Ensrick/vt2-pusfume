import ast
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
PREPARE = ROOT / "tools" / "prepare_pusfume_1p_bsi.py"
PREPARE_BLEND = ROOT / "tools" / "prepare_pusfume_1p_blend.py"
BUILD = ROOT / "tools" / "Build-NativePusfume.ps1"


class FirstPersonBsiContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = PREPARE.read_text(encoding="utf-8")
        cls.blend_source = PREPARE_BLEND.read_text(encoding="utf-8")
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

    def test_already_conformed_human_rig_is_not_rejected(self):
        self.assertIn("if maximum_vertex_delta > 0.75:", self.blend_source)
        self.assertNotIn(
            "maximum_vertex_delta <= 0.001 or maximum_vertex_delta > 0.75",
            self.blend_source,
        )

    def test_shipping_build_preserves_authored_weights(self):
        human_build, versus_build = self.build.split(
            "$versusFirstPersonAssetPath = $null", 1
        )
        self.assertNotIn('"--native-weight-donor"', human_build)
        self.assertNotIn('"--native-weight-donor"', versus_build)
        self.assertIn('"--align-native-hero-grips"', human_build)

    def test_shipping_build_uses_native_human_material_with_correct_map_roles(self):
        self.assertIn('"--expect-size", "96"', self.build)
        self.assertIn('"--expect-parent", "D97596A091982F4B"', self.build)
        self.assertIn('"86FFDEB90C40C597=E0C4E09D80AE735B"', self.build)
        self.assertIn('"258E4E4AEA37B1B8=3B3F6545AF6782F5"', self.build)
        self.assertIn('"E04C4FD132004376=DF5A1D6679E28376"', self.build)
        self.assertNotIn('"258E4E4AEA37B1B8=45FFAEEF53695A86"', self.build)

    def test_shipping_build_defaults_to_fatshark_versus_arms(self):
        self.assertIn(
            "$nativeVersusFirstPersonValue = if ($firstPersonEnabled -and -not $versusFirstPersonEnabled)",
            self.build,
        )
        self.assertIn(
            "$dualFirstPersonRigsValue = if ($firstPersonEnabled)", self.build
        )
        self.assertIn(
            "native_versus_first_person = $nativeVersusFirstPersonValue",
            self.build,
        )


if __name__ == "__main__":
    unittest.main()
