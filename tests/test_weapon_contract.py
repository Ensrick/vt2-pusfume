from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WEAPONS = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_weapons.lua").read_text()
BACKEND = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_backend.lua").read_text()
REGISTRY = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_registry.lua").read_text()
UI = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_ui.lua").read_text()


class WeaponContractTests(unittest.TestCase):
    def test_prototype_items_use_shipped_rat_units_with_safe_hero_actions(self):
        self.assertIn('slot_melee = "vs_packmaster_claw"', WEAPONS)
        self.assertIn('slot_ranged = "vs_warpfire_thrower_gun"', WEAPONS)
        self.assertIn("ItemMasterList", WEAPONS)
        self.assertIn("two_handed_axes_template_1", WEAPONS)
        self.assertIn("Weapons.vs_warpfire_thrower_gun", WEAPONS)
        self.assertNotIn('template = "vs_packmaster_claw"', WEAPONS)
        self.assertNotIn('template = "vs_warpfire_thrower_gun"', WEAPONS)

    def test_hero_actions_always_have_a_matching_wielded_hand_unit(self):
        self.assertIn("action_hand_contract_ready", WEAPONS)
        self.assertIn('local hand = action.weapon_action_hand or "right"', WEAPONS)
        ranged = WEAPONS[WEAPONS.index("[M.ITEM_KEYS.slot_ranged]") :]
        self.assertIn("left_hand_unit = warpfire_item.left_hand_unit", ranged)
        self.assertNotIn("right_hand_unit = warpfire_item", ranged)

    def test_warpfire_uses_native_versus_actions_without_adventure_only_dependencies(self):
        self.assertIn("sanitize_warpfire_template", WEAPONS)
        self.assertIn("template.actions.dark_pact_action_one", WEAPONS)
        self.assertIn("hero_warpfire_condition", WEAPONS)
        self.assertIn("template.synced_states = nil", WEAPONS)

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
