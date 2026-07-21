import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
GAMEPLAY = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_gameplay.lua").read_text(encoding="utf-8")
REGISTRY = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_registry.lua").read_text(encoding="utf-8")
LOCALIZATION = (ROOT / "pusfume/scripts/mods/pusfume/pusfume_localization.lua").read_text(encoding="utf-8")
PREFLIGHT = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_preflight.lua").read_text(encoding="utf-8")


class CareerSpecV2Tests(unittest.TestCase):
    def test_identity_stats_and_ability_names_match_v2(self):
        self.assertRegex(REGISTRY, r"career\.attributes\.max_hp\s*=\s*100")
        self.assertRegex(GAMEPLAY, r"local ACTIVE_COOLDOWN\s*=\s*90")
        self.assertIn('en = "Aggressive Iteration"', LOCALIZATION)
        self.assertIn('en = "Moulder Ingenuity"', LOCALIZATION)

    def test_late_statistics_definitions_include_leaf_names(self):
        # StatisticsDefinitions.add_names() runs before mod registration. Every
        # leaf added later must therefore carry the metadata that stops the
        # StatisticsDatabase recursive group walk.
        self.assertIn("player_definitions.min_health_percentage[career_name]", REGISTRY)
        self.assertIn("player_definitions.min_health_completed[career_name]", REGISTRY)
        self.assertGreaterEqual(REGISTRY.count("name = career_name"), 2)
        self.assertIn("name = diff", REGISTRY)

    def test_obsolete_v1_kit_is_not_registered(self):
        self.assertNotIn("The Great Scheme", LOCALIZATION)
        self.assertNotIn("Skaven Ingenuity", LOCALIZATION)
        self.assertNotIn("Insider Knowledge", LOCALIZATION)
        self.assertNotIn("pusfume_scheme_kill_skaven", GAMEPLAY)
        self.assertNotIn("power_level_skaven", GAMEPLAY)
        self.assertNotIn("state.station", GAMEPLAY)

    def test_aggressive_iteration_captures_special_kills(self):
        self.assertIn("ProcFunctions.pusfume_aggressive_iteration_proc", GAMEPLAY)
        self.assertRegex(GAMEPLAY, r'event\s*=\s*"on_kill"')
        self.assertIn("breed.special", GAMEPLAY)
        self.assertIn("pusfume_aggressive_iteration_ready", GAMEPLAY)
        self.assertIn("buff_system:add_buff(owner_unit, buff_name, owner_unit, false)", GAMEPLAY)
        self.assertIn('add(checks, "Aggressive Iteration proc"', PREFLIGHT)

    def test_v2_perks_use_native_buff_contracts(self):
        perk_module = 'require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")'

        self.assertIn(perk_module, GAMEPLAY)
        self.assertIn(perk_module, PREFLIGHT)
        self.assertIn("buff_perks.no_moveslow_on_hit", GAMEPLAY)
        self.assertIn('attack_type == "light_attack"', GAMEPLAY)
        self.assertIn('attack_type == "heavy_attack"', GAMEPLAY)
        self.assertRegex(GAMEPLAY, r'multiplier\s*=\s*1\.2')
        self.assertRegex(GAMEPLAY, r'duration\s*=\s*3')
        self.assertRegex(GAMEPLAY, r'stat_buff\s*=\s*"reload_speed"')
        self.assertRegex(GAMEPLAY, r'multiplier\s*=\s*-0\.15')

    def test_moulder_ingenuity_arms_instead_of_spawning_station(self):
        self.assertRegex(GAMEPLAY, r"augmentation_armed\s*=\s*true")
        self.assertIn("Moulder Ingenuity armed the next consumable selection", GAMEPLAY)
        self.assertNotIn("Vector3Box", GAMEPLAY)
        self.assertNotIn("STATION_DURATION", GAMEPLAY)


if __name__ == "__main__":
    unittest.main()
