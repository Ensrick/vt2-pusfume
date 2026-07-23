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
            "tools/export_pusfume_1p_actions.py",
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
        self.assertIn('$modelFbxPath, $idleFbxPath, $animationFbxPath', build)
        self.assertIn('pusfume_3p_walk.fbx', build)
        self.assertIn('pusfume_3p_idle.fbx', build)

    def test_assassin_handoff_exports_and_packages_all_authored_clips(self):
        exporter = self.read("tools/export_pusfume_1p_actions.py")
        build = self.read("tools/Build-NativePusfume.ps1")
        expected = (
            "claws_equip",
            "claws_idle",
            "claws_run",
            "claws_block",
            "claws_light_attack_right_first",
            "claws_light_attack_right_second",
            "claws_light_attack_stab_left",
            "claws_light_attack_stab_left_hit",
            "claws_light_attack_last",
        )
        for clip in expected:
            with self.subTest(clip=clip):
                self.assertIn(f'"{clip}"', exporter)
        self.assertIn("EXPECTED_BONES = 99", exporter)
        self.assertIn("maximum_pose_delta", exporter)
        self.assertIn("sanitize_pose_transforms", exporter)
        self.assertIn("preparation.rebind_to_donor_rest", exporter)
        self.assertIn("parent_space_delta", exporter)
        self.assertIn("maximum_vertex_displacement", exporter)
        self.assertIn("MAXIMUM_POSED_VERTEX_DISPLACEMENT", exporter)
        self.assertIn('TRANSFORM_PROPERTIES = ("location", "scale")', exporter)
        self.assertIn('"maximum_removed_delta"', exporter)
        self.assertIn('"removed_channels"', exporter)
        self.assertIn("action.frame_range", exporter)
        self.assertIn("bake_anim_use_all_actions=False", exporter)
        self.assertIn("[switch]$AssassinFirstPersonAnimations", build)
        self.assertIn("export_pusfume_1p_actions.py", build)
        self.assertIn(
            "$versusFirstPersonBlendPath, $versusFirstPersonDonorUnitPath,",
            build,
        )
        self.assertIn('bones = "units/pusfume/pusfume_1p_versus_arms"', build)
        self.assertIn('$requiredCompiledResources += "units/pusfume/anims/', build)

    def test_native_build_never_opens_external_tool_windows(self):
        build = self.read("tools/Build-NativePusfume.ps1")
        self.assertIn("function Invoke-HiddenTool", build)
        self.assertIn("$startInfo.UseShellExecute = $false", build)
        self.assertIn("$startInfo.CreateNoWindow = $true", build)
        self.assertIn(
            "$startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden",
            build,
        )
        self.assertIn("$startInfo.RedirectStandardOutput = $true", build)
        self.assertIn("$startInfo.RedirectStandardError = $true", build)
        self.assertIn("MainWindowHandle = $process.MainWindowHandle", build)
        self.assertNotRegex(build, r"(?m)^\s*&\s+")

    def test_native_ship_uses_vmblauncher_for_every_distribution_step(self):
        build = self.read("tools/Build-NativePusfume.ps1")
        self.assertIn('"build", "pusfume", "--clean"', build)
        self.assertIn('"deploy", "pusfume", "--no-banner"', build)
        self.assertIn('"upload", "pusfume", "--no-banner"', build)
        self.assertIn("[switch]$Upload", build)
        self.assertIn("[switch]$NoRemote", build)
        self.assertIn("Steam confirmed Pusfume Workshop ManifestID", build)

    def test_walk_retarget_is_rotation_only_and_guarded(self):
        tool = self.read("tools/retarget_pusfume_walk.py")
        self.assertIn("target_basis.to_quaternion().to_matrix().to_4x4()", tool)
        self.assertIn("Retargeted walk did not deform the new body", tool)
        self.assertIn("Retargeted walk deformed the body", tool)
        for bone_name in ("j_eye_l", "j_eye_r", "j_hipbag"):
            self.assertIn(bone_name, tool)


if __name__ == "__main__":
    unittest.main()
