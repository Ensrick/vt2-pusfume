from pathlib import Path
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import validate_first_person_donor as validator  # noqa: E402
from stingray_unit_scene import short_hash  # noqa: E402


def donor_hashes(names):
    return {short_hash(name) for name in names}


ARM_BONES = [
    "j_leftarm", "j_leftforearm", "j_lefthand",
    "j_rightarm", "j_rightforearm", "j_righthand",
    "j_leftshoulder", "j_rightshoulder", "j_spine2", "root_point",
]
# The human arms mesh weights arm + finger bones; j_lefthandpinky4 is the stray
# group observed in Janfon's rig that has no matching bone.
ARMS_VGROUPS = ["j_leftarm", "j_lefthand", "j_lefthandpinky1", "j_lefthandpinky4"]


class DonorAnalysisTests(unittest.TestCase):
    def test_full_human_donor_passes_with_orphan_warning(self):
        bones = ARM_BONES + ["j_lefthandpinky1", "j_rightweaponattach"]
        result = validator.analyze(
            donor_hashes(bones), bones, ARMS_VGROUPS, ["p_main"]
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["missing_required"], [])
        # The weapon-rig locator has no donor node in a real arms unit, but here
        # we only assert the orphan-vgroup detection surfaces pinky4.
        self.assertIn("j_lefthandpinky4", result["orphan_vgroups"])
        self.assertTrue(result["warnings"])

    def test_missing_required_bone_is_a_hard_error(self):
        donor = donor_hashes([b for b in ARM_BONES if b != "j_righthand"])
        result = validator.analyze(donor, ARM_BONES, ARMS_VGROUPS, ["p_main"])
        self.assertFalse(result["ok"])
        self.assertIn("j_righthand", result["missing_required"])
        self.assertTrue(any("required bones" in e for e in result["errors"]))

    def test_wrong_material_is_a_hard_error(self):
        result = validator.analyze(
            donor_hashes(ARM_BONES), ARM_BONES, ARMS_VGROUPS, ["p_main", "psf_arrow"]
        )
        self.assertFalse(result["ok"])
        self.assertTrue(any("material" in e for e in result["errors"]))

    def test_clean_mesh_has_no_orphan_warning(self):
        vgroups = ["j_leftarm", "j_lefthand", "j_rightarm", "j_righthand"]
        result = validator.analyze(
            donor_hashes(ARM_BONES),
            ARM_BONES,
            vgroups,
            ["p_main"],
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["orphan_vgroups"], [])
        self.assertEqual(result["warnings"], [])


class ArmsMeshSelectionTests(unittest.TestCase):
    def test_selects_single_skinned_arms_and_excludes_props(self):
        meshes = [
            {"name": "psf_arrow_1p_a", "armature_modifier": None, "vgroups": []},
            {"name": "Cube", "armature_modifier": None, "vgroups": []},
            {
                "name": "pusfume_arms",
                "armature_modifier": "pusfume_1p_human",
                "vgroups": ["j_leftarm", "j_rightarm", "j_lefthand", "j_righthand", "j_leftshoulder"],
                "materials": ["p_main"],
            },
        ]
        arms, ambiguous = validator.select_arms_mesh(meshes)
        self.assertIsNone(ambiguous)
        self.assertEqual(arms["name"], "pusfume_arms")

    def test_reports_ambiguity_when_no_single_arms_mesh(self):
        arms, ambiguous = validator.select_arms_mesh([
            {"name": "loose", "armature_modifier": None, "vgroups": []},
        ])
        self.assertIsNone(arms)
        self.assertEqual(ambiguous, [])


class DumpParsingTests(unittest.TestCase):
    def test_parses_marker_prefixed_and_bare_json(self):
        payload = '{"armatures": {}, "meshes": []}'
        self.assertEqual(validator.parse_rig_dump(payload), {"armatures": {}, "meshes": []})
        self.assertEqual(
            validator.parse_rig_dump("PUSFUME_HUMAN_RIG_DUMP=" + payload + "\n"),
            {"armatures": {}, "meshes": []},
        )


if __name__ == "__main__":
    unittest.main()
