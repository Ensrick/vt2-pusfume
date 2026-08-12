import csv
import importlib.util
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOL = ROOT / "tools" / "audit_vt2_ragdoll.py"
DOCUMENT = ROOT / "docs" / "RAGDOLL_PIPELINE.md"

spec = importlib.util.spec_from_file_location("audit_vt2_ragdoll", TOOL)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class RagdollPipelineContractTests(unittest.TestCase):
    def test_hash_dictionary_resolves_short_and_long_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            dictionary = pathlib.Path(directory) / "dictionary.csv"
            with dictionary.open("w", encoding="utf-8", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=["value", "long", "short", "group"])
                writer.writeheader()
                writer.writerow(
                    {
                        "value": "j_head",
                        "long": "111111114B8FCC6A",
                        "short": "4B8FCC6A",
                        "group": "other",
                    }
                )

            names = audit._load_dictionary(dictionary)

        self.assertEqual(names[0x4B8FCC6A], "j_head")
        self.assertEqual(names[0x111111114B8FCC6A], "j_head")

    def test_missing_dictionary_is_safe(self):
        self.assertEqual(audit._load_dictionary(None), {})
        self.assertEqual(audit._load_dictionary(pathlib.Path("missing.csv")), {})

    def test_document_preserves_required_safety_contracts(self):
        text = DOCUMENT.read_text(encoding="utf-8")
        required = (
            "exactly one runtime unit owns physical simulation",
            "dynamic_actors",
            "keyframed_actors",
            "hitbox_ragdoll_translation",
            "ragdoll_actor_thickness",
            "host player, client player, bot, remote husk, and hot join",
            "ragdolls = {}`",
        )
        for phrase in required:
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, text)


if __name__ == "__main__":
    unittest.main()
