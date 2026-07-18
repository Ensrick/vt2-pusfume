from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WEAPONS = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_weapons.lua").read_text()
BACKEND = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_backend.lua").read_text()
REGISTRY = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_registry.lua").read_text()
UI = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_ui.lua").read_text()


class WeaponContractTests(unittest.TestCase):
    def test_prototype_items_use_shipped_rat_units_with_safe_hero_actions(self):
        self.assertIn("wpn_skaven_packmaster_claw", WEAPONS)
        self.assertIn("wpn_skaven_warpfiregun", WEAPONS)
        self.assertIn("two_handed_axes_template_1", WEAPONS)
        self.assertIn("drakegun_template_1", WEAPONS)
        self.assertNotIn('template = "vs_packmaster_claw"', WEAPONS)
        self.assertNotIn('template = "vs_warpfire_thrower_gun"', WEAPONS)

    def test_weapon_items_are_pusfume_only_and_ranger_weapons_are_not_inherited(self):
        self.assertEqual(WEAPONS.count("can_wield = { registry.CAREER_NAME }"), 2)
        self.assertIn(
            'local is_weapon = item.slot_type == "melee" or item.slot_type == "ranged"',
            REGISTRY,
        )
        self.assertIn("if not is_weapon and type(can_wield)", REGISTRY)

    def test_custom_items_have_network_and_backend_registration(self):
        self.assertIn("append_lookup(NetworkLookup.item_names, item_key)", WEAPONS)
        self.assertIn("append_lookup(NetworkLookup.damage_sources, item_key)", WEAPONS)
        self.assertIn("weapons.inject_backend_items", BACKEND)
        self.assertIn("weapons.backend_id_for_slot(slot_name)", BACKEND)
        self.assertIn("weapons.overlay_loadout_collection", BACKEND)

    def test_old_weapon_visibility_diagnostics_are_disabled(self):
        self.assertNotIn("Unit.set_unit_visibility(weapon_unit, false)", UI)
        self.assertIn(
            'hide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON, false)',
            (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_native.lua").read_text(),
        )


if __name__ == "__main__":
    unittest.main()
