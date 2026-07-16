from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_ROOT = REPO_ROOT / "tools" / "material_templates"
SKINNED_DISABLED_OPTION = "b5bb2062-c8fa-43c5-8657-493a0be6860c"


class SkinnedMaterialTemplateTests(unittest.TestCase):
    def test_character_templates_do_not_disable_skinning(self):
        for name in ("character_skinned.material", "character_skinned_cutout.material"):
            with self.subTest(template=name):
                text = (TEMPLATE_ROOT / name).read_text(encoding="utf-8")
                self.assertIn(
                    'type = "core/stingray_renderer/output_nodes/standard_base"',
                    text,
                )
                self.assertNotIn(SKINNED_DISABLED_OPTION, text)

    def test_character_templates_keep_texture_contract(self):
        for name in ("character_skinned.material", "character_skinned_cutout.material"):
            with self.subTest(template=name):
                text = (TEMPLATE_ROOT / name).read_text(encoding="utf-8")
                for token in ("__COLOR_MAP__", "__NORMAL_MAP__", "__DETAIL_MAP__"):
                    self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
