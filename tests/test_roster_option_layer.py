from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODS = ROOT / "pusfume/scripts/mods/pusfume"
CONFIG = (MODS / "_pusfume_roster_config.lua").read_text()
ROSTER = (MODS / "_pusfume_roster.lua").read_text()
MAIN = (MODS / "pusfume.lua").read_text()
REGISTRY = (MODS / "_pusfume_registry.lua").read_text()
WEAPONS = (MODS / "_pusfume_weapons.lua").read_text()


class RosterGateTests(unittest.TestCase):
    def test_cross_character_roster_is_off_by_default(self):
        # The dev gate must ship closed until the human first-person rig lands.
        self.assertIn("open_all_hero_weapons = false", CONFIG)
        self.assertNotIn("open_all_hero_weapons = true", CONFIG)

    def test_expansion_is_gated_behind_the_flag(self):
        self.assertIn("function M.expand_can_wield(registry)", ROSTER)
        self.assertIn("if not M.open_all_hero_weapons() then", ROSTER)
        self.assertIn("config.open_all_hero_weapons == true", ROSTER)

    def test_hard_allowlist_remains_authoritative_while_closed(self):
        # The registry still refuses to inherit donor weapons, and the weapon
        # module still keeps exactly the two Pusfume-only can_wield entries; the
        # roster layer only opens weapons when the flag flips.
        self.assertIn("if not is_weapon and type(can_wield)", REGISTRY)
        self.assertEqual(WEAPONS.count("can_wield = { registry.CAREER_NAME }"), 2)


class RosterAllowlistTests(unittest.TestCase):
    def test_expansion_appends_the_career_to_hero_weapon_can_wield(self):
        # can_wield on the item is the vanilla career roster; opening a weapon is
        # appending Pusfume to it (idempotently).
        self.assertIn("item.can_wield[#item.can_wield + 1] = registry.CAREER_NAME", ROSTER)
        self.assertIn("not contains(item.can_wield, registry.CAREER_NAME)", ROSTER)

    def test_hero_weapon_predicate_uses_the_five_base_hero_profiles(self):
        for profile_name in (
            "empire_soldier",
            "dwarf_ranger",
            "bright_wizard",
            "wood_elf",
            "witch_hunter",
        ):
            self.assertIn(f'"{profile_name}"', ROSTER)
        self.assertIn("PROFILES_BY_NAME", ROSTER)
        self.assertIn('item.slot_type ~= "melee" and item.slot_type ~= "ranged"', ROSTER)
        self.assertIn("can_wield == CanWieldAllItemTemplates", ROSTER)

    def test_roster_enumerates_usable_keys_per_slot(self):
        self.assertIn("function M.hero_weapon_item_keys(slot_name)", ROSTER)
        self.assertIn('slot_name == "slot_melee" and "melee"', ROSTER)
        self.assertIn('slot_name == "slot_ranged" and "ranged"', ROSTER)


class RosterWireSafetyTests(unittest.TestCase):
    def test_all_three_networked_3p_send_paths_are_guarded(self):
        self.assertIn('mod:hook(WeaponUnitExtension, "_play_3p_anim"', ROSTER)
        self.assertIn('"_play_end_event_3p", "trigger_anim_event"', ROSTER)

    def test_guard_probes_networklookup_without_raising(self):
        # rawget bypasses the raising __index so the probe cannot itself crash.
        self.assertIn("rawget(NetworkLookup.anims, event)", ROSTER)
        self.assertIn("networked_event_missing", ROSTER)

    def test_guard_is_scoped_to_pusfume_owner_units(self):
        self.assertIn("is_pusfume_owner", ROSTER)
        self.assertIn('ScriptUnit.has_extension(owner_unit, "career_system")', ROSTER)
        self.assertIn(":career_name() == state.career_name", ROSTER)

    def test_wire_safety_installs_regardless_of_the_flag(self):
        # Crash floor: install_wire_safety runs before the flag is consulted.
        install = ROSTER[ROSTER.index("function M.install(registry)") :]
        wire = install.index("M.install_wire_safety(registry)")
        expand = install.index("M.expand_can_wield(registry)")
        self.assertLess(wire, expand)


class RosterWiringTests(unittest.TestCase):
    def test_main_dofiles_and_installs_the_roster(self):
        self.assertIn('mod:dofile("scripts/mods/pusfume/_pusfume_roster")', MAIN)
        self.assertEqual(MAIN.count("roster.install(registry)"), 2)


if __name__ == "__main__":
    unittest.main()
