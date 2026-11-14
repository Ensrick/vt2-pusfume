import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
GAMEPLAY = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_gameplay.lua").read_text(encoding="utf-8")
REGISTRY = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_registry.lua").read_text(encoding="utf-8")
LOCALIZATION = (ROOT / "pusfume/scripts/mods/pusfume/pusfume_localization.lua").read_text(encoding="utf-8")
PREFLIGHT = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_preflight.lua").read_text(encoding="utf-8")
TALENTS = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_talents.lua").read_text(encoding="utf-8")


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

    def test_v2_talent_tree_is_registered_with_guarded_boundaries(self):
        self.assertEqual(18, len(re.findall(r'key\s*=\s*"[a-z0-9_]+"', TALENTS)))
        self.assertEqual(6, TALENTS.count("guarded = true"))
        self.assertIn('SETTING_KEY = "pusfume_talent_columns"', TALENTS)

    def test_opportunism_doubles_only_melee_proc_health_for_the_armed_strike(self):
        self.assertIn('mod:hook(BuffExtension, "trigger_procs"', GAMEPLAY)
        self.assertIn('event == "on_player_damage_dealt"', GAMEPLAY)
        self.assertIn('event == "on_stagger"', GAMEPLAY)
        self.assertIn('event == "on_kill"', GAMEPLAY)
        self.assertIn('select(6, ...)', GAMEPLAY)
        self.assertIn('damage_profile and damage_profile.charge_value', GAMEPLAY)
        self.assertIn('killing_blow[DamageDataIndex.ATTACK_TYPE]', GAMEPLAY)
        self.assertIn('opportunism_active_time[owner_unit] == t', GAMEPLAY)
        self.assertIn('opportunism_proc_depth[owner_unit]', GAMEPLAY)
        self.assertIn('healer_unit == owner_unit', GAMEPLAY)
        self.assertIn('heal_type == "heal_from_proc"', GAMEPLAY)
        self.assertIn('heal_amount = heal_amount * 2', GAMEPLAY)

    def test_poison_filter_heals_are_host_authoritative_and_throttled(self):
        self.assertIn('has_buff_type("pusfume_run_it_through_a_filter")', GAMEPLAY)
        self.assertIn('if not Managers.player or not Managers.player.is_server then', GAMEPLAY)
        self.assertRegex(GAMEPLAY, r'poison_damage_types\s*=\s*\{[^}]*aoe_poison_dot\s*=\s*true')
        self.assertIn('poison_filter_next_heal[owner_unit] = t + 1', GAMEPLAY)
        self.assertIn('DamageUtils.heal_network(owner_unit, owner_unit, 3, "heal_from_proc")', GAMEPLAY)

    def test_enhanced_cunning_uses_server_overheal_and_native_cooldown(self):
        self.assertIn('mod:hook(PlayerUnitHealthExtension, "add_heal"', GAMEPLAY)
        self.assertIn('health_extension.is_server and is_pusfume_unit(owner_unit)', GAMEPLAY)
        self.assertIn('heal_type == "heal_from_proc"', GAMEPLAY)
        self.assertIn('health_extension:get_max_health()', GAMEPLAY)
        self.assertIn('health_extension:current_health()', GAMEPLAY)
        self.assertIn('reduce_owner_cooldown_percent(owner_unit, 0.02)', GAMEPLAY)
        self.assertIn('"rpc_reduce_activated_ability_cooldown_percent"', GAMEPLAY)
        self.assertIn('owner_player:network_id()', GAMEPLAY)


if __name__ == "__main__":
    unittest.main()
