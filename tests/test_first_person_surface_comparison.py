import ast
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "compare_pusfume_1p_surfaces.py"
ALIGNMENT = ROOT / "tools" / "analyze_pusfume_1p_alignment.py"
SCENE_READER = ROOT / "tools" / "stingray_unit_scene.py"
PREPARE = ROOT / "tools" / "prepare_pusfume_1p_blend.py"
BUILD = ROOT / "tools" / "Build-NativePusfume.ps1"
WEIGHT_AUDIT = ROOT / "tools" / "audit_pusfume_1p_weights.py"
WEIGHT_VALIDATION = ROOT / "tools" / "validate_pusfume_1p_weight_transfer.py"


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

    def test_native_weight_transfer_is_research_only(self):
        source = PREPARE.read_text(encoding="utf-8")
        self.assertIn("def transfer_weights_from_native_surface", source)
        self.assertIn("j_leftarmroll", source)
        self.assertIn("j_rightinhandindex", source)

        build = BUILD.read_text(encoding="utf-8")
        self.assertNotIn('"--native-weight-donor"', build)
        self.assertIn('"--align-native-hero-grips"', build)

    def test_weight_audit_and_posed_validation_are_executable_contracts(self):
        audit = WEIGHT_AUDIT.read_text(encoding="utf-8")
        validation = WEIGHT_VALIDATION.read_text(encoding="utf-8")
        ast.parse(audit)
        ast.parse(validation)
        self.assertIn("PUSFUME_1P_WEIGHT_AUDIT=", audit)
        self.assertIn("transferred_error", validation)
        self.assertIn("original_error", validation)
        self.assertIn('PUSFUME_1P_WEIGHT_TRANSFER_VALIDATION=', validation)


if __name__ == "__main__":
    unittest.main()
