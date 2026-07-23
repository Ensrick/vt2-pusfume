import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
PREPARE = (ROOT / "tools" / "prepare_animated_pusfume_fbx.py").read_text(
    encoding="utf-8"
)


class ThirdPersonGeometryContractTests(unittest.TestCase):
    def test_inherited_globadier_globe_is_removed_before_atlas_remap(self):
        self.assertIn("def remove_globadier_eye_globe(mesh_object):", PREPARE)
        self.assertIn('material_names.index("p_eye")', PREPARE)
        self.assertIn('component["max_z"] < 1.2', PREPARE)
        self.assertIn('component["min_z"] > 1.2', PREPARE)
        self.assertIn('backpack["vertices"] != 482', PREPARE)
        self.assertIn(
            "removed_globadier_globe = remove_globadier_eye_globe(model_mesh)",
            PREPARE,
        )
        self.assertLess(
            PREPARE.index(
                "removed_globadier_globe = remove_globadier_eye_globe(model_mesh)"
            ),
            PREPARE.index("atlas_loops = remap_material_uvs_to_atlas(model_mesh)"),
        )

    def test_two_real_eye_components_are_preserved(self):
        self.assertIn("len(head_components) != 2", PREPARE)
        self.assertIn('"remaining_eye_components": remaining_eye_components', PREPARE)


if __name__ == "__main__":
    unittest.main()
