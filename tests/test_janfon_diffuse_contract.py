import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = (ROOT / "tools" / "Build-NativePusfume.ps1").read_text(encoding="utf-8")
NATIVE = (
    ROOT / "pusfume" / "scripts" / "mods" / "pusfume" / "_pusfume_native.lua"
).read_text(encoding="utf-8")


class JanfonDiffuseContractTests(unittest.TestCase):
    def test_direct_character_textures_are_sampled_as_linear_data(self):
        writer = re.search(
            r"function Write-NativeTexture \{(?P<body>.*?)\n\}", BUILD, re.DOTALL
        )
        self.assertIsNotNone(writer)
        self.assertIn('$srgb = "false"', writer.group("body"))
        self.assertNotIn('$srgb = "true"', writer.group("body"))

    def test_composed_diffuse_atlas_encodes_only_janfon_linear_body_tile(self):
        self.assertIn(
            "Convert-LinearDiffuseToSrgb "
            "$atlasDiffusePath $atlasDiffusePath @(0, 0, 2048, 4096)",
            BUILD,
        )
        self.assertNotIn(
            "Convert-LinearDiffuseToSrgb $atlasDiffusePath $atlasDiffusePath\n",
            BUILD,
        )
        self.assertIn('Write-NativeTextureRecipe "pusfume_atlas_df" $true', BUILD)

    def test_legacy_fur_diffuse_is_not_double_encoded(self):
        self.assertIn(
            'Write-FurTexture "pusfume_fur_df" $furDiffuseSource $true $FurDiffuseGain',
            BUILD,
        )
        fur_block = BUILD.split('Write-FurTexture "pusfume_fur_df"', 1)[1].split(
            '$textureNames +=', 1
        )[0]
        self.assertNotIn("Convert-LinearDiffuseToSrgb", fur_block)

    def test_custom_skaven_hands_use_a_separate_native_material_contract(self):
        self.assertIn("CE6F40AD55CA6EDF.material", BUILD)
        self.assertIn("pusfume_1p_skaven_child", BUILD)
        self.assertIn("pusfume_body_skaven_df", BUILD)

    def test_hero_and_versus_hands_share_the_proven_skaven_material(self):
        self.assertIn('$firstPersonHeroMaterial = if ($versusFirstPersonEnabled)', BUILD)
        self.assertIn('"child_materials/pusfume/pusfume_1p_skaven_child"', BUILD)

    def test_fur_uses_native_skaven_material_instead_of_laurel_plume(self):
        fur = BUILD.split("# Fur needs the enemy fur response", 1)[1]
        self.assertIn("4322B11893593962", fur)
        self.assertIn('"--expect-size", "256"', fur)
        self.assertIn('"--expect-parent", "7B55B884FAFA2B12"', fur)
        self.assertIn("1916CFCA6ED85BFD=20A7120B25F414F7", fur)
        self.assertNotIn("C70B1AAD3B363E24", fur)

    def test_third_person_opaque_slots_share_last_coherent_outfit_parent(self):
        self.assertIn("pusfume_outfit_child.material", BUILD)
        self.assertIn('"--expect-size", "768"', BUILD)
        self.assertIn('"--expect-parent", "3D25339231384C80"', BUILD)
        self.assertNotIn("pusfume_skin_child.material", BUILD)
        self.assertNotIn("FA4FAC2D0B40B919.material", BUILD)
        self.assertNotIn("resource_packages/breeds/skaven_slave", BUILD)
        self.assertNotIn("skin_child_material", NATIVE)
        assignment = NATIVE.split(
            "local function apply_donor_material_to_unit", 1
        )[1].split("local function install_material_probe_command", 1)[0]
        self.assertIn("or config.parent_child_material", assignment)
        self.assertNotIn('slot_name == "p_main"', assignment)

    def test_third_person_response_neutralizes_only_misread_body_roughness(self):
        self.assertIn("function Assert-PusfumeBodyResponse", BUILD)
        self.assertIn("p_main_ao_neutral=true", BUILD)
        self.assertIn("if ($NeutralizeBodyAo)", BUILD)
        self.assertIn("$expectedAo = 255", BUILD)
        self.assertNotIn("Set-PackedChannelFloor", BUILD)
        self.assertNotIn("-AoFloor", BUILD)

    def test_third_person_emission_is_fully_neutralized(self):
        self.assertIn('"emissive_color=0,0,0"', BUILD)
        self.assertNotIn('"emissive_color=15,1,0.2"', BUILD)

    def test_legacy_gain_compensation_is_neutral(self):
        self.assertRegex(BUILD, r"\[double\]\$BodyDiffuseGain = 1\.0")
        self.assertRegex(BUILD, r"\[double\]\$FurDiffuseGain = 1\.0")


if __name__ == "__main__":
    unittest.main()
