import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = (ROOT / "tools" / "Build-NativePusfume.ps1").read_text(encoding="utf-8")


class JanfonDiffuseContractTests(unittest.TestCase):
    def test_direct_character_textures_are_sampled_as_linear_data(self):
        writer = re.search(
            r"function Write-NativeTexture \{(?P<body>.*?)\n\}", BUILD, re.DOTALL
        )
        self.assertIsNotNone(writer)
        self.assertIn('$srgb = "false"', writer.group("body"))
        self.assertNotIn('$srgb = "true"', writer.group("body"))

    def test_composed_diffuse_atlas_preserves_linear_values_under_donor_srgb_contract(self):
        self.assertIn('Convert-LinearDiffuseToSrgb $atlasDiffusePath $atlasDiffusePath', BUILD)
        self.assertIn('Write-NativeTextureRecipe "pusfume_atlas_df" $true', BUILD)

    def test_fur_diffuse_preserves_linear_values_under_laurel_srgb_contract(self):
        self.assertIn(
            'Write-FurTexture "pusfume_fur_df" $furDiffuseSource $false $FurDiffuseGain',
            BUILD,
        )
        self.assertIn('Convert-LinearDiffuseToSrgb $furDiffusePath $furDiffusePath', BUILD)
        self.assertIn('Write-NativeTextureRecipe "pusfume_fur_df" $true', BUILD)

    def test_custom_skaven_hands_use_a_separate_native_material_contract(self):
        self.assertIn("CE6F40AD55CA6EDF.material", BUILD)
        self.assertIn("pusfume_1p_skaven_child", BUILD)
        self.assertIn("pusfume_body_skaven_df", BUILD)

    def test_legacy_gain_compensation_is_neutral(self):
        self.assertRegex(BUILD, r"\[double\]\$BodyDiffuseGain = 1\.0")
        self.assertRegex(BUILD, r"\[double\]\$FurDiffuseGain = 1\.0")


if __name__ == "__main__":
    unittest.main()
