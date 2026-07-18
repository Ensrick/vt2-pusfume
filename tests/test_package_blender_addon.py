from pathlib import Path
import tempfile
import unittest
import zipfile

from tools import package_blender_addon


class PackageBlenderAddonTests(unittest.TestCase):
    def test_package_contains_extension_manifest_at_archive_root(self):
        repo_root = Path(__file__).resolve().parents[1]
        source = repo_root / "blender_addon" / "vt2_content_tools"
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "vt2_content_tools.zip"
            result = package_blender_addon.build_package(source, output)
            with zipfile.ZipFile(output) as archive:
                names = set(archive.namelist())
            self.assertEqual(result["id"], "vt2_content_tools")
            self.assertIn("blender_manifest.toml", names)
            self.assertIn("__init__.py", names)
            self.assertIn("live_mirror.py", names)
            self.assertFalse(any("__pycache__" in name for name in names))

    def test_package_is_byte_deterministic(self):
        repo_root = Path(__file__).resolve().parents[1]
        source = repo_root / "blender_addon" / "vt2_content_tools"
        with tempfile.TemporaryDirectory() as temporary:
            first = Path(temporary) / "first.zip"
            second = Path(temporary) / "second.zip"
            package_blender_addon.build_package(source, first)
            package_blender_addon.build_package(source, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())


if __name__ == "__main__":
    unittest.main()
