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

    def test_composed_diffuse_atlas_is_sampled_as_linear_data(self):
        self.assertIn('Write-NativeTextureRecipe "pusfume_atlas_df" $false', BUILD)

    def test_fur_diffuse_is_sampled_as_linear_data(self):
        self.assertIn(
            'Write-FurTexture "pusfume_fur_df" $furDiffuseSource $false $FurDiffuseGain',
            BUILD,
        )

    def test_legacy_gain_compensation_is_neutral(self):
        self.assertRegex(BUILD, r"\[double\]\$BodyDiffuseGain = 1\.0")
        self.assertRegex(BUILD, r"\[double\]\$FurDiffuseGain = 1\.0")


if __name__ == "__main__":
    unittest.main()
