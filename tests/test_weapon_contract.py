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

    def test_custom_items_are_complete_clones_of_the_native_versus_records(self):
        self.assertIn("local melee = deep_clone(packmaster_item)", WEAPONS)
        self.assertIn("local ranged = deep_clone(warpfire_item)", WEAPONS)
        self.assertIn("melee.source_item = M.VERSUS_ITEM_KEYS.slot_melee", WEAPONS)
        self.assertIn("ranged.source_item = M.VERSUS_ITEM_KEYS.slot_ranged", WEAPONS)
        self.assertIn("melee.mechanisms = nil", WEAPONS)
        self.assertIn("ranged.mechanisms = nil", WEAPONS)

    def test_hero_actions_always_have_a_matching_wielded_hand_unit(self):
        self.assertIn("action_hand_contract_ready", WEAPONS)
        self.assertIn('local hand = action.weapon_action_hand or "right"', WEAPONS)
        ranged = WEAPONS[WEAPONS.index("[M.ITEM_KEYS.slot_ranged]") :]
        self.assertIn("local ranged = deep_clone(warpfire_item)", WEAPONS)
        self.assertNotIn("ranged.right_hand_unit =", ranged)

    def test_warpfire_uses_native_versus_actions_with_adventure_inputs(self):
        self.assertIn("adapt_warpfire_template", WEAPONS)
        self.assertIn("template.actions.dark_pact_action_one", WEAPONS)
        self.assertIn("hero_warpfire_condition", WEAPONS)
        self.assertIn("template.actions.action_one = action_one", WEAPONS)
        self.assertIn("template.actions.weapon_reload = action_reload", WEAPONS)
        self.assertIn('"action_one_hold"', WEAPONS)
        self.assertIn('"weapon_reload_hold"', WEAPONS)
        self.assertIn("template.synced_states.priming.enter = nil", WEAPONS)
        self.assertNotIn("template.synced_states = nil", WEAPONS)

    def test_warpfire_has_a_pusfume_only_adventure_enemy_target_adapter(self):
        self.assertIn("pusfume_warpfire_targets", WEAPONS)
        self.assertIn("side:enemy_units()", WEAPONS)
        self.assertIn("DamageUtils.is_enemy(player_unit, target_unit)", WEAPONS)
        self.assertIn("PerceptionUtils.is_position_in_line_of_sight", WEAPONS)
        self.assertIn('career_extension:career_name() == installed_registry.CAREER_NAME', WEAPONS)
        self.assertIn('mod:hook(ActionWarpfireThrower, "fire"', WEAPONS)
        self.assertIn("DamageUtils.add_damage_network(target.unit, owner_unit, 2", WEAPONS)
        self.assertIn('"warpfire_ground"', WEAPONS)
        self.assertIn("M.ITEM_KEYS.slot_ranged", WEAPONS)

    def test_packmaster_hook_keeps_safe_sweeps_and_animates_the_native_claw(self):
        self.assertIn("add_packmaster_weapon_events", WEAPONS)
        self.assertIn('action.kind == "sweep"', WEAPONS)
        self.assertIn('weapon_anim_event(owner_unit, "attack_grab")', WEAPONS)

    def test_warpfire_guards_pactsworn_only_status_api_in_adventure(self):
        self.assertIn(
            'type(status_extension.is_climbing) == "function"',
            WEAPONS,
        )
        self.assertIn("hero_warpfire_reload_condition", WEAPONS)
        self.assertEqual(
            WEAPONS.count(
                'type(overcharge_extension.get_overcharge_value) == "function"'
            ),
            2,
        )

    def test_packmaster_adapter_removes_hero_only_hit_animation_events(self):
        self.assertIn("sanitize_packmaster_melee_actions", WEAPONS)
        self.assertIn("PACKMASTER_UNSAFE_HIT_ANIMATION_FIELDS", WEAPONS)
        for field_name in (
            "dual_hit_stop_anims",
            "first_person_hit_anim",
            "hit_armor_anim",
            "hit_shield_stop_anim",
            "hit_stop_anim",
            "hit_stop_kill_anim",
        ):
            self.assertIn(f'"{field_name}"', WEAPONS)
        self.assertIn("action[field_name] = nil", WEAPONS)

    def test_weapon_items_are_pusfume_only_and_ranger_weapons_are_not_inherited(self):
        self.assertEqual(WEAPONS.count("can_wield = { registry.CAREER_NAME }"), 2)
        self.assertIn(
            'local is_weapon = item.slot_type == "melee" or item.slot_type == "ranged"',
            REGISTRY,
        )
        self.assertIn("if not is_weapon and type(can_wield)", REGISTRY)
        self.assertIn('"can_wield_by_current_hero", "can_wield_by_current_career"', BACKEND)
        self.assertIn('string.find(item_filter, "slot_type == melee"', BACKEND)
        self.assertIn('string.find(item_filter, "slot_type == ranged"', BACKEND)
        runtime_install = BACKEND[BACKEND.index("function M.install_runtime_guards") :]
        install_call = runtime_install.index("install_weapon_grid_guard(registry)")
        early_return = runtime_install.index("if status.runtime_guards_installed then")
        self.assertLess(install_call, early_return)

    def test_custom_items_have_network_and_backend_registration(self):
        self.assertIn("append_lookup(NetworkLookup.item_names, item_key)", WEAPONS)
        self.assertIn("append_lookup(NetworkLookup.damage_sources, item_key)", WEAPONS)
        self.assertIn("weapons.inject_backend_items", BACKEND)
        self.assertIn("weapons.backend_id_for_slot(slot_name)", BACKEND)
        self.assertIn("weapons.overlay_loadout_collection", BACKEND)

    def test_old_weapon_visibility_diagnostics_are_disabled(self):
        self.assertNotIn("Unit.set_unit_visibility(weapon_unit, false)", UI)
        self.assertIn(
            "extension:unhide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON)",
            (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_native.lua").read_text(),
        )


if __name__ == "__main__":
    unittest.main()
