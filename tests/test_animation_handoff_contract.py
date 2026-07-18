import ast
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AnimationHandoffContractTests(unittest.TestCase):
    def read(self, relative_path):
        return (ROOT / relative_path).read_text(encoding="utf-8-sig")

    def test_blender_animation_tools_are_valid_python(self):
        for relative_path in (
            "tools/extract_pusfume_authored_idle.py",
            "tools/render_fbx_animation_samples.py",
            "tools/retarget_pusfume_walk.py",
            "tools/validate_pusfume_animation_contract.py",
        ):
            with self.subTest(path=relative_path):
                ast.parse(self.read(relative_path), filename=relative_path)

    def test_native_build_keeps_idle_and_walk_inputs_separate(self):
        build = self.read("tools/Build-NativePusfume.ps1")
        self.assertIn('[string]$AnimationFbx', build)
        self.assertIn('[string]$IdleAnimationFbx', build)
        self.assertIn('$modelFbxPath $idleFbxPath $animationFbxPath', build)
        self.assertIn('pusfume_3p_walk.fbx', build)
        self.assertIn('pusfume_3p_idle.fbx', build)

    def test_walk_retarget_is_rotation_only_and_guarded(self):
        tool = self.read("tools/retarget_pusfume_walk.py")
        self.assertIn("target_basis.to_quaternion().to_matrix().to_4x4()", tool)
        self.assertIn("Retargeted walk did not deform the new body", tool)
        self.assertIn("Retargeted walk deformed the body", tool)
        for bone_name in ("j_eye_l", "j_eye_r", "j_hipbag"):
            self.assertIn(bone_name, tool)


if __name__ == "__main__":
    unittest.main()
