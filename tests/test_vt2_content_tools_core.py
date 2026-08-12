import unittest

from blender_addon.vt2_content_tools import core


class Vt2ContentToolsCoreTests(unittest.TestCase):
    def test_safe_name_is_stingray_friendly(self):
        self.assertEqual(core.safe_name("  Pusfume 3P.body "), "Pusfume_3P_body")
        self.assertEqual(core.safe_name("25 rats"), "_25_rats")
        self.assertEqual(core.safe_name("---", "fallback"), "fallback")

    def test_export_filenames_are_deterministic(self):
        self.assertEqual(core.export_filename("Pusfume", "model"), "Pusfume_3p.fbx")
        self.assertEqual(
            core.export_filename("Pusfume", "animation", "run forward"),
            "Pusfume_run_forward.fbx",
        )

    def test_weight_analysis_reports_each_contract(self):
        result = core.analyze_weight_rows(
            [[], [0.5, 0.5], [0.2] * 5, [0.4, 0.4]],
            maximum_influences=4,
        )
        self.assertEqual(result["unweighted"], [0])
        self.assertEqual(result["over_limit"], [2])
        self.assertEqual(result["not_normalized"], [3])
        self.assertEqual(result["max_influences"], 5)

    def test_action_channel_classification(self):
        result = core.classify_action_paths(
            [
                'pose.bones["j_root"].location',
                'pose.bones["j_arm_L"].location',
                'pose.bones["j_arm_L"].rotation_quaternion',
                'pose.bones["j_arm_L"].scale',
                'pose.bones["missing"].rotation_euler',
                "custom.property",
            ],
            {"j_root", "j_arm_L"},
            {"j_root"},
        )
        self.assertEqual(result["non_root_location"], ["j_arm_L"])
        self.assertEqual(result["scale"], ["j_arm_L"])
        self.assertEqual(result["unknown_bones"], ["missing"])
        self.assertEqual(result["other"], ["custom.property"])

    def test_vt2_left_right_bone_pairs_preserve_names(self):
        names = {
            "j_leftarm",
            "j_rightarm",
            "j_lefthand",
            "j_righthand",
            "weapon_socket.L",
            "weapon_socket.R",
            "j_spine",
        }
        self.assertEqual(
            core.mirrored_bone_pairs(
                names,
                "LEFT_TO_RIGHT",
                selected_names={"j_leftarm", "weapon_socket.L"},
            ),
            [
                ("j_leftarm", "j_rightarm"),
                ("weapon_socket.L", "weapon_socket.R"),
            ],
        )
        self.assertEqual(
            core.mirrored_bone_name("j_righthand", "RIGHT_TO_LEFT"),
            "j_lefthand",
        )
        self.assertIsNone(core.mirrored_bone_name("j_spine", "LEFT_TO_RIGHT"))

    def test_mirrored_partner_is_bidirectional(self):
        self.assertEqual(core.mirrored_partner_name("j_leftarm"), "j_rightarm")
        self.assertEqual(core.mirrored_partner_name("j_rightarm"), "j_leftarm")
        self.assertEqual(core.mirrored_partner_name("finger.L"), "finger.R")
        self.assertIsNone(core.mirrored_partner_name("j_spine"))


if __name__ == "__main__":
    unittest.main()
