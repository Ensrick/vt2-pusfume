import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
TALENTS = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_talents.lua").read_text(encoding="utf-8")
BACKEND = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_backend.lua").read_text(encoding="utf-8")
REGISTRY = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_registry.lua").read_text(encoding="utf-8")
PREFLIGHT = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_preflight.lua").read_text(encoding="utf-8")
LOCALIZATION = (ROOT / "pusfume/scripts/mods/pusfume/pusfume_localization.lua").read_text(encoding="utf-8")


class TalentContractTests(unittest.TestCase):
    def test_tree_contains_six_rows_and_eighteen_unique_slots(self):
        keys = re.findall(r'key\s*=\s*"([a-z0-9_]+)"', TALENTS)

        self.assertEqual(18, len(keys))
        self.assertEqual(18, len(set(keys)))
        self.assertIn("local rows = {", TALENTS)
        self.assertIn("state.talent_count = operational_count + guarded_count", TALENTS)

    def test_every_talent_has_name_and_description_localization(self):
        keys = re.findall(r'key\s*=\s*"([a-z0-9_]+)"', TALENTS)

        for key in keys:
            self.assertIn(f"pusfume_talent_{key}_name", LOCALIZATION)
            self.assertIn(f"pusfume_talent_{key}_description", LOCALIZATION)

    def test_only_source_backed_rows_are_operational(self):
        self.assertEqual(10, TALENTS.count("guarded = true"))
        self.assertIn('{ "thp_tank" }', TALENTS)
        self.assertIn('{ "thp_smiter" }', TALENTS)
        self.assertIn('{ "thp_linesman" }', TALENTS)
        self.assertIn('{ "smiter_unbalance" }', TALENTS)
        self.assertIn('{ "tank_unbalance" }', TALENTS)
        self.assertIn('{ "power_level_unbalance" }', TALENTS)
        self.assertRegex(TALENTS, r'chunk_size\s*=\s*20')
        self.assertRegex(TALENTS, r'multiplier\s*=\s*1\.05')
        self.assertIn('{ "dodging", "distance_modifier" }', TALENTS)
        self.assertRegex(TALENTS, r'multiplier\s*=\s*1\.1')

    def test_runtime_registration_is_deterministic_and_reload_safe(self):
        self.assertIn("find_existing_tree", TALENTS)
        self.assertIn("rawget(TalentIDLookup, name)", TALENTS)
        self.assertIn("hero_talents[talent_id] = talent", TALENTS)
        self.assertIn("TalentIDLookup[name]", TALENTS)
        self.assertIn("hero_trees[tree_index] = tree", TALENTS)
        self.assertIn("coulumn = column_index", TALENTS)

    def test_pusfume_selection_is_vm_framework_owned(self):
        self.assertIn('SETTING_KEY = "pusfume_talent_columns"', TALENTS)
        self.assertIn("mod:get(SETTING_KEY)", TALENTS)
        self.assertIn("mod:set(SETTING_KEY, sanitized)", TALENTS)
        self.assertNotIn('hook_career_first("BackendInterfaceTalentsPlayfab"', BACKEND)
        self.assertIn('career_name == registry.CAREER_NAME', BACKEND)
        self.assertIn("talents.set_selection(selected_talents)", BACKEND)

    def test_registry_and_preflight_require_the_custom_tree(self):
        self.assertIn("career.talent_tree_index = talent_tree_index", REGISTRY)
        self.assertIn('add(checks, "custom talent tree"', PREFLIGHT)
        self.assertIn("talent_status.talent_count == 18", PREFLIGHT)
        self.assertIn("talent_status.operational_count == 8", PREFLIGHT)
        self.assertIn("talent_status.guarded_count == 10", PREFLIGHT)


if __name__ == "__main__":
    unittest.main()
