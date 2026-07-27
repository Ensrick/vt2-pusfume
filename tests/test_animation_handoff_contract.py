import ast
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AnimationHandoffContractTests(unittest.TestCase):
    def read(self, relative_path):
        return (ROOT / relative_path).read_text(encoding="utf-8-sig")

    def test_blender_animation_tools_are_valid_python(self):
        for relative_path in (
            "tools/audit_blend_contract.py",
            "tools/extract_pusfume_authored_idle.py",
            "tools/export_pusfume_1p_actions.py",
            "tools/prepare_animated_pusfume_fbx.py",
            "tools/render_fbx_animation_samples.py",
            "tools/retarget_pusfume_walk.py",
            "tools/validate_pusfume_animation_contract.py",
        ):
            with self.subTest(path=relative_path):
                ast.parse(self.read(relative_path), filename=relative_path)

    def test_animation_preparation_never_deletes_the_backpack_bottom(self):
        preparer = self.read("tools/prepare_animated_pusfume_fbx.py")
        self.assertNotIn("remove_globadier_eye_globe", preparer)
        self.assertNotIn("Globadier backpack globe topology changed", preparer)

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
        self.assertIn("nla_action_ranges", exporter)
        self.assertIn("strip.action_frame_start", exporter)
        self.assertIn("strip.action_frame_end", exporter)
        self.assertIn('"nla_frame_range"', exporter)
        self.assertIn("bake_anim_use_all_actions=False", exporter)
        self.assertIn("[switch]$AssassinFirstPersonAnimations", build)
        self.assertIn("export_pusfume_1p_actions.py", build)
        self.assertIn(
            "$versusFirstPersonBlendPath, $versusFirstPersonDonorUnitPath,",
            build,
        )
        self.assertIn('bones = "units/pusfume/pusfume_1p_versus_arms"', build)
        self.assertIn('$requiredCompiledResources += "units/pusfume/anims/', build)

    def test_assassin_clips_ship_authored_scale_and_camera_anchor(self):
        # Offline-verified compile scales (issue #46): plain FBX exports
        # compile every position at 1/100 of the authored value; the 100x
        # pre-scale + 0.01 global_scale pair compiles them at true scale
        # (ratio 1.00 against the unit rest). The tolerance recipe stays at
        # the proven 0.001 pair because raising it re-scales the packed
        # range instead of culling tracks. Janfon's rig is floor-origin with
        # camera_node at eye height, so the runtime must anchor the root by
        # camera_node, and must park the crossfade layer when leaving the
        # role so a stale clip cannot stretch unlinked bones.
        exporter = self.read("tools/export_pusfume_1p_actions.py")
        self.assertIn("def scale_armature_bone_positions", exporter)
        self.assertIn("scale_armature_bone_positions(target, 100.0)", exporter)
        self.assertIn("scale_armature_bone_positions(target, 0.01)", exporter)
        self.assertIn("global_scale=0.01,", exporter)
        self.assertIn("maximum_restore_delta > 0.0001", exporter)
        build = self.read("tools/Build-NativePusfume.ps1")
        assassin_recipe = build.split(
            'bones = "units/pusfume/pusfume_1p_versus_arms"', 1
        )[1].split("'@", 1)[0]
        self.assertIn("0.001", assassin_recipe)
        self.assertNotIn("100.0", assassin_recipe)
        native = self.read("pusfume/scripts/mods/pusfume/_pusfume_native.lua")
        # The v0.6.89 spine anchor is retired (unstable, and node-0 writes do
        # not reach the rendered rig); placement evidence comes from the
        # absolute roots telemetry instead.
        self.assertNotIn("base_spine - rig_spine", native)
        self.assertIn("roots: cam=%s base=%s rig=%s hand=%s", native)
        self.assertIn("local idle_clip = type(clips) == \"table\" and clips.claws_idle", native)
        self.assertIn(
            "Unit.crossfade_animation(\n"
            "                previous_clip.animation_unit, idle_clip.clip, 1, 0.05,",
            native,
        )
        # Blend type is load-bearing: "normal" composes tracked bones at the
        # WORLD ORIGIN regardless of the unit link (v0.6.90 roots telemetry:
        # cam==base==rig at the player, hand at (0.37, 0, 0)). Every assassin
        # crossfade must play "offset".
        driver_and_park = native.split(
            "local function play_custom_first_person_clip", 1)[1]
        self.assertNotIn('clip.loop == true, "normal")', driver_and_park)
        self.assertIn('clip.loop == true, "offset")', driver_and_park)
        self.assertIn('true, "offset")', driver_and_park)
        self.assertIn('false, "offset")', driver_and_park)

    def test_assassin_export_clears_saved_source_pose(self):
        exporter = self.read("tools/export_pusfume_1p_actions.py")
        duplicate = exporter.split(
            "def duplicate_source_armature", 1
        )[1].split("def assign_action", 1)[0]
        self.assertIn("pose_bone.matrix_basis = Matrix.Identity(4)", duplicate)
        self.assertIn("Duplicated Assassin source retained a saved pose", duplicate)

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
