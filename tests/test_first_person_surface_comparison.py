import ast
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "compare_pusfume_1p_surfaces.py"
ALIGNMENT = ROOT / "tools" / "analyze_pusfume_1p_alignment.py"
SCENE_READER = ROOT / "tools" / "stingray_unit_scene.py"
PREPARE = ROOT / "tools" / "prepare_pusfume_1p_blend.py"
BUILD = ROOT / "tools" / "Build-NativePusfume.ps1"


class FirstPersonSurfaceComparisonTests(unittest.TestCase):
    def test_surface_tool_is_valid_python_and_weight_aware(self):
        source = TOOL.read_text(encoding="utf-8")
        ast.parse(source)
        self.assertIn("assignment.weight", source)
        self.assertIn("custom_to_donor", source)
        self.assertIn("PUSFUME_1P_SURFACE_COMPARISON=", source)

    def test_alignment_tool_uses_current_fallback_name(self):
        source = ALIGNMENT.read_text(encoding="utf-8")
        self.assertIn("DONOR_NAME_FALLBACKS", source)
        self.assertNotIn("DONOR_NAME_OVERRIDES", source)

    def test_compiled_reader_preserves_inverse_bind_matrices(self):
        source = SCENE_READER.read_text(encoding="utf-8")
        self.assertIn("def matrix_array", source)
        self.assertIn('"inverse_bind_matrices"', source)

    def test_native_grip_alignment_is_rigid_and_profile_gated(self):
        source = PREPARE.read_text(encoding="utf-8")
        self.assertIn("NATIVE_HERO_GRIP_CORRECTIONS", source)
        self.assertIn("def align_arm_surfaces_to_native_grips", source)
        self.assertIn("maximum_edge_length_delta", source)
        self.assertNotIn("pose_bone.location", source)

        build = BUILD.read_text(encoding="utf-8")
        human_build, versus_build = build.split(
            "$versusFirstPersonAssetPath = $null", 1
        )
        self.assertIn('"--align-native-hero-grips"', human_build)
        self.assertNotIn('"--align-native-hero-grips"', versus_build)


if __name__ == "__main__":
    unittest.main()
