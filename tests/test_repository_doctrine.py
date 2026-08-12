import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class RepositoryDoctrineTests(unittest.TestCase):
    def test_project_manager_authority_and_boundaries_are_documented(self):
        contributing = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")

        required = (
            "Pusfume project-manager Sol instance",
            "full authority",
            "any file, code, asset, configuration",
            "repository safety or provenance",
            "not unrelated repositories or third-party projects",
        )
        for phrase in required:
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, contributing)


if __name__ == "__main__":
    unittest.main()
